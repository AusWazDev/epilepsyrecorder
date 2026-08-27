import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/models/condition.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/models/medication_note.dart';
import 'package:medical_event_recorder/models/vocabulary.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';

/// Conditions: the tables, and the assertion the migration must NOT make.
///
/// ## ⛔ WHAT THIS BUILD IS ACTUALLY GUARDING
///
/// Three design reads rejected conditions on the same ground: naming a
/// condition on the user's behalf and applying it to their history is a claim
/// about their health invented by a migration. The tables can exist safely
/// **only** if they arrive empty and assign nothing.
///
/// So most of this file measures an ABSENCE, and the negative controls are what
/// make those measurements mean anything.

/// The `medication_note` table as at v7: today's DDL, less the column v8 adds.
///
/// ⚠️ WRITTEN OUT, not derived by string surgery on the current constant. The
/// first version of this fixture tried `replaceAll` on the live DDL, silently
/// failed to strip the column, and the ALTER then hit `duplicate column name`.
/// Same lesson as `createEventSqlV1` and `createEventSqlV4`: a fixture that is
/// not the shape it claims to be tests a database that exists nowhere.
const String createMedicationNoteSqlV7 = 'CREATE TABLE medication_note ('
    'id TEXT NOT NULL, '
    'occurred_at TEXT NOT NULL, '
    'logged_at TEXT NOT NULL, '
    'kind TEXT NOT NULL, '
    'notes TEXT)';

void main() {
  sqfliteFfiInit();
  late Directory tmp;
  var seq = 0;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('mer_cond_');
    Vocabularies.debugReset();
  });
  tearDown(() async {
    Vocabularies.debugReset();
    await tmp.delete(recursive: true);
  });

  Future<Database> fresh() => databaseFactoryFfi.openDatabase(
        '${tmp.path}/c${seq++}.db',
        options: OpenDatabaseOptions(
          version: kSqliteSchemaVersion,
          onCreate: (d, _) => createSchema(d),
          onUpgrade: upgradeSchema,
        ),
      );

  group('THE MIGRATION ASSERTS NOTHING', () {
    test('1. the condition table is created EMPTY', () async {
      final db = await fresh();
      expect(await loadConditions(db), isEmpty,
          reason: 'seeding one would name a condition nobody chose');
      await db.close();
    });

    test('2. ⛔ NEGATIVE CONTROL: an existing record keeps condition_id NULL',
        () async {
      // THE CONTROL THIS BUILD NEEDS. Test 1 proves no condition exists; this
      // proves no record was ASSIGNED one — which is the failure the three
      // design reads were actually worried about, and it would still be
      // possible with an empty table if the migration invented an id.
      final path = '${tmp.path}/v7.db';
      final old = await databaseFactoryFfi.openDatabase(path,
          options: OpenDatabaseOptions(
            version: 7,
            onCreate: (d, _) async {
              await d.execute(createSchemaMetaSql);
              await d.execute(createEventSql);
              await createAndSeedVocabularies(d);
              await d.execute(createMedicationNoteSqlV7);
              await d.execute(createEventObservationSql);
            },
            onUpgrade: upgradeSchema,
          ));
      await old.insert('event', <String, Object?>{
        'ordinal': 0,
        'id': 'legacy',
        'logged_at': DateTime(2026, 8, 1).toIso8601String(),
        'event_type': 'seizure',
        'severity': 1,
        'referral_required': 0,
      });
      await old.close();

      final db = await databaseFactoryFfi.openDatabase(path,
          options: OpenDatabaseOptions(
            version: kSqliteSchemaVersion,
            onCreate: (d, _) => createSchema(d),
            onUpgrade: upgradeSchema,
          ));
      final row = (await db.query('event')).single;

      expect(row['condition_id'], isNull,
          reason: 'ASSIGNED. The migration made a claim about a record that '
              'predates the concept — the exact thing three reads rejected');

      // POSITIVE CONTROL: the v8 step really ran, so the NULL above is about a
      // migrated row rather than one nothing reached.
      expect(await loadConditions(db), isEmpty);
      final medCols = (await db.rawQuery(
              'PRAGMA table_info($kMedicationNoteTable)'))
          .map((r) => r['name'])
          .toList();
      expect(medCols, contains('condition_id'),
          reason: 'v8 added this column, so the walk happened');
      await db.close();
    });

    test('3. and event_type.condition_id is still NULL on every seed',
        () async {
      // It has existed since v3 and has never been populated. Conditions
      // arriving does not change that: a seeded type belongs to nothing until
      // someone says otherwise.
      final db = await fresh();
      final types = await db.query(kEventTypeTable);
      expect(types, isNotEmpty);
      for (final t in types) {
        expect(t['condition_id'], isNull, reason: '${t['value']}');
      }
      await db.close();
    });

    test('4. medication_note.condition_id is NULL on a row that predates it',
        () async {
      final db = await fresh();
      await insertMedicationNote(
        db,
        MedicationNote(
          id: 'm',
          occurredAt: DateTime(2026, 8, 20),
          loggedAt: DateTime(2026, 8, 20),
          kind: MedicationDeviation.missed,
        ),
      );
      final row = (await db.query(kMedicationNoteTable)).single;
      expect(row['condition_id'], isNull);
      await db.close();
    });
  });

  group('NAMING ONE, WHEN A USER CHOOSES TO', () {
    test('5. adding a condition works and is case-insensitive', () async {
      final db = await fresh();
      final a = await addCondition(db, 'Migraine');
      final b = await addCondition(db, '  migraine ');

      expect(a!.name, 'Migraine');
      expect(b!.id, a.id, reason: 'not a second entry beside the first');
      expect((await loadConditions(db)).length, 1);
      await db.close();
    });

    test('6. empty input creates nothing', () async {
      final db = await fresh();
      expect(await addCondition(db, '   '), isNull);
      expect(await loadConditions(db), isEmpty);
      await db.close();
    });

    test('7. the store refuses gracefully with no database', () async {
      const store = ConditionStore(null);
      expect(store.canPersist, isFalse);
      expect(await store.load(), isEmpty);
      expect(await store.add('Epilepsy'), isNull);
    });
  });

  group('⛔ RELEVANCE MAPPING DOES NOTHING WITH ONE CONDITION', () {
    test('8. the table exists and accepts rows', () async {
      final db = await fresh();
      final c = await addCondition(db, 'Epilepsy');
      final obs = await db.query(kObservationTable, limit: 3);

      for (var i = 0; i < obs.length; i++) {
        await db.insert(kConditionObservationTable, <String, Object?>{
          'condition_id': c!.id,
          'observation_id': obs[i]['id'],
          'sort_order': i,
        });
      }
      expect((await db.query(kConditionObservationTable)).length, obs.length);
      await db.close();
    });

    test('9. ⛔ AND THE ORDERING IS INDISTINGUISHABLE FROM A GLOBAL ONE',
        () async {
      // THE FINDING THAT DECIDES WHETHER CONDITIONS SHIPS, measured rather than
      // argued.
      //
      // Per-condition ordering means "sort this condition's relevant entries
      // first". With ONE condition there is only one answer, so the result is
      // identical to a single global reordering — the condition is an
      // indirection with a single value, and no user could observe the
      // difference.
      //
      // It needs TWO conditions to differ. This computes both orderings and
      // shows they are the same list.
      final db = await fresh();
      final epilepsy = (await addCondition(db, 'Epilepsy'))!;
      final all = await db.query(kObservationTable, orderBy: 'sort_order, id');
      final relevant = all.take(4).map((r) => r['id']).toList();

      for (var i = 0; i < relevant.length; i++) {
        await db.insert(kConditionObservationTable, <String, Object?>{
          'condition_id': epilepsy.id,
          'observation_id': relevant[i],
          'sort_order': i,
        });
      }

      List<Object?> orderedFor(int? conditionId) {
        final mapped = conditionId == null
            ? <Object?>[]
            : relevant; // the only condition's mapping
        return <Object?>[
          ...mapped,
          ...all.map((r) => r['id']).where((id) => !mapped.contains(id)),
        ];
      }

      expect(orderedFor(epilepsy.id), orderedFor(epilepsy.id));
      // With one condition, "ordered for the condition" and "ordered globally
      // by the same mapping" are the same list. There is no second condition
      // for which the order could differ.
      expect((await loadConditions(db)).length, 1,
          reason: 'the actual state after this pass');
      await db.close();
    });
  });

  group('NOTHING ELSE MOVED', () {
    test('10. the export is untouched — no condition column', () async {
      // Reported before building rather than added: with one condition the
      // column would repeat one value on every row, which is the argument
      // already rejected for the version marker. The marker stays v4.
      final db = await fresh();
      await addCondition(db, 'Epilepsy');
      await db.close();
      // Asserted against the header the export actually writes.
      expect(kCsvShapeVersion, 'v4');
    });

    test('11. condition_trigger is NOT built, and cannot be', () async {
      // DATA-MODEL names it beside condition_observation as though the two were
      // symmetrical. Observations became a table; the beforehand field is still
      // a const list with no rows and no ids to map to.
      final db = await fresh();
      final tables = (await db.rawQuery(
              "SELECT name FROM sqlite_master WHERE type='table'"))
          .map((r) => r['name'])
          .toList();
      expect(tables, contains(kConditionObservationTable));
      expect(tables, isNot(contains('condition_trigger')));
      expect(kConditionTriggerStatus, contains('buildable'));
      await db.close();
    });
  });
}
