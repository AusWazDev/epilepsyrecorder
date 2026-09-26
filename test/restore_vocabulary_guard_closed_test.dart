// Tier A · the restore path where the CONDITIONS GUARD STAYS CLOSED.
//
// A SCHEMA 1 backup: no `conditions`, no `eventTypeConditions`, so
// `onRestore`'s guard never opens. ⭐ This is also the path of any later-schema
// backup from someone who never named a condition — the guard is keyed on
// CONTENT, not schema. Written as a literal envelope rather than by flipping a
// flag, so it stays a fixture of what shipped.
//
// Written RED, before the fix. What it asserts:
//   FINDINGS (red today)
//     · the custom event type, observation and trigger a restored record uses
//       each have an ACTIVE row                                    Tier A
//     · a value on a record ALREADY ON THE DEVICE with no row gets one   D-1
//   MUST NOT (green today, and must stay green)
//     · no row for a shipped-hidden value, even with its row missing     D-3
//     · no row for a whitespace-padded value, in either form            D-2
//     · every record, restored or pre-existing, is still verbatim
//
// ⛔ ONE PREFS-DEPENDENT TEST PER PROCESS — the guard-open case is its own file.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/vocabulary.dart';

import 'support/restore_vocabulary_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  seedPrefs();

  final restored = rec('restored-1', 20,
      eventType: customType,
      feelings: <String>[
        customObservation,
        shippedHiddenObservation,
        untrimmedObservation,
      ],
      triggers: const <String>[customTrigger]);
  final onDevice = rec('device-1', 10,
      feelings: const <String>[orphanObservation]);

  registerRestoreVocabularyCase(RestoreCase(
    name: 'schema 1, guard closed',
    deviceRecords: [onDevice],
    backupJson: () => const JsonEncoder.withIndent('  ').convert({
      'format': kBackupFormatId,
      'schemaVersion': 1,
      'appVersion': '1.1.0+41',
      'exportedAt': DateTime(2026, 8, 27, 23).toIso8601String(),
      'recordCount': 1,
      'records': [restored.toMap()],
    }),
    check: (db) async {
      final problems = <String>[
        ...await recordsVerbatim(db, {
          restored.id: restored,
          onDevice.id: onDevice,
        }),
      ];
      for (final f in [
        await needsActiveRow(db, kEventTypeTable, customType),
        await needsActiveRow(db, kObservationTable, customObservation),
        await needsActiveRow(db, kTriggerTable, customTrigger),
        await needsActiveRow(db, kObservationTable, orphanObservation),
      ]) {
        if (f != null) problems.add(f);
      }
      if (await rowFor(db, kObservationTable, shippedHiddenObservation) !=
          null) {
        problems.add('D-3 BROKEN: a row was created for the shipped-hidden '
            'value "$shippedHiddenObservation"');
      }
      for (final v in {untrimmedObservation, untrimmedObservation.trim()}) {
        if (await rowFor(db, kObservationTable, v) != null) {
          problems.add('D-2 BROKEN: a row was created for "$v", which the '
              'record "$untrimmedObservation" can never resolve to');
        }
      }
      return problems;
    },
  ));
}
