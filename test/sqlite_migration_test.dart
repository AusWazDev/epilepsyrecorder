import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/capture_inbox.dart';
import 'package:medical_event_recorder/models/capture_instruction.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/models/storage_migration.dart';

/// SQLite phase one. The build answers ONE question — did every record survive?
/// — so these tests are arranged around exactly that, including the two cases
/// that would otherwise go untested: the fallback path, and a negative control
/// proving verification can actually fail.

Future<Database> openTestDb() => databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: kSqliteSchemaVersion,
        onCreate: (db, _) => createSchema(db),
      ),
    );

/// A record as the OLD store writes it — every key present.
Map<String, dynamic> fullRecord(String id, DateTime ts) => {
      'id': id,
      'timestamp': ts.toIso8601String(),
      'duration': 'oneToFive',
      'feelings': ['Tired', 'Confused'],
      'referralRequired': true,
      'notes': 'a note',
      'eventType': 'absence',
      'severity': 'severe',
      'triggers': ['Poor sleep'],
    };

/// A record as an OLDER build wrote it — the three later fields absent.
/// `EventRecord.fromMap` calls its coercions "safe fallbacks for old records";
/// this is the shape that exposes them.
Map<String, dynamic> legacyRecord(String id, DateTime ts) => {
      'id': id,
      'timestamp': ts.toIso8601String(),
      'duration': 'gt5',
      'feelings': ['Sore'],
      'referralRequired': false,
      'notes': '',
    };

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final t0 = DateTime(2026, 8, 20, 9, 30);

  group('the migration reads raw JSON, not EventRecord', () {
    test('1. every record survives, and the count reconciles', () async {
      final db = await openTestDb();
      final raw = jsonEncode([
        fullRecord('a', t0),
        fullRecord('b', t0.add(const Duration(hours: 1))),
        legacyRecord('c', t0.add(const Duration(hours: 2))),
      ]);

      final out = await migrateJsonToSqlite(db: db, rawJson: raw);

      expect(out.state, MigrationState.migrated);
      expect(out.sourceEntries, 3);
      expect(out.loadableCount, 3);
      expect(out.insertedCount, 3);
      expect(out.skipped, 0);
      await db.close();
    });

    test('2. ids are preserved verbatim and NEVER case-folded', () async {
      final db = await openTestDb();
      // Swift generates uppercase, Dart lowercase. Both exist in stored data,
      // and restore matches on id.
      final raw = jsonEncode([
        fullRecord('E4F2A1B0-9C3D-4E5F-8A7B-6C5D4E3F2A1B', t0),
        fullRecord('e4f2a1b0-9c3d-4e5f-8a7b-6c5d4e3f2a1b', t0),
      ]);

      await migrateJsonToSqlite(db: db, rawJson: raw);
      final ids = (await db.query('event', columns: ['id'], orderBy: 'ordinal'))
          .map((r) => r['id'] as String)
          .toList();

      expect(ids, [
        'E4F2A1B0-9C3D-4E5F-8A7B-6C5D4E3F2A1B',
        'e4f2a1b0-9c3d-4e5f-8a7b-6c5d4e3f2a1b',
      ]);
      expect(ids[0], isNot(equals(ids[1])),
          reason: 'folding case would merge two distinct records');
      await db.close();
    });

    test('3. an ABSENT key becomes NULL, not a fabricated default', () async {
      final db = await openTestDb();
      final raw = jsonEncode([legacyRecord('c', t0)]);

      final out = await migrateJsonToSqlite(db: db, rawJson: raw);
      final row = (await db.query('event')).single;

      // The whole reason the migration does not read through fromMap.
      expect(row['event_type'], isNull,
          reason: 'fromMap would have written seizure');
      expect(row['severity'], isNull, reason: 'fromMap would have written mild');
      expect(row['triggers_json'], isNull);

      expect(out.absentCounts['eventType'], 1);
      expect(out.absentCounts['severity'], 1);
      expect(out.absentCounts['triggers'], 1);

      // And the counts are durable, which the NULLs are not: save(List)
      // rewrites every row and EventRecord cannot express unknown.
      expect(await getMeta(db, '${kMetaAbsentPrefix}severity'), '1');
      await db.close();
    });

    test('4. a NULL column still loads as the record the old store produced',
        () async {
      final db = await openTestDb();
      await migrateJsonToSqlite(
          db: db, rawJson: jsonEncode([legacyRecord('c', t0)]));

      final viaSqlite = (await SqliteEventStore(db).load()).single;
      final viaOldStore =
          EventRecord.fromMap(Map<String, dynamic>.from(legacyRecord('c', t0)))!;

      expect(viaSqlite.eventType, viaOldStore.eventType);
      expect(viaSqlite.severity, viaOldStore.severity);
      expect(viaSqlite.duration, viaOldStore.duration);
      expect(viaSqlite.triggers, viaOldStore.triggers);
      expect(viaSqlite.id, viaOldStore.id);
      expect(viaSqlite.timestamp, viaOldStore.timestamp);
      await db.close();
    });

    test('5. occurred_at and duration_seconds stay NULL; the bucket is kept',
        () async {
      final db = await openTestDb();
      await migrateJsonToSqlite(
          db: db, rawJson: jsonEncode([fullRecord('a', t0)]));
      final row = (await db.query('event')).single;

      expect(row['occurred_at'], isNull,
          reason: 'the source is log time; calling it event time fabricates');
      expect(row['duration_seconds'], isNull,
          reason: 'a number must never be invented from a bucket');
      expect(row['duration_bucket'], 'oneToFive');
      expect(row['logged_at'], t0.toIso8601String());
      await db.close();
    });

    test('6. a record the old store would skip is skipped AND counted',
        () async {
      final db = await openTestDb();
      final raw = jsonEncode([
        fullRecord('a', t0),
        {'id': 'bad', 'timestamp': 'not-a-date'},
        {'id': 'none'},
      ]);

      final out = await migrateJsonToSqlite(db: db, rawJson: raw);

      expect(out.sourceEntries, 3);
      expect(out.loadableCount, 1);
      expect(out.skipped, 2, reason: 'named, not left as a silent difference');
      expect(out.state, MigrationState.migrated,
          reason: 'they are already invisible in the old store');
      await db.close();
    });

    test('7. duplicate ids are carried across, not rejected', () async {
      final db = await openTestDb();
      final raw = jsonEncode([fullRecord('dup', t0), fullRecord('dup', t0)]);

      final out = await migrateJsonToSqlite(db: db, rawJson: raw);

      expect(out.insertedCount, 2, reason: 'rejecting one would LOSE a record');
      expect(out.distinctIds, 1, reason: 'and the device is told');
      await db.close();
    });

    test('8. a second run is a no-op', () async {
      final db = await openTestDb();
      final raw = jsonEncode([fullRecord('a', t0)]);
      await migrateJsonToSqlite(db: db, rawJson: raw);

      final again = await migrateJsonToSqlite(db: db, rawJson: raw);

      expect(again.state, MigrationState.alreadyMigrated);
      expect((await db.query('event')).length, 1, reason: 'not doubled');
      await db.close();
    });

    test('9. load() returns newest-first, matching the old store', () async {
      final db = await openTestDb();
      final raw = jsonEncode([
        fullRecord('oldest', t0),
        fullRecord('newest', t0.add(const Duration(days: 2))),
        fullRecord('middle', t0.add(const Duration(days: 1))),
      ]);
      await migrateJsonToSqlite(db: db, rawJson: raw);

      final ids = (await SqliteEventStore(db).load()).map((r) => r.id).toList();

      expect(ids, ['newest', 'middle', 'oldest']);
      await db.close();
    });

    test('10. save then load round-trips every field', () async {
      final db = await openTestDb();
      final store = SqliteEventStore(db);
      final original = EventRecord.fromMap(
          Map<String, dynamic>.from(fullRecord('rt', t0)))!;

      await store.save([original]);
      final back = (await store.load()).single;

      expect(back.id, original.id);
      expect(back.timestamp, original.timestamp);
      expect(back.duration, original.duration);
      expect(back.feelings, original.feelings);
      expect(back.triggers, original.triggers);
      expect(back.notes, original.notes);
      expect(back.referralRequired, original.referralRequired);
      expect(back.eventType, original.eventType);
      expect(back.severity, original.severity);
      await db.close();
    });
  });

  group('NEGATIVE CONTROL: verification can fail', () {
    test('11. a dropped record fails verification and does NOT mark complete',
        () async {
      final db = await openTestDb();
      final raw = jsonEncode([
        fullRecord('a', t0),
        fullRecord('b', t0.add(const Duration(hours: 1))),
        fullRecord('c', t0.add(const Duration(hours: 2))),
      ]);

      final out = await migrateJsonToSqlite(
        db: db,
        rawJson: raw,
        dropForNegativeControl: 1,
      );

      expect(out.state, MigrationState.failedVerification,
          reason: 'without this the passing case is unfalsifiable');
      expect(out.loadableCount, 3);
      expect(out.insertedCount, 2);
      expect(out.succeeded, isFalse);
      expect(await getMeta(db, kMetaMigrationState), 'failed_verification');
      expect(await getMeta(db, kMetaMigratedAt), isNull,
          reason: 'never marked complete on a count that does not reconcile');
      await db.close();
    });
  });

  group('THE FALLBACK PATH: migration fails, the drain still lands', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('12. the inbox drains into the OLD store when SQLite is not adopted',
        () async {
      final db = await openTestDb();

      // Verification fails, so this launch runs on shared_preferences.
      final out = await migrateJsonToSqlite(
          db: db,
          rawJson: jsonEncode([fullRecord('a', t0)]),
          dropForNegativeControl: 1);
      expect(out.succeeded, isFalse, reason: 'precondition for this test');

      final fallbackStore = EventStore();
      expect(fallbackStore, isNot(isA<SqliteEventStore>()),
          reason: 'this launch must NOT be running on SQLite');

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '${kInboxKeyPrefix}start_x',
        jsonEncode({
          'v': kInboxSchemaVersion,
          'kind': kInboxKindStart,
          'id': 'x',
          'at': t0.toIso8601String(),
        }),
      );

      final drain = await drainInbox(
        transport: PrefsInboxTransport(prefs),
        store: fallbackStore,
        loaded: const <EventRecord>[],
      );

      expect(drain.wrote, isTrue);
      expect(drain.records.map((r) => r.id), contains('x'));

      // Landed in the OLD store, which is the whole point of the fallback.
      final stored = jsonDecode(prefs.getString(kEventStorageKey)!) as List;
      expect(stored.map((e) => (e as Map)['id']), contains('x'));

      // And only then were the keys removed.
      final leftover =
          prefs.getKeys().where((k) => k.startsWith(kInboxKeyPrefix));
      expect(leftover, isEmpty);
      await db.close();
    });

    test('13. a FAILED write leaves the inbox keys in place', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '${kInboxKeyPrefix}start_y',
        jsonEncode({
          'v': kInboxSchemaVersion,
          'kind': kInboxKindStart,
          'id': 'y',
          'at': t0.toIso8601String(),
        }),
      );

      final drain = await drainInbox(
        transport: PrefsInboxTransport(prefs),
        store: _FailingStore(),
        loaded: const <EventRecord>[],
      );

      expect(drain.attempted, isTrue);
      expect(drain.wrote, isFalse);
      expect(prefs.getKeys().where((k) => k.startsWith(kInboxKeyPrefix)),
          hasLength(1),
          reason: 'deleting before the write is confirmed would lose the '
              'capture outright');
    });
  });
}

/// Both stores must satisfy the same interface at run time — including when
/// one of them is failing.
class _FailingStore implements EventStore {
  @override
  Future<List<EventRecord>> load() async => <EventRecord>[];

  @override
  Future<void> save(List<EventRecord> records) async =>
      throw StateError('storage unavailable');

  @override
  Future<SharedPreferences> clearAll() => SharedPreferences.getInstance();
}
