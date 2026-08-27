import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/models/condition.dart';
import 'package:medical_event_recorder/models/vocabulary.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';

/// The beforehand field becomes a vocabulary — the last one to do so.
///
/// ## ⛔ TWO SUB-CASES, NOT THREE, AND THAT IS A FACT FROM THE DEVICE
///
/// Observations had seeded / legacy-clean / legacy-MIS-DECODED, and the live
/// case was the third. Checked here before building rather than assumed:
///
///     every stored trigger string     'Poor sleep' x1, ASCII only
///     any byte above U+007F           NONE
///     the seven shipped options       all ASCII
///     stored values not in the list   NONE
///
/// No trigger option has ever carried a glyph, so **there was never anything to
/// mis-decode**, and the strings have never been revised so there is no retired
/// set either. Only seeded and unknown.
///
/// **The entire real-world blast radius is one record holding `Poor sleep`.**

void main() {
  sqfliteFfiInit();
  late Directory tmp;
  var seq = 0;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('mer_trg_');
    Vocabularies.debugReset();
  });
  tearDown(() async {
    Vocabularies.debugReset();
    await tmp.delete(recursive: true);
  });

  /// A v8 database — everything except the trigger tables.
  ///
  /// ⚠️ WRITTEN OUT rather than built at the current version. Five times paid
  /// for now: `createEventSqlV1`, `createEventSqlV4`, medication_note's v7 DDL,
  /// observation_table's missing v6 table, and the one-sided ALTER that threw
  /// on every database below v6.
  Future<String> v8With(List<String> triggersPerEvent) async {
    final path = '${tmp.path}/v8_${seq++}.db';
    final db = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 8,
          onCreate: (d, _) async {
            await d.execute(createSchemaMetaSql);
            await d.execute(createEventSql);
            await createAndSeedVocabularies(d);
            await d.execute('CREATE TABLE medication_note ('
                'id TEXT NOT NULL, occurred_at TEXT NOT NULL, '
                'logged_at TEXT NOT NULL, kind TEXT NOT NULL, notes TEXT, '
                'condition_id INTEGER)');
            await d.execute(createEventObservationSql);
            await d.execute(createConditionSql);
            await d.execute(createConditionObservationSql);
          },
          onUpgrade: upgradeSchema,
        ));
    for (var i = 0; i < triggersPerEvent.length; i++) {
      await db.insert('event', <String, Object?>{
        'ordinal': i,
        'id': 'e$i',
        'logged_at': DateTime(2026, 8, 20 + i).toIso8601String(),
        'event_type': 'seizure',
        'severity': 1,
        'triggers_json': triggersPerEvent[i],
        'referral_required': 0,
      });
    }
    await db.close();
    return path;
  }

  Future<Database> upgrade(String path) => databaseFactoryFfi.openDatabase(path,
      options: OpenDatabaseOptions(
        version: kSqliteSchemaVersion,
        onCreate: (d, _) => createSchema(d),
        onUpgrade: upgradeSchema,
      ));

  Future<List<Map<String, Object?>>> linksFor(Database db, String id) =>
      db.rawQuery(
          'SELECT t.value AS value, l.position AS position '
          'FROM $kEventTriggerTable l '
          'JOIN $kTriggerTable t ON t.id = l.trigger_id '
          'WHERE l.event_id = ? ORDER BY l.position',
          <Object?>[id]);

  group('THE DATA SAYS TWO SUB-CASES, NOT THREE', () {
    test('1. no shipped option carries a glyph, so nothing can mis-decode', () {
      for (final o in kSeedTriggers) {
        expect(o.value.runes.every((r) => r < 0x80), isTrue,
            reason: '${o.value} has a non-ASCII byte — a mis-decode case would '
                'exist and this build does not handle one');
      }
    });

    test('2. and there is no retired set, unlike observations', () {
      // kLegacyObservations exists because the observation strings WERE
      // revised. The trigger strings never have been, so every seeded value is
      // still offered.
      expect(kSeedTriggers.every((s) => s.isActive), isTrue);
    });
  });

  group('THE MIGRATION', () {
    test('3. a SEEDED value links to the seeded row', () async {
      final db = await upgrade(await v8With(<String>[jsonEncode(['Poor sleep'])]));
      expect((await linksFor(db, 'e0')).single['value'], 'Poor sleep');
      final row = (await db.query(kTriggerTable,
              where: 'value = ?', whereArgs: <Object?>['Poor sleep']))
          .single;
      expect(row['is_seeded'], 1);
      expect(row['is_active'], 1);
      await db.close();
    });

    test('4. an UNKNOWN value keeps its exact string and is not offered',
        () async {
      const odd = 'Heatwave';
      final db = await upgrade(await v8With(<String>[jsonEncode([odd])]));
      expect((await linksFor(db, 'e0')).single['value'], odd);
      final row = (await db.query(kTriggerTable,
              where: 'value = ?', whereArgs: <Object?>[odd]))
          .single;
      expect(row['is_seeded'], 0);
      expect(row['is_active'], 0, reason: 'recorded but not offered');
      await db.close();
    });

    test('5. ⛔ NEGATIVE CONTROL: triggers_json is byte-identical afterwards',
        () async {
      // THE CONTROL THIS BUILD NEEDS. The migration is ADDITIVE — it reads the
      // column and writes a separate table. A lost or rewritten value fails
      // here, and nothing else in the suite would notice.
      final payloads = <String>[
        jsonEncode(['Poor sleep']),
        jsonEncode(['Stress', 'Illness']),
        jsonEncode(['Heatwave']),
        jsonEncode(<String>[]),
      ];
      final db = await upgrade(await v8With(payloads));

      final after = await db.query('event',
          columns: <String>['id', 'triggers_json'], orderBy: 'ordinal');
      for (var i = 0; i < payloads.length; i++) {
        expect(after[i]['triggers_json'], payloads[i],
            reason: 'event e$i had its stored triggers rewritten');
      }
      // POSITIVE CONTROL: the migration really ran over these rows, so the
      // equality above is about a migrated record rather than an untouched one.
      expect((await linksFor(db, 'e1')).length, 2);
      await db.close();
    });

    test('6. order within a record is preserved', () async {
      final db = await upgrade(
          await v8With(<String>[jsonEncode(['Illness', 'Stress'])]));
      final links = await linksFor(db, 'e0');
      expect(links.map((l) => l['value']), <String>['Illness', 'Stress'],
          reason: 'stored order, not canonical order — the table records what '
              'the record holds');
      await db.close();
    });

    test('7. re-running rebuilds rather than duplicating', () async {
      final db = await upgrade(await v8With(<String>[jsonEncode(['Stress'])]));
      expect((await linksFor(db, 'e0')).length, 1);
      await migrateTriggersToTable(db);
      expect((await linksFor(db, 'e0')).length, 1);
      await db.close();
    });

    test('8. an unreadable triggers_json is SKIPPED, never invented', () async {
      final path = await v8With(<String>[]);
      final pre = await databaseFactoryFfi.openDatabase(path,
          options: OpenDatabaseOptions(version: 8));
      await pre.insert('event', <String, Object?>{
        'ordinal': 0,
        'id': 'broken',
        'logged_at': DateTime(2026, 8, 20).toIso8601String(),
        'triggers_json': 'not json',
        'referral_required': 0,
      });
      await pre.close();

      final db = await upgrade(path);
      expect(await linksFor(db, 'broken'), isEmpty);
      expect(
          (await db.query('event',
                  columns: <String>['triggers_json'],
                  where: 'id = ?',
                  whereArgs: <Object?>['broken']))
              .single['triggers_json'],
          'not json');
      await db.close();
    });
  });

  group('THE CSV IS UNCHANGED', () {
    test('9. ⛔ kTriggerOptions and kSeedTriggers must not drift apart',
        () async {
      // Two lists holding the same seven strings, and the duplication is
      // deliberate: making the CSV's canonical order depend on the LIVE
      // vocabulary would let a user's additions reorder the historical column.
      //
      // Deliberate duplication still rots. This is what stops it doing so
      // silently.
      expect(kTriggerOptions, kSeedTriggers.map((s) => s.value).toList());
    });

    test('10. the export still writes canonical order, unknowns appended',
        () async {
      final r = EventRecord(
        id: 'x',
        timestamp: DateTime(2026, 8, 20),
        duration: null,
        feelings: const <String>[],
        triggers: const <String>['Heatwave', 'Illness', 'Stress'],
        referralRequired: false,
        notes: '',
      );
      final cell = buildCsv(<EventRecord>[r]).trim().split('\n').last.split(',')[9];
      expect(cell, 'Stress; Illness; Heatwave',
          reason: 'seeded seven in canonical order, unknown appended');
      expect(kCsvShapeVersion, 'v4', reason: 'no column added, no bump');
    });
  });

  group('CREATION', () {
    test('11. adding through the store persists and is offered next time',
        () async {
      final db = await upgrade(await v8With(<String>[]));
      await Vocabularies.load(db);
      final before = Vocabularies.offerableTriggers.length;

      final e = await Vocabularies.add(kTriggerTable, 'Heatwave');
      expect(e, isNotNull);
      expect(Vocabularies.offerableTriggers.length, before + 1);
      expect(Vocabularies.offerableTriggers.map((x) => x.value),
          contains('Heatwave'));
      await db.close();
    });

    test('12. and the label resolves for a record that holds it', () async {
      final db = await upgrade(await v8With(<String>[]));
      await Vocabularies.load(db);
      await Vocabularies.add(kTriggerTable, 'Heatwave');
      expect(Vocabularies.labelFor(kTriggerTable, 'Heatwave'), 'Heatwave');
      // An unknown string still falls back to itself rather than a wrong label.
      expect(Vocabularies.labelFor(kTriggerTable, 'Never seen'), 'Never seen');
      await db.close();
    });
  });
}
