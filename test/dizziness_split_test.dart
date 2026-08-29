import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/models/vocabulary.dart';

/// The dizziness split, and the two rules that made it possible.
///
/// ## ⛔ ONE ENTRY CANNOT HOLD A DISTINCTION THREE SOURCES DRAW
///
/// `Dizzy or spinning` carried both halves of something the sources separate:
/// vertigo is SPINNING, presyncope is LIGHT-HEADED, and DSM-5's panic criterion
/// lists both under a single symptom. The entry is now narrowed to the
/// vestibular half and `Light-headed or faint` carries the other.
///
/// ## ⛔ WHAT WAS FREE AND WHAT WAS NEVER FREE
///
/// **The LABEL moves; the VALUE never does.** `syncSeededPresentation` writes
/// `label` and `emoji` onto existing rows keyed on the value, so a relabel
/// reaches every database already in the field — and the CSV writes LABELS via
/// `labelFor`, so the export follows too.
///
/// The VALUE could not move at any point, records or none: `seedVocabulary`
/// skips values that already exist, so editing it would INSERT A SECOND ROW and
/// orphan the first. Test 3 is the one that pins that, because it is the
/// mistake a future split would make.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Future<Database> fresh() => databaseFactory.openDatabase(inMemoryDatabasePath,
      options: OpenDatabaseOptions(version: 1, onCreate: (d, _) async {
        await createAndSeedVocabularies(d);
      }));

  test('1. both halves exist, and they are distinct entries', () async {
    final db = await fresh();
    final v = await loadVocabulary(db, kObservationTable);
    final byValue = <String, VocabularyEntry>{for (final e in v) e.value: e};

    expect(byValue['Dizzy or spinning']!.label, 'Spinning');
    expect(byValue['Light-headed or faint']!.label, 'Light-headed or faint');
    expect(byValue['Dizzy or spinning']!.emoji,
        isNot(byValue['Light-headed or faint']!.emoji),
        reason: 'two entries that exist to be told apart must not share a glyph');
    await db.close();
  });

  test('2. ⛔ THE VALUE IS UNCHANGED — records reference it, forever', () async {
    final db = await fresh();
    final values =
        (await loadVocabulary(db, kObservationTable)).map((e) => e.value);
    expect(values, contains('Dizzy or spinning'),
        reason: 'the stored value is permanent; only the label was narrowed');
    expect(values, isNot(contains('Spinning')),
        reason: 'NEGATIVE CONTROL: the new LABEL must not have become a value');
    await db.close();
  });

  test('3. a relabel reaches a database that already exists', () async {
    // The mechanism the split relies on: seed the OLD label, then run the live
    // presentation sync, which is what happens on the next launch after an
    // update.
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1, onCreate: (d, _) async {
      await d.execute(createVocabularySql(kObservationTable));
      await seedVocabulary(d, kObservationTable, const <VocabularySeed>[
        VocabularySeed('Dizzy or spinning', 'Dizzy or spinning', emoji: '💫'),
      ]);
    }));

    final before = await loadVocabulary(db, kObservationTable);
    expect(before.single.label, 'Dizzy or spinning');

    await syncSeededPresentation(db, kObservationTable, kSeedObservations);

    final after = await loadVocabulary(db, kObservationTable);
    expect(after.single.label, 'Spinning',
        reason: 'the label must propagate, or the app and an older device '
            'disagree about what the same record says');
    expect(after.single.value, 'Dizzy or spinning',
        reason: 'and the value must NOT have moved with it');
    await db.close();
  });

  test('4. ⛔ CHANGING A VALUE WOULD ORPHAN, NOT RENAME', () async {
    // Pinning the hazard rather than describing it, because it is the mistake
    // the next split would make. seedVocabulary matches on VALUE and skips what
    // it finds, so a "renamed" value arrives as a second row and the first
    // stays — still referenced by every record that used it.
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1, onCreate: (d, _) async {
      await d.execute(createVocabularySql(kObservationTable));
      await seedVocabulary(d, kObservationTable, const <VocabularySeed>[
        VocabularySeed('Dizzy or spinning', 'Spinning', emoji: '💫'),
      ]);
    }));

    // Someone "renames" the value in the seed list.
    await seedVocabulary(db, kObservationTable, const <VocabularySeed>[
      VocabularySeed('Spinning', 'Spinning', emoji: '💫'),
    ]);

    final v = await loadVocabulary(db, kObservationTable);
    expect(v.length, 2,
        reason: 'TWO ROWS, not one renamed — this is why the value is treated '
            'as permanent whether or not any record references it');
    expect(v.map((e) => e.value), containsAll(<String>['Dizzy or spinning', 'Spinning']));
    await db.close();
  });
}
