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
    // ⛔ WHICH fallback (Brief 222, 28 September 2026). The two lines above hold
    // for ANY fallback, including a missing sqflite plugin on a macOS host. A
    // corrupt file does NOT fail the open: SQLite opens it lazily and fails on
    // the first read, with SQLITE_NOTADB (26), which is what this pins. Observed
    // on macOS; Windows FFI is expected to report the same code, and not yet seen.
    // See the rule at `StorageBoot.debugDatabaseFactory`.
    expect(
        outcome.error,
        isA<DatabaseException>()
            .having((e) => e.getResultCode(), 'getResultCode()', 26),
        reason: 'CONTROL: the fallback must come from the corrupt file '
            '(SQLITE_NOTADB), not from any other failure, such as a missing '
            'sqflite plugin.');
    expect(ids, <String>['alpha', 'bravo', 'charlie', 'pair'],
        reason: 'OBSERVED: and the history shown is the frozen list');
  }, timeout: const Timeout(Duration(seconds: 90)));
}
