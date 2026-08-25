import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/models/backup.dart';
import 'package:medical_event_recorder/models/capture_inbox.dart';
import 'package:medical_event_recorder/models/capture_instruction.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';

/// Stage 1a — nullable duration.
///
/// NULL means UNKNOWN: not zero, not short. Before this, an unanswered duration
/// became `lt1` — "< 1 minute" — which is wrong data and indistinguishable from
/// a real short event. Confirmed on hardware: 37 minutes recorded as
/// "< 1 minute".

EventRecord rec(String id, DateTime ts, {DurationCategory? duration}) =>
    EventRecord(
      id: id,
      timestamp: ts,
      duration: duration,
      feelings: const <String>[],
      referralRequired: false,
      notes: '',
      eventType: EventType.seizure,
      severity: EventSeverity.mild,
      triggers: const <String>[],
    );

void main() {
  final t0 = DateTime(2026, 8, 26, 9, 0);

  group('the model represents unknown', () {
    test('1. an ABSENT duration key reads as null, not lt1', () {
      final r = EventRecord.fromMap({
        'id': 'a',
        'timestamp': t0.toIso8601String(),
      });

      expect(r, isNotNull);
      expect(r!.duration, isNull,
          reason: 'the orElse that produced lt1 here is the defect');
    });

    test('2. NEGATIVE CONTROL: a present duration still reads as its bucket',
        () {
      // Without this, test 1 passes just as well if durationFromName always
      // returned null — which would silently erase every real duration.
      final r = EventRecord.fromMap({
        'id': 'a',
        'timestamp': t0.toIso8601String(),
        'duration': 'gt5',
      });

      expect(r!.duration, DurationCategory.gt5);
    });

    test('3. an UNRECOGNISED duration reads as null', () {
      final r = EventRecord.fromMap({
        'id': 'a',
        'timestamp': t0.toIso8601String(),
        'duration': 'about ten minutes',
      });

      expect(r!.duration, isNull);
    });
  });

  group('the backup envelope round-trips null', () {
    test('4. null survives backup and restore, uncoerced on both sides', () {
      final original = rec('unknown-dur', t0);
      expect(original.duration, isNull, reason: 'precondition');

      final json = buildBackupJson([original], exportedAt: t0);
      final parsed = parseBackup(json);
      final back = parsed.records.single;

      expect(parsed.problem, isNull, reason: parsed.message);
      expect(back.duration, isNull,
          reason: 'a default appearing here would be the same class of defect '
              'as the migration coercing an absent key');
    });

    test('5. NEGATIVE CONTROL: a coerced default WOULD fail this test', () {
      // Proves test 4 is discriminating. If either side defaulted to lt1, the
      // round-tripped value would equal this, and test 4 would fail — so test 4
      // passing means the value genuinely survived as null.
      const wouldBeCoercedTo = DurationCategory.lt1;

      final back =
          parseBackup(buildBackupJson([rec('x', t0)], exportedAt: t0))
              .records
              .single;

      expect(back.duration, isNot(wouldBeCoercedTo),
          reason: 'null must not equal the old default');
      expect(back.duration, isNull);
    });

    test('6. a KNOWN duration also round-trips, unchanged', () {
      final back = parseBackup(buildBackupJson(
              [rec('y', t0, duration: DurationCategory.oneToFive)],
              exportedAt: t0))
          .records
          .single;

      expect(back.duration, DurationCategory.oneToFive);
    });
  });

  group('SQLite round-trips null', () {
    test('7. eventToRow writes NULL and eventFromRow reads it back', () {
      final row = eventToRow(rec('z', t0), 0);
      expect(row['duration_bucket'], isNull);

      final back = eventFromRow(row);
      expect(back!.duration, isNull);
    });

    test('8. NEGATIVE CONTROL: a known bucket survives the same path', () {
      final row = eventToRow(rec('z', t0, duration: DurationCategory.gt5), 0);
      expect(row['duration_bucket'], 'gt5');
      expect(eventFromRow(row)!.duration, DurationCategory.gt5);
    });
  });

  group('the abandonment timeout', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('9. an abandon instruction sets the duration to null', () async {
      final prefs = await SharedPreferences.getInstance();
      await writeAbandonInstruction(prefs, id: 'ev', at: t0);

      // The record as the notification start created it: lt1 by default.
      final existing = [rec('ev', t0, duration: DurationCategory.lt1)];
      final result = applyInbox(existing, readInboxEntries(prefs));

      expect(result.merged.single.duration, isNull,
          reason: 'the whole point: unknown, not "< 1 minute"');
      expect(result.changed, isTrue);
      expect(result.drainableKeys, hasLength(1));
    });

    test('10. a real END beats an abandon for the same id', () async {
      // Both present: the event WAS finished and the timeout lost the race.
      // Setting null here would destroy a known duration.
      final prefs = await SharedPreferences.getInstance();
      await writeEndInstruction(prefs,
          id: 'ev', at: t0.add(const Duration(seconds: 200)), seconds: 200);
      await writeAbandonInstruction(prefs, id: 'ev', at: t0);

      final result = applyInbox(
          [rec('ev', t0, duration: DurationCategory.lt1)],
          readInboxEntries(prefs));

      expect(result.merged.single.duration, DurationCategory.oneToFive,
          reason: '200s is 1-5 minutes; the end must win');
    });

    test('11. a repeated abandon is idempotent', () async {
      final prefs = await SharedPreferences.getInstance();
      await writeAbandonInstruction(prefs, id: 'ev', at: t0);
      await writeAbandonInstruction(prefs, id: 'ev', at: t0);

      final result =
          applyInbox([rec('ev', t0, duration: DurationCategory.lt1)],
              readInboxEntries(prefs));

      expect(result.merged, hasLength(1));
      expect(result.merged.single.duration, isNull);
    });

    test('12. an abandon for a record that does not exist is an orphan',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await writeAbandonInstruction(prefs, id: 'gone', at: t0);

      final result = applyInbox(const <EventRecord>[], readInboxEntries(prefs));

      expect(result.orphanEndIds, contains('gone'));
      expect(result.merged, isEmpty, reason: 'never invent a record');
    });

    test('13. an OLDER build defers the abandon rather than misreading it',
        () async {
      // Forward compatibility, and the reason this is a new KIND rather than an
      // `end` with seconds omitted: a build that does not know `abandon` leaves
      // the key in place untouched.
      final entry = parseInboxEntry('${kInboxKeyPrefix}x',
          jsonEncode({'v': 1, 'kind': 'abandon-from-the-future', 'id': 'ev'}));

      expect(entry.instruction, isNull);
      expect(entry.defer, InboxDefer.unknownKind);
    });
  });

  group('what unknown looks like', () {
    test('14. the CSV cell is EXPLICIT, never blank', () {
      // A clinician reading a blank cannot tell "unknown" from "not recorded"
      // from a broken export.
      expect(durationCsv(null), 'Unknown');
      expect(durationCsv(DurationCategory.lt1), '< 1 minute');
    });

    test('15. the CSV keeps its 26 columns and its ordering', () {
      // Stage 5 makes this file multi-stream. Nothing here may anticipate that.
      final csv = buildCsv([rec('a', t0)]);
      final header = const LineSplitter().convert(csv).first;

      expect(header, contains('duration'));
      expect(header.split(',').length, 26,
          reason: 'stage 5 makes this multi-stream; nothing here anticipates it');
    });
  });
}
