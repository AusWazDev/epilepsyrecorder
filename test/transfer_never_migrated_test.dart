// Brief 215 §2.2 case 3, and §3.1's "restore from a 1.0.2 backup onto a
// current build": a device that never migrated. No marker, no database, the
// legacy list is the live history.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/storage_migration.dart';

import 'support/transfer_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late dynamic root;
  setUp(() async => root = await prepareDevice());
  tearDown(() async => tearDownDevice(root));

  test('never migrated (a 1.0.2 backup): no marker, and boot looks identical',
      () async {
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kEventStorageKey), isNotNull,
        reason: 'CONTROL: the legacy list is present');
    expect(prefs.getString(kLegacyMigrationMarkerKey), isNull,
        reason: 'MARKER: a device that never migrated carries no marker');

    final outcome = await StorageBoot.init();
    final ids = (await StorageBoot.store.load()).map((r) => r.id).toList()..sort();
    print('[b215n] outcome=${outcome.state} ids=$ids');
    expect(ids, <String>['alpha', 'bravo', 'charlie', 'pair'],
        reason: 'the same four records the restored device ends up with');
    expect(outcome.state, MigrationState.migrated,
        reason: 'SIGNAL: the same outcome the restored device reports');
  }, timeout: const Timeout(Duration(seconds: 90)));
}
