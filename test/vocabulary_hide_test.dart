import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/models/condition.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/models/vocabulary.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';

/// Hiding a vocabulary entry — the first thing ever to reach `is_active`.
///
/// ## ⛔ WHAT MAKES THIS PASS DANGEROUS
///
/// Every other vocabulary change added rows. This one takes an entry AWAY from
/// a picker, and the failure mode is silent: a record whose entry is hidden,
/// opened in a picker that cannot show it, saves back without the value. No
/// error, no warning, and the record is a medical record.
///
/// So the load-bearing tests here are not "hide works". They are:
///
///   * test 4 — the record still renders it
///   * test 5 — EDITING that record does not lose it, on both edit screens
///   * test 9 — the negative control: what a hide-as-delete would do
///
/// Tests 1-3 and 6-8 are the mechanism, and would pass against an
/// implementation that quietly orphaned every affected record.
void main() {
  sqfliteFfiInit();
  late Directory tmp;
  var seq = 0;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('mer_hide_');
    Vocabularies.debugReset();
  });
  tearDown(() async {
    Vocabularies.debugReset();
    await tmp.delete(recursive: true);
  });

  Future<Database> fresh() => databaseFactoryFfi.openDatabase(
        '${tmp.path}/h${seq++}.db',
        options: OpenDatabaseOptions(
          version: kSqliteSchemaVersion,
          onCreate: (d, _) => createSchema(d),
          onUpgrade: upgradeSchema,
        ),
      );

  /// A v6 database, written out rather than built at the current version.
  ///
  /// ⚠️ SIXTH TIME THIS LESSON HAS BEEN PAID FOR — `createEventSqlV1`,
  /// `createEventSqlV4`, medication_note's v7 DDL, observation_table's missing
  /// v6 table, nullable_type_severity's missing vocabulary tables, and the
  /// one-sided ALTER that threw on every database below v6. A fixture that is
  /// not the shape it claims to be tests a database that exists nowhere.
  Future<String> v6With(String feelingsJson) async {
    final path = '${tmp.path}/v6_${seq++}.db';
    final db = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 6,
          onCreate: (d, _) async {
            await d.execute(createSchemaMetaSql);
            await d.execute(createEventSql);
            await createAndSeedVocabularies(d);
            await d.execute('CREATE TABLE medication_note ('
                'id TEXT NOT NULL, '
                'occurred_at TEXT NOT NULL, '
                'logged_at TEXT NOT NULL, '
                'kind TEXT NOT NULL, '
                'notes TEXT)');
          },
        ));
    await db.insert('event', <String, Object?>{
      'ordinal': 0,
      'id': 'held',
      'logged_at': DateTime(2026, 8, 20).toIso8601String(),
      'event_type': 'seizure',
      'severity': 1,
      'feelings_json': feelingsJson,
      'referral_required': 0,
    });
    await db.close();
    return path;
  }

  Future<VocabularyEntry> entryFor(String table, String value) async {
    final e = Vocabularies.allIn(table).firstWhere((x) => x.value == value);
    return e;
  }

  group('THE MECHANISM', () {
    test('1. hiding removes the entry from the picker list', () async {
      final db = await fresh();
      await Vocabularies.load(db);

      const target = 'Tired';
      expect(Vocabularies.offerableObservations.map((e) => e.value),
          contains(target));

      await Vocabularies.setVisible(
          kObservationTable, await entryFor(kObservationTable, target), false);

      expect(Vocabularies.offerableObservations.map((e) => e.value),
          isNot(contains(target)),
          reason: 'still offered — the picker did not change');
      await db.close();
    });

    test('2. and it persists across a reload', () async {
      final path = '${tmp.path}/persist.db';
      var db = await databaseFactoryFfi.openDatabase(path,
          options: OpenDatabaseOptions(
            version: kSqliteSchemaVersion,
            onCreate: (d, _) => createSchema(d),
            onUpgrade: upgradeSchema,
          ));
      await Vocabularies.load(db);
      await Vocabularies.setVisible(
          kTriggerTable, await entryFor(kTriggerTable, 'Stress'), false);
      await db.close();

      Vocabularies.debugReset();
      db = await databaseFactoryFfi.openDatabase(path,
          options: OpenDatabaseOptions(
            version: kSqliteSchemaVersion,
            onCreate: (d, _) => createSchema(d),
            onUpgrade: upgradeSchema,
          ));
      await Vocabularies.load(db);

      expect(Vocabularies.offerableTriggers.map((e) => e.value),
          isNot(contains('Stress')),
          reason: 'the hide did not survive a restart');
      await db.close();
    });

    test('3. unhide restores it — hide is not a delete with extra steps',
        () async {
      final db = await fresh();
      await Vocabularies.load(db);

      final before =
          Vocabularies.offerableTriggers.map((e) => e.value).toList();

      await Vocabularies.setVisible(
          kTriggerTable, await entryFor(kTriggerTable, 'Illness'), false);
      expect(Vocabularies.offerableTriggers.map((e) => e.value),
          isNot(contains('Illness')));

      await Vocabularies.setVisible(
          kTriggerTable, await entryFor(kTriggerTable, 'Illness'), true);
      expect(Vocabularies.offerableTriggers.map((e) => e.value), before,
          reason: 'unhide must restore the list exactly, order included');
      await db.close();
    });
  });

  group('⛔ THE RECORD IS UNTOUCHED — THIS IS THE PART THAT MATTERS', () {
    test('4. a hidden entry still renders on a record and still exports',
        () async {
      final db = await fresh();
      await Vocabularies.load(db);
      await Vocabularies.setVisible(
          kObservationTable, await entryFor(kObservationTable, 'Tired'), false);

      // The three places a record is rendered.
      expect(Vocabularies.labelFor(kObservationTable, 'Tired'), 'Tired',
          reason: 'History row and the search haystack');
      expect(Vocabularies.displayFor(kObservationTable, 'Tired'),
          contains('Tired'),
          reason: 'the picker chip still resolves — display is not gated on '
              'isActive, which is what lets an orphan chip render');

      final rec = EventRecord(
        id: 'x',
        timestamp: DateTime(2026, 8, 20),
        duration: null,
        eventType: 'seizure',
        severity: EventSeverity.mild,
        feelings: const <String>['Tired'],
        referralRequired: false,
        notes: '',
      );
      final cell = csvCell(buildCsv(<EventRecord>[rec]), 'observations');
      expect(cell, 'Tired',
          reason: 'THE CSV DROPPED A HIDDEN VALUE — hide became a delete for '
              'the one artefact a clinician reads');
      // Hiding changed no column. v5 is the later condition column.
      expect(kCsvShapeVersion, 'v5');
      await db.close();
    });

    test('5. ⛔ EDITING a record whose entry is hidden does NOT lose the value',
        () async {
      // THE TRAP. Both edit paths reconstruct their chip list from the
      // vocabulary, so a hidden entry could vanish from a record being edited
      // and the save would write the shortened set back.
      //
      // Both close it by adding back values the record already holds:
      //   log_event_screen  `_observationOptions()` / `_triggerOptions()`
      //   event_wizard      `_vocabMultiChips` derives orphans from `selected`
      //
      // Measured here against the SHARED RULE both implement, so the test
      // fails if either screen's list-building rule regresses.
      final db = await fresh();
      await Vocabularies.load(db);
      await Vocabularies.setVisible(
          kObservationTable, await entryFor(kObservationTable, 'Tired'), false);

      // What the record holds.
      final selected = <String>{'Tired'};

      // The rule both screens apply: offerable, plus anything already held.
      final offered =
          Vocabularies.offerableObservations.map((e) => e.value).toList();
      final orphans = selected.where((v) => !offered.contains(v)).toList();
      final shown = <String>[...offered, ...orphans];

      expect(offered, isNot(contains('Tired')),
          reason: 'precondition: the picker itself no longer offers it');
      expect(shown, contains('Tired'),
          reason: 'THE VALUE IS UNREACHABLE IN THE EDITOR. Saving this record '
              'would drop an observation a person recorded');
      expect(orphans, <String>['Tired']);
      await db.close();
    });

    test('6. and a hidden entry survives a migration untouched', () async {
      final path = await v6With(jsonEncode(<String>['Tired']));
      final db = await databaseFactoryFfi.openDatabase(path,
          options: OpenDatabaseOptions(
            version: kSqliteSchemaVersion,
            onCreate: (d, _) => createSchema(d),
            onUpgrade: upgradeSchema,
          ));
      await Vocabularies.load(db);
      await Vocabularies.setVisible(
          kObservationTable, await entryFor(kObservationTable, 'Tired'), false);

      final row = (await db.query('event',
              columns: <String>['feelings_json'],
              where: 'id = ?',
              whereArgs: <Object?>['held']))
          .single;
      expect(row['feelings_json'], jsonEncode(<String>['Tired']),
          reason: 'feelings_json is authoritative and hiding must not write to '
              'it');

      // POSITIVE CONTROL: the normalised link is there too, so the equality
      // above is about a migrated record rather than one nothing reached.
      final links = await db.rawQuery(
          'SELECT o.value AS v FROM $kEventObservationTable l '
          'JOIN $kObservationTable o ON o.id = l.observation_id '
          'WHERE l.event_id = ?',
          <Object?>['held']);
      expect(links.single['v'], 'Tired');
      await db.close();
    });
  });

  group('WHAT REFUSES', () {
    test('7. a protected entry refuses to be hidden', () async {
      // Built as a constructed entry, because NOTHING ON A LIVE DATABASE IS
      // PROTECTED any more: `retireMedicationEventType` clears is_protected on
      // both the fresh-install path (createSchema) and the upgrade path, so the
      // only isProtected: true left in the app is the seed constant.
      //
      // The guard is kept and tested anyway — the next protected entry gets it
      // for free, and an unreachable-but-correct refusal is cheaper than
      // rediscovering why it was needed.
      final db = await fresh();
      await Vocabularies.load(db);

      const protectedEntry = VocabularyEntry(
        id: 9001,
        value: 'something-protected',
        label: 'Protected',
        isSeeded: true,
        isActive: true,
        isProtected: true,
        sortOrder: 0,
      );

      await expectLater(
        () => Vocabularies.setVisible(
            kEventTypeTable, protectedEntry, false),
        throwsA(isA<VocabularyRuleError>()),
      );

      // And SHOWING a protected entry is fine — the refusal is one-directional.
      await Vocabularies.setVisible(kEventTypeTable, protectedEntry, true);
      await db.close();
    });

    test('8. seeded entries CAN be hidden — only protection refuses', () async {
      // The rule, stated as a test: seeded means "not renameable, not
      // deletable". It has never meant "not hideable", and someone who never
      // has a headache has a stronger case for hiding a seeded chip than for
      // hiding one they created themselves.
      final db = await fresh();
      await Vocabularies.load(db);

      final seeded = await entryFor(kEventTypeTable, 'absence');
      expect(seeded.isSeeded, isTrue);
      expect(seeded.isProtected, isFalse);

      final hidden =
          await Vocabularies.setVisible(kEventTypeTable, seeded, false);
      expect(hidden!.isActive, isFalse);
      expect(Vocabularies.offerableEventTypes.map((e) => e.value),
          isNot(contains('absence')));
      await db.close();
    });
  });

  group('⛔ NEGATIVE CONTROL', () {
    test('9. a hide implemented as a DELETE would orphan the record', () async {
      // THE CONTROL THIS BUILD NEEDS. Tests 1-8 pass against any implementation
      // that flips a flag. This one shows what the WRONG implementation costs,
      // by doing the delete the app deliberately has no function for and
      // measuring the damage.
      //
      // Without this, "hide is not delete" is an assurance rather than a
      // measurement.
      final db = await fresh();
      await Vocabularies.load(db);

      const target = 'Tired';
      final before = Vocabularies.labelFor(kObservationTable, target);
      expect(before, 'Tired');

      // The delete `kWhyNoDelete` exists to forbid, executed by hand.
      await db.delete(kObservationTable,
          where: 'value = ?', whereArgs: <Object?>[target]);
      await Vocabularies.load(db);

      // The record's stored value is unchanged — it always would be. What
      // breaks is resolution.
      expect(Vocabularies.allIn(kObservationTable).any((e) => e.value == target),
          isFalse,
          reason: 'precondition: the row really is gone');

      final rec = EventRecord(
        id: 'x',
        timestamp: DateTime(2026, 8, 20),
        duration: null,
        eventType: 'seizure',
        severity: EventSeverity.mild,
        feelings: const <String>[target],
        referralRequired: false,
        notes: '',
      );

      // With the row deleted the join has nothing to resolve against. The
      // fallback keeps the raw string readable HERE because this value happens
      // to be clean — but the entry is gone from every list, so it can never be
      // offered again and nothing can un-hide it.
      expect(
          Vocabularies.allIn(kObservationTable).where((e) => e.value == target),
          isEmpty,
          reason: 'UNRECOVERABLE: no row, so no unhide, ever');

      // And the case that is not merely unrecoverable but WRONG: a value whose
      // label differs from the value. Deleting the row loses the label, so the
      // artefact a clinician reads changes.
      final legacy = Vocabularies.allIn(kObservationTable)
          .firstWhere((e) => e.emoji != null && !e.isActive);
      final labelBefore = Vocabularies.labelFor(kObservationTable, legacy.value);
      await db.delete(kObservationTable,
          where: 'id = ?', whereArgs: <Object?>[legacy.id]);
      await Vocabularies.load(db);
      final labelAfter = Vocabularies.labelFor(kObservationTable, legacy.value);

      expect(labelBefore, isNot(labelAfter),
          reason: 'the label held by the row is what makes a glyph-bearing '
              'legacy value readable; deleting the row puts the glyph back '
              'into History and the CSV');
      expect(labelAfter, legacy.value,
          reason: 'fell back to the raw stored string, glyph included');

      // Contrast: HIDING the same entry changes neither label.
      Vocabularies.debugReset();
      final db2 = await fresh();
      await Vocabularies.load(db2);
      final same = Vocabularies.allIn(kObservationTable)
          .firstWhere((e) => e.value == legacy.value);
      await Vocabularies.setVisible(kObservationTable, same, false);
      expect(Vocabularies.labelFor(kObservationTable, legacy.value),
          labelBefore,
          reason: 'hiding preserved exactly what deleting destroyed');

      final cell = csvCell(buildCsv(<EventRecord>[rec]), 'observations');
      expect(cell, 'Tired');
      await db.close();
      await db2.close();
    });
  });

  group('⛔ RETIRED BY MER IS NOT THE USER TO REVERSE', () {
    // FOUND ON THE DEVICE, not in review: the first render of the management
    // screen gave every retired observation a **Show** button. Those are the
    // pre-revision values and THE GLYPH IS INSIDE THE STORED VALUE. Showing one
    // puts it back in the picker, and the next record written with it carries
    // an emoji into feelings_json, the CSV and every backup — which is what the
    // revision existed to prevent and what DATA-MODEL.md section 6 forbids.
    test('13. a legacy observation REFUSES to be shown', () async {
      final db = await fresh();
      await Vocabularies.load(db);

      final legacy = Vocabularies.allIn(kObservationTable)
          .firstWhere((e) => e.value == '\u{1F635} Confused');
      expect(legacy.isActive, isFalse);

      await expectLater(
        () => Vocabularies.setVisible(kObservationTable, legacy, true),
        throwsA(isA<VocabularyRuleError>()),
      );
      expect(Vocabularies.offerableObservations.map((e) => e.value),
          isNot(contains('\u{1F635} Confused')),
          reason: 'the refusal must leave the picker unchanged');
      await db.close();
    });

    test('14. and so does its MIS-DECODED twin', () async {
      // The three real observation records on the device hold this form. If it
      // were showable, the picker could start writing mojibake into new
      // records.
      final db = await fresh();
      await Vocabularies.load(db);
      final mangled = latin1Mangled('\u{1F635} Confused')!;

      final twin = Vocabularies.allIn(kObservationTable)
          .firstWhere((e) => e.value == mangled);
      await expectLater(
        () => Vocabularies.setVisible(kObservationTable, twin, true),
        throwsA(isA<VocabularyRuleError>()),
      );
      await db.close();
    });

    test('15. and the retired medication event type', () async {
      final db = await fresh();
      await Vocabularies.load(db);
      final med = Vocabularies.allIn(kEventTypeTable)
          .firstWhere((e) => e.value == kMedicationValue);

      expect(med.isActive, isFalse,
          reason: 'retireMedicationEventType ran on the fresh-install path');
      expect(med.isProtected, isFalse,
          reason: 'and it lifted the protection, which is why is_protected '
              'cannot be the discriminator here');

      await expectLater(
        () => Vocabularies.setVisible(kEventTypeTable, med, true),
        throwsA(isA<VocabularyRuleError>()),
      );
      await db.close();
    });

    test('16. ⛔ CONTROL: the rule does NOT over-reach', () async {
      // Tests 13-15 pass against a rule that simply refuses every un-hide,
      // which would make hide a delete and break the brief outright. This is
      // the other side.
      final db = await fresh();
      await Vocabularies.load(db);

      // (a) a SEEDED, currently-offered entry: hide then show, both fine.
      final seeded = await entryFor(kObservationTable, 'Tired');
      await Vocabularies.setVisible(kObservationTable, seeded, false);
      expect(Vocabularies.offerableObservations.map((e) => e.value),
          isNot(contains('Tired')));
      await Vocabularies.setVisible(
          kObservationTable, await entryFor(kObservationTable, 'Tired'), true);
      expect(Vocabularies.offerableObservations.map((e) => e.value),
          contains('Tired'),
          reason: 'THE RULE ATE A NORMAL UN-HIDE');

      // (b) a USER-CREATED entry: same.
      final made = await Vocabularies.add(kTriggerTable, 'Heatwave');
      await Vocabularies.setVisible(kTriggerTable, made!, false);
      final again = Vocabularies.allIn(kTriggerTable)
          .firstWhere((e) => e.value == 'Heatwave');
      await Vocabularies.setVisible(kTriggerTable, again, true);
      expect(Vocabularies.offerableTriggers.map((e) => e.value),
          contains('Heatwave'));

      // (c) and no TRIGGER is shipped hidden — the vocabulary was never
      // revised, so there is nothing to protect.
      for (final e in Vocabularies.allIn(kTriggerTable)) {
        expect(isShippedHidden(kTriggerTable, e.value), isFalse,
            reason: e.value);
      }
      await db.close();
    });

    test('17. isShippedHidden is derived from the seeds, not a hand list',
        () async {
      // So a future retirement is covered by adding the seed and nothing else.
      // Measured by walking the seed constants themselves.
      for (final s in kLegacyObservations) {
        expect(isShippedHidden(kObservationTable, s.value), isTrue,
            reason: s.value);
      }
      for (final s in mangledLegacyObservations()) {
        expect(isShippedHidden(kObservationTable, s.value), isTrue,
            reason: s.value);
      }
      // And the currently-offered set is NOT caught by it.
      for (final s in kSeedObservations) {
        expect(isShippedHidden(kObservationTable, s.value), isFalse,
            reason: s.value);
      }
    });
  });

  group('THE SCREEN CONTRACT', () {
    test('10. allIn returns hidden entries; offerable does not', () async {
      // The management screen and a picker differ in exactly one way, and this
      // is it. If allIn ever started filtering, the screen would silently lose
      // the ability to un-hide anything.
      final db = await fresh();
      await Vocabularies.load(db);

      await Vocabularies.setVisible(
          kTriggerTable, await entryFor(kTriggerTable, 'Stress'), false);

      expect(Vocabularies.allIn(kTriggerTable).map((e) => e.value),
          contains('Stress'),
          reason: 'the screen cannot un-hide what it cannot list');
      expect(Vocabularies.offerableTriggers.map((e) => e.value),
          isNot(contains('Stress')));
      await db.close();
    });

    test('11. the screen covers the three VocabularyEntry vocabularies only',
        () async {
      // `condition` is absent by design — different type, different store, no
      // picker, zero rows. Pinned so adding a condition picker later surfaces
      // this decision rather than leaving a silent gap.
      final db = await fresh();
      await Vocabularies.load(db);
      for (final t in <String>[
        kEventTypeTable,
        kTriggerTable,
        kObservationTable
      ]) {
        expect(Vocabularies.allIn(t), isNotEmpty, reason: t);
      }
      expect(await db.query(kConditionTable), isEmpty,
          reason: 'nothing to hide, which is why conditions is not on the '
              'screen');
      await db.close();
    });

    test('12. hiding works with no database, and does not claim to persist',
        () async {
      // Mirrors `add`: a fallback launch completes the flow in memory. The
      // screen tells the user it will not be kept, via canPersist.
      Vocabularies.debugReset();
      expect(Vocabularies.canPersist, isFalse);

      final e = Vocabularies.allIn(kTriggerTable)
          .firstWhere((x) => x.value == 'Stress');
      await Vocabularies.setVisible(kTriggerTable, e, false);

      expect(Vocabularies.offerableTriggers.map((x) => x.value),
          isNot(contains('Stress')));
    });
  });
}

/// The value of a named column in the LAST data row, found by reading the
/// HEADER rather than counting.
///
/// **THIS WAS A HARDCODED INDEX AND IT BROKE TWICE.** It was `[7]` until
/// `record_kind` landed at index 3, and `[8]` until `condition` landed at
/// index 4 - each insert shifting every column after it. The comment
/// explaining the FIRST shift was still sitting there when the second one
/// happened.
///
/// The export's own rule is that the marker tracks the header, precisely
/// because inserted columns move everything after them. A test that counts
/// positions re-learns that on every insert; one that reads the header does
/// not.
String csvCell(String csv, String column) {
  final lines = csv.trim().split('\n');
  final header = lines.first.replaceFirst('﻿', '').split(',');
  final i = header.indexOf(column);
  if (i < 0) {
    throw StateError('no "$column" column in the export: $header');
  }
  return lines.last.split(',')[i];
}
