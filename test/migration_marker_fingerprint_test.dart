// Brief 205 · the fingerprint function, and the never-migrated outcomes that
// are decided inside `migrateJsonToSqlite` (test 3.3, function half).
//
// No SharedPreferences here: `writeMarker` is a capturing callback, so every
// test in this file can share the process.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/models/storage_migration.dart';

import 'support/migration_marker_fixture.dart';

Future<Database> openTestDb() async {
  final db = await databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: kSqliteSchemaVersion,
      onCreate: (db, _) => createSchema(db),
    ),
  );
  // inMemoryDatabasePath is ONE database per process; start each test clean.
  await db.delete('event');
  await db.delete('schema_meta');
  return db;
}

void main() {
  sqfliteFfiInit();

  group('legacyPayloadFingerprint', () {
    test('matches the published FNV-1a 32 vectors', () {
      // '' is the offset basis by definition. The other two are recalled
      // FNV-1a test values, NOT re-read from the FNV authors' list, and are
      // trusted because the BigInt reference (plain multiply) agrees. That
      // agreement is what proves the split multiplication exact.
      const vectors = <String, String>{
        '': '811c9dc5',
        'a': 'e40c292c',
        // ⚠️ First written here from memory as bfd0e9ae, which is wrong, and
        // this test failed on it. bf9cf968 is what BOTH the production hash
        // and the BigInt reference produce.
        'foobar': 'bf9cf968',
      };
      vectors.forEach((input, expected) {
        expect(legacyPayloadFingerprint(input).fnv1a32, expected,
            reason: 'production hash of "$input"');
        expect(referenceFnv1a32(utf8.encode(input)), expected,
            reason: 'reference hash of "$input"');
      });
    });

    test('counts UTF-8 bytes, not characters, and treats null as empty', () {
      expect(legacyPayloadFingerprint('é').bytes, 2);
      expect(legacyPayloadFingerprint(null).bytes, 0);
      expect(legacyPayloadFingerprint(null).fnv1a32, '811c9dc5');
    });

    test('agrees with the reference over a real payload', () {
      final raw = legacyPayload();
      expect(legacyPayloadFingerprint(raw).fnv1a32,
          referenceFnv1a32(utf8.encode(raw)));
    });
  });

  group('3.3 never-migrated outcomes write no marker', () {
    test('failed verification', () async {
      final db = await openTestDb();
      final written = <String>[];
      final out = await migrateJsonToSqlite(
        db: db,
        rawJson: legacyPayload(),
        dropForNegativeControl: 1,
        writeMarker: (m) async => written.add(m),
      );
      expect(out.state, MigrationState.failedVerification,
          reason: 'CONTROL: verification must actually have failed.');
      expect(written, isEmpty);
      await db.close();
    }, timeout: const Timeout(Duration(seconds: 45)));

    test('a conversion that throws', () async {
      final db = await openTestDb();
      final written = <String>[];
      final out = await migrateJsonToSqlite(
        db: db,
        rawJson: '{not json',
        writeMarker: (m) async => written.add(m),
      );
      expect(out.state, MigrationState.error,
          reason: 'CONTROL: the conversion must actually have thrown.');
      expect(written, isEmpty);
      await db.close();
    }, timeout: const Timeout(Duration(seconds: 45)));

    test('CONTROL: the same fixture, verified, DOES write one', () async {
      // Without this, the two above would pass against a writeMarker that
      // is never called at all.
      final db = await openTestDb();
      final written = <String>[];
      final out = await migrateJsonToSqlite(
        db: db,
        rawJson: legacyPayload(),
        writeMarker: (m) async => written.add(m),
      );
      expect(out.state, MigrationState.migrated);
      expect(written, hasLength(1));
      await db.close();
    }, timeout: const Timeout(Duration(seconds: 45)));

    test('a throwing marker write does not change the outcome', () async {
      final db = await openTestDb();
      final out = await migrateJsonToSqlite(
        db: db,
        rawJson: legacyPayload(),
        writeMarker: (_) async => throw StateError('prefs unavailable'),
      );
      expect(out.state, MigrationState.migrated);
      expect(await getMeta(db, kMetaMigrationState), 'migrated');
      await db.close();
    }, timeout: const Timeout(Duration(seconds: 45)));
  });
}
