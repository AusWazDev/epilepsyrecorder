// Brief 223, 28 September 2026: the two daylight-saving transitions.
//
//   4 Oct 2026  AEST -> AEDT  clocks FORWARD  02:00-03:00 does not exist
//   4 Apr 2027  AEDT -> AEST  clocks BACK     02:00-03:00 happens twice
//
// ⛔ THE ZONE CANNOT BE FIXED FROM INSIDE THE TEST ON WINDOWS. Dart takes local
// time from the OS and ignores `TZ` there. So every test starts with
// [requireMelbourneRules], which FAILS (never skips) unless the host applies
// those two transitions. A host in any other zone goes red with that reason,
// so this file cannot pass by being somewhere else. On the Mac run it as
// `TZ=Australia/Melbourne flutter test test/dst_melbourne_test.dart`.
//
// Everything here drives the app's own parse and encode functions. Nothing
// restates them.

import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/capture_instruction.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';

void requireMelbourneRules() {
  final offsets = <int>[
    DateTime(2026, 10, 4, 1, 59).timeZoneOffset.inHours,
    DateTime(2026, 10, 4, 3, 1).timeZoneOffset.inHours,
    DateTime(2027, 4, 4, 1, 0).timeZoneOffset.inHours,
    DateTime(2027, 4, 4, 4, 0).timeZoneOffset.inHours,
  ];
  expect(offsets, <int>[10, 11, 11, 10],
      reason: 'HOST ZONE: these tests need a host applying Melbourne\'s '
          'transitions (4 Oct 2026 forward, 4 Apr 2027 back). This host does '
          'not, so nothing below would be a measurement.');
}

EventRecord rec(String id, DateTime t, {DateTime? occurred}) => EventRecord(
      id: id,
      timestamp: t,
      occurredAt: occurred,
      duration: DurationCategory.lt1,
      durationSeconds: 40,
      eventType: 'seizure',
      severity: EventSeverity.mild,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: false,
      notes: '',
      detailsCompleted: true,
    );

/// Through the prefs store's encode and decode.
EventRecord viaPrefs(EventRecord r) => EventRecord.fromMap(r.toMap())!;

/// Through the SQLite store's encode and decode.
EventRecord viaSqlite(EventRecord r) => eventFromRow(eventToRow(r, 0))!;

void main() {
  group('4 October 2026: the skipped hour', () {
    test('1.1 a local 02:30 chosen in the picker becomes 03:30, not refused',
        () {
      requireMelbourneRules();
      // The expression `OccurredAtField._pick` builds from the two pickers.
      final chosen = DateTime(2026, 10, 4, 2, 30);
      expect(chosen.hour, 3,
          reason: 'SKIPPED: a non-existent 02:30 is moved forward to 03:30');
      expect(chosen.isAfter(DateTime(2026, 10, 5)), isFalse,
          reason: 'and the only refusal, "has not happened yet", does not apply');
      expect(viaSqlite(rec('a', chosen)).timestamp.hour, 3,
          reason: 'SKIPPED: what is stored and read back is 03:30');
    });

    test('1.2 no UTC instant maps into the gap, and every one round-trips',
        () {
      requireMelbourneRules();
      for (var m = 0; m <= 120; m++) {
        final instant = DateTime.utc(2026, 10, 3, 15).add(Duration(minutes: m));
        final local = instant.toLocal();
        expect(local.day == 4 && local.hour == 2, isFalse,
            reason: 'SKIPPED: $instant must not become a 02:xx local time');
        final back = viaSqlite(rec('a', local)).timestamp;
        expect(back.toUtc(), instant,
            reason: 'SKIPPED: $instant must survive the store unchanged');
        expect(viaPrefs(rec('a', local)).timestamp.toUtc(), instant,
            reason: 'SKIPPED: and the prefs store');
        // A UTC string, as iOS native capture writes it.
        expect(viaPrefs(rec('a', instant)).timestamp.toUtc(), instant,
            reason: 'SKIPPED: a UTC-written record survives as well');
      }
    });

    test('1.3 order and the CSV across the boundary', () {
      requireMelbourneRules();
      final before = DateTime.utc(2026, 10, 3, 15, 50).toLocal(); // 01:50 AEST
      final after = DateTime.utc(2026, 10, 3, 16, 10).toLocal(); //  03:10 AEDT
      final back = <EventRecord>[viaSqlite(rec('b', before)), viaSqlite(rec('a', after))]
        ..sort((x, y) => x.whenHappened.compareTo(y.whenHappened));
      expect(back.map((r) => r.id), <String>['b', 'a'],
          reason: 'SKIPPED: order holds across the jump');
      expect(after.difference(before), const Duration(minutes: 20),
          reason: 'SKIPPED: elapsed time is real time, 20 minutes, not 80');
      final row = buildCsv(<EventRecord>[rec('a', after)]).split('\n')[1];
      expect(row.startsWith('2026-10-04T03:10:00.000,'), isTrue,
          reason: 'CSV: timestamp_iso is naive local, with NO offset. row=$row');
    });
  });

  group('4 April 2027: the repeated hour', () {
    final first = DateTime.utc(2027, 4, 3, 15, 30).toLocal(); //  02:30 AEDT
    final second = DateTime.utc(2027, 4, 3, 16, 30).toLocal(); // 02:30 AEST

    test('2.1 the two 02:30s are stored as the SAME string', () {
      requireMelbourneRules();
      expect(second.difference(first), const Duration(hours: 1),
          reason: 'CONTROL: they are an hour apart');
      expect(eventToRow(rec('a', first), 0)['logged_at'],
          eventToRow(rec('b', second), 0)['logged_at'],
          reason: 'REPEATED: storage cannot tell them apart');
      expect(rec('a', first).toMap()['timestamp'], rec('b', second).toMap()['timestamp'],
          reason: 'REPEATED: and neither can the prefs store');
    });

    test('2.2 the second one comes back an hour EARLY', () {
      requireMelbourneRules();
      expect(viaSqlite(rec('a', first)).timestamp.toUtc(), first.toUtc(),
          reason: 'CONTROL: the first occurrence survives');
      expect(viaSqlite(rec('b', second)).timestamp.toUtc(),
          second.toUtc().subtract(const Duration(hours: 1)),
          reason: 'REPEATED: the second occurrence reads back as the first');
      expect(viaPrefs(rec('b', second)).timestamp.toUtc(),
          second.toUtc().subtract(const Duration(hours: 1)),
          reason: 'REPEATED: the same through the prefs store');
    });

    test('2.2 two records in the hour swap order after a reload', () {
      requireMelbourneRules();
      final a = DateTime.utc(2027, 4, 3, 15, 45).toLocal(); // 02:45 AEDT, earlier
      final b = DateTime.utc(2027, 4, 3, 16, 15).toLocal(); // 02:15 AEST, later
      int byTime(EventRecord x, EventRecord y) =>
          x.whenHappened.compareTo(y.whenHappened);
      final live = <EventRecord>[rec('b', b), rec('a', a)]..sort(byTime);
      expect(live.map((r) => r.id), <String>['a', 'b'],
          reason: 'CONTROL: in memory, a happened first');
      final reloaded = <EventRecord>[viaSqlite(rec('b', b)), viaSqlite(rec('a', a))]
        ..sort(byTime);
      expect(reloaded.map((r) => r.id), <String>['b', 'a'],
          reason: 'REPEATED: after a reload, b sorts before a');
    });

    test('2.3 an Android quick-log started in the second 02:xx over-counts by '
        'an hour', () {
      requireMelbourneRules();
      final start = DateTime.utc(2027, 4, 3, 16, 40).toLocal(); // 02:40 AEST
      final end = DateTime.utc(2027, 4, 3, 17, 0).toLocal(); //    03:00 AEST
      // The End handler re-reads the start from the stored `startIso` marker.
      final restored = parseInstructionAt(start.toIso8601String())!;
      expect(end.difference(start).inSeconds, 1200,
          reason: 'CONTROL: the event lasted 20 minutes');
      expect(end.difference(restored).inSeconds, 4800,
          reason: 'REPEATED: the recorded duration is 80 minutes');
    });
  });

  group('the day arithmetic History uses', () {
    test('"Yesterday" is lost on 5 October and 5 April', () {
      requireMelbourneRules();
      // `_groupByDay`: yesterday = today.subtract(const Duration(days: 1)).
      for (final d in <DateTime>[DateTime(2026, 10, 5), DateTime(2027, 4, 5)]) {
        final yesterday = d.subtract(const Duration(days: 1));
        final prior = DateTime(d.year, d.month, d.day - 1);
        expect(yesterday == prior, isFalse,
            reason: 'DAY: on $d, midnight minus 24 hours is $yesterday, not '
                '$prior, so no header matches "Yesterday"');
      }
      final ordinary = DateTime(2026, 9, 29).subtract(const Duration(days: 1));
      expect(ordinary, DateTime(2026, 9, 28),
          reason: 'CONTROL: on an ordinary day it matches');
    });
  });

  group('1.0.2, for the record', () {
    test('a UTC-written record read the 1.0.2 way is 10 hours out in AEST and '
        '11 in AEDT', () {
      requireMelbourneRules();
      int shownEarly(DateTime instant) {
        final s = instant.toIso8601String(); // what iOS native capture wrote
        final shipped = DateTime.parse(s); //   1.0.2: no toLocal
        final now = EventRecord.fromMap(rec('x', instant).toMap())!.timestamp;
        return DateTime(now.year, now.month, now.day, now.hour)
            .difference(DateTime(shipped.year, shipped.month, shipped.day, shipped.hour))
            .inHours;
      }
      expect(shownEarly(DateTime.utc(2026, 8, 1, 2)), 10,
          reason: 'SHIPPED: AEST, displayed 10 hours early');
      expect(shownEarly(DateTime.utc(2026, 11, 1, 2)), 11,
          reason: 'SHIPPED: AEDT, displayed 11 hours early');
    });
  });
}
