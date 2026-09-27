// Brief 205, test 3.2 · a payload appended to after migration no longer
// matches the marker's fingerprint.
//
// The append is made by the REAL fallback writer, `EventStore.save`, which is
// what a shared_preferences launch does to the legacy list. The match is
// asserted BEFORE the append too, so the mismatch afterwards is attributable
// to the append and not to a marker that never matched.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/storage_migration.dart';

import 'support/migration_marker_fixture.dart';

bool matches(String marker, String? payload) {
  final m = jsonDecode(marker) as Map<String, dynamic>;
  final fp = legacyPayloadFingerprint(payload);
  return m['payloadBytes'] == fp.bytes && m['fnv1a32'] == fp.fnv1a32;
}

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

  test('3.2 an append after migration no longer matches the marker', () async {
    await StorageBoot.init();
    final marker = await readMarker();
    expect(marker, isNotNull, reason: 'CONTROL: migration wrote a marker.');

    final before = await readLegacy();
    expect(matches(marker!, before), isTrue,
        reason: 'CONTROL: before the append, the payload must MATCH the '
            'marker, or the mismatch below proves nothing.');

    // A fallback launch's save: the existing records plus one new one.
    await EventStore().save(
        [markerRec('alpha', 1), markerRec('beta', 2), markerRec('gamma', 3)]);

    final after = await readLegacy();
    expect(after, isNot(before), reason: 'CONTROL: the save must have landed.');
    expect(matches(marker, after), isFalse,
        reason: 'an appended payload must not match the migrated fingerprint.');
    expect(await readMarker(), marker,
        reason: 'the fallback writer must not touch the marker.');
  }, timeout: const Timeout(Duration(seconds: 45)));
}
