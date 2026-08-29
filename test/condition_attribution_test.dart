import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/models/condition.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/models/vocabulary.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';

/// Multi-condition, pass 1: attribution by DERIVATION.
///
/// ## ⛔ WHAT THIS BUILD AVOIDS, AND WHY THAT IS THE WHOLE POINT
///
/// The alternative design stores `condition_id` on every event. That needs
/// someone to decide what the 72 existing records belong to — and **a migration
/// deciding that is an assertion about the user's health that nobody made.**
/// Three design reads rejected exactly that, and nullable `condition_id` is
/// what resolved it.
///
/// Deriving asks for ONE statement instead: "these types are my epilepsy". The
/// statement is the user's, about their own vocabulary, and it is revisable.
///
/// So the load-bearing tests here are not "assignment works". They are:
///
///   * test 4 — NO RECORD IS TOUCHED by any of this
///   * test 5 — the untyped record stays unattributed
///   * test 8a — grouping is driven by GROUPS PRESENT, not condition count
void main() {
  sqfliteFfiInit();
  late Directory tmp;
  var seq = 0;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('mer_cond_attr_');
    Vocabularies.debugReset();
  });
  tearDown(() async {
    Vocabularies.debugReset();
    await tmp.delete(recursive: true);
  });

  Future<Database> fresh() => databaseFactoryFfi.openDatabase(
        '${tmp.path}/a${seq++}.db',
        options: OpenDatabaseOptions(
          version: kSqliteSchemaVersion,
          onCreate: (d, _) => createSchema(d),
          onUpgrade: upgradeSchema,
        ),
      );

  VocabularyEntry typeNamed(String value) =>
      Vocabularies.allIn(kEventTypeTable).firstWhere((e) => e.value == value);

  group('ASSIGNMENT', () {
    test('1. a type can be assigned to a condition, and it persists', () async {
      final db = await fresh();
      await Vocabularies.load(db);
      final epilepsy = (await addCondition(db, 'Epilepsy'))!;

      await Vocabularies.setCondition(
          kEventTypeTable, typeNamed('seizure'), epilepsy.id);

      expect(typeNamed('seizure').conditionId, epilepsy.id);

      // Survives a reload — the write reached the row, not just the cache.
      Vocabularies.debugReset();
      await Vocabularies.load(db);
      expect(typeNamed('seizure').conditionId, epilepsy.id);
      await db.close();
    });

    test('2. ⛔ a second assignment REPLACES the first — one condition per type',
        () async {
      // The constraint the whole attribution model rests on. It is enforced by
      // the COLUMN SHAPE: `condition_id` holds one value, so the second
      // assignment overwrites. Nothing throws, because the shape refuses before
      // the code has to — and the user sees it in the picker immediately.
      final db = await fresh();
      await Vocabularies.load(db);
      final epilepsy = (await addCondition(db, 'Epilepsy'))!;
      final migraine = (await addCondition(db, 'Migraine'))!;

      await Vocabularies.setCondition(
          kEventTypeTable, typeNamed('seizure'), epilepsy.id);
      await Vocabularies.setCondition(
          kEventTypeTable, typeNamed('seizure'), migraine.id);

      expect(typeNamed('seizure').conditionId, migraine.id);
      expect(typeNamed('seizure').conditionId, isNot(epilepsy.id),
          reason: 'a type under TWO conditions is not a type, it is an '
              'ambiguity — an event of that type could be either');
      await db.close();
    });

    test('3. an assignment can be CLEARED back to null', () async {
      // Null is a real value here, not "leave it alone" — which is why
      // copyWith takes a sentinel. A user who mis-assigns must be able to undo
      // it without deleting the type.
      final db = await fresh();
      await Vocabularies.load(db);
      final epilepsy = (await addCondition(db, 'Epilepsy'))!;

      await Vocabularies.setCondition(
          kEventTypeTable, typeNamed('seizure'), epilepsy.id);
      expect(typeNamed('seizure').conditionId, isNotNull);

      await Vocabularies.setCondition(
          kEventTypeTable, typeNamed('seizure'), null);
      expect(typeNamed('seizure').conditionId, isNull);
      await db.close();
    });

    test('4. ⛔ NEGATIVE CONTROL: NO RECORD IS TOUCHED BY ANY OF THIS',
        () async {
      // THE CONTROL THIS BUILD NEEDS. Every test above passes against an
      // implementation that also writes `condition_id` onto 72 event rows —
      // which is the migration three design reads rejected. This is what
      // separates deriving from assigning.
      final db = await fresh();
      await Vocabularies.load(db);

      for (var i = 0; i < 3; i++) {
        await db.insert('event', <String, Object?>{
          'ordinal': i,
          'id': 'e$i',
          'logged_at': DateTime(2026, 8, 20 + i).toIso8601String(),
          'event_type': 'seizure',
          'severity': 1,
          'referral_required': 0,
        });
      }

      final epilepsy = (await addCondition(db, 'Epilepsy'))!;
      await Vocabularies.setCondition(
          kEventTypeTable, typeNamed('seizure'), epilepsy.id);

      final rows = await db.query('event', columns: <String>['id', 'condition_id']);
      expect(rows.length, 3);
      for (final r in rows) {
        expect(r['condition_id'], isNull,
            reason: 'ASSIGNED. A record was given a condition by code rather '
                'than by the user — the exact migration this design exists to '
                'avoid');
      }

      // POSITIVE CONTROL: the assignment really happened, so the NULLs above
      // are about a live attribution rather than a no-op.
      expect(typeNamed('seizure').conditionId, epilepsy.id);
      await db.close();
    });
  });

  group('⛔ DERIVATION', () {
    test('5. a record derives its condition from its type — and NULL survives',
        () async {
      final db = await fresh();
      await Vocabularies.load(db);
      final epilepsy = (await addCondition(db, 'Epilepsy'))!;
      await Vocabularies.setCondition(
          kEventTypeTable, typeNamed('seizure'), epilepsy.id);

      expect(Vocabularies.conditionIdForEventType('seizure'), epilepsy.id);

      // The quick-record path writes NO event type. That record has no
      // condition, and that is a real answer — NOT YET SAID, the same rule as
      // occurredAt and duration at creation.
      expect(Vocabularies.conditionIdForEventType(null), isNull,
          reason: 'an untyped record must NOT inherit the primary condition — '
              'that would invent the attribution this design avoids');

      // A type nobody has assigned also has no condition.
      expect(Vocabularies.conditionIdForEventType('absence'), isNull);

      // A value this vocabulary has never seen resolves to null, not a throw.
      expect(Vocabularies.conditionIdForEventType('never-seen'), isNull);
      await db.close();
    });

    test('6. ONE user statement attributes every record carrying that type',
        () async {
      // The payoff, stated as the device's real shape: 71 of 72 records carry
      // `seizure`. One assignment attributes all 71, with no migration and no
      // bulk edit of medical records.
      final db = await fresh();
      await Vocabularies.load(db);
      final epilepsy = (await addCondition(db, 'Epilepsy'))!;
      await Vocabularies.setCondition(
          kEventTypeTable, typeNamed('seizure'), epilepsy.id);

      final deviceTypes = <String?>[
        for (var i = 0; i < 71; i++) 'seizure',
        null, // the one record with no type
      ];
      final derived =
          deviceTypes.map(Vocabularies.conditionIdForEventType).toList();

      expect(derived.where((c) => c == epilepsy.id).length, 71);
      expect(derived.where((c) => c == null).length, 1,
          reason: 'the untyped record stays unattributed, honestly');
      await db.close();
    });

    test('7. reassigning the type re-attributes every record at once', () async {
      // The other half of deriving: a correction is one edit, not 71. With
      // stored attribution this would need a second migration.
      final db = await fresh();
      await Vocabularies.load(db);
      final a = (await addCondition(db, 'Epilepsy'))!;
      final b = (await addCondition(db, 'Something else'))!;

      await Vocabularies.setCondition(kEventTypeTable, typeNamed('seizure'), a.id);
      expect(Vocabularies.conditionIdForEventType('seizure'), a.id);

      await Vocabularies.setCondition(kEventTypeTable, typeNamed('seizure'), b.id);
      expect(Vocabularies.conditionIdForEventType('seizure'), b.id);
      await db.close();
    });
  });

  group('⛔ THE PICKER GROUPS, IT DOES NOT FILTER', () {
    test('8a. ⛔ grouping is driven by GROUPS PRESENT, not by condition count',
        () async {
      // ⚠️ THIS TEST WAS FIRST WRITTEN AS "one condition means one group" and
      // that assertion is FALSE: seeded types nobody has assigned form a second, null
      // group. Recorded rather than deleted — the wrong assertion is the
      // interesting half, because a picker that grouped only on condition
      // COUNT would show one heading and hide the unassigned types under it.
      //
      // The real rule: group when there is more than one GROUP.
      final db = await fresh();
      await Vocabularies.load(db);
      final epilepsy = (await addCondition(db, 'Epilepsy'))!;

      // Nothing assigned yet: everything is unassigned, so ONE group.
      expect(Vocabularies.offerableEventTypesByCondition().length, 1,
          reason: 'a user who has named a condition but assigned nothing must '
              'not suddenly see headings');

      await Vocabularies.setCondition(
          kEventTypeTable, typeNamed('seizure'), epilepsy.id);

      // Now some are assigned and some are not: TWO groups, and the heading
      // is what tells the user their assignment landed.
      expect(Vocabularies.offerableEventTypesByCondition().length, 2);
      await db.close();
    });

    test('9. unassigned types sort LAST, and every type stays reachable',
        () async {
      // GROUPED, NOT FILTERED. There is no condition context at capture, so a
      // filtered picker would make a second condition unrecordable. Every
      // offerable type must appear in exactly one group, and the null group —
      // which is not a condition — comes last.
      final db = await fresh();
      await Vocabularies.load(db);
      final epilepsy = (await addCondition(db, 'Epilepsy'))!;
      await Vocabularies.setCondition(
          kEventTypeTable, typeNamed('seizure'), epilepsy.id);

      final groups = Vocabularies.offerableEventTypesByCondition();
      expect(groups.keys.last, isNull, reason: 'the unassigned group is last');

      final grouped = groups.values.expand((v) => v).map((e) => e.value).toSet();
      final offerable =
          Vocabularies.offerableEventTypes.map((e) => e.value).toSet();
      expect(grouped, offerable,
          reason: 'A TYPE WENT MISSING FROM THE PICKER. Grouping must not '
              'drop anything — that would be filtering, and filtering at '
              'capture makes a condition unrecordable');
      await db.close();
    });
  });

  group('THE SHARED VOCABULARIES ARE NOT TOUCHED', () {
    test('10. observations and triggers REFUSE assignment', () async {
      // DATA-MODEL §1 principle 4: one trigger list, one observation list,
      // shared across conditions. Someone tracking two conditions does not
      // configure "Poor sleep" twice. Assigning one would contradict the model,
      // so it throws rather than quietly writing a column nothing reads.
      final db = await fresh();
      await Vocabularies.load(db);
      final epilepsy = (await addCondition(db, 'Epilepsy'))!;

      for (final table in <String>[kObservationTable, kTriggerTable]) {
        final entry = Vocabularies.allIn(table).first;
        await expectLater(
          () => Vocabularies.setCondition(table, entry, epilepsy.id),
          throwsA(isA<VocabularyRuleError>()),
          reason: table,
        );
      }
      await db.close();
    });
  });
}
