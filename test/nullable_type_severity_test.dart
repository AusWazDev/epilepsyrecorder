import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/models/backup.dart';
import 'package:medical_event_recorder/models/capture_inbox.dart';
import 'package:medical_event_recorder/models/capture_instruction.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';

/// `eventType` and `severity` become nullable at construction.
///
/// The last two fields that still FABRICATED. Both defaulted to the first enum
/// value, so a one-tap capture asserted a type and a comparison nobody made —
/// 71 records in the device export read "Seizure / fit · Mild" on that basis,
/// and a clinician could not tell an answer from a default.
///
/// Same change stage 1a made to `duration`, and the same rule: **NULL means NOT
/// ASKED.** Third and fourth fields to take it, after `duration` and
/// `detailsCompleted`.
///
/// ## Severity is the sharper of the two
///
/// It is a RELATIVE self-assessment — how this event felt against the person's
/// other events. A defaulted duration is a wrong measurement; a defaulted
/// severity is a comparison that was never performed at all.

EventRecord bare(String id, DateTime ts) => EventRecord(
      id: id,
      timestamp: ts,
      duration: null,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: false,
      notes: '',
    );

/// The `event` table as at v4: today's DDL, less the three columns v5 adds.
///
/// Verbatim rather than approximate, for the reason `createEventSqlV1` gives -
/// an approximation proves the upgrade works on a table that does not exist.
const String createEventSqlV4 = 'CREATE TABLE event ('
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
    'details_completed INTEGER, '
    'condition_id INTEGER)';

void main() {
  final t0 = DateTime(2026, 8, 26, 9, 0);

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(Vocabularies.debugReset);
  tearDown(Vocabularies.debugReset);

  group('CONSTRUCTION WRITES NULL', () {
    test('1. an unspecified type and severity are NULL, not the first enum',
        () {
      final r = bare('a', t0);
      expect(r.eventType, isNull);
      expect(r.severity, isNull);
    });

    test('2. NEGATIVE CONTROL: the old defaults are what would appear', () {
      // Names the exact values the constructor used to supply, so a future
      // change reinstating either fails here with the reason attached rather
      // than passing quietly.
      final r = bare('a', t0);
      expect(r.eventType, isNot('seizure'),
          reason: 'the first EventType enum value, supplied by nobody');
      expect(r.severity, isNot(EventSeverity.mild),
          reason: 'the first EventSeverity value, and a comparison nobody made');
    });

    test('3. a supplied value still arrives intact', () {
      // Without this, tests 1 and 2 pass just as well against a model that
      // dropped both fields entirely.
      final r = EventRecord(
        id: 'a',
        timestamp: t0,
        duration: null,
        feelings: const <String>[],
        referralRequired: false,
        notes: '',
        eventType: 'absence',
        severity: EventSeverity.severe,
      );
      expect(r.eventType, 'absence');
      expect(r.severity, EventSeverity.severe);
    });
  });

  group('THE CAPTURE PATH — the one producer, both platforms', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('4. a notification START creates a record with NEITHER', () async {
      // iOS routes here too: handleQuickLogStart posts a start fact and builds
      // no record, deferring every default to this drain. One fix, both
      // platforms — the same property the duration fix relied on.
      final prefs = await SharedPreferences.getInstance();
      await writeStartInstruction(prefs, id: 'ev', at: t0);

      final r =
          applyInbox(const <EventRecord>[], readInboxEntries(prefs)).merged.single;

      expect(r.eventType, isNull);
      expect(r.severity, isNull);
      expect(r.duration, isNull, reason: 'and duration, from stage 1a');
    });

    test('5. an END does not invent them either', () async {
      // The end knows a DURATION. It knows nothing about type or severity, and
      // the pass that rebuilds the record must not fill them in on the way.
      final prefs = await SharedPreferences.getInstance();
      await writeStartInstruction(prefs, id: 'ev', at: t0);
      await writeEndInstruction(prefs,
          id: 'ev', at: t0.add(const Duration(seconds: 200)), seconds: 200);

      final r =
          applyInbox(const <EventRecord>[], readInboxEntries(prefs)).merged.single;

      expect(r.durationSeconds, 200, reason: 'what the end DOES know');
      expect(r.eventType, isNull);
      expect(r.severity, isNull);
    });
  });

  group('NOTHING COERCES ON THE WAY IN OR OUT', () {
    test('6. fromMap: an ABSENT key reads as null', () {
      final r = EventRecord.fromMap(<String, dynamic>{
        'id': 'a',
        'timestamp': t0.toIso8601String(),
      });
      expect(r!.eventType, isNull);
      expect(r.severity, isNull);
    });

    test('7. NEGATIVE CONTROL: a PRESENT key still reads as its value', () {
      // The orElse that used to sit here turned "absent" into a confident
      // clinical claim. Removing it must not also break the normal case.
      final r = EventRecord.fromMap(<String, dynamic>{
        'id': 'a',
        'timestamp': t0.toIso8601String(),
        'eventType': 'absence',
        'severity': 'severe',
      });
      expect(r!.eventType, 'absence');
      expect(r.severity, EventSeverity.severe);
    });

    test('8. an UNRECOGNISED severity reads as null, not mild', () {
      final r = EventRecord.fromMap(<String, dynamic>{
        'id': 'a',
        'timestamp': t0.toIso8601String(),
        'severity': 'catastrophic',
      });
      expect(r!.severity, isNull);
    });

    test('9. SQLite round-trips both nulls', () async {
      final tmp = await Directory.systemTemp.createTemp('mer_ns_');
      final db = await databaseFactoryFfi.openDatabase(
        '${tmp.path}/a.db',
        options: OpenDatabaseOptions(
          version: kSqliteSchemaVersion,
          onCreate: (d, _) => createSchema(d),
          onUpgrade: upgradeSchema,
        ),
      );
      final store = SqliteEventStore(db);
      await store.save(<EventRecord>[bare('a', t0)]);

      final back = (await store.load()).single;
      expect(back.eventType, isNull);
      expect(back.severity, isNull,
          reason: 'the `?? mild` on the way out was the same defect as the '
              'orElse on the way in');

      await db.close();
      await tmp.delete(recursive: true);
    });

    test('10. the backup envelope round-trips both nulls', () {
      final back = parseBackup(buildBackupJson(<EventRecord>[bare('a', t0)],
              exportedAt: t0))
          .records
          .single;
      expect(back.eventType, isNull);
      expect(back.severity, isNull);
    });

    test('11. and the envelope still WRITES the severity key', () {
      // Explicit null rather than an absent key, so a reader can tell "asked
      // and unanswered" from a payload that predates the field.
      final json = jsonDecode(
          buildBackupJson(<EventRecord>[bare('a', t0)], exportedAt: t0));
      final rec = (json['records'] as List).single as Map<String, dynamic>;
      expect(rec.containsKey('severity'), isTrue);
      expect(rec['severity'], isNull);
    });
  });

  group('THE THREE SURFACES', () {
    test('12. the CSV writes an EXPLICIT unknown, never blank', () {
      // The duration decision, applied. A clinician reading a blank cell cannot
      // tell "not asked" from "not recorded" from a broken export.
      final header = buildCsv(const <EventRecord>[]).split('\n').first;
      final row = buildCsv(<EventRecord>[bare('a', t0)]).split('\n')[1];

      final cols = header.replaceFirst('﻿', '').trim().split(',');
      final vals = row.trim().split(',');
      expect(vals[cols.indexOf('event_type')], 'unknown');
      expect(vals[cols.indexOf('severity')], 'unknown');
      expect(vals[cols.indexOf('duration')], 'unknown',
          reason: 'the precedent this follows');
    });

    test('13. NEGATIVE CONTROL: a supplied value is NOT written as unknown',
        () {
      final row = buildCsv(<EventRecord>[
        EventRecord(
          id: 'a',
          timestamp: t0,
          duration: null,
          feelings: const <String>[],
          referralRequired: false,
          notes: '',
          eventType: 'absence',
          severity: EventSeverity.severe,
        ),
      ]).split('\n')[1];

      expect(row, contains('Absence episode'));
      expect(row, contains('Severe'));
    });

    test('14. a SCREEN gets null and omits, rather than a word', () {
      // The History row's rule, and the opposite of the CSV's. A row has one
      // line and must not spend it on an absence; a spreadsheet cell is read
      // in a column where blank is ambiguous.
      expect(eventTypeDisplay(null), isNull);
      expect(severityDisplay(null), isNull);
      expect(eventTypeCsv(null), 'unknown');
      expect(severityCsv(null), 'unknown');
    });
  });

  group('NO MIGRATION RUNS', () {
    test('15. NO MIGRATION HAS EVER ALTERED THESE TWO COLUMNS', () async {
      // ⚠️ REWRITTEN. This asserted `kSqliteSchemaVersion == 4` to prove a
      // LOCAL fact - that the nullable change added no step - by pinning a
      // GLOBAL constant. The fact is still true; the constant moved for an
      // unrelated reason (v5 added three rescue-medication columns) and the
      // test failed while nothing it cared about had changed.
      //
      // A test that pins a global to prove a local claim breaks on every
      // future change and says nothing about the one it was written for. This
      // measures the claim directly instead: a row written at v4 survives the
      // walk to the current version with both columns byte-identical.
      // ⚠️ THE v4 TABLE IS RECONSTRUCTED EXPLICITLY, not built by `createSchema`
      // at `version: 4`. `createEventSql` always emits the CURRENT column list,
      // so `onCreate` would produce a "v4" database that already carries v5's
      // columns - and the ALTER would then fail with `duplicate column name`
      // against a schema that exists nowhere.
      //
      // This is the same trap the v4 emoji step fell into for real, and the
      // first draft of THIS test fell into it too. Same pattern as
      // `createEventSqlV1` in sqlite_upgrade_v2_test: a fixture built at the
      // current version cannot fail.
      final tmp = await Directory.systemTemp.createTemp('mer_ns15_');
      final path = '${tmp.path}/v4.db';

      final old = await databaseFactoryFfi.openDatabase(path,
          options: OpenDatabaseOptions(
            version: 4,
            onCreate: (d, _) async {
              await d.execute(createSchemaMetaSql);
              await d.execute(createEventSqlV4);
              await d.insert('schema_meta',
                  <String, Object?>{'key': kMetaSchemaVersion, 'value': '4'});
            },
            onUpgrade: upgradeSchema,
          ));
      await old.insert('event', <String, Object?>{
        'ordinal': 0,
        'id': 'v4row',
        'logged_at': t0.toIso8601String(),
        'event_type': 'seizure',
        'severity': 1,
        'referral_required': 0,
      });
      await old.close();

      final now = await databaseFactoryFfi.openDatabase(path,
          options: OpenDatabaseOptions(
            version: kSqliteSchemaVersion,
            onCreate: (d, _) => createSchema(d),
            onUpgrade: upgradeSchema,
          ));
      final row = (await now.query('event', where: 'id = ?',
          whereArgs: <Object?>['v4row'])).single;

      expect(row['event_type'], 'seizure');
      expect(row['severity'], 1);
      // POSITIVE CONTROL: the upgrade really did run, so the two assertions
      // above are about a migrated row rather than one nothing touched.
      expect(row.containsKey('rescue_med_given'), isTrue,
          reason: 'v5 added this column, so the walk happened');
      expect(row['rescue_med_given'], isNull,
          reason: 'and it is NULL on a row that predates the question');

      await now.close();
      await tmp.delete(recursive: true);
    });

    test('16. an EXISTING row still reads as what it holds', () async {
      // The 71 records carry severity 0 and event_type "seizure" because a
      // version that coerced wrote them. They must keep reading that way: this
      // change stops NEW records fabricating, it does not un-fabricate old
      // ones, and silently nulling them would be the rewrite §3 forbids.
      final tmp = await Directory.systemTemp.createTemp('mer_ns2_');
      final db = await databaseFactoryFfi.openDatabase(
        '${tmp.path}/b.db',
        options: OpenDatabaseOptions(
          version: kSqliteSchemaVersion,
          onCreate: (d, _) => createSchema(d),
          onUpgrade: upgradeSchema,
        ),
      );
      await db.insert('event', <String, Object?>{
        'ordinal': 0,
        'id': 'old',
        'logged_at': t0.toIso8601String(),
        'event_type': 'seizure',
        // 1, not 0 — `severityToInt(mild)` is 1 and the enum index is not the
        // stored value. A fixture written with 0 read back as NULL, correctly,
        // and briefly looked like this change silently nulling existing
        // records. It was the fixture that was wrong; checking which took one
        // read of `severityFromInt`.
        'severity': 1,
        'referral_required': 0,
      });

      final back = (await SqliteEventStore(db).load()).single;
      expect(back.eventType, 'seizure');
      expect(back.severity, EventSeverity.mild);

      await db.close();
      await tmp.delete(recursive: true);
    });
  });
}
