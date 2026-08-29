import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/models/medication_note.dart';
import 'package:medical_event_recorder/models/vocabulary.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';

/// Regular medication as a SEPARATE RECORD KIND.
///
/// ## What is actually at risk
///
/// The defect this split exists to remove is that a dose and a seizure shared a
/// row and **counted identically** — so "N events this month" inflated the
/// seizure count for anyone tracking adherence. The way to reintroduce it is
/// not to merge the tables again; it is for a count, a filter or an export to
/// quietly start including notes. Most of this file measures that.

MedicationNote note(String id, DateTime at, MedicationDeviation k,
        {String notes = ''}) =>
    MedicationNote(
      id: id,
      occurredAt: at,
      loggedAt: at.add(const Duration(hours: 3)),
      kind: k,
      notes: notes,
    );

EventRecord event(String id, DateTime at) => EventRecord(
      id: id,
      timestamp: at,
      duration: null,
      durationSeconds: 90,
      eventType: 'seizure',
      severity: EventSeverity.mild,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: false,
      notes: '',
    );

List<String> header(String csv) =>
    csv.split('\n').first.replaceFirst('﻿', '').trim().split(',');

List<List<String>> dataRows(String csv) => csv
    .trim()
    .split('\n')
    .skip(1)
    .map((l) => l.split(','))
    .toList();

void main() {
  sqfliteFfiInit();
  late Directory tmp;
  var seq = 0;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('mer_med_');
    Vocabularies.debugReset();
  });
  tearDown(() async {
    Vocabularies.debugReset();
    await tmp.delete(recursive: true);
  });

  Future<Database> open({int version = kSqliteSchemaVersion}) =>
      databaseFactoryFfi.openDatabase(
        '${tmp.path}/db${seq++}.db',
        options: OpenDatabaseOptions(
          version: version,
          onCreate: (d, _) => createSchema(d),
          onUpgrade: upgradeSchema,
        ),
      );

  group('THE TABLE', () {
    test('1. a note round-trips through the database', () async {
      final db = await open();
      final n = note('a', DateTime(2026, 8, 20, 8, 30),
          MedicationDeviation.missed, notes: 'morning dose');
      await insertMedicationNote(db, n);

      final back = (await loadMedicationNotes(db)).single;
      expect(back.id, 'a');
      expect(back.kind, MedicationDeviation.missed);
      expect(back.notes, 'morning dose');
      expect(back.occurredAt, DateTime(2026, 8, 20, 8, 30));
      expect(back.loggedAt, isNot(back.occurredAt),
          reason: 'when it happened and when it was written are separate');
      await db.close();
    });

    test('2. an unparseable row is SKIPPED, never defaulted', () async {
      // Same discipline as EventRecord.fromMap: a silently wrong date in a
      // medical record is worse than an omission.
      final db = await open();
      await db.insert(kMedicationNoteTable, <String, Object?>{
        'id': 'bad',
        'occurred_at': 'not-a-date',
        'logged_at': DateTime(2026, 8, 20).toIso8601String(),
        'kind': 'missed',
        'notes': '',
      });
      await insertMedicationNote(
          db, note('good', DateTime(2026, 8, 21), MedicationDeviation.late));

      final back = await loadMedicationNotes(db);
      expect(back.length, 1);
      expect(back.single.id, 'good');
      await db.close();
    });

    test('3. an unrecognised kind is skipped, not coerced to the first',
        () async {
      // The `orElse` that produced `seizure` and `mild` is the defect this
      // project spent a week undoing. It is not repeated here.
      expect(medicationDeviationFromName('missed'), MedicationDeviation.missed);
      expect(medicationDeviationFromName('something-else'), isNull);
      expect(medicationDeviationFromName(null), isNull);
    });
  });

  group('THE MIGRATION', () {
    test('4. v5 → v6 creates the table and retires the event type', () async {
      final path = '${tmp.path}/v5.db';
      final old = await databaseFactoryFfi.openDatabase(path,
          options: OpenDatabaseOptions(
            version: 5,
            onCreate: (d, _) async {
              await d.execute(createSchemaMetaSql);
              await d.execute(createEventSql);
              await createAndSeedVocabularies(d);
            },
            onUpgrade: upgradeSchema,
          ));
      await old.insert('event', <String, Object?>{
        'ordinal': 0,
        'id': 'keep',
        'logged_at': DateTime(2026, 8, 1).toIso8601String(),
        'event_type': 'seizure',
        'severity': 1,
        'referral_required': 0,
      });
      final medBefore = (await old.query(kEventTypeTable,
              where: 'value = ?', whereArgs: <Object?>['medication']))
          .single;
      expect(medBefore['is_active'], 1, reason: 'precondition: still offered');
      expect(medBefore['is_protected'], 1);
      await old.close();

      final now = await databaseFactoryFfi.openDatabase(path,
          options: OpenDatabaseOptions(
            version: kSqliteSchemaVersion,
            onCreate: (d, _) => createSchema(d),
            onUpgrade: upgradeSchema,
          ));

      expect(await loadMedicationNotes(now), isEmpty,
          reason: 'the table exists and is empty');

      final med = (await now.query(kEventTypeTable,
              where: 'value = ?', whereArgs: <Object?>['medication']))
          .single;
      expect(med['is_active'], 0, reason: 'retired: no longer offered');
      expect(med['is_protected'], 0,
          reason: 'the protection guarded an empty set and has served its '
              'purpose');
      await now.close();
    });

    test('5. NEGATIVE CONTROL: the migration does not touch a single record',
        () async {
      // ⛔ THE CONTROL THIS BUILD NEEDS. Test 4 proves the table appears; this
      // proves nothing ELSE moved. A migration that quietly rewrote an event
      // would pass test 4 unchanged.
      final path = '${tmp.path}/v5b.db';
      final before = <String, Object?>{
        'ordinal': 0,
        'id': 'untouched',
        'logged_at': DateTime(2026, 8, 1, 12, 34, 56).toIso8601String(),
        'duration_bucket': 'oneToFive',
        'event_type': 'seizure',
        'severity': 2,
        'feelings_json': '["\u{1F635} Confused"]',
        'triggers_json': '["Poor sleep"]',
        'notes': 'a note',
        'referral_required': 1,
      };
      final old = await databaseFactoryFfi.openDatabase(path,
          options: OpenDatabaseOptions(
            version: 5,
            onCreate: (d, _) async {
              await d.execute(createSchemaMetaSql);
              await d.execute(createEventSql);
              await createAndSeedVocabularies(d);
            },
            onUpgrade: upgradeSchema,
          ));
      await old.insert('event', before);
      await old.close();

      final now = await databaseFactoryFfi.openDatabase(path,
          options: OpenDatabaseOptions(
            version: kSqliteSchemaVersion,
            onCreate: (d, _) => createSchema(d),
            onUpgrade: upgradeSchema,
          ));
      final after = (await now.query('event')).single;

      for (final k in before.keys) {
        expect(after[k], before[k],
            reason: 'the v6 migration rewrote `$k` — it must touch NOTHING '
                'on the event table');
      }
      // POSITIVE CONTROL: the upgrade really ran, so the comparison above is
      // over a migrated row rather than one nothing reached.
      expect(await loadMedicationNotes(now), isEmpty);
      await now.close();
    });
  });

  group('THE HOME SCREEN COUNT — the defect this split removes', () {
    test('6. notes live in a DIFFERENT TABLE, so no event query sees them',
        () async {
      // The original defect was medication-as-an-event-type: a dose and a
      // seizure shared a row and counted identically. Structurally impossible
      // now — this measures it rather than asserting it.
      final db = await open();
      final store = SqliteEventStore(db);
      await store.save(<EventRecord>[event('e', DateTime(2026, 8, 10))]);
      for (var i = 0; i < 5; i++) {
        await insertMedicationNote(db, note('m$i',
            DateTime(2026, 8, 11 + i), MedicationDeviation.missed));
      }

      expect((await store.load()).length, 1,
          reason: 'five deviations must not inflate the event count');
      expect((await loadMedicationNotes(db)).length, 5);
      await db.close();
    });
  });

  group('THE EXPORT', () {
    test('7. seventeen columns, record_kind after time', () {
      final h = header(buildCsv(<EventRecord>[event('e', DateTime(2026, 8, 1))]));
      // 17 since `condition` landed before event_type. The golden header
      // in csv_delimited_test is what enforces the marker rule; this is
      // just the count this test depends on.
      expect(h.length, 17);
      expect(h[3], 'record_kind');
      expect(h[15], 'medication_kind');
      // Not because of this pass: v5 was the condition column, v6 the time
      // columns changing meaning. The COUNT above is what this file depends
      // on, and seventeen is still right — v6 added no column.
      expect(kCsvShapeVersion, 'v6');
      expect(csvFilename(when: DateTime(2026, 8, 28, 9, 0, 0)),
          'medical_event_recorder_20260828_090000.v6.csv');
    });

    test('8. an events-only export marks every row as an event', () {
      final rows = dataRows(
          buildCsv(<EventRecord>[event('e', DateTime(2026, 8, 1))]));
      expect(rows.single[3], kRecordKindEvent);
      expect(rows.single[15], '',
          reason: 'medication_kind is not applicable');
    });

    test('9. ⛔ ONE TIMELINE: the two streams interleave by date', () {
      // The whole point of record_kind. Emitting events then notes would put
      // every deviation at the bottom and lose the adjacency that makes the
      // file worth reading — a missed dose three days before a cluster.
      final csv = buildCsv(
        <EventRecord>[
          event('e1', DateTime(2026, 8, 1)),
          event('e2', DateTime(2026, 8, 5)),
        ],
        notes: <MedicationNote>[
          note('m1', DateTime(2026, 8, 3), MedicationDeviation.missed),
        ],
      );
      final kinds = dataRows(csv).map((r) => r[3]).toList();
      expect(kinds,
          <String>[kRecordKindEvent, kRecordKindMedication, kRecordKindEvent]);
    });

    test('10. a medication row blanks every event-only column', () {
      final row = dataRows(buildCsv(
        const <EventRecord>[],
        notes: <MedicationNote>[
          note('m', DateTime(2026, 8, 3, 7, 15), MedicationDeviation.late,
              notes: 'took it at lunch'),
        ],
      )).single;

      expect(row[3], kRecordKindMedication);
      expect(row[15], 'Late');
      expect(row[16], 'took it at lunch');

      // Column 4 is `condition`, and it is EXPLICITLY EXCLUDED from the
      // blanking loop below rather than silently skipped. A medication note
      // has no event type, so there is nothing to derive a condition FROM -
      // that is "not known", not "not applicable", and the two are different
      // facts. `medication_note.condition_id` exists and is unpopulated; when
      // it is populated this reads it instead.
      expect(row[4], 'unknown', reason: 'condition is not derivable for a dose');

      for (final i in <int>[5, 6, 7, 8, 9, 10, 11, 12, 13, 14]) {
        expect(row[i], '', reason: 'column $i is not applicable to a dose');
      }
    });

    test('11. NEGATIVE CONTROL: a caller that passes no notes gets none', () {
      // ⛔ THE SCOPE GUARANTEE. History's export is FILTERED and must stay
      // events-only: including notes would make its scope statement false —
      // "Export 1 of 71 events" beside a file holding every deviation.
      //
      // `notes` defaults to empty, so single-stream is what a caller gets
      // unless it asks. This is the test that would fail if the default
      // changed.
      final csv = buildCsv(<EventRecord>[event('e', DateTime(2026, 8, 1))]);
      expect(dataRows(csv).length, 1);
      expect(csv.contains(kRecordKindMedication), isFalse);

      // And the same call WITH notes proves the parameter works, so the
      // absence above is a scope fact rather than a broken writer.
      final both = buildCsv(
        <EventRecord>[event('e', DateTime(2026, 8, 1))],
        notes: <MedicationNote>[
          note('m', DateTime(2026, 8, 2), MedicationDeviation.changed),
        ],
      );
      expect(dataRows(both).length, 2);
    });

    test('12. record_kind can carry a THIRD value without a shape change', () {
      // DATA-MODEL.md §9's `daily_entry`. Written as a string rather than a
      // two-valued flag from the outset, so §9 is an addition rather than a
      // breaking change to the export.
      expect(kRecordKindEvent, isNot(kRecordKindMedication));
      expect(kRecordKindEvent, isA<String>());
    });
  });
}
