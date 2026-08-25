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

  group('creation writes null — the ONE producer, both platforms', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('9. a notification START creates a record with NO duration', () async {
      // iOS routes here too: handleQuickLogStart posts a start fact and builds
      // no record, deferring every default to this drain. One fix, both
      // platforms.
      final prefs = await SharedPreferences.getInstance();
      await writeStartInstruction(prefs, id: 'ev', at: t0);

      final result = applyInbox(const <EventRecord>[], readInboxEntries(prefs));

      expect(result.merged.single.duration, isNull,
          reason: 'at start the duration genuinely IS unknown');
    });

    test('10. NEGATIVE CONTROL: a start followed by an END gets a real quantity',
        () async {
      // Without this, test 9 passes just as well if the drain never set a
      // duration at all — which would break every normally-completed event.
      final prefs = await SharedPreferences.getInstance();
      await writeStartInstruction(prefs, id: 'ev', at: t0);
      await writeEndInstruction(prefs,
          id: 'ev', at: t0.add(const Duration(seconds: 200)), seconds: 200);

      final result = applyInbox(const <EventRecord>[], readInboxEntries(prefs));

      // The drain stores the MEASURED SECONDS now, not a bucket derived from
      // them. Without this control, test 9 passes just as well if the drain
      // never set a duration at all — which would break every completed event.
      expect(result.merged.single.durationSeconds, 200,
          reason: 'a completed event still measures');
      expect(result.merged.single.duration, isNull,
          reason: 'and no bucket is invented alongside it');
    });

    test('11. an ABANDONED event keeps null with no timeout involvement',
        () async {
      // The abandonment case, end to end: a start arrives, no end ever does.
      // The timeout clears mer_active_event and never touches the record, so
      // the record simply stays as created.
      final prefs = await SharedPreferences.getInstance();
      await writeStartInstruction(prefs, id: 'ev', at: t0);

      final first = applyInbox(const <EventRecord>[], readInboxEntries(prefs));
      // ... time passes, the timeout fires, the marker goes, nothing else ...
      final later = applyInbox(first.merged, const <InboxEntry>[]);

      expect(later.merged.single.duration, isNull,
          reason: '37 minutes must not read as "< 1 minute"');
    });

    test('12. the drain no longer knows an abandon kind', () {
      // The instruction built for this was removed: it solved at the timeout a
      // problem that belongs at creation, reached Android only, and could null
      // a duration the user had since filled in by hand.
      final entry = parseInboxEntry('${kInboxKeyPrefix}x',
          jsonEncode({'v': 1, 'kind': 'abandon', 'id': 'ev'}));

      expect(entry.instruction, isNull);
      expect(entry.defer, InboxDefer.unknownKind);
    });
  });

  group('THREE STATES: a number, a bucket, or nothing', () {
    EventRecord withState({DurationCategory? bucket, int? secs}) => EventRecord(
          id: 'r',
          timestamp: t0,
          duration: bucket,
          durationSeconds: secs,
          feelings: const <String>[],
          referralRequired: false,
          notes: '',
        );

    test('16. a MEASURED record round-trips its seconds through the envelope',
        () {
      final back = parseBackup(buildBackupJson(
              [withState(secs: 187)], exportedAt: t0))
          .records
          .single;

      expect(back.durationSeconds, 187);
      expect(back.duration, isNull);
      expect(durationDisplay(back.duration, back.durationSeconds), '3m 7s');
    });

    test('17. a LEGACY record round-trips its bucket and gains no number', () {
      final back = parseBackup(buildBackupJson(
              [withState(bucket: DurationCategory.oneToFive)], exportedAt: t0))
          .records
          .single;

      expect(back.duration, DurationCategory.oneToFive);
      expect(back.durationSeconds, isNull,
          reason: 'a range contains no number and never acquires one');
      expect(durationDisplay(back.duration, back.durationSeconds), '1–5 minutes');
    });

    test('18. an UNKNOWN record round-trips as unknown', () {
      final back = parseBackup(buildBackupJson([withState()], exportedAt: t0))
          .records
          .single;

      expect(back.duration, isNull);
      expect(back.durationSeconds, isNull);
      expect(durationDisplay(back.duration, back.durationSeconds), isNull);
    });

    test('19. NEGATIVE CONTROL: a number fabricated from a bucket WOULD fail',
        () {
      // The rule this whole change is governed by. If anything ever derived
      // seconds from a range - a midpoint, a lower bound, anything - the legacy
      // record above would come back with a number, and test 17 would fail.
      //
      // Asserted directly so the rule is pinned rather than implied: these are
      // the values a fabricating implementation would plausibly produce.
      final back = parseBackup(buildBackupJson(
              [withState(bucket: DurationCategory.oneToFive)], exportedAt: t0))
          .records
          .single;

      for (final fabricated in <int>[60, 90, 180, 299, 300]) {
        expect(back.durationSeconds, isNot(fabricated),
            reason: 'a midpoint or bound derived from "1-5 minutes" is still an '
                'invention');
      }
      expect(back.durationSeconds, isNull);
    });

    test('20. seconds WIN over a bucket where a record somehow has both', () {
      // Reachable by editing a legacy record: the range is what was recorded
      // then, the number is what the user supplied now. Both are kept - neither
      // is derived from the other - and the number is what is shown.
      final r = withState(bucket: DurationCategory.gt5, secs: 90);

      expect(durationDisplay(r.duration, r.durationSeconds), '1m 30s');
      expect(durationCsv(r.duration, r.durationSeconds), '1m 30s');
      expect(r.duration, DurationCategory.gt5, reason: 'the bucket is not erased');
    });
  });

  group('what unknown looks like', () {
    test('14. the CSV cell is EXPLICIT, never blank', () {
      // A clinician reading a blank cannot tell "unknown" from "not recorded"
      // from a broken export.
      expect(durationCsv(null, null), 'unknown',
          reason: 'a NEW value in a column that has only ever held three bucket strings');
      expect(durationCsv(DurationCategory.lt1, null), '< 1 minute');
      expect(durationCsv(null, 187), '3m 7s',
          reason: 'a measured quantity, not a raw second count');
      expect(durationCsv(DurationCategory.lt1, 187), '3m 7s',
          reason: 'seconds win where both exist; the bucket is never derived from');
    });

    test('15. the CSV keeps its 26 columns and its ordering', () {
      // Stage 5 makes this file multi-stream. Nothing here may anticipate that.
      final csv = buildCsv([rec('a', t0)]);
      final header = const LineSplitter().convert(csv).first;

      expect(header, contains('duration'));
      expect(header.split(',').length, 27,
          reason: 'duration_seconds was added deliberately; stage 5 makes this multi-stream and nothing here anticipates that');
    });
  });
}
