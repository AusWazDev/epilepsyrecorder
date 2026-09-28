// Brief 215 §1 and §2.1: a device restored from an iOS backup rebuilds its
// history from the frozen legacy list, silently.
//
// ⚠️ ONE prefs-dependent test per file. The CONTROL for this file is run by
// setting `kKeepDatabase` to true: "the database survived the transfer".

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/storage_migration.dart';

import 'support/transfer_fixture.dart';

const bool kKeepDatabase = false;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late dynamic root;
  setUp(() async => root = await prepareDevice());
  tearDown(() async => tearDownDevice(root));

  test('restored device: history rebuilt from the frozen list, no signal', () async {
    print('[b215] first life');
    final before = await firstLife();
    final beforeIds = before.map((r) => r.id).toList()..sort();
    expect(beforeIds, <String>['alpha', 'bravo', 'charlie', 'delta', 'pair', 'pair'],
        reason: 'CONTROL: the first life holds the post-migration work');

    print('[b215] transfer');
    await transfer(root, keepDatabase: kKeepDatabase);

    // §2.1 — the marker, read BEFORE boot, because boot's migration rewrites it.
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kEventStorageKey);
    final markerRaw = prefs.getString(kLegacyMigrationMarkerKey);
    expect(markerRaw, isNotNull,
        reason: 'MARKER: the restored prefs carry the marker from the first life');
    final marker = jsonDecode(markerRaw!) as Map<String, Object?>;
    final fp = legacyPayloadFingerprint(raw);
    print('[b215] marker=$markerRaw payloadBytes=${fp.bytes} fnv=${fp.fnv1a32}');
    expect(marker['payloadBytes'] == fp.bytes && marker['fnv1a32'] == fp.fnv1a32,
        isTrue,
        reason: 'MARKER: its fingerprint matches the legacy payload boot is about '
            'to migrate, i.e. a frozen snapshot');

    print('[b215] second boot');
    final outcome = await StorageBoot.init();
    final after = await StorageBoot.store.load();
    final afterIds = after.map((r) => r.id).toList()..sort();
    final days = after.map((r) => r.whenHappened).toList()..sort();
    print('[b215] outcome=${outcome.state} isSqlite=${StorageBoot.isSqlite} '
        'count=${after.length} range=${days.first}..${days.last} '
        'banner=${!outcome.succeeded}');

    // §1.2 — WHAT THE LIST CONTAINS.
    expect(afterIds, <String>['alpha', 'bravo', 'charlie', 'pair'],
        reason: 'REBUILD: after the transfer the history is exactly the list as '
            'it stood at migration; everything since is gone');
    expect(after.firstWhere((r) => r.id == 'bravo').notes, 'note bravo',
        reason: 'REBUILD: the post-migration edit is undone');
    expect(after.firstWhere((r) => r.id == 'charlie').hidden, isFalse,
        reason: 'REBUILD: the post-migration hide is undone');
    expect(after.where((r) => r.id == 'pair').single.notes, 'pair, first copy',
        reason: 'REBUILD: the second record under a shared id is gone');

    // §1.4 — WHAT THE USER IS TOLD. Home's banner shows iff !outcome.succeeded.
    expect(outcome.state, MigrationState.migrated,
        reason: 'SIGNAL: boot reports an ordinary first migration');
    expect(outcome.succeeded, isTrue,
        reason: 'SIGNAL: so the storage-fallback banner does not show');

    final markerAfter = prefs.getString(kLegacyMigrationMarkerKey);
    print('[b215] marker after boot=$markerAfter');
  }, timeout: const Timeout(Duration(seconds: 90)));
}
