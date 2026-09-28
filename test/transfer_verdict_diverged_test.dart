// Brief 217 §3.2: fallback writes landed after migration, then the transfer.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';

import 'support/transfer_fixture.dart';
import 'support/verdict_read.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late dynamic root;
  setUp(() async => root = await prepareDevice());
  tearDown(() async => tearDownDevice(root));

  test('diverged payload: verdict DIVERGED', () async {
    await firstLife();
    await transfer(root, keepDatabase: true);
    StorageBoot.debugSet(store: EventStore());
    final list = await StorageBoot.store.load();
    await StorageBoot.store.save(<EventRecord>[...list, tRec('echo', 25)]);
    StorageBoot.debugSet();
    await transfer(root);

    await StorageBoot.init();
    expect(StorageBoot.isSqlite, isTrue, reason: 'CONTROL: SQLite launch');
    expect(await storedVerdict(), 'diverged',
        reason: 'VERDICT: a payload changed after an earlier migration is '
            'DIVERGED');
  }, timeout: const Timeout(Duration(seconds: 90)));
}
