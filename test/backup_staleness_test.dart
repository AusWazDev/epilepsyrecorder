import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/backup.dart';
import 'package:medical_event_recorder/models/event_record.dart';

/// Choosing the right backup file.
///
/// From a real mis-restore: six backups, indistinguishable in the system
/// picker, and an older one restored over a device holding more. Nothing was
/// lost — merge-only saw to that — but nothing in the flow made the mistake
/// visible either.
///
/// The app cannot say a file is the WRONG one; it has no idea which device
/// wrote it, and deliberately records nothing that would say so. What it can
/// do is compare the newest event in the file against the newest event already
/// here, which needs no provenance at all.

EventRecord rec(String id, DateTime ts) => EventRecord(
      id: id,
      timestamp: ts,
      duration: DurationCategory.lt1,
      feelings: const <String>[],
      referralRequired: false,
      notes: '',
      eventType: EventType.seizure,
      severity: EventSeverity.mild,
      triggers: const <String>[],
    );

/// A backup envelope, built the way the app builds one.
String envelope(List<EventRecord> records, DateTime exportedAt) =>
    buildBackupJson(records, exportedAt: exportedAt);

void main() {
  final t0 = DateTime(2026, 8, 20, 9, 0);
  final older = t0;
  final newer = t0.add(const Duration(days: 5));

  group('staleness caution', () {
    test('1. an OLDER backup warns', () {
      final onDevice = [rec('device-new', newer)];
      final parsed = parseBackup(envelope([rec('file-old', older)], newer));

      final plan = planRestore(onDevice, parsed);

      expect(plan.isStalerThanDevice, isTrue,
          reason: 'newest in file precedes newest on device');
    });

    test('2. a NEWER backup does not warn', () {
      final onDevice = [rec('device-old', older)];
      final parsed = parseBackup(envelope([rec('file-new', newer)], newer));

      final plan = planRestore(onDevice, parsed);

      expect(plan.isStalerThanDevice, isFalse);
    });

    test('3. an EMPTY device never warns', () {
      // The fresh-install case. Restoring anything is normal here and a
      // caution would be pure noise.
      final parsed = parseBackup(envelope([rec('file-old', older)], older));

      final plan = planRestore(const <EventRecord>[], parsed);

      expect(plan.isStalerThanDevice, isFalse,
          reason: 'nothing to be staler THAN');
    });

    test('4. equal newest timestamps do not warn', () {
      // Boundary. `isBefore` is strict, so a backup taken from this very device
      // moments ago must not accuse itself.
      final onDevice = [rec('a', newer)];
      final parsed = parseBackup(envelope([rec('b', newer)], newer));

      expect(planRestore(onDevice, parsed).isStalerThanDevice, isFalse);
    });

    test('5. NEGATIVE CONTROL: an inverted comparison would NOT warn here',
        () async {
      // Without this the passing cases prove nothing: a check hardwired to
      // return true would satisfy test 1 just as well.
      //
      // Re-implements the rule with the comparison reversed and asserts it
      // reaches the OPPOSITE verdict on the same fixtures. If both orientations
      // agreed, the inputs would not be discriminating and tests 1-2 would be
      // measuring nothing.
      final onDevice = [rec('device-new', newer)];
      final parsed = parseBackup(envelope([rec('file-old', older)], newer));
      final plan = planRestore(onDevice, parsed);

      DateTime? deviceLatest;
      for (final r in onDevice) {
        if (deviceLatest == null || r.timestamp.isAfter(deviceLatest)) {
          deviceLatest = r.timestamp;
        }
      }
      final inverted = onDevice.isNotEmpty &&
          plan.latest != null &&
          deviceLatest != null &&
          deviceLatest.isBefore(plan.latest!); // <- reversed

      expect(plan.isStalerThanDevice, isTrue);
      expect(inverted, isFalse,
          reason: 'the two orientations must disagree on this fixture, or the '
              'fixture cannot tell a working check from a broken one');
    });
  });

  group('the envelope is read, not extended', () {
    test('6. exportedAt reaches the plan', () {
      final stamp = DateTime(2026, 8, 25, 14, 22, 2);
      final parsed = parseBackup(envelope([rec('a', older)], stamp));

      final plan = planRestore(const <EventRecord>[], parsed);

      expect(plan.exportedAt, stamp,
          reason: 'the signal the picker cannot show');
    });

    test('7. no key was added to the envelope', () {
      final map = jsonDecode(envelope([rec('a', older)], older))
          as Map<String, dynamic>;

      expect(map.keys.toSet(), {
        'format',
        'schemaVersion',
        'appVersion',
        'exportedAt',
        'recordCount',
        'records',
      }, reason: 'read more of it, add nothing to it — a device identifier in '
          'particular, since these files get emailed around');
    });
  });

  group('old filenames still restore', () {
    test('8. nothing matches on the filename prefix', () {
      // The rename is cosmetic BY DESIGN. Restore filters by extension and
      // validates by the envelope's `format` field, so a file written under the
      // old long name parses identically — the name never reaches the parser.
      final json = envelope([rec('legacy', older)], older);

      final parsed = parseBackup(json);

      expect(parsed.problem, isNull, reason: parsed.message);
      expect(parsed.records.single.id, 'legacy');
    });

    test('9. positive control: a genuinely invalid envelope IS refused', () {
      // Proves test 8 is asserting something. If parseBackup accepted
      // everything, "the old format still restores" would be vacuous.
      final parsed = parseBackup('{"format":"not-a-mer-backup"}');

      expect(parsed.problem, isNotNull);
      expect(parsed.records, isEmpty);
    });
  });
}
