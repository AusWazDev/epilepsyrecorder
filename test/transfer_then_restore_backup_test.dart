// Brief 215 §4: the user on a restored device restores a JSON backup made
// just before the transfer. Applied the way Home's onRestore applies it:
// `planRestore`, then the merged list saved through the store, then the notes
// inserted.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/models/backup.dart';
import 'package:medical_event_recorder/models/medication_note.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';

import 'support/transfer_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late dynamic root;
  setUp(() async => root = await prepareDevice());
  tearDown(() async => tearDownDevice(root));

  test('restore on a restored device: what comes back, per category', () async {
    final beforeTransfer = await firstLife();
    final note = MedicationNote(
        id: 'med1',
        occurredAt: DateTime(2026, 9, 23),
        loggedAt: DateTime(2026, 9, 23),
        kind: MedicationDeviation.missed,
        notes: 'missed evening dose');
    await insertMedicationNote(StorageBoot.database!, note);
    final json = buildBackupJson(beforeTransfer, notes: <MedicationNote>[note]);

    await transfer(root);
    await StorageBoot.init();
    final existing = await StorageBoot.store.load();

    final plan = planRestore(existing, parseBackup(json),
        existingNotes: await loadMedicationNotes(StorageBoot.database!));
    print('[b215r] inBackup=${plan.inBackup} alreadyPresent=${plan.alreadyPresent} '
        'toAdd=${plan.toAdd} notesToAdd=${plan.notesToAdd.length}');
    await StorageBoot.store.save(plan.merged);
    for (final n in plan.notesToAdd) {
      await insertMedicationNote(StorageBoot.database!, n);
    }
    final after = await StorageBoot.store.load();
    final notes = await loadMedicationNotes(StorageBoot.database!);
    String notesOf(String id) =>
        after.where((r) => r.id == id).map((r) => r.notes).join(' | ');
    print('[b215r] ids=${(after.map((r) => r.id).toList()..sort())}');
    print('[b215r] bravo="${notesOf('bravo')}" charlie.hidden='
        '${after.firstWhere((r) => r.id == 'charlie').hidden} pair="${notesOf('pair')}" '
        'notes=${notes.map((n) => n.id).toList()}');

    expect(after.any((r) => r.id == 'delta'), isTrue,
        reason: 'NEW RECORD: a post-migration record with a new id comes back');
    expect(notes.map((n) => n.id), contains('med1'),
        reason: 'MEDICATION NOTE: comes back');
    expect(notesOf('bravo'), 'note bravo',
        reason: 'EDIT: NOT recovered. The stale migrated copy shares the id and '
            'existing wins');
    expect(after.firstWhere((r) => r.id == 'charlie').hidden, isFalse,
        reason: 'HIDE: NOT recovered, for the same reason');
    expect(notesOf('pair'), 'pair, first copy',
        reason: 'SHARED ID: the second record under an id the device already '
            'holds is NOT recovered; it is counted "already on this device"');
    expect(plan.alreadyPresent, 5,
        reason: 'the dialog will say 5 are already on this device: alpha, bravo, '
            'charlie and BOTH pair records');
  }, timeout: const Timeout(Duration(seconds: 90)));
}
