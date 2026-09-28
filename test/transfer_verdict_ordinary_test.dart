// Brief 217 §3.2 and §3.3: a device that never migrated, which is also an
// ordinary first migration on a normal device, is ORDINARY. The reminder's
// count is unchanged: a recent backup still suppresses it.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/services/backup_service.dart';

import 'support/transfer_fixture.dart';
import 'support/verdict_read.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late dynamic root;
  setUp(() async => root = await prepareDevice());
  tearDown(() async => tearDownDevice(root));

  test('never migrated: verdict ORDINARY, reminder as today', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kLegacyMigrationMarkerKey), isNull,
        reason: 'CONTROL: no marker before the first migration');

    await StorageBoot.init();
    expect(StorageBoot.isSqlite, isTrue, reason: 'CONTROL: SQLite launch');
    expect(prefs.getString(kLegacyMigrationMarkerKey), isNotNull,
        reason: 'CONTROL: this boot wrote a marker, so the verdict had to be '
            'taken before it');
    expect(await storedVerdict(), 'ordinary',
        reason: 'VERDICT: a first migration is ORDINARY');

    final records = await StorageBoot.store.load();
    expect(await eventsSinceLastBackup(records), records.length,
        reason: 'REMINDER: with no backup, every record counts, as today');
    await markBackupTaken();
    expect(await eventsSinceLastBackup(records), 0,
        reason: 'REMINDER: a genuine recent backup still suppresses it, as today');
  }, timeout: const Timeout(Duration(seconds: 90)));
}
