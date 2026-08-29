import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/models/vocabulary.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';

/// The glyph is PRESENTATION, and this file exists to keep it that way.
///
/// ## Why it moved
///
/// The original vocabulary stored `😵 Confused` as the VALUE, so the glyph was
/// inside the record, inside every backup file and inside every CSV. Three
/// consequences followed, all observed rather than predicted:
///
///   * History rows rendered it as mojibake on the tablet — that text style has
///     no emoji coverage, and `ð..µ Confused` is what a clinician saw;
///   * three records on the device carry a mis-decoded form whose cause is
///     still unknown, and the corruption was invisible because the glyph was
///     data;
///   * `DATA-MODEL.md` §6 requires emoji stripped from values as well as
///     headers, which a value containing one cannot satisfy.
///
/// The fix is the value/label split extended by one field. A chip renders
/// `display`; a record renders `label`; nothing renders `value`. Every test
/// here attacks the boundary between those three.

void main() {
  late Directory tmp;
  var seq = 0;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('mer_emoji_');
    Vocabularies.debugReset();
  });

  tearDown(() async {
    Vocabularies.debugReset();
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  String nextPath() => '${tmp.path}/mer_${seq++}.db';

  Future<Database> openFresh() => databaseFactoryFfi.openDatabase(
        nextPath(),
        options: OpenDatabaseOptions(
          version: kSqliteSchemaVersion,
          onCreate: (db, _) => createSchema(db),
          onUpgrade: upgradeSchema,
        ),
      );

  group('NO GLYPH IS EVER IN A STORED VALUE', () {
    test('1. every REVISED seed value is plain text', () {
      for (final s in kSeedObservations) {
        for (final r in s.value.runes) {
          expect(r, lessThan(0x2000),
              reason: 'the value "${s.value}" contains a non-ASCII rune — a '
                  'glyph in a value is what caused the mojibake, the '
                  'unauditable corruption, and the §6 violation');
        }
      }
    });

    test('2. and every revised seed still HAS a glyph to show', () {
      // Without this, test 1 passes just as well against a list with no glyphs
      // at all — which is where this started, and it read as unfinished.
      for (final s in kSeedObservations) {
        expect(s.emoji, isNotNull, reason: '"${s.label}" has no glyph');
        expect(s.emoji, isNot(''));
      }
      // 13 until the migraine pass appended eight, 29 Aug 2026. The number
      // is pinned so a seed cannot be added without this control being
      // read -- which is exactly what happened: `Neck stiffness` was first
      // written with no glyph and this test refused it.
      expect(kSeedObservations.length, 21);
    });

    test('3. the LEGACY values keep their glyph — they are stored data', () {
      // The opposite rule, and both are right. A legacy value must not change
      // because records reference it; a new value must not contain a glyph
      // because nothing forces it to.
      for (final s in kLegacyObservations) {
        expect(s.value.runes.any((r) => r > 0x2000), isTrue,
            reason: 'the legacy value "${s.value}" is what records hold');
        expect(s.emoji, isNotNull,
            reason: 'and it renders the same glyph it always did');
        expect(s.label.runes.any((r) => r > 0x2000), isFalse,
            reason: 'while its LABEL is plain, which is what the CSV writes');
      }
    });
  });

  group('THE THREE RENDERINGS', () {
    test('4. display carries the glyph, label does not', () async {
      final db = await openFresh();
      await Vocabularies.load(db);

      expect(Vocabularies.displayFor(kObservationTable, 'Tired'), '😴 Tired');
      expect(Vocabularies.labelFor(kObservationTable, 'Tired'), 'Tired');
      await db.close();
    });

    test('5. a LEGACY value resolves both ways too', () async {
      final db = await openFresh();
      await Vocabularies.load(db);

      const legacy = '\u{1F634} Tired and weary';
      expect(Vocabularies.displayFor(kObservationTable, legacy),
          '\u{1F634} Tired and weary',
          reason: 'the chip looks exactly as it always did');
      expect(Vocabularies.labelFor(kObservationTable, legacy),
          'Tired and weary',
          reason: 'the row and the CSV get the plain words');
      await db.close();
    });

    test('6. THE CSV CARRIES NO GLYPH, for revised or legacy values', () async {
      final db = await openFresh();
      await Vocabularies.load(db);

      final csv = buildCsv(<EventRecord>[
        EventRecord(
          id: 'a',
          timestamp: DateTime(2026, 8, 26, 10),
          duration: null,
          feelings: const <String>['Tired', '\u{1F635} Confused'],
          referralRequired: false,
          notes: '',
        ),
      ]);

      expect(csv, contains('Tired; Confused'));
      // Every rune checked, not sampled. The BOM is the one deliberate
      // exception — it is what tells Excel to read the file as UTF-8.
      final offenders =
          csv.runes.where((r) => r > 0x2500 && r != 0xFEFF).toList();
      expect(offenders, isEmpty,
          reason: 'a glyph reached the export: '
              '${offenders.map((r) => r.toRadixString(16)).toList()}');
      await db.close();
    });
  });

  group('THE BACKFILL', () {
    test('7. a v3 database with no glyphs GAINS them on the next open',
        () async {
      // The trap this project has now hit twice: a seed list that grows does
      // not reach a database that already has the rows. `seedVocabulary` skips
      // by value, so a NEW FIELD on an existing seed needs its own pass.
      final db = await openFresh();
      await db.update(kObservationTable, <String, Object?>{'emoji': null});

      // PRECONDITION, asserted rather than assumed.
      expect(
          (await loadVocabulary(db, kObservationTable))
              .every((e) => e.emoji == null),
          isTrue);

      await ensureSeeded(db);

      final after = await loadVocabulary(db, kObservationTable);
      expect(after.firstWhere((e) => e.value == 'Tired').emoji, '😴');
      await db.close();
    });

    test('8. NEGATIVE CONTROL: the INSERT pass alone would NOT have', () async {
      // Shows the difference is real and not an artefact: run only the insert
      // half, and the glyphs stay missing. This is exactly what happened to the
      // mis-decoded twins one build ago.
      final db = await openFresh();
      await db.update(kObservationTable, <String, Object?>{'emoji': null});

      await seedVocabulary(db, kObservationTable, kSeedObservations);

      expect(
          (await loadVocabulary(db, kObservationTable))
              .firstWhere((e) => e.value == 'Tired')
              .emoji,
          isNull,
          reason: 'skipped by value, so the new field never lands');
      await db.close();
    });

    test('9. the backfill does NOT touch a user entry', () async {
      final db = await openFresh();
      await addUserEntry(db, kObservationTable, 'Dizzy');

      await ensureSeeded(db);

      final dizzy = (await loadVocabulary(db, kObservationTable))
          .firstWhere((e) => e.value == 'Dizzy');
      expect(dizzy.emoji, isNull,
          reason: 'MER does not decorate what a user typed');
      expect(dizzy.label, 'Dizzy', reason: 'and does not relabel it');
      await db.close();
    });
  });
}
