import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common/sqflite.dart' as sqflite_common;
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import 'package:sqflite/sqflite.dart' as sqflite_plugin;

import '../constants.dart';
import 'event_record.dart';
import 'event_store_sqlite.dart';
import 'storage_migration.dart';

/// Selects the store for this launch, and runs the one-shot migration.
///
/// ## First-launch order, and why "during migration" is an empty interval
///
/// 1. Open SQLite
/// 2. If not yet migrated: write the backup FIRST, read the raw JSON maps,
///    insert rows, verify the row count
/// 3. Mark complete in `schema_meta`
/// 4. Drain the inbox
/// 5. Render
///
/// The drain writes the NEW store — not by policy, but because it is ordered
/// after the migration completes. Nothing drains while the migration runs, so
/// there is no interleaving to test.
///
/// Step 4 is not here: it stays in `_loadRecords`, which already owns it. This
/// class only decides WHICH store `_loadRecords` is handed.
class StorageBoot {
  StorageBoot._();

  static EventStore? _store;
  static Database? _db;
  static MigrationOutcome? outcome;

  /// The store for this launch.
  ///
  /// Defaults to shared_preferences when [init] has not run, so widget tests
  /// and any path that constructs a screen without booting keep working exactly
  /// as they did.
  static EventStore get store => _store ??= EventStore();

  /// Whether the app is running on SQLite. False on a fallback launch.
  static bool get isSqlite => _store is SqliteEventStore;

  static Database? get database => _db;

  /// Test seam: lets a test install a chosen store and outcome.
  static void debugSet({EventStore? store, Database? db, MigrationOutcome? result}) {
    _store = store;
    _db = db;
    outcome = result;
  }

  static void configureDatabaseFactory() {
    if (Platform.isWindows || Platform.isLinux) {
      ffi.sqfliteFfiInit();
      sqflite_common.databaseFactory = ffi.databaseFactoryFfi;
    } else {
      sqflite_common.databaseFactory = sqflite_plugin.databaseFactorySqflitePlugin;
    }
  }

  /// Opens the database, migrates if needed, and picks the store.
  ///
  /// NEVER throws: any failure falls back to shared_preferences, because a
  /// launch that cannot open SQLite must still be a working app with the user's
  /// history in it.
  static Future<MigrationOutcome> init() async {
    try {
      configureDatabaseFactory();

      final supportDir = await getApplicationSupportDirectory();
      final db = await sqflite_common.databaseFactory.openDatabase(
        '${supportDir.path}/$kSqliteDbFileName',
        options: OpenDatabaseOptions(
          version: kSqliteSchemaVersion,
          onCreate: (db, _) => createSchema(db),
        ),
      );
      _db = db;

      final prefs = await SharedPreferences.getInstance();
      final rawJson = prefs.getString(kEventStorageKey);

      // The backup is written BEFORE anything is touched, and is never deleted.
      String? backupPath;
      final alreadyDone = await getMeta(db, kMetaMigrationState) == 'migrated';
      if (!alreadyDone) {
        try {
          backupPath = await writeMigrationBackup(
              await getApplicationDocumentsDirectory(), rawJson);
        } catch (_) {
          // A backup that cannot be written must not stop the app booting, but
          // it DOES stop the migration: converting without one removes the
          // rollback this whole build depends on.
          const result = MigrationOutcome(
            state: MigrationState.error,
            sourceEntries: 0,
            loadableCount: 0,
            insertedCount: 0,
            distinctIds: 0,
            absentCounts: <String, int>{},
            error: 'backup could not be written; migration not attempted',
          );
          _store = EventStore();
          outcome = result;
          return result;
        }
      }

      final result = await migrateJsonToSqlite(
        db: db,
        rawJson: rawJson,
        backupPath: backupPath,
      );

      // The fallback. Verification failed or the conversion threw, so this
      // launch runs on shared_preferences — and the inbox still drains, into
      // the OLD store, because deferring real captures is not acceptable.
      _store = result.succeeded ? SqliteEventStore(db) : EventStore();
      outcome = result;
      return result;
    } catch (e) {
      final result = MigrationOutcome(
        state: MigrationState.error,
        sourceEntries: 0,
        loadableCount: 0,
        insertedCount: 0,
        distinctIds: 0,
        absentCounts: const <String, int>{},
        error: e,
      );
      _store = EventStore();
      outcome = result;
      return result;
    }
  }
}
