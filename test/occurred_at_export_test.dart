import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/duration_format.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/medication_note.dart';

/// `occurred_at`, and the two things a header golden cannot check.
///
/// ## ⛔ WHY THIS FILE EXISTS SEPARATELY FROM `csv_delimited_test`
///
/// That file pins the COLUMN SET and calls itself "the mechanical enforcement
/// of the marker rule". It is, for adding, removing, renaming and reordering.
/// **It is blind to a column that keeps its name and changes what it holds** —
/// and v6 is exactly that change, so the golden passed across it unmodified.
///
/// A declared scope reports clean on everything outside itself. The scope here
/// is stated the other way round: build a record whose two times DIFFER, and
/// assert which one reaches the file.
///
/// ## ⛔ AND THE NULL CASE IS THE MORE IMPORTANT HALF
///
/// `occurredAt` is null on every record written before 29 Aug 2026, so the
/// coalesce must be a no-op for all of them. If it is not, this change
/// rewrites 72 records' apparent times. That is test 1, and it is deliberately
/// first.
void main() {
  EventRecord rec({DateTime? occurred}) => EventRecord(
        id: 'e1',
        timestamp: DateTime(2026, 8, 29, 21, 30),
        occurredAt: occurred,
        duration: null,
        durationSeconds: 5400,
        feelings: const <String>[],
        triggers: const <String>[],
        referralRequired: false,
        notes: '',
        eventType: 'seizure',
      );

  String cell(String csv, int i) =>
      csv.split('\n')[1].split(',')[i].replaceAll('"', '');

  group('NULL IS A NO-OP — the existing history does not move', () {
    test('1. whenHappened falls back to the log time', () {
      final r = rec();
      expect(r.occurredAt, isNull);
      expect(r.whenHappened, r.timestamp);
      expect(r.isBackdated, isFalse);
    });

    test('2. and the CSV is byte-identical to the logged time', () {
      final csv = buildCsv(<EventRecord>[rec()]);
      expect(cell(csv, 0), DateTime(2026, 8, 29, 21, 30).toIso8601String(),
          reason: 'a record with no occurred time must export exactly as '
              'before, or v6 silently restates 72 records');
    });
  });

  group('⛔ THE MEANING OF COLUMN 1 — what the golden cannot see', () {
    test('3. a backdated record exports WHEN IT HAPPENED, not when logged',
        () {
      final happened = DateTime(2026, 8, 27, 16, 41);
      final csv = buildCsv(<EventRecord>[rec(occurred: happened)]);

      expect(cell(csv, 0), happened.toIso8601String());
      expect(cell(csv, 0), isNot(contains('2026-08-29')),
          reason: 'NEGATIVE CONTROL: the log time must not be in column 1');
      // The readable date column follows column 0. Format read from the
      // export rather than assumed — the first draft of this line guessed
      // dd/MM/yyyy and the export writes ISO.
      expect(cell(csv, 1), '2026-08-27');
    });

    test('4. the header is UNCHANGED, which is the whole point', () {
      final a = buildCsv(<EventRecord>[rec()]).split('\n').first;
      final b = buildCsv(<EventRecord>[rec(occurred: DateTime(2026, 8, 27))])
          .split('\n')
          .first;
      expect(a, b,
          reason: 'the column set is identical either way — so a header test '
              'could never have caught this, and the marker had to move on a '
              'meaning change');
      expect(kCsvShapeVersion, 'v6');
    });

    test('5. events and medication notes now agree on what column 1 means',
        () {
      // The defect v6 fixes: an event row wrote its LOG time here while a
      // medication row wrote its OCCURRED time, so the two kinds interleaved
      // on different clocks in one sorted file.
      final happened = DateTime(2026, 8, 27, 16, 41);
      final note = MedicationNote(
        id: 'm1',
        occurredAt: DateTime(2026, 8, 27, 8, 0),
        loggedAt: DateTime(2026, 8, 29, 21, 30),
        kind: MedicationDeviation.missed,
        notes: '',
      );
      final csv = buildCsv(<EventRecord>[rec(occurred: happened)],
          notes: <MedicationNote>[note]);
      final lines = csv.split('\n').where((l) => l.trim().isNotEmpty).toList();

      // Sorted together on one timeline: the 08:00 note precedes the 16:41
      // event. Under the old behaviour the event carried 29 Aug and sorted
      // after it on a different day entirely.
      expect(lines[1], contains('2026-08-27T08:00'));
      expect(lines[2], contains('2026-08-27T16:41'));
    });
  });

  group('THE ROUND TRIP', () {
    test('6. toMap/fromMap carry it, and null stays null', () {
      final happened = DateTime(2026, 8, 27, 16, 41);
      final back = EventRecord.fromMap(rec(occurred: happened).toMap());
      expect(back!.occurredAt, happened);

      final plain = EventRecord.fromMap(rec().toMap());
      expect(plain!.occurredAt, isNull);
    });

    test('7. the KEY is always written, even as null', () {
      // Same rule as `severity` and `triggers`: a reader must be able to tell
      // "asked and unanswered" from a payload that predates the field.
      expect(rec().toMap().containsKey('occurredAt'), isTrue);
      expect(rec().toMap()['occurredAt'], isNull);
    });

    test('8. a payload PREDATING the field reads as null, not as an error',
        () {
      final map = rec().toMap()..remove('occurredAt');
      final back = EventRecord.fromMap(map);
      expect(back, isNotNull);
      expect(back!.occurredAt, isNull);
      expect(back.whenHappened, back.timestamp);
    });

    test('9. the backup envelope bumped, so an older build REFUSES', () {
      expect(kBackupSchemaVersion, 4);
    });
  });

  group('THE HOURS UNIT — wrong on the shipped set, not a hypothetical one',
      () {
    test('10. durations over an hour read in hours', () {
      expect(durationSecondsLabel(5400), '1h 30m');
      expect(durationSecondsLabel(14400), '4h');
      expect(durationSecondsLabel(259200), '72h');
    });

    test('11. under an hour is UNCHANGED', () {
      expect(durationSecondsLabel(7), '7s');
      expect(durationSecondsLabel(180), '3m');
      expect(durationSecondsLabel(187), '3m 7s');
      expect(durationSecondsLabel(3599), '59m 59s');
    });

    test('12. the clamp is untouched and now matches its own docstring', () {
      // The doc has said "the upper bound is 99 hours" since the seconds
      // migration, while the code could not render an `h` at all. 359999s
      // used to read `5999m 59s`.
      expect(durationSecondsLabel(359999), '99h 59m');
      expect(durationSecondsLabel(432000), '99h 59m',
          reason: 'still clamped — a timer past 99h is a clock fault');
      expect(durationSecondsLabel(-5), '0s');
    });

    test('13. the CLAMP IS DISPLAY ONLY — the number survives export', () {
      final r = EventRecord(
        id: 'e2',
        timestamp: DateTime(2026, 8, 29, 21, 30),
        duration: null,
        durationSeconds: 432000, // five days
        feelings: const <String>[],
        triggers: const <String>[],
        referralRequired: false,
        notes: '',
      );
      final csv = buildCsv(<EventRecord>[r]);
      final header = csv.split('\n').first.replaceFirst('﻿', '');
      final i = header.split(',').indexOf('duration_seconds');
      expect(cell(csv, i), '432000',
          reason: 'the readable column clamps; the numeric one must not, or a '
              'multi-day duration is unrecoverable from the file');
    });
  });
}
