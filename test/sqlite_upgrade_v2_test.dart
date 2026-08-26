import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';

/// The v1 to v2 schema upgrade, run against a database built the way the
/// device's actually was.
///
/// This is not a hypothetical path. The tablet holds a phase-one database at
/// version 1 with real records in it, and the next launch after this build
/// installs runs `upgradeSchema` over them. An additive ALTER TABLE is about as
/// safe as a schema change gets, and it is still the first migration this app
/// has run over data it did not itself create in the same session.
///
/// So the v1 table is reconstructed from the ACTUAL phase-one DDL - column for
/// column, minus the one column v2 adds - rather than from a convenient
/// approximation. An approximation would prove the upgrade works on a table
/// that does not exist anywhere.

/// The phase-one `event` table, verbatim, less `details_completed`.
const String createEventSqlV1 = 'CREATE TABLE event ('
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
    'referral_required INTEGER)';

Future<List<String>> columnsOf(Database db) async {
  final info = await db.rawQuery('PRAGMA table_info(event)');
  return info.map((r) => r['name'] as String).toList();
}

void main() {
  late Directory tmp;
  var seq = 0;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('mer_upgrade_');
  });

  tearDown(() async {
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  // A REAL FILE, not `inMemoryDatabasePath`. An in-memory database is discarded
  // on close, so the "reopen at v2" would silently open a fresh EMPTY database
  // through onCreate and never run the upgrade at all - and every assertion
  // would then be about a table the migration never touched. The first run of
  // this file did exactly that, and failed loudly only because test 3 read rows
  // that were not there.
  String nextPath() => '${tmp.path}/mer_${seq++}.db';

  /// Builds a v1 database holding [n] rows, then reopens it at v2 through the
  /// SAME `onUpgrade` the app wires up.
  Future<Database> openV1ThenUpgrade(String path, {int rows = 3}) async {
    final v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(createSchemaMetaSql);
          await db.execute(createEventSqlV1);
          await db.execute(createEventIdIndexSql);
          await db.execute(createEventLoggedAtIndexSql);
          await putMeta(db, kMetaSchemaVersion, '1');
          await putMeta(db, kMetaMigrationState, 'migrated');
        },
      ),
    );

    for (var i = 0; i < rows; i++) {
      await v1.insert('event', <String, Object?>{
        'ordinal': i,
        'id': 'rec-$i',
        'logged_at': DateTime(2026, 8, 20, 9, i).toIso8601String(),
        'occurred_at': null,
        // Row 0 legacy bucket, row 1 measured, row 2 unknown - the three
        // duration states the device actually holds.
        'duration_bucket': i == 0 ? 'oneToFive' : null,
        'duration_seconds': i == 1 ? 187 : null,
        'event_type': 'seizure',
        'severity': 0,
        'feelings_json': null,
        'triggers_json': null,
        'notes': 'row $i',
        'referral_required': 0,
      });
    }
    await v1.close();

    return databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: kSqliteSchemaVersion,
        onCreate: (db, _) => createSchema(db),
        onUpgrade: upgradeSchema,
      ),
    );
  }

  test('1. the column is added and every existing row reads NULL', () async {
    final db = await openV1ThenUpgrade(nextPath());

    expect(await columnsOf(db), contains('details_completed'));

    final rows = await db.query('event', orderBy: 'ordinal');
    expect(rows.length, 3, reason: 'no row lost by the ALTER');
    for (final r in rows) {
      expect(r['details_completed'], isNull,
          reason: 'NULL is the honest answer for a record that predates the '
              'wizard - not 0, which would claim it is a partial and route it '
              'into a guided flow that does not describe it');
    }

    await db.close();
  });

  test('2. NEGATIVE CONTROL: the v1 table genuinely lacks the column', () async {
    // Without this, test 1 passes just as well if the fixture had been built
    // at v2 all along and no upgrade ever ran.
    final db = await databaseFactoryFfi.openDatabase(
      nextPath(),
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(createSchemaMetaSql);
          await db.execute(createEventSqlV1);
        },
      ),
    );

    expect(await columnsOf(db), isNot(contains('details_completed')));
    await db.close();
  });

  test('3. every other column survives the upgrade unchanged', () async {
    final db = await openV1ThenUpgrade(nextPath());

    final records = await SqliteEventStore(db).load();
    expect(records.length, 3);

    final byId = {for (final r in records) r.id: r};

    // The legacy bucket is still a bucket, and still has no number.
    expect(byId['rec-0']!.duration, DurationCategory.oneToFive);
    expect(byId['rec-0']!.durationSeconds, isNull,
        reason: 'a schema upgrade must not invent a number from a range');

    // The measured row is still measured.
    expect(byId['rec-1']!.durationSeconds, 187);
    expect(byId['rec-1']!.duration, isNull);

    // The unknown row is still unknown.
    expect(byId['rec-2']!.duration, isNull);
    expect(byId['rec-2']!.durationSeconds, isNull);

    for (var i = 0; i < 3; i++) {
      expect(byId['rec-$i']!.notes, 'row $i');
      expect(byId['rec-$i']!.detailsCompleted, isNull);
    }

    await db.close();
  });

  test('4. the recorded schema version advances to 2', () async {
    final db = await openV1ThenUpgrade(nextPath());
    expect(await getMeta(db, kMetaSchemaVersion), '2');
    // The phase-one migration marker is untouched: this is a schema change,
    // not a re-migration, and clearing it would re-run the JSON conversion.
    expect(await getMeta(db, kMetaMigrationState), 'migrated');
    await db.close();
  });

  test('5. a record written AFTER the upgrade round-trips all three states',
      () async {
    final db = await openV1ThenUpgrade(nextPath());
    final store = SqliteEventStore(db);

    final existing = await store.load();
    EventRecord marked(EventRecord r, bool? c) => EventRecord(
          id: r.id,
          timestamp: r.timestamp,
          duration: r.duration,
          durationSeconds: r.durationSeconds,
          feelings: r.feelings,
          triggers: r.triggers,
          referralRequired: r.referralRequired,
          notes: r.notes,
          eventType: r.eventType,
          severity: r.severity,
          detailsCompleted: c,
        );

    await store.save([
      marked(existing[0], true),
      marked(existing[1], false),
      marked(existing[2], null),
    ]);

    final back = await store.load();
    final states = back.map((r) => r.detailsCompleted).toList();

    expect(states, containsAll(<bool?>[true, false, null]),
        reason: 'all three states survive the upgraded column - a column '
            'written as `== 1` would fold NULL into false');

    await db.close();
  });
}
