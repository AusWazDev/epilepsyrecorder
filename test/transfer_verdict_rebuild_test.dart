// Brief 217 §3.1: a restored device's verdict is REBUILD, captured before the
// migration overwrites the marker, and it survives later launches.
//
// ⛔ CORRECTED 28 September 2026 (Brief 229): "a restored device" named the
// iOS-restore trigger of `10c2f7c`, which was reverted before it shipped. Since
// then an iOS restore keeps the database, and that device is NOT a rebuild.
// Superseded wording: "a restored device's verdict is REBUILD". Read it as: a
// device whose DATABASE IS ABSENT while its prefs carry a marker gets the
// verdict REBUILD. Kept as the regression guard described in
// `support/transfer_fixture.dart`. The test's NAME still says "restored
// device"; it is left as it is so runs stay comparable by name.

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
    // Reason string CORRECTED 28 Sep 2026 (Brief 229). It read: "VERDICT: a
    // restored device is REBUILD, taken before the marker was overwritten".
    expect(await storedVerdict(), 'rebuild',
        reason: 'VERDICT: a database-absent device is REBUILD, taken before '
            'the marker was overwritten');

    await transfer(root, keepDatabase: true);
    final again = await StorageBoot.init();
    expect(again.state, MigrationState.alreadyMigrated,
        reason: 'CONTROL: an ordinary later launch');
    expect(await storedVerdict(), 'rebuild',
        reason: 'VERDICT: a later launch keeps the database\'s verdict');
  }, timeout: const Timeout(Duration(seconds: 90)));
}
