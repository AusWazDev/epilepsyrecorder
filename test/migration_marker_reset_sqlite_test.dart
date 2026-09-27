// Brief 205, test 3.4 (SQLite half) · the user's Reset on a SQLite launch
// clears the marker AND the legacy list together.
//
// The fallback half is `migration_marker_reset_fallback_test.dart`, in its own
// file because both depend on SharedPreferences.

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

  setUp(() async {
    root = await markerRoot();
    SharedPreferences.setMockInitialValues(<String, Object>{
      kEventStorageKey: legacyPayload(),
    });
  });

  tearDown(() => markerTearDown(root));

  test('3.4 SqliteEventStore.clearAll clears the marker and the legacy list',
      () async {
    await StorageBoot.init();
    expect(StorageBoot.isSqlite, isTrue);
    expect(await readMarker(), isNotNull,
        reason: 'CONTROL: the marker must exist before Reset.');
    expect(await readLegacy(), isNotNull,
        reason: 'CONTROL: the legacy list must exist before Reset.');

    await SqliteEventStore(StorageBoot.database!).clearAll();

    expect(await readMarker(), isNull);
    expect(await readLegacy(), isNull);
  }, timeout: const Timeout(Duration(seconds: 45)));
}
