import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/models/vocabulary.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';

/// User-defined vocabularies.
///
/// The one property everything else hangs off: **`value` is what a record
/// stores and never changes; `label` is what a person reads and may.** Every
/// safety rule here is a consequence of that split, so the tests are arranged
/// to attack it directly rather than to exercise the API.

/// The v2 `event` table — before `condition_id`. Used to build a fixture the
/// upgrade can walk, from the real DDL rather than an approximation.
const String createEventSqlV2 = 'CREATE TABLE event ('
    'ordinal INTEGER NOT NULL, '
    'id TEXT NOT NULL, '
    'logged_at TEXT NOT NULL, '
    'occurred_at TEXT, '
    'duration_bucket TEXT, '
    'duration_seconds INTEGER, '
    'event_type TEXT, '
    'severity INTEGER, '
    'feelings_json TEXT, '
    'triggers_json TEXT, '
    'notes TEXT, '
    'referral_required INTEGER, '
    'details_completed INTEGER)';

Future<List<String>> columnsOf(Database db, String table) async {
  final info = await db.rawQuery('PRAGMA table_info($table)');
  return info.map((r) => r['name'] as String).toList();
}

Future<List<String>> tablesOf(Database db) async {
  final rows = await db
      .rawQuery("SELECT name FROM sqlite_master WHERE type = 'table'");
  return rows.map((r) => r['name'] as String).toList();
}

void main() {
  late Directory tmp;
  var seq = 0;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('mer_vocab_');
    // Otherwise one test's additions leak into the next, and a test that
    // passes only because an earlier one ran is worse than no test.
    Vocabularies.debugReset();
  });

  tearDown(() async {
    Vocabularies.debugReset();
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  // A REAL FILE. An in-memory database is discarded on close, so a "reopen at
  // v3" would silently open a fresh EMPTY database through onCreate and never
  // run the upgrade — and every assertion would be about a table the migration
  // never touched.
  String nextPath() => '${tmp.path}/mer_${seq++}.db';

  Future<Database> openFresh() => databaseFactoryFfi.openDatabase(
        nextPath(),
        options: OpenDatabaseOptions(
          version: kSqliteSchemaVersion,
          onCreate: (db, _) => createSchema(db),
          onUpgrade: upgradeSchema,
        ),
      );

  /// A v2 database holding [rows] records, then reopened at v3 through the SAME
  /// onUpgrade the app wires up.
  Future<Database> openV2ThenUpgrade({
    List<Map<String, Object?>> rows = const <Map<String, Object?>>[],
  }) async {
    final path = nextPath();
    final v2 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 2,
        onCreate: (db, _) async {
          await db.execute(createSchemaMetaSql);
          await db.execute(createEventSqlV2);
          await putMeta(db, kMetaSchemaVersion, '2');
          await putMeta(db, kMetaMigrationState, 'migrated');
        },
      ),
    );
    for (final r in rows) {
      await v2.insert('event', r);
    }
    await v2.close();

    return databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: kSqliteSchemaVersion,
        onCreate: (db, _) => createSchema(db),
        onUpgrade: upgradeSchema,
      ),
    );
  }

  group('BOTH SEEDED SETS', () {
    test('1. event types reproduce today\'s four, in order, "Other" last',
        () async {
      final db = await openFresh();
      final types = await loadVocabulary(db, kEventTypeTable);

      expect(types.map((e) => e.value).toList(),
          <String>['seizure', 'absence', 'medication', 'other']);
      expect(types.map((e) => e.label).toList(), <String>[
        'Seizure / fit',
        'Absence episode',
        'Medication taken',
        'Other / custom',
      ]);
      expect(offerable(types).last.value, kOtherEventTypeValue,
          reason: '"Other" is placed last, permanently');
      await db.close();
    });

    test('2. the four labels are CHARACTER-IDENTICAL to what shipped',
        () async {
      // Reproducing them "exactly" is the whole claim of §9, and a label that
      // drifted by a space would change every History badge and CSV cell.
      final db = await openFresh();
      final byValue = <String, String>{
        for (final e in await loadVocabulary(db, kEventTypeTable))
          e.value: e.label,
      };
      expect(byValue['seizure'], 'Seizure / fit');
      expect(byValue['absence'], 'Absence episode');
      expect(byValue['medication'], 'Medication taken');
      expect(byValue['other'], 'Other / custom');
      await db.close();
    });

    test('3. observations carry the revised set AND every legacy string',
        () async {
      final db = await openFresh();
      final obs = await loadVocabulary(db, kObservationTable);
      final values = obs.map((e) => e.value).toSet();

      // The revision.
      for (final v in <String>[
        'Tired',
        'Weak',
        'Memory gap',
        'Speech difficulty',
        'Confused',
        'Headache',
        'Sore or aching',
        'Nauseous',
        'Sad',
        'Anxious',
        'Angry',
        'Irritable',
        'Other',
      ]) {
        expect(values, contains(v), reason: 'revised entry "$v" is missing');
      }

      // EVERY string the app ever stored, retained. This is the migration
      // decision made testable: the collapse is a change to what is OFFERED,
      // never a rewrite of what was RECORDED.
      for (final legacy in kFeelingsOptions) {
        expect(values, contains(legacy),
            reason: 'the stored string "$legacy" must survive so records that '
                'reference it still render');
      }
      await db.close();
    });

    test('4. the collapsed and reworded originals are RETIRED, not offered',
        () async {
      final db = await openFresh();
      final obs = await loadVocabulary(db, kObservationTable);
      final offeredValues = offerable(obs).map((e) => e.value).toSet();

      for (final legacy in kFeelingsOptions) {
        expect(offeredValues, isNot(contains(legacy)),
            reason: '"$legacy" was collapsed or reworded and must not be '
                'offered alongside its replacement');
      }
      // POSITIVE CONTROL: something IS offered, so the assertion above is not
      // passing because the picker is empty.
      expect(offeredValues, contains('Tired'));
      expect(offeredValues.length, kSeedObservations.length);
      await db.close();
    });

    test('5. "Other" is last in the observation picker too', () async {
      final db = await openFresh();
      final offered = offerable(await loadVocabulary(db, kObservationTable));
      expect(offered.last.value, kOtherObservationValue);
      await db.close();
    });
  });

  group('THE 71 MAPPING — existing records are untouched', () {
    test('6. a v2 record keeps its type string through the upgrade', () async {
      final db = await openV2ThenUpgrade(rows: <Map<String, Object?>>[
        <String, Object?>{
          'ordinal': 0,
          'id': 'r0',
          'logged_at': DateTime(2026, 8, 20, 9).toIso8601String(),
          'event_type': 'seizure',
          'severity': 0,
          // The three records on the device that carry a feeling carry THIS
          // exact string, emoji included.
          'feelings_json': '["\u{1F635} Confused"]',
          'triggers_json': '["Poor sleep"]',
          'notes': 'kept',
          'referral_required': 0,
        },
      ]);

      final back = (await SqliteEventStore(db).load()).single;
      expect(back.eventType, 'seizure');
      expect(back.feelings, <String>['\u{1F635} Confused']);
      expect(back.triggers, <String>['Poor sleep']);
      expect(back.notes, 'kept');
      await db.close();
    });

    test('7. and it still RENDERS, through the retired entry', () async {
      final db = await openV2ThenUpgrade();
      await Vocabularies.load(db);

      expect(Vocabularies.labelFor(kObservationTable, '\u{1F635} Confused'),
          'Confused',
          reason: 'the retired entry resolves the stored string to a label '
              'with no emoji — which is why retiring beats deleting');
      expect(Vocabularies.labelFor(kEventTypeTable, 'seizure'), 'Seizure / fit');
      await db.close();
    });

    test('8. the upgrade adds condition_id, NULL on every existing row',
        () async {
      final db = await openV2ThenUpgrade(rows: <Map<String, Object?>>[
        <String, Object?>{
          'ordinal': 0,
          'id': 'r0',
          'logged_at': DateTime(2026, 8, 20, 9).toIso8601String(),
          'event_type': 'seizure',
          'severity': 0,
          'referral_required': 0,
        },
      ]);

      expect(await columnsOf(db, 'event'), contains('condition_id'));
      final rows = await db.query('event');
      expect(rows.single['condition_id'], isNull,
          reason: 'NOT YET SAID. There is no condition table and no screen on '
              'which someone could say what they track, so any value here '
              'would be an assertion about their health invented by a '
              'migration');
      await db.close();
    });

    test('9. and NO condition table is created', () async {
      // The stage boundary, asserted rather than assumed. Building the table
      // now would make it inert AND make the seed question live.
      final db = await openFresh();
      final tables = await tablesOf(db);

      expect(tables, contains(kEventTypeTable));
      expect(tables, contains(kObservationTable));
      expect(tables, isNot(contains('condition')),
          reason: 'deferred until a screen exists where someone says what they '
              'track');
      await db.close();
    });

    test('10. a v2 database walks 2 -> 3 and keeps its migration marker',
        () async {
      final db = await openV2ThenUpgrade();
      expect(await getMeta(db, kMetaSchemaVersion), '$kSqliteSchemaVersion');
      expect(await getMeta(db, kMetaMigrationState), 'migrated',
          reason: 'a schema change is not a re-migration');
      await db.close();
    });
  });

  group('CREATING AN ENTRY', () {
    test('11. a user entry persists and is offered next time', () async {
      final db = await openFresh();
      final added = await addUserEntry(db, kObservationTable, 'Dizzy');

      expect(added, isNotNull);
      expect(added!.isSeeded, isFalse);
      expect(added.isActive, isTrue);
      expect(added.value, 'Dizzy');

      // Re-read from the DATABASE, not from the returned object — the claim is
      // that it survives, not that the function returned something.
      final reread = await loadVocabulary(db, kObservationTable);
      expect(reread.map((e) => e.value), contains('Dizzy'));
      expect(offerable(reread).map((e) => e.value), contains('Dizzy'));
      await db.close();
    });

    test('12. adding the same name twice does not create a second entry',
        () async {
      final db = await openFresh();
      await addUserEntry(db, kObservationTable, 'Dizzy');
      final again = await addUserEntry(db, kObservationTable, '  dizzy  ');

      final all = await loadVocabulary(db, kObservationTable);
      expect(all.where((e) => e.label.toLowerCase() == 'dizzy').length, 1,
          reason: 'trimmed and case-insensitive, so "dizzy" does not sit beside '
              '"Dizzy" as a second permanent entry');
      expect(again!.value, 'Dizzy');
      await db.close();
    });

    test('13. empty input creates nothing', () async {
      final db = await openFresh();
      final before = (await loadVocabulary(db, kObservationTable)).length;
      expect(await addUserEntry(db, kObservationTable, '   '), isNull);
      expect((await loadVocabulary(db, kObservationTable)).length, before,
          reason: 'a blank entry could never be deleted');
      await db.close();
    });

    test('14. a user-defined EVENT TYPE persists and a record can carry it',
        () async {
      final db = await openFresh();
      await addUserEntry(db, kEventTypeTable, 'Cluster headache');
      await Vocabularies.load(db);

      final store = SqliteEventStore(db);
      await store.save(<EventRecord>[
        EventRecord(
          id: 'ch',
          timestamp: DateTime(2026, 8, 26, 10),
          duration: null,
          feelings: const <String>[],
          referralRequired: false,
          notes: '',
          eventType: 'Cluster headache',
        ),
      ]);

      final back = (await store.load()).single;
      expect(back.eventType, 'Cluster headache',
          reason: 'the old enum could not represent this at all');
      expect(eventTypeDisplay(back.eventType), 'Cluster headache');
      await db.close();
    });
  });

  group('SEEDED ENTRIES REFUSE RENAME AND DELETE', () {
    test('15. renaming a seeded entry throws', () async {
      final db = await openFresh();
      final seizure = (await loadVocabulary(db, kEventTypeTable))
          .firstWhere((e) => e.value == kTypeSeizure);

      expect(
        () => renameEntry(db, kEventTypeTable, seizure, 'Fit'),
        throwsA(isA<VocabularyRuleError>()),
      );
      await db.close();
    });

    test('16. there is NO delete function at all', () {
      // Asserted as a fact about the surface rather than a behaviour: the API
      // has no delete, so no caller can reach one. `kWhyNoDelete` is the text
      // the UI shows, and its presence is what this pins.
      expect(kWhyNoDelete, contains('hidden, never deleted'));
    });

    test('17. a USER entry may be renamed, and the stored value does NOT move',
        () async {
      final db = await openFresh();
      final added = await addUserEntry(db, kObservationTable, 'Dizy');
      final fixed =
          await renameEntry(db, kObservationTable, added!, 'Dizzy');

      expect(fixed.label, 'Dizzy');
      expect(fixed.value, 'Dizy',
          reason: 'the TYPO stays as the stored value, forever. That is not a '
              'defect — records already carry it, and moving it is exactly the '
              'orphaning this design prevents');
      await db.close();
    });

    test(
        '18. NEGATIVE CONTROL: a rename that moved the VALUE would orphan a '
        'record', () async {
      // The trap, made concrete. Without this, test 17 reads as a quirk rather
      // than the load-bearing rule — and nothing would notice an implementation
      // that "helpfully" updated the value too.
      final db = await openFresh();
      final added = await addUserEntry(db, kObservationTable, 'Dizy');

      final store = SqliteEventStore(db);
      await store.save(<EventRecord>[
        EventRecord(
          id: 'r',
          timestamp: DateTime(2026, 8, 26, 10),
          duration: null,
          feelings: const <String>['Dizy'],
          referralRequired: false,
          notes: '',
        ),
      ]);

      await renameEntry(db, kObservationTable, added!, 'Dizzy');
      await Vocabularies.load(db);

      final back = (await store.load()).single;
      expect(back.feelings.single, 'Dizy', reason: 'the record is untouched');
      expect(Vocabularies.labelFor(kObservationTable, 'Dizy'), 'Dizzy',
          reason: 'and it now RESOLVES to the corrected label');

      // What the defect would look like: simulate a rename that also moved the
      // value, and show the record stops resolving.
      await db.update(kObservationTable, <String, Object?>{'value': 'Dizzy'},
          where: 'id = ?', whereArgs: <Object?>[added.id]);
      await Vocabularies.load(db);

      expect(Vocabularies.labelFor(kObservationTable, 'Dizy'), 'Dizy',
          reason: 'ORPHANED — the record now resolves to nothing but its own '
              'raw string, and the entry it belonged to is unreachable from it. '
              'This is what renameEntry structurally cannot do');
      await db.close();
    });
  });

  group('MEDICATION IS PROTECTED', () {
    test('19. medication refuses to be hidden', () async {
      final db = await openFresh();
      final med = (await loadVocabulary(db, kEventTypeTable))
          .firstWhere((e) => e.value == kMedicationValue);

      expect(med.isProtected, isTrue);
      expect(
        () => setActive(db, kEventTypeTable, med, false),
        throwsA(isA<VocabularyRuleError>()),
      );
      await db.close();
    });

    test('20. the refusal EXPLAINS why', () async {
      // A user who cannot edit something has to be told the reason, or the app
      // is just broken from where they are standing.
      final db = await openFresh();
      final med = (await loadVocabulary(db, kEventTypeTable))
          .firstWhere((e) => e.value == kMedicationValue);

      try {
        await setActive(db, kEventTypeTable, med, false);
        fail('should have thrown');
      } on VocabularyRuleError catch (e) {
        expect(e.message, contains('recorded separately'));
        expect(e.message.toLowerCase(), contains('future version'));
      }
      await db.close();
    });

    test('21. NEGATIVE CONTROL: an UNPROTECTED seeded entry CAN be hidden',
        () async {
      // Without this, test 19 passes just as well against an implementation
      // that refuses to hide anything — which would be a different bug.
      final db = await openFresh();
      final absence = (await loadVocabulary(db, kEventTypeTable))
          .firstWhere((e) => e.value == kTypeAbsence);

      final hidden = await setActive(db, kEventTypeTable, absence, false);
      expect(hidden.isActive, isFalse);

      final offered =
          offerable(await loadVocabulary(db, kEventTypeTable)).map((e) => e.value);
      expect(offered, isNot(contains(kTypeAbsence)));
      expect(offered, contains(kMedicationValue),
          reason: 'medication is still there — it cannot be hidden');
      await db.close();
    });

    test('22. a hidden type still RENDERS on records that use it', () async {
      final db = await openFresh();
      final absence = (await loadVocabulary(db, kEventTypeTable))
          .firstWhere((e) => e.value == kTypeAbsence);
      await setActive(db, kEventTypeTable, absence, false);
      await Vocabularies.load(db);

      expect(eventTypeLabel(kTypeAbsence), 'Absence episode',
          reason: 'hiding changes what is OFFERED, never what is READABLE');
      await db.close();
    });
  });

  group('THE MIS-DECODED LEGACY STRINGS', () {
    // Found on the tablet, not in code review: three records store the UTF-8
    // bytes of an emoji read back as Latin-1. Pre-existing, cause unknown, and
    // deliberately repaired by ADDING VOCABULARY rather than editing records.
    //
    // Written as escapes, not as literal characters, so this file cannot itself
    // be the thing that mangles the string it is asserting about.
    const mangledConfused = '\u00F0\u009F\u0098\u00B5 Confused';

    test('25. the transform is exact, and reverses', () {
      expect(latin1Mangled('\u{1F635} Confused'), mangledConfused);
      // POSITIVE CONTROL that this is the real corruption and not a lookalike:
      // reading those characters back as bytes gives the original UTF-8.
      expect(mangledConfused.codeUnits.take(4).toList(),
          <int>[0xF0, 0x9F, 0x98, 0xB5]);
    });

    test('26. an ASCII-only string produces NO twin', () {
      // Otherwise it would collide with the real entry's UNIQUE value and the
      // seed would fail.
      expect(latin1Mangled('Poor sleep'), isNull);
      expect(latin1Mangled('Tired'), isNull);
    });

    test('27. the mangled value RESOLVES to a readable label', () async {
      final db = await openFresh();
      await Vocabularies.load(db);

      expect(Vocabularies.labelFor(kObservationTable, mangledConfused),
          'Confused',
          reason: 'the records on the tablet become readable without a single '
              'stored value being edited');
      await db.close();
    });

    test('28. and the twins are RETIRED, never offered', () async {
      final db = await openFresh();
      final offered = offerable(await loadVocabulary(db, kObservationTable));
      expect(offered.map((e) => e.value), isNot(contains(mangledConfused)));
      // POSITIVE CONTROL: the picker is not simply empty.
      expect(offered.map((e) => e.value), contains('Confused'));
      await db.close();
    });

    test('29. NEGATIVE CONTROL: the record itself is NOT rewritten', () async {
      // The rule the whole revision follows, and it applies with MORE force to
      // a corruption than to a wording change: a repair that edits records is
      // unreviewable afterwards; a vocabulary row can be read and removed.
      final db = await openFresh();
      final store = SqliteEventStore(db);
      await store.save(<EventRecord>[
        EventRecord(
          id: 'm',
          timestamp: DateTime(2026, 8, 22, 20, 38),
          duration: null,
          feelings: const <String>[mangledConfused],
          referralRequired: false,
          notes: '',
        ),
      ]);
      await Vocabularies.load(db);

      final back = (await store.load()).single;
      expect(back.feelings.single, mangledConfused,
          reason: 'byte for byte what was stored');
      expect(back.feelings.single, isNot('\u{1F635} Confused'),
          reason: 'nothing silently "corrected" it into the clean string');
      await db.close();
    });
  });

  group('SEEDS REACH A DATABASE THAT IS ALREADY CURRENT', () {
    // THE DEFECT THIS EXISTS FOR, and it shipped to the device before it was
    // caught. The seeds first lived inside the v2 -> v3 upgrade branch. A
    // database ALREADY at v3 runs no upgrade branch, so a seed added in a later
    // build never reached it — and every test passed, because every test opened
    // a FRESH database where onCreate seeded everything.
    //
    // The fixture therefore has to be a database at the CURRENT version that
    // is MISSING a seed. Anything else cannot fail.

    test('30. a v3 database missing a seed gains it on the next open',
        () async {
      final path = nextPath();

      // Open at the current version, then DELETE a seeded row to simulate a
      // database created before that seed existed.
      final first = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: kSqliteSchemaVersion,
          onCreate: (db, _) => createSchema(db),
          onUpgrade: upgradeSchema,
        ),
      );
      await first.delete(kObservationTable,
          where: 'value = ?', whereArgs: <Object?>['\u00F0\u009F\u0098\u00B5 Confused']);
      // PRECONDITION, asserted rather than assumed.
      expect(
          (await loadVocabulary(first, kObservationTable))
              .map((e) => e.value),
          isNot(contains('\u00F0\u009F\u0098\u00B5 Confused')));
      await first.close();

      // Reopen at the SAME version. No onCreate, no onUpgrade.
      final second = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: kSqliteSchemaVersion,
          onCreate: (db, _) => createSchema(db),
          onUpgrade: upgradeSchema,
        ),
      );
      await ensureSeeded(second);

      expect(
          (await loadVocabulary(second, kObservationTable))
              .map((e) => e.value),
          contains('\u00F0\u009F\u0098\u00B5 Confused'),
          reason: 'a seed list that grows needs a seed pass that RUNS');
      await second.close();
    });

    test('31. NEGATIVE CONTROL: the upgrade branch alone would NOT have',
        () async {
      // Shows the difference is real and not an artefact of the fixture: run
      // the upgrade function directly at from == to == current, which is what
      // sqflite does on a reopen, and the missing seed stays missing.
      final path = nextPath();
      final first = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: kSqliteSchemaVersion,
          onCreate: (db, _) => createSchema(db),
        ),
      );
      await first.delete(kObservationTable,
          where: 'value = ?', whereArgs: <Object?>['\u00F0\u009F\u0098\u00B5 Confused']);

      await upgradeSchema(first, kSqliteSchemaVersion, kSqliteSchemaVersion);

      expect(
          (await loadVocabulary(first, kObservationTable))
              .map((e) => e.value),
          isNot(contains('\u00F0\u009F\u0098\u00B5 Confused')),
          reason: 'this is exactly what happened on the tablet');
      await first.close();
    });

    test('32. re-seeding twice adds nothing and changes nothing', () async {
      final db = await openFresh();
      final before = await loadVocabulary(db, kObservationTable);

      await ensureSeeded(db);
      await ensureSeeded(db);

      final after = await loadVocabulary(db, kObservationTable);
      expect(after.length, before.length, reason: 'idempotent on value');
      expect(after.map((e) => e.value).toList(),
          before.map((e) => e.value).toList());
      await db.close();
    });

    test('33. re-seeding does NOT revive an entry the user hid', () async {
      // The seed must not undo a decision. `seedVocabulary` skips any value
      // that is already present, whatever its is_active.
      final db = await openFresh();
      final absence = (await loadVocabulary(db, kEventTypeTable))
          .firstWhere((e) => e.value == kTypeAbsence);
      await setActive(db, kEventTypeTable, absence, false);

      await ensureSeeded(db);

      final again = (await loadVocabulary(db, kEventTypeTable))
          .firstWhere((e) => e.value == kTypeAbsence);
      expect(again.isActive, isFalse,
          reason: 'a seed pass that revived hidden entries would silently '
              'reverse the user every launch');
      await db.close();
    });
  });

  group('THE CSV', () {
    test('23. a user-defined observation reaches the export', () async {
      // The reason the one-hot columns had to go. Under the old shape this
      // value had no column and vanished silently.
      Vocabularies.debugSet(observations: <VocabularyEntry>[
        const VocabularyEntry(
          id: 1,
          value: 'Dizzy',
          label: 'Dizzy',
          isSeeded: false,
          isActive: true,
          isProtected: false,
          sortOrder: 1,
        ),
      ]);

      final csv = buildCsv(<EventRecord>[
        EventRecord(
          id: 'r',
          timestamp: DateTime(2026, 8, 26, 10),
          duration: null,
          feelings: const <String>['Dizzy'],
          referralRequired: false,
          notes: '',
        ),
      ]);

      expect(csv, contains('Dizzy'));
      expect(csv.split('\n').first, contains('observations'));
    });

    test('24. several observations are delimited, not concatenated', () {
      final csv = buildCsv(<EventRecord>[
        EventRecord(
          id: 'r',
          timestamp: DateTime(2026, 8, 26, 10),
          duration: null,
          feelings: const <String>['Tired', 'Confused'],
          referralRequired: false,
          notes: '',
        ),
      ]);
      expect(csv, contains('Tired; Confused'));
    });
  });
}
