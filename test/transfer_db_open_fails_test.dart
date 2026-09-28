// Brief 215 §3.1: the database cannot be opened at all. Prefs untouched.
// A directory stands where the database file should be.

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

  test('database fails to open: what boot does and what the user sees', () async {
    await firstLife();
    await transfer(root);
    await Directory('${root.path}/support/$kSqliteDbFileName').create();

    final outcome = await StorageBoot.init();
    final ids = (await StorageBoot.store.load()).map((r) => r.id).toList()..sort();
    print('[b215o] outcome=${outcome.state} isSqlite=${StorageBoot.isSqlite} '
        'banner=${!outcome.succeeded} ids=$ids error=${outcome.error}');
    expect(StorageBoot.isSqlite, isFalse,
        reason: 'OBSERVED: a failed open falls back to the prefs store');
    expect(outcome.succeeded, isFalse, reason: 'OBSERVED: so the banner shows');
    // ⛔ WHICH fallback (Brief 222, 28 September 2026). The two lines above hold
    // for ANY fallback, including a missing sqflite plugin on a macOS host. Only
    // the error says the directory standing in for the database caused this one.
    // See the rule at `StorageBoot.debugDatabaseFactory`.
    expect(
        outcome.error,
        isA<DatabaseException>().having(
            (e) => e.isOpenFailedError(), 'isOpenFailedError()', isTrue),
        reason: 'CONTROL: the fallback must come from the failed OPEN, not '
            'from any other failure, such as a missing sqflite plugin.');
    expect(ids, <String>['alpha', 'bravo', 'charlie', 'pair'],
        reason: 'OBSERVED: and the history shown is the frozen list');
  }, timeout: const Timeout(Duration(seconds: 90)));
}
