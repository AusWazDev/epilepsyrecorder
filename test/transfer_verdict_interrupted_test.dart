// Brief 217 §1.1's hazard: an interrupted first migration leaves THIS
// database's own marker behind (the marker is written before `migrated`,
// Brief 205). The re-run must not read that as a travelled marker.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/storage_migration.dart';

import 'support/transfer_fixture.dart';
import 'support/verdict_read.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late dynamic root;
  setUp(() async => root = await prepareDevice());
  tearDown(() async => tearDownDevice(root));

  test('interrupted first migration: the re-run keeps ORDINARY', () async {
    await StorageBoot.init();
    // The crash window: marker written, `migrated` not yet.
    final db = StorageBoot.database!;
    await putMeta(db, kMetaMigrationState, 'in_progress');
    await putMeta(db, kMetaMigrationInProgress, '1');
    await transfer(root, keepDatabase: true);

    final prefs = await SharedPreferences.getInstance();
    expect(
        rebuildVerdictFor(prefs.getString(kLegacyMigrationMarkerKey),
            prefs.getString(kEventStorageKey)),
        RebuildVerdict.rebuild,
        reason: 'CONTROL: read fresh, this device\'s own marker looks exactly '
            'like a travelled one');

    final outcome = await StorageBoot.init();
    expect(outcome.state, MigrationState.migrated,
        reason: 'CONTROL: the re-run migrated');
    expect(await storedVerdict(), 'ordinary',
        reason: 'VERDICT: the re-run of an interrupted first migration stays '
            'ORDINARY');
  }, timeout: const Timeout(Duration(seconds: 90)));
}
