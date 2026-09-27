// Brief 205, test 3.4 (fallback half) · the Reset a shared_preferences launch
// runs, `EventStore.clearAll`, clears the marker AND the legacy list together.
//
// ⚠️ It leaves the SQLite database alone, by design: that store is not open on
// a fallback launch. So a device reset this way ends up migrated with no
// marker. That is recorded in the Brief 205 report and is not changed here.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_record.dart';
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

  test('3.4 EventStore.clearAll clears the marker and the legacy list',
      () async {
    await StorageBoot.init();
    expect(await readMarker(), isNotNull,
        reason: 'CONTROL: the marker must exist before Reset.');
    expect(await readLegacy(), isNotNull,
        reason: 'CONTROL: the legacy list must exist before Reset.');

    await EventStore().clearAll();

    expect(await readMarker(), isNull);
    expect(await readLegacy(), isNull);
  }, timeout: const Timeout(Duration(seconds: 45)));
}
