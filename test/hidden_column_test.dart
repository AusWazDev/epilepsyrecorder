import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/backup.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/models/vocabulary.dart';

/// Schema v10 — `event.hidden` — proved on a MIGRATED database, not a fresh one.
///
/// ⛔ **THE FIELD IS INERT AT THIS CHANGE.** It is written, read and
/// round-tripped, and nothing looks at it: no list filters on it, no screen
/// offers to set it, and no read site changed class. Storage lands before
/// behaviour so the migration can be proved on its own terms.
///
/// ## ⭐ WHY A REAL FILE AT v1 RATHER THAN A FRESH DATABASE
///
/// The same reason `sqlite_upgrade_v2_test` gives: a fixture built at the
/// current version **cannot fail**, because `createEventSql` always emits the
/// current column list. Every test here walks 1 → 10 through the app's own
/// `onUpgrade`, over rows inserted by the v1 DDL.
///
/// ## ⛔ AND WHY `ordinal` IS THE THIRD TEST RATHER THAN A DETAIL
///
/// `AUDIT.md` §13(cj) failure mode (a) — **the bin would empty itself.** `save`
/// is a full delete-and-reinsert of whatever list it is handed, so the moment
/// anything filters hidden rows out of that list, the next write deletes them
/// from the table permanently. **That guard has to exist before anything can
/// filter**, which is why it lands with the column and not with the feature.

/// The phase-one `event` table, verbatim — the same fixture
/// `sqlite_upgrade_v2_test` uses, and deliberately a COPY rather than an import:
/// that constant is the v1 shape and must stay frozen even if this file's
/// expectations move.
const String createEventSqlV1 = 'CREATE TABLE event ('
    'ordinal INTEGER NOT NULL, '
    'id TEXT NOT NULL, '
    'logged_at TEXT NOT NULL, '
    'occurred_at TEXT, '
    'duration_bucket TEXT, '
    'duration_seconds INTEGER, '
    'event_type TEXT, '
    'severity INTEGER, '
    'feelings_json TEXT, '
    'triggers_json TEXT, '
    'notes TEXT, '
    'referral_required INTEGER)';

Future<List<String>> columnsOf(Database db) async {
  final info = await db.rawQuery('PRAGMA table_info(event)');
  return info.map((r) => r['name'] as String).toList();
}

/// Every field populated and every one of them NON-DEFAULT, so a value lost on
/// the way through shows as a difference rather than as default-equals-default.
///
/// ⚠️ `hidden: true` is the point of the helper, not an extra: `false` is the
/// default at all three layers, so a fixture leaving it unset would compare
/// equal to a store that dropped the column entirely.
EventRecord full(String id, {required bool hidden}) => EventRecord(
      id: id,
      timestamp: DateTime(2026, 8, 22, 18, 30),
      occurredAt: DateTime(2026, 8, 20, 9, 15),
      duration: DurationCategory.oneToFive,
      durationSeconds: 187,
      detailsCompleted: true,
      feelings: const <String>['Tired'],
      triggers: const <String>['Stress'],
      referralRequired: true,
      notes: 'a note',
      eventType: 'seizure',
      severity: EventSeverity.moderate,
      rescueMedGiven: true,
      rescueMedHelped: RescueResponse.helped,
      rescueMedSecondDose: false,
      hidden: hidden,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  var seq = 0;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('mer_hidden_');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  // A REAL FILE. An in-memory database is discarded on close, so the reopen
  // would run onCreate and never exercise the upgrade at all — and every
  // assertion would then be about a table the migration never touched.
  String nextPath() => '${tmp.path}/mer_${seq++}.db';

  /// Builds a v1 database holding [rows] rows, then reopens it at the current
  /// version through the SAME `onUpgrade` the app wires up.
  Future<Database> openV1ThenUpgrade(String path, {int rows = 3}) async {
    final v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(createSchemaMetaSql);
          await db.execute(createEventSqlV1);
          await db.execute(createEventIdIndexSql);
          await db.execute(createEventLoggedAtIndexSql);
          await putMeta(db, kMetaSchemaVersion, '1');
          await putMeta(db, kMetaMigrationState, 'migrated');
        },
      ),
    );

    for (var i = 0; i < rows; i++) {
      await v1.insert('event', <String, Object?>{
        'ordinal': i,
        'id': 'rec-$i',
        'logged_at': DateTime(2026, 8, 20, 9, i).toIso8601String(),
        'occurred_at': null,
        'duration_bucket': null,
        'duration_seconds': null,
        'event_type': 'seizure',
        'severity': null,
        'feelings_json': null,
        'triggers_json': null,
        'notes': 'row $i',
        'referral_required': 0,
      });
    }
    await v1.close();

    return databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: kSqliteSchemaVersion,
        onCreate: (db, _) => createSchema(db),
        onUpgrade: upgradeSchema,
      ),
    );
  }

  group('the migration', () {
    test('1. the column is added and every pre-existing row reads NOT HIDDEN',
        () async {
      final db = await openV1ThenUpgrade(nextPath());

      expect(await columnsOf(db), contains('hidden'),
          reason: 'schema v10 adds it by ALTER TABLE ADD COLUMN');

      final rows = await db.query('event', orderBy: 'ordinal');
      expect(rows.length, 3, reason: 'no row lost by the ALTER');
      for (final r in rows) {
        // ⛔ 0, NOT NULL — the opposite of every other added column, and
        // deliberately. NULL means NOT ASKED elsewhere; hiding was never a
        // question, so a record that predates the column genuinely is not
        // hidden. `DEFAULT 0` states that rather than guessing it.
        expect(r['hidden'], 0,
            reason: 'a record that predates the column is not hidden, and '
                'that is a fact rather than a default standing in for one');
      }

      await db.close();
    });

    test('2. NEGATIVE CONTROL: the v1 fixture genuinely lacks the column',
        () async {
      // Without this, test 1 passes just as well if the fixture had been built
      // at v10 all along and no upgrade ever ran.
      final db = await databaseFactoryFfi.openDatabase(
        nextPath(),
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute(createSchemaMetaSql);
            await db.execute(createEventSqlV1);
          },
        ),
      );

      expect(await columnsOf(db), isNot(contains('hidden')),
          reason: 'if the fixture already had it, test 1 measures nothing');
      await db.close();
    });

    test('3a. a database that ALREADY carries the column upgrades cleanly',
        () async {
      // ⛔ REGRESSION. The first draft of the v10 step was `from < 10 && to >=
      // 10` with a comment asserting the v4/v8 duplicate-column trap "does not
      // apply", because `event` is created only by `createSchema`. That is true
      // of `lib/` and was declared over everything — six fixtures open at
      // `version: 5`..`8` and build the table with `createEventSql`, which
      // always emits the CURRENT column list. 22 tests threw
      // `duplicate column name: hidden`.
      //
      // This reproduces that exact shape: a database DECLARING an old version
      // while carrying today's columns.
      final path = nextPath();
      final old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 5,
          onCreate: (db, _) async {
            await db.execute(createSchemaMetaSql);
            // Today's DDL, which already has `hidden` — the whole point.
            await db.execute(createEventSql);
            // The v6 step retires an event type, so the vocabulary tables have
            // to exist — the same v5 shape `medication_note_test` builds.
            await createAndSeedVocabularies(db);
            await putMeta(db, kMetaSchemaVersion, '5');
          },
        ),
      );
      expect(await columnsOf(old), contains('hidden'),
          reason: 'positive control: the fixture really does arrive carrying '
              'the column, or this test reproduces nothing');
      await old.close();

      // Must not throw.
      final db = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: kSqliteSchemaVersion,
          onCreate: (db, _) => createSchema(db),
          onUpgrade: upgradeSchema,
        ),
      );
      expect(await getMeta(db, kMetaSchemaVersion), '$kSqliteSchemaVersion',
          reason: 'the upgrade ran to completion rather than throwing part way');
      expect(await columnsOf(db), contains('hidden'));
      await db.close();
    });

    test('3. the schema version actually advanced', () async {
      final db = await openV1ThenUpgrade(nextPath());
      // ⚠️ READ FROM THE CONSTANT, not a literal. This assertion has now been
      // updated twice for a bump it is not about — v10 added `hidden`, v11
      // added `updated_at` — and each time it failed for the right reason and
      // the wrong file. The constant is the thing this test means.
      expect(await getMeta(db, kMetaSchemaVersion), '$kSqliteSchemaVersion',
          reason: 'positive control: the upgrade ran to completion');
      await db.close();
    });
  });

  group('VERIFICATION 1 — round-trip on a MIGRATED database', () {
    test('4. every field survives save then load, hidden among them', () async {
      final db = await openV1ThenUpgrade(nextPath(), rows: 0);
      final store = SqliteEventStore(db);

      final before = <EventRecord>[
        full('keep-visible', hidden: false),
        full('keep-hidden', hidden: true),
      ];
      await store.save(before);
      final after = await store.load();

      expect(after.length, 2, reason: 'positive control: both rows came back, '
          'so the comparison below is over real data');

      // ⛔ COMPARED AS WHOLE MAPS, minus nothing. This path is not meant to
      // change any field, so there is no exclusion to name — the same shape as
      // `rebuild_preserves_fields_test`, with an empty exclusion set.
      for (final b in before) {
        final a = after.firstWhere((r) => r.id == b.id);
        expect(a.toMap(), b.toMap(),
            reason: 'the store lost or altered a field on ${b.id}');
      }

      // Stated separately as well, because the map comparison would also pass
      // if BOTH records came back hidden.
      expect(after.firstWhere((r) => r.id == 'keep-visible').hidden, isFalse);
      expect(after.firstWhere((r) => r.id == 'keep-hidden').hidden, isTrue,
          reason: 'the flag is the whole point of the column');

      await db.close();
    });
  });

  group('VERIFICATION 2 — an old backup has no such key', () {
    test('5. a record with the key ABSENT restores to the constructor default',
        () async {
      // An envelope written before v10: every key this build knows EXCEPT
      // `hidden`. Hand-built rather than produced by `buildBackupJson`, which
      // now always writes the key and so could never reproduce an old file.
      final legacyRecord = full('old', hidden: false).toMap()..remove('hidden');
      expect(legacyRecord.containsKey('hidden'), isFalse,
          reason: 'positive control: the fixture really is missing the key');

      final parsed = parseBackup(jsonEncode(<String, Object?>{
        'format': kBackupFormatId,
        'schemaVersion': kBackupSchemaVersion,
        'exportedAt': DateTime(2026, 8, 1).toIso8601String(),
        'recordCount': 1,
        'records': <Object?>[legacyRecord],
      }));

      expect(parsed.isValid, isTrue,
          reason: 'positive control: an old backup must still restore at all — '
              'treating the absent key as a fault would break every backup '
              'ever taken');
      expect(parsed.records, hasLength(1));
      expect(parsed.records.single.hidden, isFalse,
          reason: 'absent means NOT HIDDEN, and it must equal the constructor '
              'default — see rebuild_preserves_fields_test test 3');
    });

    test('6. the flag TRAVELS in the backup payload', () async {
      // ⛔ NON-NEGOTIABLE. Restore is merge-by-id and add-only, so on a fresh
      // install the backup is a full reconstruction. A hidden record absent
      // from the file is destroyed by an uninstall, and retention is FOREVER.
      final parsed = parseBackup(buildBackupJson(<EventRecord>[
        full('v', hidden: false),
        full('h', hidden: true),
      ]));

      expect(parsed.isValid, isTrue);
      expect(parsed.records.firstWhere((r) => r.id == 'v').hidden, isFalse);
      expect(parsed.records.firstWhere((r) => r.id == 'h').hidden, isTrue,
          reason: 'a hidden record that restores visible has lost the only '
              'thing this column records');
    });
  });

  group('VERIFICATION 3 — §13(cj) failure mode (a), the bin emptying itself',
      () {
    test('7. ordinals survive save/load with a hidden row present', () async {
      final db = await openV1ThenUpgrade(nextPath(), rows: 0);
      final store = SqliteEventStore(db);

      // The hidden row sits in the MIDDLE, so a drop shows as a shifted
      // sequence rather than only as a shorter one.
      final saved = <EventRecord>[
        full('a', hidden: false),
        full('b', hidden: true),
        full('c', hidden: false),
      ];
      await store.save(saved);

      // Read the COLUMN, not the loaded list: `load()` re-sorts on timestamp,
      // so list position after a load says nothing about what was stored.
      final rows = await db.query('event',
          columns: <String>['ordinal', 'id', 'hidden'], orderBy: 'ordinal ASC');

      expect(rows.map((r) => r['id']).toList(), <String>['a', 'b', 'c'],
          reason: 'the hidden row must still be IN the table. If anything ever '
              'filters before save, this is the assertion that catches it — '
              'save is a full delete-and-reinsert, so an omitted row is gone '
              'permanently and retention is FOREVER');
      expect(rows.map((r) => r['ordinal']).toList(), <int>[0, 1, 2],
          reason: 'ordinal is the list index at save time, and it is what makes '
              'unhide restore POSITION rather than append');
      expect(rows.firstWhere((r) => r['id'] == 'b')['hidden'], 1,
          reason: 'positive control: row b really was hidden, so this is not a '
              'test over three visible rows');

      // And the round trip keeps all three.
      final loaded = await store.load();
      expect(loaded.map((r) => r.id).toSet(), <String>{'a', 'b', 'c'},
          reason: 'a hidden record must survive a save/load cycle intact');

      await db.close();
    });
  });
}
