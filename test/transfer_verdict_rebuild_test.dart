// Brief 217 §3.1: a restored device's verdict is REBUILD, captured before the
// migration overwrites the marker, and it survives later launches.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/constants.dart';
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

  test('restored device: verdict REBUILD, kept across launches', () async {
    await firstLife();
    expect(await storedVerdict(), 'ordinary',
        reason: 'CONTROL: the first life was an ordinary first migration');
    await transfer(root);
    final prefs = await SharedPreferences.getInstance();
    final markerBefore = prefs.getString(kLegacyMigrationMarkerKey);

    final outcome = await StorageBoot.init();
    expect(outcome.state, MigrationState.migrated,
        reason: 'CONTROL: this boot rebuilt the database');
    expect(prefs.getString(kLegacyMigrationMarkerKey), isNot(markerBefore),
        reason: 'CONTROL: boot rewrote the marker, so a later reader cannot '
            'tell this was a rebuild');
    expect(await storedVerdict(), 'rebuild',
        reason: 'VERDICT: a restored device is REBUILD, taken before the '
            'marker was overwritten');

    await transfer(root, keepDatabase: true);
    final again = await StorageBoot.init();
    expect(again.state, MigrationState.alreadyMigrated,
        reason: 'CONTROL: an ordinary later launch');
    expect(await storedVerdict(), 'rebuild',
        reason: 'VERDICT: a later launch keeps the database\'s verdict');
  }, timeout: const Timeout(Duration(seconds: 90)));
}
