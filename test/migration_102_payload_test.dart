// Brief 286 Part D — would a record written by App Store 1.0.2 migrate?
//
// App Store 1.0.2 is build 3, submitted 6 May 2026 05:20 from 192ae40 (Change
// Register: "Version 1.0.2, Build 3"; "1.0.2+4 never existed"). Its iOS tree
// carries the native Swift writer (285bb74 to 4ba63e1^), so a real 1.0.2
// iPhone can hold records that no 1.1.x build writes:
//
//   * Dart-written (EventStore.save, notification_service): toIso8601String()
//     of a LOCAL DateTime, naive, with microseconds, or milliseconds only when
//     the microsecond part is 0.
//   * Swift-written (AppDelegate.handleQuickLogStart, the lock-screen path):
//     ISO8601DateFormatter() with DEFAULT options, so "yyyy-MM-ddTHH:mm:ssZ",
//     UTC, NO fractional seconds. That exact form is absent from
//     migration_instant_test.dart, whose Z shape is ".000Z".
//   * A Swift record after ANY later Dart save: 1.0.2's fromMap uses a bare
//     DateTime.parse, which keeps it UTC, so toMap re-writes it as ".000Z".
//
// The list under flutter.epilepsy_event_records_v1 is always re-encoded whole
// by whichever side wrote last, so a device holds ONE of two payloads:
//   (A) last written by Swift: JSONSerialization, which escapes "/" as "\/",
//       native records still fraction-less;
//   (B) last written by Dart: jsonEncode, native records now ".000Z".
// Both are run.
//
// ⛔ THE POPULATION IS THE LITERAL LIST BELOW, NEVER THE MIGRATION'S OWN PARSE.
// rawMapToRow skips a record whose timestamp fails DateTime.tryParse, and the
// migration's verification counts with the same predicate (the Brief 197
// finding), so a record lost that way would pass its check. Here every
// expected record is named in advance and must come back.
//
// ⚠️ SYNTHETIC FIXTURE, constructed from the 192ae40 writers. It is not a
// device capture and must not be cited as one.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/models/storage_migration.dart';

// singleInstance: false — inMemoryDatabasePath is otherwise ONE shared database
// per process, and the second payload would find the first one's migrated
// schema and report alreadyMigrated without reading its payload at all.
Future<Database> _openDb() => databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: kSqliteSchemaVersion,
        onCreate: (db, _) => createSchema(db),
        singleInstance: false,
      ),
    );

typedef _Rec = ({
  String id,
  String storedA, // the timestamp string in payload (A), last written by Swift
  String storedB, // the timestamp string in payload (B), last written by Dart
  DateTime instant,
  String duration,
  List<String> feelings,
  bool referral,
  String notes,
  String eventType,
  String severity,
  List<String> triggers,
});

/// Every record a 1.0.2 device could hold, each with the INSTANT it must land
/// on, written independently of any parser.
final List<_Rec> _expected = [
  // Dart, detailed form: naive local with microseconds.
  (
    id: '5f0c1a7e-2b44-4a8e-9d3f-6c1b2a9e7d10',
    storedA: '2026-05-08T19:42:11.482913',
    storedB: '2026-05-08T19:42:11.482913',
    instant: DateTime(2026, 5, 8, 19, 42, 11, 482, 913),
    duration: 'oneToFive',
    feelings: ['😵 Confused', '😰 Anxious'],
    referral: true,
    notes: 'left arm / right leg, called GP',
    eventType: 'seizure',
    severity: 'severe',
    triggers: ['Poor sleep', 'Missed medication'],
  ),
  // Dart: microsecond part 0, so toIso8601String prints milliseconds only.
  (
    id: 'a3d9e2c4-7f10-4b6a-8e21-0c5d4f3b2a19',
    storedA: '2026-05-09T07:05:00.250',
    storedB: '2026-05-09T07:05:00.250',
    instant: DateTime(2026, 5, 9, 7, 5, 0, 250),
    duration: 'lt1',
    feelings: <String>[],
    referral: false,
    notes: 'at school',
    eventType: 'absence',
    severity: 'mild',
    triggers: <String>[],
  ),
  // Dart, Android quick log (notification_service): same writer, same shape.
  (
    id: 'c81f5e0a-4d3b-4c2e-a6f7-9b8e1d2c3a40',
    storedA: '2026-05-12T21:00:03.000001',
    storedB: '2026-05-12T21:00:03.000001',
    instant: DateTime(2026, 5, 12, 21, 0, 3, 0, 1),
    duration: 'lt1',
    feelings: <String>[],
    referral: false,
    notes: 'rescue med',
    eventType: 'medication',
    severity: 'mild',
    triggers: <String>[],
  ),
  // Swift lock-screen start, never ended: uppercase id, fraction-less Z.
  (
    id: 'E621E1F8-C36C-495A-93FC-0C247A3E6E5F',
    storedA: '2026-05-10T23:30:00Z',
    storedB: '2026-05-10T23:30:00.000Z',
    instant: DateTime.utc(2026, 5, 10, 23, 30),
    duration: 'lt1',
    feelings: <String>[],
    referral: false,
    notes: '',
    eventType: 'seizure',
    severity: 'mild',
    triggers: <String>[],
  ),
  // Swift start and Swift end (duration re-bucketed); the UTC date is the day
  // BEFORE the local date, so a dropped zone would also move the day.
  (
    id: '9A1C7B3E-55D2-4F08-B6E4-2C7D9A0B1E33',
    storedA: '2026-05-11T15:59:59Z',
    storedB: '2026-05-11T15:59:59.000Z',
    instant: DateTime.utc(2026, 5, 11, 15, 59, 59),
    duration: 'gt5',
    feelings: <String>[],
    referral: false,
    notes: '',
    eventType: 'seizure',
    severity: 'mild',
    triggers: <String>[],
  ),
  // Swift record re-saved by Dart (".000Z" in BOTH payloads) and then edited.
  (
    id: '3F2B8D10-6A7C-4E91-8B05-D4C3A2F1E077',
    storedA: '2026-05-07T02:14:30.000Z',
    storedB: '2026-05-07T02:14:30.000Z',
    instant: DateTime.utc(2026, 5, 7, 2, 14, 30),
    duration: 'oneToFive',
    feelings: ['🤕 Experiencing a headache'],
    referral: false,
    notes: 'edited after lock-screen log',
    eventType: 'seizure',
    severity: 'moderate',
    triggers: ['Stress'],
  ),
];

Map<String, dynamic> _map(_Rec r, String ts) => <String, dynamic>{
      'id': r.id,
      'timestamp': ts,
      'duration': r.duration,
      'feelings': r.feelings,
      'referralRequired': r.referral,
      'notes': r.notes,
      'eventType': r.eventType,
      'severity': r.severity,
      'triggers': r.triggers,
    };

/// (A) As JSONSerialization writes it: compact, and "/" escaped as "\/".
/// "/" occurs only inside strings in this payload, so the replace is exact.
String _payloadSwift() =>
    jsonEncode([for (final r in _expected) _map(r, r.storedA)]).replaceAll('/', r'\/');

/// (B) As 1.0.2's EventStore.save writes it.
String _payloadDart() => jsonEncode([for (final r in _expected) _map(r, r.storedB)]);

Future<void> _runAndCheck(String label, String raw) async {
  final db = await _openDb();
  final out = await migrateJsonToSqlite(db: db, rawJson: raw);
  // ignore: avoid_print
  print('   [$label] state=${out.state.name} source=${out.sourceEntries} '
      'loadable=${out.loadableCount} inserted=${out.insertedCount} absent=${out.absentCounts}');
  expect(out.state, MigrationState.migrated, reason: '[$label] migration did not verify');
  // ⭐ Survival against the LITERAL list first. The migration's own
  // verification counts with the predicate that decides what to migrate, so it
  // can report `migrated` while records are missing; this cannot.
  expect(out.insertedCount, _expected.length,
      reason: '[$label] ${_expected.length - out.insertedCount} record(s) LOST at migration, '
          'while the migration itself reported ${out.state.name}');

  // No field lost or defaulted: every key a 1.0.2 record carries is present
  // for every record. durationSeconds is the one key 1.0.2 never wrote.
  for (final e in out.absentCounts.entries) {
    if (e.key == 'durationSeconds') {
      expect(e.value, _expected.length, reason: '[$label] durationSeconds should be absent on every 1.0.2 record');
    } else {
      expect(e.value, 0, reason: '[$label] ${e.value} record(s) lost "${e.key}"');
    }
  }

  // Survival and values, read back through the REAL store.
  final loaded = {for (final r in await SqliteEventStore(db).load()) r.id: r};
  expect(loaded.length, _expected.length,
      reason: '[$label] ${_expected.length} records went in, ${loaded.length} came back');
  var checked = 0;
  for (final x in _expected) {
    final r = loaded[x.id];
    expect(r, isNotNull, reason: '[$label] ${x.id} did not survive (stored "${label == 'A' ? x.storedA : x.storedB}")');
    // ignore: avoid_print
    print('   [$label] ${x.id.substring(0, 8)} "${label == 'A' ? x.storedA : x.storedB}" '
        '-> ${r!.timestamp.toUtc().toIso8601String()} (expected ${x.instant.toUtc().toIso8601String()})');
    expect(r.timestamp.isAtSameMomentAs(x.instant), isTrue, reason: '[$label] ${x.id}: instant moved');
    expect(r.duration?.name, x.duration, reason: '[$label] ${x.id}: duration');
    expect(r.feelings, x.feelings, reason: '[$label] ${x.id}: feelings');
    expect(r.triggers, x.triggers, reason: '[$label] ${x.id}: triggers');
    expect(r.notes, x.notes, reason: '[$label] ${x.id}: notes');
    expect(r.referralRequired, x.referral, reason: '[$label] ${x.id}: referral');
    expect(r.eventType, x.eventType, reason: '[$label] ${x.id}: event type');
    expect(r.severity?.name, x.severity, reason: '[$label] ${x.id}: severity');
    // Log time only: the migration must not invent an event time or seconds.
    expect(r.occurredAt, isNull, reason: '[$label] ${x.id}: occurredAt invented');
    expect(r.durationSeconds, isNull, reason: '[$label] ${x.id}: durationSeconds invented');
    checked++;
  }
  // ignore: avoid_print
  print('   [$label] RECORDS CHECKED (unit=records): $checked of ${_expected.length}');
  expect(checked, _expected.length);
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('PRECONDITION: the host is not UTC on the fixture dates', () {
    final offset = DateTime(2026, 5, 10, 12).timeZoneOffset;
    // ignore: avoid_print
    print('   HOST OFFSET on 2026-05-10: $offset');
    expect(offset, isNot(Duration.zero),
        reason: 'on a UTC host a dropped zone cannot be distinguished from a kept one');
  });

  test('PRECONDITION: payload (A) really carries the Swift encoder\'s escaping and the fraction-less Z', () {
    final raw = _payloadSwift();
    expect(raw.contains(r'left arm \/ right leg'), isTrue);
    expect(raw.contains('"2026-05-10T23:30:00Z"'), isTrue);
  });

  test('D1: payload (A), last written by 1.0.2 Swift, migrates every record intact',
      () => _runAndCheck('A', _payloadSwift()));

  test('D2: payload (B), last written by 1.0.2 Dart, migrates every record intact',
      () => _runAndCheck('B', _payloadDart()));
}
