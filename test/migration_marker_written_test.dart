// Brief 205, test 3.1 · a migration that verifies writes the marker, and the
// marker's fingerprint is the fingerprint of the payload that was migrated.
//
// ⭐ DRIVES THE REAL CALL SITE. `StorageBoot.init()` is what supplies
// `writeMarker`, so a test of `migrateJsonToSqlite` alone would pass with the
// call site unwired.
//
// ⭐ THE FINGERPRINT IS CHECKED AGAINST AN INDEPENDENT IMPLEMENTATION
// (`referenceFnv1a32`), not against `legacyPayloadFingerprint`, so a broken
// hash cannot agree with itself.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';

import 'support/migration_marker_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory root;
  late String raw;

  setUp(() async {
    root = await markerRoot();
    raw = legacyPayload();
    SharedPreferences.setMockInitialValues(<String, Object>{
      kEventStorageKey: raw,
    });
  });

  tearDown(() => markerTearDown(root));

  test('3.1 a verified migration writes the marker, fingerprinting the payload',
      () async {
    expect(await readMarker(), isNull,
        reason: 'CONTROL: a pre-migration device must start with no marker.');

    await StorageBoot.init();

    expect(StorageBoot.isSqlite, isTrue,
        reason: 'the launch must have run on SQLite, or nothing migrated.');
    expect(await getMeta(StorageBoot.database!, kMetaMigrationState),
        'migrated');

    final marker = await readMarker();
    expect(marker, isNotNull,
        reason: 'a verified migration must leave the marker behind.');
    final m = jsonDecode(marker!) as Map<String, dynamic>;
    final bytes = utf8.encode(raw);
    expect(m['v'], 1);
    expect(m['payloadBytes'], bytes.length,
        reason: 'payloadBytes must be the UTF-8 byte length of the payload.');
    expect(m['fnv1a32'], referenceFnv1a32(bytes),
        reason: 'fnv1a32 must be FNV-1a 32 over the payload bytes.');
    expect(DateTime.tryParse(m['migratedAt'] as String), isNotNull);

    // The legacy list is NOT cleared by writing the marker (D5).
    expect(await readLegacy(), raw);
  }, timeout: const Timeout(Duration(seconds: 45)));
}
