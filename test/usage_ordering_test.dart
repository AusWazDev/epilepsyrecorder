import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/models/vocabulary.dart';

/// Relevance ordering, derived from what this person has actually recorded.
///
/// ## ⛔ WHY THIS AND NOT `condition_observation`
///
/// The relevance ordering these lists were promised was
/// `condition_observation` / `condition_trigger`. **Those tables cannot be
/// populated.** `setConditionFor` throws for observations and triggers by
/// design, no screen assigns them, and conditions are not seeded — so there is
/// no key to hang relevance on. `condition.dart` has said so since v9:
/// *"BUILDABLE IS NOT USEFUL. Relevance mapping is a no-op at one condition."*
///
/// Usage relevance is a different claim and is **not** a no-op at one
/// condition: it asks what this person recorded, which their 72 records already
/// answer.
///
/// ## ⛔ ORDERS, NEVER FILTERS — the rule the mapping was to have followed
///
/// Test 3 is the one that enforces it. Every active entry is returned whatever
/// its count, because a migraine user who has a memory gap must still be able
/// to record it.
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

  test('1. NO USAGE IS SEED ORDER — the cold start must not move', () async {
    final all = await seeded(kObservationTable);
    final plain = offerable(kObservationTable, all);
    final empty = offerable(kObservationTable, all, usage: const <String, int>{});
    expect(plain.map((e) => e.value), empty.map((e) => e.value),
        reason: 'a user with no records must see exactly today\'s order');
    expect(plain.last.value, kOtherObservationValue);
  });

  test('2. used entries lead, most-used first', () async {
    final all = await seeded(kObservationTable);
    final ordered = offerable(kObservationTable, all,
        usage: <String, int>{'Vomiting': 9, 'Confused': 40, 'Yawning': 1});
    final v = ordered.map((e) => e.value).toList();

    expect(v[0], 'Confused');
    expect(v[1], 'Vomiting');
    // 'Yawning' is not an observation at all — it is beforehand-only. An
    // unknown key must be ignored rather than inserted.
    expect(v, isNot(contains('Yawning')));
  });

  test('3. ⛔ NEVER FILTERS — an unused entry is still offered', () async {
    final all = await seeded(kObservationTable);
    final ordered = offerable(kObservationTable, all,
        usage: <String, int>{'Confused': 40});
    expect(ordered.length, offerable(kObservationTable, all).length,
        reason: 'ordering must not change what is OFFERED, only where it sits');
    expect(ordered.map((e) => e.value), contains('Memory gap'),
        reason: 'never recorded, still offerable');
  });

  // ⚠️ THIS TEST DOES NOT PROVE WHAT ITS TITLE FIRST CLAIMED, and the claim is
  // corrected rather than the test deleted. It read "Dart's sort is not
  // stable", and a NEGATIVE CONTROL DISAGREED: removing the index tiebreak from
  // `offerable` leaves all seven tests passing. Dart's `List.sort` uses
  // insertion sort below roughly 32 elements and that IS stable -- these
  // vocabularies hold 21.
  //
  // So the tiebreak is not load-bearing TODAY. It becomes load-bearing when a
  // vocabulary crosses that threshold, which 21 entries and a second sourced
  // condition make a real prospect, and above it Dart switches to an introsort
  // that is not stable. It stays; this test pins the OBSERVABLE property, which
  // is true at every size, rather than a mechanism that is not yet engaged.
  test('4. ties keep SEED ORDER', () async {
    final all = await seeded(kObservationTable);
    final seedOrder =
        offerable(kObservationTable, all).map((e) => e.value).toList();
    // Every count equal, so the tiebreak decides the whole list.
    final flat = <String, int>{for (final e in all) e.value: 3};
    final ordered =
        offerable(kObservationTable, all, usage: flat).map((e) => e.value);
    expect(ordered, seedOrder,
        reason: 'equal counts must leave the list exactly as seeded — the '
            'majority of entries are never used, so this IS the order most '
            'people see');
  });

  test('5. the catch-all stays last even when it is the most used', () async {
    final all = await seeded(kObservationTable);
    final ordered = offerable(kObservationTable, all,
        usage: <String, int>{kOtherObservationValue: 999});
    expect(ordered.last.value, kOtherObservationValue,
        reason: '"Other" is a catch-all wherever it sits in the counts');
  });

  test('6. ⛔ THE HAZARD THE DUPLICATION CREATES: counts are PER TABLE',
      () async {
    // `Tired` is now seeded in BOTH vocabularies — ICHD-3 names fatigue in the
    // prodromal and the postdromal lists. A usage map keyed by value ALONE
    // would add its afterwards count to its beforehand count, so an entry
    // recorded fifty times afterwards would lead the beforehand list having
    // never been used there once.
    final obs = await seeded(kObservationTable);
    final trg = await seeded(kTriggerTable);

    expect(obs.map((e) => e.value), contains('Tired'));
    expect(trg.map((e) => e.value), contains('Tired'),
        reason: 'the duplication is real — this is not a hypothetical hazard');

    // Heavy afterwards use, no beforehand use.
    final afterwards = <String, int>{'Tired': 50};
    expect(offerable(kObservationTable, obs, usage: afterwards).first.value,
        'Tired');

    // The beforehand list is passed ITS OWN map, which is empty, so nothing
    // moves. `Vocabularies.usageFor(table)` is what keeps them separate.
    final before =
        offerable(kTriggerTable, trg, usage: const <String, int>{});
    expect(before.first.value, 'Stress',
        reason: 'beforehand order is untouched by afterwards usage');
  });

  test('7. the same works on the beforehand vocabulary', () async {
    final trg = await seeded(kTriggerTable);
    final ordered = offerable(kTriggerTable, trg,
        usage: <String, int>{'Neck stiffness': 12, 'Stress': 3});
    final v = ordered.map((e) => e.value).toList();
    expect(v[0], 'Neck stiffness');
    expect(v[1], 'Stress');
    expect(v.last, kUnknownTriggerValue);
  });
}
