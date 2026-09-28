// Brief 208 Part B, 28 September 2026: Reset clears what it claims.
//
// ⛔ DRIVES THE COMPOSITION. `StorageBoot.init()` opens a real FFI database in
// a fake Application Support directory and runs the real migration, which
// writes the real pre-migration backup. The Reset call is
// `StorageBoot.store.clearAll()`, which is what `_confirmResetDisclaimer`
// calls through `_store`. Nothing here hands the function under test a
// directory, so "which directories does Reset reach" is decided by the code.
//
// ⚠️ ONE prefs-dependent test per file (CLAUDE.md, the harness rule). Every
// assertion carries a `reason:` so a control's failure names its property.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/condition.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/models/medication_note.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/vocabulary.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';

class _Dirs extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _Dirs(this.support, this.documents, this.temp, this.downloads);
  final String support;
  final String documents;
  final String temp;
  final String downloads;

  @override
  Future<String?> getApplicationSupportPath() async => support;
  @override
  Future<String?> getApplicationDocumentsPath() async => documents;
  @override
  Future<String?> getTemporaryPath() async => temp;
  @override
  Future<String?> getLibraryPath() async => support;
  @override
  Future<String?> getDownloadsPath() async => downloads;
}

EventRecord rec(String id, int day) => EventRecord(
      id: id,
      timestamp: DateTime(2026, 9, day),
      duration: DurationCategory.lt1,
      durationSeconds: 40,
      eventType: 'seizure',
      severity: EventSeverity.mild,
      feelings: <String>[kSeedObservations.first.value],
      triggers: <String>[kSeedTriggers.first.value],
      referralRequired: false,
      notes: 'note $id',
      detailsCompleted: true,
    );

/// Every vocabulary row minus its local id, which AUTOINCREMENT mints fresh.
Future<List<String>> vocabRows(DatabaseExecutor db, String table) async {
  final rows = await db.query(table, orderBy: 'value');
  return rows.map((r) {
    final m = Map<String, Object?>.of(r)..remove('id');
    return jsonEncode(m);
  }).toList();
}

Future<int> count(DatabaseExecutor db, String table) async =>
    (await db.rawQuery('SELECT COUNT(*) AS n FROM $table')).first['n']! as int;

List<String> names(Directory d) => d.existsSync()
    ? d.listSync().whereType<File>().map((f) => f.uri.pathSegments.last).toList()
    : <String>[];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory root, support, documents, temp, downloads, chosen;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mer_b208_');
    support = await Directory('${root.path}/support').create();
    documents = await Directory('${root.path}/documents').create();
    temp = await Directory('${root.path}/tmp').create();
    downloads = await Directory('${root.path}/Download').create();
    chosen = await Directory('${root.path}/chosen').create();
    PathProviderPlatform.instance =
        _Dirs(support.path, documents.path, temp.path, downloads.path);
    // Brief 211: FFI on every host. On macOS the production gate picks the
    // plugin, which a test process does not have, and every init() fell back.
    StorageBoot.debugDatabaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues(<String, Object>{
      kEventStorageKey: jsonEncode([rec('alpha', 1).toMap(), rec('beta', 2).toMap()]),
    });
  });

  tearDown(() async {
    await StorageBoot.database?.close();
    StorageBoot.debugSet();
    StorageBoot.debugDatabaseFactory = null;
    Vocabularies.debugReset();
    try {
      if (await root.exists()) await root.delete(recursive: true);
    } catch (_) {}
  });

  test('Reset empties every record table, rebuilds the vocabularies as fresh, '
      'keeps schema_meta, deletes its own files and no one else\'s', () async {
    print('[b208] boot');
    final outcome = await StorageBoot.init();
    expect(StorageBoot.isSqlite, isTrue,
        reason: 'CONTROL: this test is about the SQLite Reset. outcome=$outcome');
    final db = StorageBoot.database!;

    // ── FIXTURE: one of everything Reset must remove ──
    print('[b208] fixture');
    await insertMedicationNote(db, MedicationNote(
        id: 'm1',
        occurredAt: DateTime(2026, 9, 3),
        loggedAt: DateTime(2026, 9, 3),
        kind: MedicationDeviation.missed,
        notes: 'dose note'));
    final cond = await addCondition(db, 'Migraine');
    await db.insert(kConditionObservationTable,
        <String, Object?>{'condition_id': cond!.id, 'observation_id': 1, 'sort_order': 0});
    await db.insert(kEventObservationTable,
        <String, Object?>{'event_id': 'alpha', 'observation_id': 1, 'position': 0});
    await db.insert(kEventTriggerTable,
        <String, Object?>{'event_id': 'alpha', 'trigger_id': 1, 'position': 0});
    final mine = await addUserEntry(db, kObservationTable, 'Tingling left hand');
    await renameEntry(db, kObservationTable, mine!, 'Tingling, left hand');
    await addUserEntry(db, kTriggerTable, 'Flashing lights at work');
    final hideable = (await loadVocabulary(db, kObservationTable))
        .firstWhere((e) => e.isSeeded && e.isActive && !e.isProtected);
    await setActive(db, kObservationTable, hideable, false);
    await Vocabularies.load(db);
    final seizureType = Vocabularies.eventTypes.firstWhere((e) => e.value == 'seizure');
    await Vocabularies.setCondition(kEventTypeTable, seizureType, cond.id);

    // The pre-migration backup, where boot wrote it, plus a copy at a
    // Documents path recorded in schema_meta: the pre-9eed24f device.
    final supportBackups =
        names(support).where((n) => n.startsWith('mer_pre_sqlite_backup_')).toList();
    final documentsBackup = File('${documents.path}/mer_pre_sqlite_backup_20260901_000000.json')
      ..writeAsStringSync('[]');
    await putMeta(db, kMetaBackupPath, documentsBackup.path);

    // Share intermediates, every name any build has used.
    const shareNames = <String>[
      'medical_event_recorder_all_20260901_101010.v8.csv',
      'medical_event_recorder_filtered_20260901_101010.v8.csv',
      'medical_event_recorder_20260101_101010.csv',
      'mer_backup_20260901_101010.json',
      'medical_event_recorder_backup_20260820_101010.json',
    ];
    for (final n in shareNames) {
      File('${temp.path}/$n').writeAsStringSync('x');
    }
    final sharePlus = await Directory('${temp.path}/share_plus').create();
    File('${sharePlus.path}/mer_backup_20260901_101010.json').writeAsStringSync('x');
    // Not ours: must survive even though it sits in the swept directory.
    File('${temp.path}/other_app_export.csv').writeAsStringSync('keep');

    // User-saved exports, with EXACTLY the names Reset sweeps, in the places a
    // user's Save puts them.
    final userSaved = <File>[
      File('${downloads.path}/medical_event_recorder_all_20260901_101010.v8.csv'),
      File('${downloads.path}/mer_backup_20260901_101010.json'),
      File('${chosen.path}/medical_event_recorder_all_20260901_101010.v8.csv'),
      File('${chosen.path}/mer_pre_sqlite_backup_20260901_000000.json'),
      File('${documents.path}/medical_event_recorder_all_20260901_101010.v8.csv'),
    ];
    for (final f in userSaved) {
      f.writeAsStringSync('user copy');
    }

    // ── CONTROLS: every REMOVE item is present BEFORE Reset ──
    for (final t in kResetClearedTables) {
      expect(await count(db, t), greaterThan(0),
          reason: 'CONTROL: $t must hold rows before Reset, or "empty after" '
              'proves nothing');
    }
    expect(supportBackups, hasLength(1),
        reason: 'CONTROL: boot must have written the pre-migration backup');
    expect(Vocabularies.observations.any((e) => e.value == 'Tingling left hand'),
        isTrue, reason: 'CONTROL: the cache holds the user entry before Reset');
    final metaBefore = await db.query('schema_meta', orderBy: 'key');
    expect(metaBefore.any((r) => r['key'] == kMetaMigrationState && r['value'] == 'migrated'),
        isTrue, reason: 'CONTROL: schema_meta records the migration');

    // ── RESET ──
    print('[b208] reset');
    await StorageBoot.store.clearAll();
    print('[b208] assert');

    // 6.1 — every REMOVE item is gone.
    for (final t in <String>[
      'event', kMedicationNoteTable, kConditionTable, kConditionObservationTable,
      kEventObservationTable, kEventTriggerTable,
    ]) {
      expect(await count(db, t), 0,
          reason: 'REMOVE: $t must be empty after Reset');
    }

    // Vocabularies: exactly a fresh install's, user entries, renames, hides
    // and the type-to-condition mapping all gone, MER's retirements intact.
    final fresh = await databaseFactoryFfi.openDatabase('${root.path}/fresh.db',
        options: OpenDatabaseOptions(
            version: kSqliteSchemaVersion, onCreate: (d, _) => createSchema(d)));
    await ensureSeeded(fresh);
    await ensureTriggersSeeded(fresh);
    for (final t in <String>[kEventTypeTable, kObservationTable, kTriggerTable]) {
      expect(await vocabRows(db, t), await vocabRows(fresh, t),
          reason: 'REMOVE: $t after Reset must equal a freshly installed '
              'database, row for row (ids aside)');
    }
    await fresh.close();
    expect(Vocabularies.observations.any((e) => e.value == 'Tingling left hand'),
        isFalse,
        reason: 'REMOVE: the in-memory vocabulary must not keep offering the '
            'user\'s entry after Reset');

    // 6.2 — the bookkeeping table survives, unchanged.
    expect(await db.query('schema_meta', orderBy: 'key'), metaBefore,
        reason: 'KEEP: schema_meta must survive Reset unchanged');

    // Every table in the file is classified: cleared or kept. None unaccounted.
    final tables = (await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type = 'table' "
            "AND name NOT LIKE 'sqlite_%'"))
        .map((r) => r['name']! as String)
        .toSet();
    expect(tables.difference(<String>{...kResetClearedTables, 'schema_meta'}),
        isEmpty,
        reason: 'CENSUS: a table neither cleared nor kept is a table Reset has '
            'not been told about. tables=$tables');

    // The pre-migration backup, both copies.
    expect(names(support).where((n) => n.startsWith('mer_pre_sqlite_backup_')),
        isEmpty, reason: 'REMOVE: the pre-migration backup in Support');
    expect(documentsBackup.existsSync(), isFalse,
        reason: 'REMOVE: the pre-migration backup at its RECORDED path');

    // Share intermediates.
    for (final n in shareNames) {
      expect(File('${temp.path}/$n').existsSync(), isFalse,
          reason: 'REMOVE: share intermediate $n');
    }
    expect(names(sharePlus), isEmpty,
        reason: 'REMOVE: the share_plus copy of a shared file');
    expect(File('${temp.path}/other_app_export.csv').existsSync(), isTrue,
        reason: 'KEEP: a file in temp that is not the app\'s own');

    // 6.3 — user-chosen export locations: untouched, byte for byte.
    for (final f in userSaved) {
      expect(f.existsSync() && f.readAsStringSync() == 'user copy', isTrue,
          reason: 'EXEMPT: a user-saved export must be untouched: ${f.path}');
    }

    // Unchanged behaviour: prefs, legacy key included, are cleared.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(kEventStorageKey), isNull,
        reason: 'UNCHANGED: Reset still clears prefs');
  }, timeout: const Timeout(Duration(seconds: 90)));
}
