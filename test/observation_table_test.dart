import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/models/vocabulary.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';

/// Observations become a table — and nothing a user recorded is rewritten.
///
/// ## ⛔ THE BLAST RADIUS, MEASURED BEFORE THE BUILD
///
/// The tablet holds 72 records. Exactly **three** carry an observation, and all
/// three carry the same value: `ðµ Confused` — the UTF-8 bytes of `😵` read
/// back as Latin-1. That is not a hypothetical; it is **all of the observation
/// data on the device**.
///
/// So the migration's real job is the third sub-case, not the first two:
///
///   seeded              one of the revised twelve
///   legacy, clean       `😵 Confused`, retired but present
///   legacy, MIS-DECODED `ðµ Confused`  ← the live one
///
/// A migration handling only the first two would orphan every observation the
/// user has, and the failure would look like the mojibake that was already
/// found and fixed once.

/// The mis-decoded twin, derived the way the app derives it rather than pasted.
final String kMangledConfused = latin1Mangled('\u{1F635} Confused')!;

void main() {
  sqfliteFfiInit();
  late Directory tmp;
  var seq = 0;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('mer_obs_');
    Vocabularies.debugReset();
  });
  tearDown(() async {
    Vocabularies.debugReset();
    await tmp.delete(recursive: true);
  });

  /// A v6 database — everything except `event_observation`.
  Future<String> v6With(List<String> feelingsPerEvent) async {
    final path = '${tmp.path}/v6_${seq++}.db';
    final db = await databaseFactoryFfi.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 6,
          onCreate: (d, _) async {
            await d.execute(createSchemaMetaSql);
            await d.execute(createEventSql);
            await createAndSeedVocabularies(d);
          },
        ));
    for (var i = 0; i < feelingsPerEvent.length; i++) {
      await db.insert('event', <String, Object?>{
        'ordinal': i,
        'id': 'e$i',
        'logged_at': DateTime(2026, 8, 20 + i).toIso8601String(),
        'event_type': 'seizure',
        'severity': 1,
        'feelings_json': feelingsPerEvent[i],
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

  Future<List<Map<String, Object?>>> linksFor(Database db, String eventId) =>
      db.rawQuery(
          'SELECT o.value AS value, l.position AS position '
          'FROM $kEventObservationTable l '
          'JOIN $kObservationTable o ON o.id = l.observation_id '
          'WHERE l.event_id = ? ORDER BY l.position',
          <Object?>[eventId]);

  group('THE THREE SUB-CASES', () {
    test('1. a SEEDED value links to the seeded row', () async {
      final db = await upgrade(await v6With(<String>[jsonEncode(['Tired'])]));
      final links = await linksFor(db, 'e0');

      expect(links.single['value'], 'Tired');
      final row = (await db.query(kObservationTable,
              where: 'value = ?', whereArgs: <Object?>['Tired']))
          .single;
      expect(row['is_seeded'], 1);
      expect(row['is_active'], 1, reason: 'still offered');
      await db.close();
    });

    test('2. a LEGACY CLEAN value links to its retired row', () async {
      final db = await upgrade(
          await v6With(<String>[jsonEncode(['\u{1F635} Confused'])]));
      final links = await linksFor(db, 'e0');

      expect(links.single['value'], '\u{1F635} Confused');
      final row = (await db.query(kObservationTable,
              where: 'value = ?', whereArgs: <Object?>['\u{1F635} Confused']))
          .single;
      expect(row['is_active'], 0, reason: 'retired, not deleted');
      expect(row['label'], 'Confused', reason: 'the label strips the glyph');
      await db.close();
    });

    test('3. ⛔ THE LIVE CASE: a MIS-DECODED value links, and is not repaired',
        () async {
      // All three of the device's observation records. If this fails, the
      // migration orphans every observation the user has.
      final db = await upgrade(
          await v6With(<String>[jsonEncode([kMangledConfused])]));
      final links = await linksFor(db, 'e0');

      expect(links.single['value'], kMangledConfused,
          reason: 'VERBATIM. Not repaired into the clean form, not normalised');
      expect(links.single['value'], isNot('\u{1F635} Confused'));

      final row = (await db.query(kObservationTable,
              where: 'value = ?', whereArgs: <Object?>[kMangledConfused]))
          .single;
      expect(row['label'], 'Confused',
          reason: 'it resolves to a readable label, which is why records '
              'carrying it render correctly');
      expect(row['is_seeded'], 1,
          reason: 'it is a shipped row via mangledLegacyObservations, NOT a '
              'user-defined one the migration invented');
      await db.close();
    });

    test('4. NEGATIVE CONTROL: handling only cases 1 and 2 would create a NEW '
        'row for the live one', () async {
      // ⛔ THE CONTROL THIS BUILD NEEDS. Test 3 passes against any migration
      // that links SOMETHING. This shows what the wrong one looks like: if the
      // mis-decoded twin were not already a row, the migration would create one
      // — is_seeded 0, sort_order 9000 — and every device observation would
      // become a user-defined retired entry.
      //
      // Measured by asking for a value that genuinely is not a row.
      final db = await upgrade(await v6With(<String>[]));

      final before = ((await db.rawQuery('SELECT COUNT(*) FROM $kObservationTable')).first.values.first! as int);
      final created = await observationRowFor(db, 'Not in any vocabulary');
      final after = ((await db.rawQuery('SELECT COUNT(*) FROM $kObservationTable')).first.values.first! as int);

      expect(after, before + 1, reason: 'an unknown value DOES create a row');
      final row = (await db.query(kObservationTable,
              where: 'id = ?', whereArgs: <Object?>[created]))
          .single;
      expect(row['is_seeded'], 0);
      expect(row['is_active'], 0, reason: 'recorded but not offered');

      // And the mis-decoded twin does NOT take that path — same call, no new
      // row. That is the difference the control exists to show.
      final b2 = ((await db.rawQuery('SELECT COUNT(*) FROM $kObservationTable')).first.values.first! as int);
      await observationRowFor(db, kMangledConfused);
      final a2 = ((await db.rawQuery('SELECT COUNT(*) FROM $kObservationTable')).first.values.first! as int);
      expect(a2, b2, reason: 'already a row — resolved, not invented');
      await db.close();
    });

    test('5. an UNKNOWN value keeps its exact string as the row value',
        () async {
      const odd = 'Something only they use';
      final db = await upgrade(await v6With(<String>[jsonEncode([odd])]));
      expect((await linksFor(db, 'e0')).single['value'], odd);
      await db.close();
    });
  });

  group('⛔ NOTHING IS REWRITTEN, AND THAT IS THE RULE', () {
    test('6. NEGATIVE CONTROL: feelings_json is byte-identical afterwards',
        () async {
      // The rule this project has held throughout. The migration is ADDITIVE:
      // it reads the column and writes a separate table. If it ever wrote back
      // — repairing the mis-decode, say, which would look like a kindness —
      // this fails.
      final payloads = <String>[
        jsonEncode([kMangledConfused]),
        jsonEncode(['Tired', 'Memory gap']),
        jsonEncode(['\u{1F635} Confused', 'Sad']),
      ];
      final path = await v6With(payloads);
      final db = await upgrade(path);

      final after = await db.query('event', columns: <String>['id', 'feelings_json'],
          orderBy: 'ordinal');
      for (var i = 0; i < payloads.length; i++) {
        expect(after[i]['feelings_json'], payloads[i],
            reason: 'event e$i had its stored observations rewritten');
      }
      // POSITIVE CONTROL: the migration really ran over these rows, so the
      // equality above is about a migrated record rather than an untouched one.
      expect((await linksFor(db, 'e1')).length, 2);
      await db.close();
    });

    test('7. order within a record is preserved', () async {
      final db = await upgrade(
          await v6With(<String>[jsonEncode(['Confused', 'Tired'])]));
      final links = await linksFor(db, 'e0');
      expect(links.map((l) => l['value']), <String>['Confused', 'Tired']);
      expect(links.map((l) => l['position']), <int>[0, 1]);
      await db.close();
    });

    test('8. re-running rebuilds rather than duplicating', () async {
      final db = await upgrade(
          await v6With(<String>[jsonEncode([kMangledConfused])]));
      expect((await linksFor(db, 'e0')).length, 1);

      await migrateObservationsToTable(db);
      expect((await linksFor(db, 'e0')).length, 1,
          reason: 'idempotent — safe to re-run');
      await db.close();
    });

    test('9. an unreadable feelings_json is SKIPPED, never invented', () async {
      final path = await v6With(<String>[]);
      final pre = await databaseFactoryFfi.openDatabase(path,
          options: OpenDatabaseOptions(version: 6));
      await pre.insert('event', <String, Object?>{
        'ordinal': 0,
        'id': 'broken',
        'logged_at': DateTime(2026, 8, 20).toIso8601String(),
        'feelings_json': 'not json at all',
        'referral_required': 0,
      });
      await pre.close();

      final db = await upgrade(path);
      expect(await linksFor(db, 'broken'), isEmpty);
      expect(
          (await db.query('event',
                  columns: <String>['feelings_json'],
                  where: 'id = ?',
                  whereArgs: <Object?>['broken']))
              .single['feelings_json'],
          'not json at all',
          reason: 'the source of truth is unharmed; the gap is a count '
              'mismatch, not invented data');
      await db.close();
    });
  });

  group('EVERYTHING ELSE IS UNAFFECTED', () {
    test('10. the CSV is unchanged — it reads the record, not the table',
        () async {
      // The export is delimited already and reads `EventRecord.feelings`, which
      // still comes from `feelings_json`. The table is not on that path.
      final db = await upgrade(
          await v6With(<String>[jsonEncode([kMangledConfused])]));
      await Vocabularies.load(db);

      final rec = (await SqliteEventStore(db).load()).single;
      expect(rec.feelings, <String>[kMangledConfused],
          reason: 'the record still carries the stored string');

      final cell = buildCsv(<EventRecord>[rec])
          .trim()
          .split('\n')
          .last
          .split(',')[8];
      expect(cell, 'Confused', reason: 'resolved to its label, as before');
      await db.close();
    });

    test('11. and the backup envelope is untouched', () async {
      // `toMap` writes `feelings`, which is unchanged. No new key, no bump.
      final r = EventRecord(
        id: 'x',
        timestamp: DateTime(2026, 8, 20),
        duration: null,
        feelings: <String>[kMangledConfused],
        referralRequired: false,
        notes: '',
      );
      final back = EventRecord.fromMap(r.toMap())!;
      expect(back.feelings, <String>[kMangledConfused]);
      expect(r.toMap().containsKey('observations'), isFalse,
          reason: 'the envelope gained nothing');
    });
  });
}
