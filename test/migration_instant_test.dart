// Brief 196 Part B (reissued) — does the SQLite migration preserve the INSTANT?
//
// The three stored shapes are defined once, in the chat-side doc
// MER-timestamp-shapes-2026-09-27; they are named here and not re-explained.
//
// ⛔ INSTANTS, NEVER STRINGS OR RENDERED TEXT. A comparison of strings would pass
// on a migration that shifted every record by a whole number of hours.
//
// ⚠️ THE ZONE IS A PRECONDITION, NOT A SETTING. Dart takes local time from the
// OS and cannot be given a per-process zone on Windows, so this suite — like
// timestamp_timezone_test.dart — runs in the host's zone. What it REQUIRES is
// that the host is NOT UTC on the fixture's dates: on a UTC host shape 2's
// normalisation is a no-op and this test could not tell a correct migration
// from a broken one. It fails loudly rather than skipping, so a UTC run cannot
// read as a pass.
//
// ⚠️ SYNTHETIC FIXTURE. Danny's iPad holds seven shape-2 records, but no JSON
// backup was ever taken from it — only a CSV, which the app cannot read back.
// The shape-2 record below is CONSTRUCTED to match that shape. It is not a
// device capture and must not be cited as one.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/models/storage_migration.dart';

Future<Database> _openDb() => databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: kSqliteSchemaVersion,
        onCreate: (db, _) => createSchema(db),
      ),
    );

/// A legacy record in the 1.0.x shape, every field present, only the
/// timestamp varying.
Map<String, dynamic> _legacy(String id, String timestamp) => <String, dynamic>{
      'id': id,
      'timestamp': timestamp,
      'duration': 'oneToFive',
      'feelings': <String>['😪 Just tired'],
      'referralRequired': true,
      'notes': 'fixture',
      'eventType': 'seizure',
      'severity': 'moderate',
      'triggers': <String>['Poor sleep'],
    };

/// The three shapes, with the INSTANT each must land on. Shapes 1 and 3 are
/// naive, so their instant is the host's local wall clock by definition;
/// shape 2 carries its own instant.
final _shapes = <({String id, String stored, DateTime instant})>[
  (
    id: 'shape-1',
    stored: '2026-08-22T18:18:35.180820',
    instant: DateTime(2026, 8, 22, 18, 18, 35, 180, 820),
  ),
  (
    id: 'shape-2',
    stored: '2026-08-22T06:45:09.000Z',
    instant: DateTime.utc(2026, 8, 22, 6, 45, 9),
  ),
  (
    id: 'shape-3',
    stored: '2026-08-24T03:07:06.000',
    instant: DateTime(2026, 8, 24, 3, 7, 6),
  ),
];

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('PRECONDITION: the host is not UTC on the fixture dates', () {
    final offset = DateTime(2026, 8, 22, 12).timeZoneOffset;
    // ignore: avoid_print
    print('   HOST OFFSET on 2026-08-22: $offset');
    expect(offset, isNot(Duration.zero),
        reason: 'on a UTC host shape 2 cannot be distinguished from shapes 1 and 3; '
            'every assertion below would pass on a broken migration');
  });

  test('B1: each shape migrates to the SAME INSTANT, read back through the real store',
      () async {
    final db = await _openDb();
    final raw = jsonEncode([for (final s in _shapes) _legacy(s.id, s.stored)]);

    final out = await migrateJsonToSqlite(db: db, rawJson: raw);
    expect(out.state, MigrationState.migrated);

    final loaded = {for (final r in await SqliteEventStore(db).load()) r.id: r};
    var checked = 0;
    for (final s in _shapes) {
      final r = loaded[s.id];
      expect(r, isNotNull, reason: '${s.id} did not survive migration');
      // ignore: avoid_print
      print('   ${s.id}: stored "${s.stored}" -> instant ${r!.timestamp.toUtc()} '
          '(expected ${s.instant.toUtc()})');
      expect(r.timestamp.isAtSameMomentAs(s.instant), isTrue,
          reason: '${s.id}: the migration moved the instant');
      checked++;
    }
    // ignore: avoid_print
    print('   INSTANTS CHECKED (unit=records): $checked of ${_shapes.length}');
    expect(checked, _shapes.length);
  });
}
