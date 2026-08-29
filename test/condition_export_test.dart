import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/models/condition.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/models/medication_note.dart';
import 'package:medical_event_recorder/models/vocabulary.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';

/// Multi-condition pass 2: the condition reaches the CSV.
///
/// ## ⛔ THE DECISION THIS PASS COULD SILENTLY REVERSE
///
/// Pass 1 chose DERIVATION over storage: a record's condition is a function of
/// its event type, so `event.condition_id` stays NULL on all 72 rows and no
/// migration ever invents an attribution. **The easiest way to write this
/// column would have been to store the value on the record** — and that is the
/// thing pass 1 exists to avoid.
///
/// Test 5 is the negative control for exactly that: it exports, then asserts
/// every event row still has a NULL `condition_id`. Every other test here
/// passes against a stored implementation.
///
/// ## ⚠️ AND `EventRecord` DELIBERATELY GAINED NOTHING
///
/// The scoping report listed a `conditionId` field as this pass's cost. It is
/// not needed: `buildCsv` already reads the `Vocabularies` static three times
/// for labels, so the derivation is a fourth read of the same in-memory cache.
/// A field would be null on every record forever — the shape that has bitten
/// twice this month, with `setActive` unreachable for three schema versions and
/// `renameEntry` still unreachable now.

String cell(String csv, String column, {int row = 1}) {
  final lines = csv.trim().split('\n');
  final header = lines.first.replaceFirst('﻿', '').split(',');
  final i = header.indexOf(column);
  if (i < 0) throw StateError('no "$column" column: $header');
  return lines[row].split(',')[i];
}

EventRecord rec(String id, String? type) => EventRecord(
      id: id,
      timestamp: DateTime(2026, 8, 20, 9),
      duration: null,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: false,
      notes: '',
      eventType: type,
    );

void main() {
  sqfliteFfiInit();
  late Directory tmp;
  var seq = 0;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('mer_cond_exp_');
    Vocabularies.debugReset();
  });
  tearDown(() async {
    Vocabularies.debugReset();
    await tmp.delete(recursive: true);
  });

  Future<Database> fresh() => databaseFactoryFfi.openDatabase(
        '${tmp.path}/e${seq++}.db',
        options: OpenDatabaseOptions(
          version: kSqliteSchemaVersion,
          onCreate: (d, _) => createSchema(d),
          onUpgrade: upgradeSchema,
        ),
      );

  VocabularyEntry typeNamed(String v) =>
      Vocabularies.allIn(kEventTypeTable).firstWhere((e) => e.value == v);

  group('THE COLUMN', () {
    test('1. the marker bumped, because the column set changed', () {
      // The rule is mechanical: ANY change to the column set bumps it. The
      // golden header in csv_delimited_test is what enforces it; this states
      // the resulting value so a reader of THIS file knows which shape it
      // describes.
      expect(kCsvShapeVersion, 'v5');
    });

    test('2. an ATTRIBUTED record exports its condition NAME', () async {
      final db = await fresh();
      await Vocabularies.load(db);
      await addCondition(db, 'Epilepsy');
      await Vocabularies.load(db);
      final epilepsy = (await loadConditions(db)).single;
      await Vocabularies.setCondition(
          kEventTypeTable, typeNamed('seizure'), epilepsy.id);

      final csv = buildCsv(<EventRecord>[rec('a', 'seizure')]);
      expect(cell(csv, 'condition'), 'Epilepsy',
          reason: 'a specialist reads names, not ids');
      await db.close();
    });

    test('3. the three UNATTRIBUTED cases all export `unknown`', () async {
      // ⚠️ `unknown`, not blank, and the precedent is split so this is a
      // decision. Duration, event type and severity write `unknown` because a
      // blank SCALAR cannot distinguish "not asked" from "not recorded" from a
      // truncated file. Observations and beforehand write blank because they
      // are DELIMITED and `unknown` would parse as a member of the set.
      // Condition is a scalar that applies to every event, so it takes the
      // scalar rule.
      final db = await fresh();
      await Vocabularies.load(db);
      await addCondition(db, 'Epilepsy');
      await Vocabularies.load(db);
      final epilepsy = (await loadConditions(db)).single;
      await Vocabularies.setCondition(
          kEventTypeTable, typeNamed('seizure'), epilepsy.id);

      // (a) NO TYPE — the quick-record path writes none. This is the device's
      //     72nd record.
      expect(cell(buildCsv(<EventRecord>[rec('a', null)]), 'condition'),
          'unknown',
          reason: 'an untyped record must NOT inherit the primary condition');

      // (b) A TYPE ASSIGNED TO NO CONDITION.
      expect(cell(buildCsv(<EventRecord>[rec('b', 'absence')]), 'condition'),
          'unknown');

      // (c) A TYPE THIS VOCABULARY HAS NEVER SEEN — restored from another
      //     device. Resolves to unknown rather than throwing.
      expect(cell(buildCsv(<EventRecord>[rec('c', 'cluster-headache')]),
              'condition'),
          'unknown');
      await db.close();
    });

    test('4. a MEDICATION row exports unknown, not blank', () async {
      // Not derivable: a note has no event type. That is "not known", which is
      // a different fact from the blanks beside it, which are "not applicable".
      final csv = buildCsv(
        const <EventRecord>[],
        notes: <MedicationNote>[
          MedicationNote(
            id: 'm',
            occurredAt: DateTime(2026, 8, 20, 8),
            loggedAt: DateTime(2026, 8, 20, 20),
            kind: MedicationDeviation.missed,
          ),
        ],
      );
      expect(cell(csv, 'condition'), 'unknown');
      expect(cell(csv, 'event_type'), '',
          reason: 'not applicable stays blank — the two facts differ');
    });
  });

  group('⛔ DERIVED, NOT STORED', () {
    test('5. ⛔ NEGATIVE CONTROL: exporting writes NOTHING to condition_id',
        () async {
      // THE CONTROL THIS PASS NEEDS, and the model is pass 1's test 4. The
      // easiest implementation of this column stores the value on the record.
      // This is what separates the two.
      final db = await fresh();
      await Vocabularies.load(db);
      await addCondition(db, 'Epilepsy');
      await Vocabularies.load(db);
      final epilepsy = (await loadConditions(db)).single;
      await Vocabularies.setCondition(
          kEventTypeTable, typeNamed('seizure'), epilepsy.id);

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

      final records = await SqliteEventStore(db).load();
      final csv = buildCsv(records);

      // The export SAYS Epilepsy...
      expect(cell(csv, 'condition'), 'Epilepsy');

      // ...and the rows STILL carry nothing.
      final rows =
          await db.query('event', columns: <String>['id', 'condition_id']);
      expect(rows.length, 3);
      for (final r in rows) {
        expect(r['condition_id'], isNull,
            reason: 'STORED. The export wrote an attribution onto a record — '
                'the migration pass 1 exists to avoid, arriving by a '
                'different door');
      }
      await db.close();
    });

    test('6. and EventRecord carries no conditionId to store one IN', () {
      // Structural, in the style of `sqlite_single_writer_test`. A round-trip
      // test cannot see a field that is simply always null; this can.
      //
      // The scoping report listed this field as the pass's cost, and it turned
      // out unnecessary. A field that exists and is always null is how
      // `setActive` sat unreachable for three schema versions.
      final src = File('lib/models/event_record.dart').readAsStringSync();
      final classBody = src.substring(
          src.indexOf('class EventRecord'), src.indexOf('\n}', src.indexOf('class EventRecord')));

      expect(classBody.contains('conditionId'), isFalse,
          reason: 'EventRecord GAINED A conditionId FIELD. Nothing populates '
              'the column, so it would be null on every record forever — and '
              'the CSV derives the value without it');

      // POSITIVE CONTROL: the matcher finds fields that ARE there, so the
      // false above means something.
      expect(classBody.contains('referralRequired'), isTrue);
      expect(classBody.contains('rescueMedGiven'), isTrue);
    });

    test('7. the derivation reads the vocabulary, not the database', () {
      // `buildCsv` takes in-memory records and opens nothing. This is what
      // lets the storage engine change without moving a byte of the export —
      // proven when SQLite landed. The condition must not break that.
      Vocabularies.debugSet(eventTypes: <VocabularyEntry>[
        const VocabularyEntry(
          id: 1,
          value: 'seizure',
          label: 'Seizure / fit',
          isSeeded: true,
          isActive: true,
          isProtected: false,
          sortOrder: 0,
          conditionId: 7,
        ),
      ]);

      // No database anywhere in this test, and no condition NAME cached, so
      // the id resolves to nothing and the cell says unknown rather than
      // printing a raw id at a clinician.
      expect(Vocabularies.conditionIdForEventType('seizure'), 7);
      expect(Vocabularies.conditionNameForEventType('seizure'), isNull,
          reason: 'an id with no name is not a name — never print the number');
      expect(cell(buildCsv(<EventRecord>[rec('a', 'seizure')]), 'condition'),
          'unknown');
    });
  });

  group('NOTHING ELSE MOVED', () {
    test('8. observations and beforehand still blank when empty', () async {
      // The delimited columns keep the OPPOSITE rule, and adding a scalar that
      // writes `unknown` beside them must not drag them along.
      final csv = buildCsv(<EventRecord>[rec('a', 'seizure')]);
      expect(cell(csv, 'observations'), '');
      expect(cell(csv, 'beforehand'), '');
    });

    test('9. the event_type column is unchanged by the column beside it', () {
      expect(cell(buildCsv(<EventRecord>[rec('a', 'seizure')]), 'event_type'),
          'Seizure / fit');
      expect(cell(buildCsv(<EventRecord>[rec('a', null)]), 'event_type'),
          'unknown');
    });
  });
}
