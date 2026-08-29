import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/models/vocabulary.dart';

/// Condition relevance as a RANKING KEY — the link cold start needs.
///
/// ## ⛔ WHY THE DEVICE CANNOT DECIDE THIS, AND THE UNIT TESTS CAN
///
/// The brief's decisive test was "does the real user's picker demonstrably
/// improve". It cannot, for two INDEPENDENT reasons, and neither is a defect:
///
///   1. **Seed order is already a perfect proxy** for epilepsy relevance. The
///      twelve mapped entries occupy seed positions 1-12 and everything
///      appended since is migraine, so ranking them first changes nothing.
///      Seed order is a proxy for relevance for exactly ONE condition — the
///      first one seeded — and that is the one the device has.
///   2. **Nothing on any device carries a `seeded_key`.** `addCondition`
///      writes null and there is no other writer, so the mapping cannot attach
///      to a user-typed name without MER inferring which condition they meant.
///
/// So the demonstration lives here, where a second condition can be posited
/// without publishing a list of names. Test 4 is the one that shows relevance
/// doing work the seed order does not.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Future<List<VocabularyEntry>> seeded(String table) async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1, onCreate: (d, _) async {
      await createAndSeedVocabularies(d);
      await createAndSeedTriggers(d);
    }));
    final v = await loadVocabulary(db, table);
    await db.close();
    return v;
  }

  final epilepsy = relevantValues(<String>{'epilepsy'}, kObservationTable);

  group('THE MAPPING IS THE ONE IN THE RECORD', () {
    test('1. twelve values, and every one exists in the vocabulary', () async {
      expect(epilepsy.length, 12);
      final values =
          (await seeded(kObservationTable)).map((e) => e.value).toSet();
      for (final v in epilepsy) {
        expect(values, contains(v), reason: '"$v" is mapped but not seeded');
      }
    });

    test('2. it excludes every migraine addition', () {
      for (final v in <String>[
        'Sensitive to light',
        'Sensitive to smell',
        'Neck stiffness',
        'Vomiting',
        'Light-headed or faint',
      ]) {
        expect(epilepsy, isNot(contains(v)),
            reason: 'the mapping is as much about what it does NOT rank');
      }
    });

    test('3. ⛔ THERE IS NO TRIGGER MAPPING, and that is deliberate', () {
      expect(relevantValues(<String>{'epilepsy'}, kTriggerTable), isEmpty,
          reason: 'the register sources the observation set for epilepsy and '
              'sources nothing for the seven original triggers — inventing one '
              'from the entry names is what the sourcing rule forbids');
    });
  });

  group('⭐ RELEVANCE DOES WORK SEED ORDER CANNOT', () {
    test('4. a SECOND condition ranks its own entries first', () async {
      // Posited, not published: a mapping whose entries sit LATE in seed order,
      // which is every condition except the first one seeded. This is the case
      // the device cannot show.
      final all = await seeded(kObservationTable);
      // Observations only. `Yawning` is a BEFOREHAND entry and would test
      // nothing here -- the first draft of this file used it and the
      // controls caught it.
      final migraineish = <String>{'Sensitive to light', 'Vomiting'};

      final before = offerable(kObservationTable, all).map((e) => e.value).toList();
      final after = offerable(kObservationTable, all, relevant: migraineish)
          .map((e) => e.value)
          .toList();

      expect(before.indexOf('Sensitive to light'), greaterThan(10),
          reason: 'POSITIVE CONTROL: it really is buried in seed order');
      expect(after.take(2), containsAll(<String>['Sensitive to light', 'Vomiting']));
      expect(after.first, isNot(before.first),
          reason: 'the list genuinely reorders');
    });

    test('5. and for EPILEPSY it changes nothing — the finding, pinned',
        () async {
      final all = await seeded(kObservationTable);
      final plain = offerable(kObservationTable, all).map((e) => e.value);
      final ranked = offerable(kObservationTable, all, relevant: epilepsy)
          .map((e) => e.value);
      expect(ranked, plain,
          reason: 'seed order already ranks the twelve first, so relevance is '
              'a no-op for the one condition the device has. If this ever '
              'FAILS, seed order and the mapping have diverged.');
    });
  });

  group('⛔ ORDERS, NEVER FILTERS', () {
    test('6. THE CONTROL: a filter implementation would fail here', () async {
      final all = await seeded(kObservationTable);
      final ranked = offerable(kObservationTable, all,
          relevant: <String>{'Confused', 'Tired'});

      expect(ranked.length, offerable(kObservationTable, all).length,
          reason: 'RELEVANCE MUST NOT CHANGE WHAT IS OFFERED. A filter would '
              'return 2 here and this is the rule refused three times.');
      expect(ranked.map((e) => e.value), contains('Sensitive to smell'),
          reason: 'an entry relevant to nothing the user tracks is still '
              'offered — a migraine user who has a memory gap must be able to '
              'record it');
    });

    test('7. the catch-all stays last, relevance or not', () async {
      final all = await seeded(kObservationTable);
      final ranked = offerable(kObservationTable, all,
          relevant: <String>{kOtherObservationValue, 'Confused'});
      expect(ranked.last.value, kOtherObservationValue);
    });
  });

  group('⚠️ USAGE OUTRANKS RELEVANCE — the deliberate deviation', () {
    test('8. a used entry is NOT demoted by being irrelevant', () async {
      final all = await seeded(kObservationTable);
      final ranked = offerable(kObservationTable, all,
          usage: <String, int>{'Vomiting': 20},
          relevant: epilepsy);
      expect(ranked.first.value, 'Vomiting',
          reason: 'evidence about THIS person outranks a prior about people '
              'with the condition. Relevance-first would sink twenty records '
              'below entries never touched.');
    });

    test('9. and at COLD START relevance decides the whole list', () async {
      final all = await seeded(kObservationTable);
      final ranked = offerable(kObservationTable, all,
          usage: const <String, int>{},
          relevant: <String>{'Sensitive to smell'});
      expect(ranked.first.value, 'Sensitive to smell',
          reason: 'no usage means every count ties, so relevance is the key '
              'that decides — which is the case it exists for');
    });
  });

  test('10. a user who has adopted nothing sees exactly today\'s order',
      () async {
    final all = await seeded(kObservationTable);
    expect(
        offerable(kObservationTable, all, relevant: const <String>{})
            .map((e) => e.value),
        offerable(kObservationTable, all).map((e) => e.value));
    expect(relevantValues(const <String>{}, kObservationTable), isEmpty);
    expect(relevantValues(<String>{'not-a-key'}, kObservationTable), isEmpty,
        reason: 'a key from a newer build must not break a picker');
  });
}
