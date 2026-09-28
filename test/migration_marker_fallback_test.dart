// Brief 205, test 3.3 (boot half) · a launch that never migrates leaves no
// marker.
//
// The support path is a regular FILE, so `openDatabase` beneath it fails and
// `StorageBoot.init()` falls back to shared_preferences. That is the device
// the marker must not be written on: nothing was migrated.
//
// The other two never-migrated outcomes, failed verification and a conversion
// that throws, are decided inside `migrateJsonToSqlite` and are pinned in
// `migration_marker_fingerprint_test.dart`.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';

import 'support/migration_marker_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory root;
  late String raw;

  setUp(() async {
    root = await markerRoot(supportIsFile: true);
    raw = legacyPayload();
    SharedPreferences.setMockInitialValues(<String, Object>{
      kEventStorageKey: raw,
    });
  });

  tearDown(() => markerTearDown(root));

  test('3.3 a fallback launch writes no marker', () async {
    await StorageBoot.init();

    expect(StorageBoot.isSqlite, isFalse,
        reason: 'CONTROL: this launch must have FALLEN BACK, or it tests '
            'the migrated path instead.');
    // ⛔ WHICH fallback, not merely that one happened. Added 28 September 2026
    // (Brief 211). Until then this test passed on a macOS host for the WRONG
    // reason: `init()` fell back from a MissingPluginException before the
    // support path was ever opened, so the file below was never the cause.
    // Both fallbacks leave `isSqlite` false and no marker, so only the error
    // tells them apart: the file path fails the OPEN, as a DatabaseException.
    expect(
        StorageBoot.outcome?.error,
        isA<DatabaseException>().having(
            (e) => e.isOpenFailedError(), 'isOpenFailedError()', isTrue),
        reason: 'CONTROL: the fallback must come from opening the database '
            'beneath a support path that is a FILE, not from any other '
            'failure, such as a missing sqflite plugin.');
    expect(await readMarker(), isNull,
        reason: 'a launch that did not migrate must not claim it did.');
    expect(await readLegacy(), raw);
  }, timeout: const Timeout(Duration(seconds: 45)));
}
