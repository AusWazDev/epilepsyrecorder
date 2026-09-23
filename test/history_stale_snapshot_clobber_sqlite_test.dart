// Brief 135R · the clobber contract, against the PRIMARY (SQLite) store.
//
// ⭐ The assertion is not here. It lives once, in
// `support/history_clobber_contract.dart`, and is run against each store.
//
// ⛔ ONE PREFS-DEPENDENT TEST PER PROCESS (CLAUDE.md) — this file exists
// because the contract cannot share a process with the prefs case. The reason,
// measured rather than assumed, is in the support file's header.

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';

import 'support/history_clobber_contract.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  seedPrefs();
  sqfliteFfiInit();

  // ⛔ NO-ISOLATE ON PURPOSE, and this is the other half of the fake-clock
  // rule. `databaseFactoryFfi` runs the database in a BACKGROUND ISOLATE, so
  // every query completes by a port message — an event the fake clock never
  // services. Moving the TEST's own I/O to the real clock does not help the
  // APP's: `HomeScreen`'s load runs inside the pump. The in-process factory
  // completes through microtasks, which the fake clock does flush.
  // ⭐ It changes WHERE the query runs. It changes nothing about what is
  // driven, and nothing about `lib/`.
  databaseFactory = databaseFactoryFfiNoIsolate;

  Database? db;

  /// Ids in the SQLITE table, read back from storage.
  Future<List<String>> sqliteIds() async =>
      [for (final r in await db!.query('event')) '${r['id']}'];

  registerClobberContract(StoreCase(
    'sqlite',
    () async {
      db = await databaseFactory.openDatabase(inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            version: kSqliteSchemaVersion,
            onCreate: (d, v) async => createSchema(d),
          ));
      await db!.delete('event'); // inMemoryDatabasePath is shared per process
      await SqliteEventStore(db!).save(kSeed);
      StorageBoot.debugSet(store: SqliteEventStore(db!), db: db);
    },
    sqliteIds,
    () async {
      await db?.close();
      db = null;
    },
  ));
}
