import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/vocabulary.dart';

/// The catch-all entry renders LAST, on every vocabulary, whatever its
/// `sort_order` says.
///
/// ## ⛔ WHAT THIS EXISTS TO STOP, AND IT ALMOST HAPPENED
///
/// `offerable` forced "Other" last by comparing against exactly two constants —
/// `kOtherEventTypeValue` and `kOtherObservationValue`. **The trigger
/// vocabulary's catch-all, `Unknown`, was not among them**, and nothing showed,
/// because `Unknown` was the LAST seed in `kSeedTriggers` and its `sort_order`
/// put it last anyway.
///
/// **The closed list and the seed order agreed by coincidence.** The first
/// trigger appended after `Unknown` separates them — and the migraine pass
/// appends three, so this would have shipped as a visible defect on the
/// epilepsy path caused by a migraine change.
///
/// ⚠️ Test 3 is the one that matters: it appends and then asserts. A test that
/// only checked today's seed list would have passed before the fix.
///
/// ## ⚠️ WHY THE RULE IS APPLIED AT READ TIME RATHER THAN FIXED IN THE DATA
///
/// `seedVocabulary` skips values that already exist, and
/// `syncSeededPresentation` updates only `label` and `emoji` — **nothing
/// rewrites `sort_order` on a row that is already there.** So on every database
/// already in the field the catch-all keeps the order it was first inserted
/// with. Sorting it last on the way out is the only fix that reaches those
/// devices, and test 4 pins that property directly.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Future<Database> fresh() async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1, onCreate: (d, _) async {
      await createAndSeedVocabularies(d);
      // Triggers became a vocabulary at schema v9 and have their own creator;
      // createAndSeedVocabularies does not cover them.
      await createAndSeedTriggers(d);
    }));
    return db;
  }

  group('THE CATCH-ALL IS LAST ON EVERY VOCABULARY', () {
    test('1. event types', () async {
      final db = await fresh();
      final offered =
          offerable(kEventTypeTable, await loadVocabulary(db, kEventTypeTable));
      expect(offered.last.value, kOtherEventTypeValue);
      await db.close();
    });

    test('2. observations', () async {
      final db = await fresh();
      final offered = offerable(
          kObservationTable, await loadVocabulary(db, kObservationTable));
      expect(offered.last.value, kOtherObservationValue);
      await db.close();
    });

    test('3. ⛔ TRIGGERS — and it is last even with entries AFTER it', () async {
      final db = await fresh();
      final offered =
          offerable(kTriggerTable, await loadVocabulary(db, kTriggerTable));

      expect(offered.last.value, kUnknownTriggerValue,
          reason: 'Unknown was NOT in the forced-last set, and three seeded '
              'triggers now sort after it');

      // The negative control: those three really are present and really do
      // sort after Unknown by sort_order, so this is not passing vacuously.
      final bySortOrder =
          (await loadVocabulary(db, kTriggerTable)).map((e) => e.value).toList();
      expect(bySortOrder.last, 'Dehydration',
          reason: 'POSITIVE CONTROL: by raw sort_order the catch-all is NOT '
              'last, which is exactly the condition being corrected');
      expect(bySortOrder.indexOf(kUnknownTriggerValue),
          lessThan(bySortOrder.indexOf('Period or hormonal')));

      await db.close();
    });

    test('4. a user entry added later does not displace it', () async {
      final db = await fresh();
      await addUserEntry(db, kTriggerTable, 'Heatwave');
      final offered =
          offerable(kTriggerTable, await loadVocabulary(db, kTriggerTable));
      expect(offered.last.value, kUnknownTriggerValue);
      expect(offered.map((e) => e.value), contains('Heatwave'));
      await db.close();
    });

    test('5. SCOPED BY (TABLE, VALUE), not by the word alone', () async {
      // A user's own observation typed as "Unknown" is THEIRS and must not be
      // dragged to the end by a rule about the trigger table.
      expect(isCatchAll(kObservationTable, kUnknownTriggerValue), isFalse);
      expect(isCatchAll(kTriggerTable, kUnknownTriggerValue), isTrue);
      expect(isCatchAll(kTriggerTable, kOtherObservationValue), isFalse);
      expect(isCatchAll(kObservationTable, kOtherObservationValue), isTrue);
    });
  });

  group('THE THREE MIGRAINE TRIGGERS', () {
    test('6. seeded, offered, and appended after the existing seven', () async {
      final db = await fresh();
      final values =
          (await loadVocabulary(db, kTriggerTable)).map((e) => e.value).toList();

      expect(values.take(7), <String>[
        'Stress',
        'Poor sleep',
        'Missed medication',
        'Alcohol',
        'Flashing lights',
        'Illness',
        'Unknown',
      ], reason: 'the original seven keep their order, so no existing export '
          'column reorders');
      expect(values.sublist(7),
          <String>['Period or hormonal', 'Certain foods', 'Dehydration']);
      await db.close();
    });

    test('7. ⛔ kTriggerOptions and kSeedTriggers still agree', () {
      // The CSV's canonical order is a DELIBERATE duplicate of the seed list,
      // so a user's additions cannot reorder the historical column. A seeded
      // addition must land in both, and this is what says so.
      expect(kTriggerOptions, kSeedTriggers.map((s) => s.value).toList());
    });

    test('8. they reach an EXISTING database, with no migration', () async {
      // Seeded WITHOUT the three, then re-seeded with the live list — which is
      // what happens on the next launch after an update. seedVocabulary is
      // idempotent and additive, so no schema change is involved.
      final db = await databaseFactory.openDatabase(inMemoryDatabasePath,
          options: OpenDatabaseOptions(version: 1, onCreate: (d, _) async {
        await d.execute(createVocabularySql(kTriggerTable));
        await seedVocabulary(d, kTriggerTable, const <VocabularySeed>[
          VocabularySeed('Stress', 'Stress'),
          VocabularySeed('Unknown', 'Unknown'),
        ]);
      }));

      expect((await loadVocabulary(db, kTriggerTable)).length, 2);

      await seedVocabulary(db, kTriggerTable, kSeedTriggers);
      final after = await loadVocabulary(db, kTriggerTable);
      expect(after.map((e) => e.value), contains('Period or hormonal'));

      // ⚠️ AND THE PROPERTY THAT FORCED THE READ-TIME FIX: the pre-existing
      // Unknown keeps its ORIGINAL sort_order, so the new rows sort after it.
      // Nothing rewrites sort_order on a row that already exists.
      final raw = after.map((e) => e.value).toList();
      expect(raw.indexOf('Unknown'), lessThan(raw.indexOf('Period or hormonal')),
          reason: 'proves the read-time ordering is doing real work on a '
              'database that already existed');
      expect(
          offerable(kTriggerTable, after).last.value, kUnknownTriggerValue);
      await db.close();
    });
  });
}
