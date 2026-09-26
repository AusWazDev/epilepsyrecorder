// Tier A · the restore path where the CONDITIONS GUARD OPENS.
//
// A current-schema backup carrying a condition and an assignment for a CUSTOM
// event type the new device has never seen. Today `onRestore` creates the
// condition, then drops the assignment at `if (matches.isEmpty) continue;`
// because the type has no row.
//
// Written RED, before the fix. What it asserts:
//   CONTROL (green today)  the condition itself is created — the guard opened
//   FINDINGS (red today)   the custom type has an ACTIVE row, and that row is
//                          assigned to the restored condition. The second is
//                          claim (a): fixed by ORDERING alone, with no change
//                          to the assignment loop.
//   MUST NOT               the record is still verbatim
//
// ⛔ ONE PREFS-DEPENDENT TEST PER PROCESS — the guard-closed case is its own file.

import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/backup.dart';
import 'package:medical_event_recorder/models/condition.dart';
import 'package:medical_event_recorder/models/vocabulary.dart';

import 'support/restore_vocabulary_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  seedPrefs();

  const conditionName = 'Epilepsy';
  final restored = rec('restored-1', 20, eventType: customType);

  registerRestoreVocabularyCase(RestoreCase(
    name: 'current schema, guard open',
    deviceRecords: const [],
    backupJson: () => buildBackupJson(
      [restored],
      conditions: const <Condition>[Condition(id: 1, name: conditionName)],
      eventTypeConditions: const <String, String>{customType: conditionName},
    ),
    check: (db) async {
      final problems = <String>[
        ...await recordsVerbatim(db, {restored.id: restored}),
      ];
      final conditions = await loadConditions(db);
      final matching = conditions.where((c) => c.name == conditionName);
      if (matching.isEmpty) {
        problems.add('CONTROL FAILED: the condition "$conditionName" was not '
            'created, so the guard never opened and this case tests nothing.');
        return problems;
      }
      final missing = await needsActiveRow(db, kEventTypeTable, customType);
      if (missing != null) {
        problems.add(missing);
        problems.add('ASSIGNMENT DROPPED: with no row, "$customType" cannot be '
            'assigned to "$conditionName"');
        return problems;
      }
      final row = (await rowFor(db, kEventTypeTable, customType))!;
      if (row.conditionId != matching.first.id) {
        problems.add('ASSIGNMENT DROPPED: "$customType" has condition_id '
            '${row.conditionId}, expected ${matching.first.id} '
            '("$conditionName")');
      }
      return problems;
    },
  ));
}
