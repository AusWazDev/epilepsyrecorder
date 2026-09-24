// Brief 175d · a migration killed mid-flight recovers instead of accumulating.
//
// ⛔ THE ABSORBING STATE. Rows commit before `migration_state` is written, so a
// kill in between leaves rows with no marker. The next launch re-inserted them,
// `COUNT(*)` overtook `loadableCount`, and because verification compares a
// count that only grows it could never succeed again. Measured at `aa2285f`:
// 9 → 19 → 29 → 39 with `COUNT(DISTINCT id)` frozen at 10.
//
// ⭐ THE TEST DRIVES `StorageBoot.init()`, because that is where the recovery
// check lives and it HAS to live there — `migrateJsonToSqlite` returns
// `alreadyMigrated` early, so a check inside it would be skipped on exactly the
// launches that reach the insert path.
//
// ⚠️ A RE-RUN MIGRATES A MOVING TARGET. Prefs keeps accumulating while the
// device is in the failed state, so `sourceEntries` legitimately grows between
// attempts. Nothing here treats that growth as corruption.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';

class _Dirs extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _Dirs(this.root);
  final String root;
  @override
  Future<String?> getApplicationSupportPath() async => root;
  @override
  Future<String?> getApplicationDocumentsPath() async => root;
  @override
  Future<String?> getTemporaryPath() async => root;
  @override
  Future<String?> getLibraryPath() async => root;
}

EventRecord rec(String id, int i) => EventRecord(
      id: id,
      timestamp: DateTime(2026, 9, 1).add(Duration(minutes: i)),
      duration: DurationCategory.lt1,
      durationSeconds: 40,
      eventType: 'seizure',
      severity: EventSeverity.mild,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: false,
      notes: '',
      detailsCompleted: true,
    );

String payload(int n) =>
    jsonEncode([for (var i = 0; i < n; i++) rec('r$i', i).toMap()]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mer_b175d_');
    PathProviderPlatform.instance = _Dirs(root.path);
    SharedPreferences.setMockInitialValues(<String, Object>{
      kEventStorageKey: payload(10),
    });
  });

  tearDown(() async {
    await StorageBoot.database?.close();
    StorageBoot.debugSet();
    try {
      if (await root.exists()) await root.delete(recursive: true);
    } catch (_) {}
  });

  Future<Map<String, Object?>> shape() async {
    final db = StorageBoot.database!;
    return {
      'rows': (await db.rawQuery('SELECT COUNT(*) c FROM event')).first['c'],
      'distinct':
          (await db.rawQuery('SELECT COUNT(DISTINCT id) c FROM event'))
              .first['c'],
      'state': await getMeta(db, kMetaMigrationState),
      'inProgress': await getMeta(db, kMetaMigrationInProgress),
    };
  }

  test('a migration killed mid-flight recovers instead of accumulating',
      () async {
    // ── LAUNCH 1 · a clean, successful migration ─────────────────────────
    final first = await StorageBoot.init();
    expect(first.succeeded, isTrue,
        reason: 'CONTROL: the baseline migration must succeed, or the kill '
            'below is not interrupting anything.');
    expect(await shape(), {
      'rows': 10,
      'distinct': 10,
      'state': 'migrated',
      'inProgress': '0',
    }, reason: 'CONTROL: ten rows, marker cleared on the verified branch.');

    // ── SIMULATE THE KILL ────────────────────────────────────────────────
    // Exactly the state a crash between the insert commit and the state write
    // leaves behind: rows present, in-progress SET, state NOT migrated.
    final db = StorageBoot.database!;
    await putMeta(db, kMetaMigrationInProgress, '1');
    await putMeta(db, kMetaMigrationState, 'failed_verification');
    expect(await shape(), {
      'rows': 10,
      'distinct': 10,
      'state': 'failed_verification',
      'inProgress': '1',
    }, reason: 'CONTROL: the interrupted state is set up as described.');
    await db.close();
    StorageBoot.debugSet();

    // ── LAUNCH 2 · recovery, not accumulation ────────────────────────────
    final second = await StorageBoot.init();
    final after = await shape();

    expect(after['rows'], 10,
        reason: '⛔ THE WHOLE POINT. Before the marker this was 19 — the rows '
            'were inserted a second time on top of the first set, and every '
            'later launch added ten more (19, 29, 39). Recovery means the '
            'row count returns to the record count, not that it climbs.');
    expect(after['rows'], after['distinct'],
        reason: '⛔ AND NO DUPLICATES. COUNT(*) equal to COUNT(DISTINCT id) is '
            'the property that broke: it was 19 rows against 10 distinct ids.');
    expect(second.succeeded, isTrue,
        reason: '⭐ AND IT RECOVERS RATHER THAN LIMPING. Verification now '
            'reconciles, so the device is on SQLite again instead of stuck on '
            'the prefs fallback forever.');
    expect(after['state'], 'migrated');
    expect(after['inProgress'], '0',
        reason: 'the marker is cleared on the verified branch.');
  });

  test('⭐ migrated is AUTHORITATIVE — a set marker never deletes a good '
      'migration', () async {
    await StorageBoot.init();
    final db = StorageBoot.database!;

    // The other crash window: between the two putMeta calls on the verified
    // branch, leaving BOTH migrated and in-progress set.
    await putMeta(db, kMetaMigrationInProgress, '1');
    expect(await shape(), {
      'rows': 10,
      'distinct': 10,
      'state': 'migrated',
      'inProgress': '1',
    }, reason: 'CONTROL: both flags set, which is the window under test.');
    await db.close();
    StorageBoot.debugSet();

    await StorageBoot.init();
    final after = await shape();

    expect(after['rows'], 10,
        reason: '⛔ THE ROWS MUST SURVIVE. `migrated` means the migration '
            'COMPLETED and the rows are correct. Deleting here because the '
            'marker happened to be set would destroy a good migration — which '
            'is why the launch check tests migrated FIRST.');
    expect(after['inProgress'], '0',
        reason: 'and the stale marker is tidied rather than acted on.');
  });

  test('⚠️ a re-run migrates a MOVING TARGET and that is not corruption',
      () async {
    await StorageBoot.init();
    final db = StorageBoot.database!;
    await putMeta(db, kMetaMigrationInProgress, '1');
    await putMeta(db, kMetaMigrationState, 'failed_verification');
    await db.close();
    StorageBoot.debugSet();

    // The user kept recording while the device was in the failed state: the
    // prefs payload is the LIVE store there, so it has grown.
    SharedPreferences.setMockInitialValues(<String, Object>{
      kEventStorageKey: payload(13),
    });

    final result = await StorageBoot.init();
    final after = await shape();

    expect(after['rows'], 13,
        reason: '⛔ THE GROWTH IS THE USER RECORDING EVENTS, not corruption. '
            'The re-run must migrate what prefs holds NOW, not refuse because '
            'the number changed.');
    expect(after['rows'], after['distinct'], reason: 'and still no duplicates.');
    expect(result.succeeded, isTrue,
        reason: '⭐ and it verifies — sourceEntries growing between attempts '
            'is a legitimate outcome, so nothing may treat it as a failure.');
  });
}
