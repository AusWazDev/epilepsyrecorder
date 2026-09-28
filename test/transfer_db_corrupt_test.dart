// Brief 215 §3.1: the database is present but corrupt. Prefs untouched.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';

import 'support/transfer_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late dynamic root;
  setUp(() async => root = await prepareDevice());
  tearDown(() async => tearDownDevice(root));

  test('corrupt database: what boot does and what the user sees', () async {
    await firstLife();
    await transfer(root, keepDatabase: true);
    final db = File('${root.path}/support/$kSqliteDbFileName');
    expect(db.existsSync(), isTrue, reason: 'CONTROL: the database file exists');
    db.writeAsBytesSync(List<int>.filled(db.lengthSync(), 0x5A));

    final outcome = await StorageBoot.init();
    final ids = (await StorageBoot.store.load()).map((r) => r.id).toList()..sort();
    print('[b215c] outcome=${outcome.state} isSqlite=${StorageBoot.isSqlite} '
        'banner=${!outcome.succeeded} ids=$ids error=${outcome.error}');
    expect(StorageBoot.isSqlite, isFalse,
        reason: 'OBSERVED: a corrupt file falls back to the prefs store');
    expect(outcome.succeeded, isFalse, reason: 'OBSERVED: so the banner shows');
    expect(ids, <String>['alpha', 'bravo', 'charlie', 'pair'],
        reason: 'OBSERVED: and the history shown is the frozen list');
  }, timeout: const Timeout(Duration(seconds: 90)));
}
