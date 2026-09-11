import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';

import 'csv_no_blank_test.dart' show cells, header;

/// The named cell of the FIRST data row. Quote-aware, so the fixture's notes
/// — a comma and quotes — do not shift the columns.
String cellOf(String csv, String column) {
  final h = header(csv);
  final i = h.indexOf(column);
  if (i < 0) throw StateError('no "$column" column: $h');
  return cells(csv.trim().split('\n')[1])[i];
}

/// Does the STORAGE ENGINE change the export?
///
/// The question behind a proposal to keep one CSV fixture per platform, on the
/// grounds that `sqflite` and `sqflite_common_ffi` produce different data for
/// the same input.
///
/// STRUCTURALLY THEY CANNOT, and this pins it: `buildCsv` takes a
/// `List<EventRecord>` and touches no database and no platform check. Anything
/// that survives the round trip unchanged produces a byte-identical CSV.
///
/// So there is nothing for a per-platform fixture to document — and two files
/// required to be identical would be worse than none, because they drift and
/// the next reader assumes one is stale. This test is what a fixture pair would
/// have been FOR: it fails loudly if an engine ever does change a value.
///
/// WHAT IT DOES NOT COVER, stated rather than implied: only the engine
/// available in a Dart VM test runs here, which is `sqflite_common_ffi` — the
/// Windows and test-runner engine. `sqflite` proper is a platform plugin and
/// cannot be exercised from a unit test at all, so a genuine cross-engine
/// comparison needs two device exports, not a fixture.

EventRecord rec(String id, DateTime ts, DurationCategory? d) => EventRecord(
      id: id,
      timestamp: ts,
      duration: d,
      feelings: const ['😪 Just tired', '😵 Confused'],
      referralRequired: true,
      notes: 'a note, with a comma and "quotes"',
      eventType: kTypeAbsence,
      severity: EventSeverity.moderate,
      triggers: const ['Poor sleep'],
    );

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final t0 = DateTime(2026, 8, 26, 14, 5, 30);

  Future<Database> openDb() => databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: kSqliteSchemaVersion,
          onCreate: (db, _) => createSchema(db),
        ),
      );

  test('1. the CSV is identical in memory and after a SQLite round trip',
      () async {
    final records = <EventRecord>[
      rec('known', t0, DurationCategory.gt5),
      rec('unknown', t0.add(const Duration(hours: 1)), null),
    ];

    final db = await openDb();
    final store = SqliteEventStore(db);
    await store.save(records);
    final roundTripped = await store.load();

    // load() returns newest-first; buildCsv reverses internally, so feed both
    // sides the same ordering to compare the EXPORT rather than the sort.
    final fromMemory = buildCsv(List<EventRecord>.of(records)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp)));
    final fromSqlite = buildCsv(roundTripped);

    expect(fromSqlite, fromMemory,
        reason: 'the engine must not change a single byte of the export');
    await db.close();
  });

  test('2. NEGATIVE CONTROL: a changed value DOES change the CSV', () async {
    // Without this, test 1 passes just as well if buildCsv ignored its input.
    final a = buildCsv([rec('x', t0, DurationCategory.gt5)]);
    final b = buildCsv([rec('x', t0, null)]);

    expect(a, isNot(b),
        reason: 'the comparison in test 1 must be capable of failing');
    // ⛔ ANCHORED TO THE DURATION CELL, 11 Sep 2026 — AUDIT.md §13(ce).
    // These two lines read `expect(a, contains('> 5 minutes'))` and
    // `expect(b, contains('unknown'))` until then: substring matches over the
    // WHOLE ROW. After 8e1bc96 moved the duration cell to `Not Captured`, the
    // second kept passing because the CONDITION cell of this typed,
    // unattributed fixture happened to say `unknown` — the assertion was
    // satisfied by a cell it did not mean, while the thing it tests had
    // changed. A whole-row contains cannot say which cell it means.
    expect(cellOf(a, 'duration'), '> 5 minutes');
    expect(cellOf(b, 'duration'), kCsvNotCaptured);
  });

  test('3. an unknown duration survives the round trip as unknown', () async {
    final db = await openDb();
    final store = SqliteEventStore(db);
    await store.save([rec('u', t0, null)]);

    final back = (await store.load()).single;

    expect(back.duration, isNull,
        reason: 'not coerced to a bucket by the engine or the row mapping');
    // Anchored to the duration cell, 11 Sep 2026 — see test 2's note. This
    // read `contains('unknown')` over the whole row and was satisfied by the
    // condition cell after 8e1bc96.
    expect(cellOf(buildCsv([back]), 'duration'), kCsvNotCaptured);
    await db.close();
  });
}
