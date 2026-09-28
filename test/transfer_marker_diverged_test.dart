// Brief 215 §2.2, case 2: fallback writes landed after migration, then the
// transfer. The marker's fingerprint must NOT match the payload boot migrates.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/storage_migration.dart';

import 'support/transfer_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late dynamic root;
  setUp(() async => root = await prepareDevice());
  tearDown(() async => tearDownDevice(root));

  test('fallback writes after migration: marker present, fingerprint differs',
      () async {
    await firstLife();
    await transfer(root, keepDatabase: true);

    // A fallback launch: the real prefs store, the real fallback writer.
    StorageBoot.debugSet(store: EventStore());
    final fallbackList = await StorageBoot.store.load();
    await StorageBoot.store
        .save(<EventRecord>[...fallbackList, tRec('echo', 25, notes: 'echo, on a fallback launch')]);
    StorageBoot.debugSet();

    await transfer(root);
    final prefs = await SharedPreferences.getInstance();
    final marker =
        jsonDecode(prefs.getString(kLegacyMigrationMarkerKey)!) as Map<String, Object?>;
    final fp = legacyPayloadFingerprint(prefs.getString(kEventStorageKey));
    print('[b215d] marker=$marker payload=${fp.bytes}/${fp.fnv1a32}');
    expect(marker['payloadBytes'] == fp.bytes && marker['fnv1a32'] == fp.fnv1a32,
        isFalse,
        reason: 'MARKER: a payload the fallback store wrote to after migration '
            'must not match the migrated fingerprint');

    final outcome = await StorageBoot.init();
    final ids = (await StorageBoot.store.load()).map((r) => r.id).toList()..sort();
    print('[b215d] outcome=${outcome.state} ids=$ids');
    expect(ids, <String>['alpha', 'bravo', 'charlie', 'echo', 'pair'],
        reason: 'REBUILD: the frozen list plus the fallback-era write, and '
            'nothing from the SQLite era');
    expect(outcome.succeeded, isTrue, reason: 'SIGNAL: no banner');
  }, timeout: const Timeout(Duration(seconds: 90)));
}
