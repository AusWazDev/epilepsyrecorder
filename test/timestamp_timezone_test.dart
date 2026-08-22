import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:medical_event_recorder/models/backup.dart';
import 'package:medical_event_recorder/models/event_record.dart';

/// Timestamp normalisation across the two writers.
///
/// Dart writes naive local time; native iOS capture (`AppDelegate.swift:248`,
/// `ISO8601DateFormatter`) writes UTC with a Z suffix. `DateTime.tryParse`
/// honours that difference and `DateFormat` renders whatever wall clock the
/// resulting `DateTime` carries, so before the fix a Lock Screen or Live
/// Activity event — the primary iOS capture path — displayed ten hours early in
/// AEST.
///
/// Every assertion here is written relative to the host's own zone via
/// `toLocal()`, so the suite is correct on the Mac, on Windows, and in a UTC
/// CI container. Nowhere is a +10 offset assumed; what is asserted is that a Z
/// timestamp and the same instant expressed locally are indistinguishable once
/// parsed.

/// One of the four records actually on the test device, written by Swift.
const kNativeZ = '2026-08-22T06:29:59.000Z';

/// A Dart-written record, in the shape `toIso8601String()` produces locally.
const kDartNaive = '2026-08-22T18:18:35.180820';

Map<String, dynamic> recordMap(String id, String timestamp) => {
      'id': id,
      'timestamp': timestamp,
      'duration': 'lt1',
      'feelings': <String>[],
      'referralRequired': false,
      'notes': '',
      'eventType': 'seizure',
      'severity': 'mild',
      'triggers': <String>[],
    };

EventRecord parse(String timestamp, {String id = 'r'}) =>
    EventRecord.fromMap(recordMap(id, timestamp))!;

void main() {
  group('a Z-suffixed timestamp becomes local wall clock', () {
    test('lands on the same instant, expressed locally', () {
      final r = parse(kNativeZ);
      final expected = DateTime.utc(2026, 8, 22, 6, 29, 59).toLocal();

      expect(r.timestamp.isUtc, isFalse,
          reason: 'a UTC DateTime renders its UTC wall clock through '
              'DateFormat, which is the defect');
      expect(r.timestamp, expected);
      expect(r.timestamp.isAtSameMomentAs(DateTime.utc(2026, 8, 22, 6, 29, 59)),
          isTrue,
          reason: 'normalising must not move the instant, only how it reads');
    });

    test('displays the local time, not the UTC one', () {
      final r = parse(kNativeZ);
      final shown = DateFormat('EEE d MMM yyyy, h:mm a').format(r.timestamp);
      final expected = DateFormat('EEE d MMM yyyy, h:mm a')
          .format(DateTime.utc(2026, 8, 22, 6, 29, 59).toLocal());

      expect(shown, expected);

      // In any zone east of UTC this is a different clock time from the stored
      // 6:29 AM. Skipped at UTC+0, where there is nothing to convert.
      final offset = DateTime.now().timeZoneOffset;
      if (offset != Duration.zero) {
        expect(shown, isNot(contains('6:29 AM')),
            reason: 'displaying the stored UTC clock time is the bug');
      }
    });
  });

  group('a naive local timestamp is left exactly as it was', () {
    test('parses to the same local DateTime, to the microsecond', () {
      final r = parse(kDartNaive);

      expect(r.timestamp.isUtc, isFalse);
      expect(r.timestamp, DateTime(2026, 8, 22, 18, 18, 35, 180, 820));
      expect(r.timestamp.toIso8601String(), kDartNaive,
          reason: 'a Dart-written record must round trip byte for byte, or '
              'the fix has changed existing behaviour');
    });
  });

  group('the midnight case — the shift changes the DATE, not just the time',
      () {
    // The case that would corrupt a CSV a clinician reads: a record whose
    // local date is not its UTC date. 2026-08-22T16:00:00Z is 2026-08-23 in
    // AEST (+10) and 2026-08-22 in UTC.
    const lateUtc = '2026-08-22T16:00:00.000Z';

    test('the date follows the local instant, not the stored UTC one', () {
      final r = parse(lateUtc);
      final expected = DateTime.utc(2026, 8, 22, 16, 0, 0).toLocal();

      expect(r.timestamp, expected);
      expect(DateFormat('yyyy-MM-dd').format(r.timestamp),
          DateFormat('yyyy-MM-dd').format(expected));
    });

    test('CSV carries the local date, so a day-boundary record is not '
        'misfiled', () {
      final r = parse(lateUtc);
      final expected = DateTime.utc(2026, 8, 22, 16, 0, 0).toLocal();
      final csv = buildCsv([r]);

      expect(csv, contains(DateFormat('yyyy-MM-dd').format(expected)));

      // Where the local date differs from the UTC date, the UTC date must not
      // appear in the date column. Only meaningful when the offset shifts it.
      if (expected.day != 22) {
        final dateColumn = csv.trim().split('\n').last.split(',')[1];
        expect(dateColumn, isNot('2026-08-22'),
            reason: 'the stored UTC date would put this event on the wrong '
                'day in an exported CSV');
      }
    });
  });

  group('CSV export picks the fix up with no change of its own', () {
    test('date and time columns render the normalised timestamp', () {
      final r = parse(kNativeZ);
      final expected = DateTime.utc(2026, 8, 22, 6, 29, 59).toLocal();
      final row = buildCsv([r]).trim().split('\n').last.split(',');

      // Columns are timestamp_iso, date, time, ...
      expect(row[0], expected.toIso8601String());
      expect(row[1], DateFormat('yyyy-MM-dd').format(expected));
      expect(row[2],
          DateFormat.jm().format(expected).replaceAll(' ', ' '));
    });
  });

  group('sort order is unchanged', () {
    test('mixed shapes still order by absolute instant', () {
      // Interleaved deliberately: the Z record is the EARLIEST instant but has
      // the LARGEST stored clock-time digits in a +10 zone, so a sort that
      // compared wall clocks rather than instants would misorder it.
      final records = <EventRecord>[
        parse('2026-08-22T18:18:35.180820', id: 'dart-late'),
        parse('2026-08-22T06:29:59.000Z', id: 'native-early'),
        parse('2026-08-22T17:00:12.782711', id: 'dart-mid'),
      ];

      final sorted = [...records]
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Newest first, matching EventStore.load's ordering. Which record is
      // newest depends on the host offset — a naive-local string and a UTC one
      // are different instants in every zone but UTC — so what is asserted is
      // that the order is strictly descending by instant, not a fixed lineup.
      final instants = sorted.map((r) => r.timestamp).toList();
      expect(instants[0].isAfter(instants[1]), isTrue);
      expect(instants[1].isAfter(instants[2]), isTrue);

      // The native record's instant is preserved wherever it lands in the
      // order: normalising changes how it reads, never when it happened.
      final native =
          sorted.firstWhere((r) => r.id == 'native-early').timestamp;
      expect(native.isAtSameMomentAs(DateTime.utc(2026, 8, 22, 6, 29, 59)),
          isTrue);
    });
  });

  group('backup round trip lands on the same instant', () {
    test('a Z-written record survives read, backup and restore', () {
      final original = parse(kNativeZ, id: 'native-1');

      final json = buildBackupJson([original]);
      final restored = parseBackup(json);

      expect(restored.isValid, isTrue, reason: restored.message);
      expect(restored.records, hasLength(1));
      expect(restored.records.single.timestamp
          .isAtSameMomentAs(original.timestamp), isTrue);
      expect(restored.records.single.timestamp, original.timestamp);
      expect(restored.records.single.timestamp.isUtc, isFalse);

      // The instant is still the one Swift wrote, three hops later.
      expect(
        restored.records.single.timestamp
            .isAtSameMomentAs(DateTime.utc(2026, 8, 22, 6, 29, 59)),
        isTrue,
      );
    });

    test('a naive-written record survives unchanged', () {
      final original = parse(kDartNaive, id: 'dart-1');
      final restored = parseBackup(buildBackupJson([original]));

      expect(restored.isValid, isTrue, reason: restored.message);
      expect(restored.records.single.timestamp, original.timestamp);
      expect(restored.records.single.timestamp.toIso8601String(), kDartNaive);
    });

    test('a restored backup merges by id against the same instant', () {
      // planRestore matches on id, so a record already present must not be
      // re-added just because its stored shape changed.
      final onDevice = [parse(kNativeZ, id: 'native-1')];
      final backup = parseBackup(buildBackupJson(onDevice));
      final plan = planRestore(onDevice, backup);

      expect(plan.inBackup, 1);
      expect(plan.alreadyPresent, 1);
      expect(plan.toAdd, 0);
      expect(plan.addsNothing, isTrue);
    });
  });
}
