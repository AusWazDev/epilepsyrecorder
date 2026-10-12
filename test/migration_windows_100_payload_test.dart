// Brief 340 Part B4 — does a Windows install of the live Store package keep
// its records when 1.1.1 opens over it?
//
// THE LIVE PACKAGE. Microsoft Store Submission 2, MSIX 1.0.0.0, x64. The MSIX
// version is hardcoded in msix_config and stayed 1.0.0.0 from a84f00e to
// 2828faa, so it does not name the app version. STATUS.md records the MSIX
// "built and submitted" in the 26 April 2026 evening Windows session; the
// candidate commits are b289a26 to fc0c7da, all pubspec `version: 1.0.0+1`,
// and all with the same storage code. 8801097 is used here as the proxy.
//
// WHAT THAT BUILD WRITES ON WINDOWS (8801097, located in the code):
//   * lib/models/event_record.dart EventStore.save: SharedPreferences key
//     `epilepsy_event_records_v1`, a JSON string of the whole list, each
//     record from EventRecord.toMap. No SQLite; sqflite is not a dependency.
//   * lib/screens/disclaimer_screen.dart: `disclaimerAcceptedVersion` = '1.0'.
//   * NotificationService.init returns on Windows, so no other writer runs.
//   * shared_preferences_windows 2.4.1 stores the map, keys prefixed
//     `flutter.`, as `shared_preferences.json` in path_provider_windows'
//     getApplicationSupportPath: RoamingAppData\<CompanyName>\<ProductName>
//     from the exe's VERSIONINFO, which Runner.rc sets to
//     `au.com.bedlin\epilepsyrecorder` and has not changed since c7fc127.
//
// WHAT 1.1.1 DOES WITH IT (HEAD): StorageBoot.init opens mer_events.db in
// getApplicationSupportDirectory() through sqflite_common_ffi (the production
// gate picks FFI on Windows), reads `kEventStorageKey` from SharedPreferences
// (same key, same plugin version, same directory) and migrates.
//
// ⭐ THE REAL PLUGIN READS THE REAL FILE. SharedPreferencesWindows is pointed at
// a temp directory through its public `pathProvider` field, so the JSON file is
// parsed by the plugin 1.1.1 ships, not by a mock map.
//
// ⛔ THE POPULATION IS THE LITERAL LIST BELOW, NEVER THE MIGRATION'S OWN PARSE
// (the Brief 197 finding, as in migration_102_payload_test.dart).
//
// ⚠️ SYNTHETIC FIXTURE, constructed from the 8801097 writers. It is not a
// capture from a real Windows install and must not be cited as one. What it
// cannot model: MSIX file-system redirection of AppData, and the Store's
// handling of package data across an update. Both are OS behaviour, outside
// this repo.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_windows/path_provider_windows.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_windows/shared_preferences_windows.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';

/// path_provider for StorageBoot (getApplicationSupportDirectory).
class _Provider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _Provider(this.support, this.temp);
  final String support;
  final String temp;
  @override
  Future<String?> getApplicationSupportPath() async => support;
  @override
  Future<String?> getApplicationDocumentsPath() async => temp;
  @override
  Future<String?> getTemporaryPath() async => temp;
}

/// The same directory, for the real Windows prefs plugin, which calls
/// PathProviderWindows directly rather than the platform instance.
class _WinProvider extends PathProviderWindows {
  _WinProvider(this.support);
  final String support;
  @override
  Future<String?> getApplicationSupportPath() async => support;
}

typedef _Rec = ({
  String id,
  String stored,
  DateTime instant,
  String duration,
  List<String> feelings,
  bool referral,
  String notes,
  String eventType,
  String severity,
  List<String> triggers,
});

/// Every shape the 8801097 Windows writer produces. Timestamps come only from
/// `DateTime.now()` (log_event_screen: `widget.existing?.timestamp ??
/// DateTime.now()`), so they are naive local `toIso8601String()` output.
final List<_Rec> _expected = [
  // Microseconds present: the usual form.
  (
    id: '0b7e3c1a-5d2f-4a8e-9c61-2f4e8a1b7d30',
    stored: '2026-05-02T08:14:37.519204',
    instant: DateTime(2026, 5, 2, 8, 14, 37, 519, 204),
    duration: 'oneToFive',
    feelings: ['😴 Tired and weary', '😵 Confused'],
    referral: true,
    notes: 'left side / jerking, "called GP"',
    eventType: 'seizure',
    severity: 'severe',
    triggers: ['Poor sleep', 'Missed medication'],
  ),
  // Microsecond part 0: milliseconds only.
  (
    id: '6a2d9f40-1c3b-4e7a-b852-90d1c4e3f6a7',
    stored: '2026-06-14T21:03:09.250',
    instant: DateTime(2026, 6, 14, 21, 3, 9, 250),
    duration: 'lt1',
    feelings: <String>[],
    referral: false,
    notes: '',
    eventType: 'absence',
    severity: 'mild',
    triggers: <String>[],
  ),
  // Both parts 0: ".000".
  (
    id: 'd4f1a8b2-7e6c-4b09-a3d5-1e2f3a4b5c6d',
    stored: '2026-07-01T06:30:00.000',
    instant: DateTime(2026, 7, 1, 6, 30),
    duration: 'lt1',
    feelings: <String>[],
    referral: false,
    notes: 'morning dose',
    eventType: 'medication',
    severity: 'mild',
    triggers: <String>[],
  ),
  // The fourth event type, every feeling and every trigger, a multi-line note.
  (
    id: 'f9e8d7c6-b5a4-4321-8fed-cba987654321',
    stored: '2026-08-20T23:59:59.999999',
    instant: DateTime(2026, 8, 20, 23, 59, 59, 999, 999),
    duration: 'gt5',
    feelings: [
      '😴 Tired and weary', '😪 Just tired', '😩 Just weary',
      '🤕 Experiencing a headache', '😢 Sad', '😵 Confused', '😠 Annoyed',
      '😡 Angry', '😰 Anxious', '🤢 Nauseous', '😣 In pain',
    ],
    referral: false,
    notes: 'line one\nline two, ünïcode, tab\there',
    eventType: 'other',
    severity: 'moderate',
    triggers: [
      'Stress', 'Poor sleep', 'Missed medication', 'Alcohol',
      'Flashing lights', 'Illness', 'Unknown',
    ],
  ),
];

/// 8801097 EventRecord.toMap, key for key.
Map<String, dynamic> _map(_Rec r) => <String, dynamic>{
      'id': r.id,
      'timestamp': r.stored,
      'duration': r.duration,
      'feelings': r.feelings,
      'referralRequired': r.referral,
      'notes': r.notes,
      'eventType': r.eventType,
      'severity': r.severity,
      'triggers': r.triggers,
    };

/// The file as shared_preferences_windows 2.4.1 `_writePreferences` leaves it:
/// `json.encode` of the whole map, keys carrying the `flutter.` prefix.
String _prefsFile() => json.encode(<String, Object>{
      'flutter.epilepsy_event_records_v1':
          jsonEncode([for (final r in _expected) _map(r)]),
      'flutter.disclaimerAcceptedVersion': '1.0',
    });

/// Every way the store can disagree with the literal list. Empty means every
/// record survived with every field. Returned, not asserted, so the controls
/// below can show it reporting a loss.
Future<List<String>> _losses(EventStore store) async {
  final out = <String>[];
  final loaded = {for (final r in await store.load()) r.id: r};
  if (loaded.length != _expected.length) {
    out.add('${_expected.length} records went in, ${loaded.length} came back');
  }
  for (final x in _expected) {
    final r = loaded[x.id];
    if (r == null) {
      out.add('${x.id}: LOST');
      continue;
    }
    void chk(String f, Object? got, Object? want) {
      if (jsonEncode(got) != jsonEncode(want)) out.add('${x.id}: $f $got != $want');
    }
    if (!r.timestamp.isAtSameMomentAs(x.instant)) {
      out.add('${x.id}: instant ${r.timestamp} != ${x.instant}');
    }
    chk('duration', r.duration?.name, x.duration);
    chk('feelings', r.feelings, x.feelings);
    chk('triggers', r.triggers, x.triggers);
    chk('notes', r.notes, x.notes);
    chk('referral', r.referralRequired, x.referral);
    chk('eventType', r.eventType, x.eventType);
    chk('severity', r.severity?.name, x.severity);
    // Log time only: the migration must not invent an event time or seconds.
    chk('occurredAt', r.occurredAt, null);
    chk('durationSeconds', r.durationSeconds, null);
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory root;
  late Directory support;
  late Directory temp;

  /// Boots 1.1.1 with SharedPreferences backed by the real Windows plugin
  /// reading [prefsDir], and path_provider's support directory at [support].
  Future<void> boot(Directory prefsDir) async {
    SharedPreferences.resetStatic();
    SharedPreferencesStorePlatform.instance = SharedPreferencesWindows()
      ..pathProvider = _WinProvider(prefsDir.path);
    PathProviderPlatform.instance = _Provider(support.path, temp.path);
    StorageBoot.debugSet();
    await StorageBoot.init();
  }

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mer_b340_');
    support = await Directory('${root.path}/au.com.bedlin/epilepsyrecorder')
        .create(recursive: true);
    temp = await Directory('${root.path}/tmp').create();
    // The production gate picks this same factory on Windows (storage_boot
    // configureDatabaseFactory); set explicitly so a non-Windows host runs it.
    StorageBoot.debugDatabaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await StorageBoot.database?.close();
    StorageBoot.debugSet();
    StorageBoot.debugDatabaseFactory = null;
    SharedPreferences.resetStatic();
    try {
      if (await root.exists()) await root.delete(recursive: true);
    } catch (_) {
      // Cleanup must not mask the assertion result above it.
    }
  });

  test('PRECONDITION: the host is not UTC on the fixture dates', () {
    final offset = DateTime(2026, 6, 14, 12).timeZoneOffset;
    // ignore: avoid_print
    print('   HOST OFFSET on 2026-06-14: $offset');
    expect(offset, isNot(Duration.zero),
        reason: 'on a UTC host a dropped zone cannot be distinguished from a kept one');
  });

  test('B4: a live-package Windows prefs file migrates every record intact, '
      'and survives a relaunch', () async {
    final file = File('${support.path}/shared_preferences.json');
    await file.writeAsString(_prefsFile());

    await boot(support);
    final out = StorageBoot.outcome!;
    // ignore: avoid_print
    print('   state=${out.state.name} source=${out.sourceEntries} '
        'loadable=${out.loadableCount} inserted=${out.insertedCount} '
        'absent=${out.absentCounts} error=${out.error}');
    expect(out.state.name, 'migrated', reason: 'first 1.1.1 launch must migrate');
    expect(StorageBoot.isSqlite, isTrue, reason: 'first launch fell back');
    expect(out.sourceEntries, _expected.length);

    final first = await _losses(StorageBoot.store);
    // ignore: avoid_print
    print('   RECORDS CHECKED (unit=records): ${_expected.length}; losses: $first');
    expect(first, isEmpty);

    // The database sits beside the prefs file, and so does the backup.
    final names = support.listSync().map((e) => e.uri.pathSegments.last).toList();
    // ignore: avoid_print
    print('   support dir after boot: $names');
    expect(names, contains('mer_events.db'));
    expect(names.where((n) => n.startsWith('mer_pre_sqlite_backup_')), hasLength(1));

    // D5: the legacy payload is never cleared, and the disclaimer key stays.
    final onDisk = json.decode(await file.readAsString()) as Map<String, dynamic>;
    expect(onDisk['flutter.epilepsy_event_records_v1'],
        jsonEncode([for (final r in _expected) _map(r)]),
        reason: 'the legacy payload on disk changed');
    expect(onDisk['flutter.disclaimerAcceptedVersion'], '1.0');

    // Relaunch: no re-migration, no duplicates, nothing lost.
    await StorageBoot.database?.close();
    await boot(support);
    expect(StorageBoot.outcome!.state.name, 'alreadyMigrated');
    expect(await _losses(StorageBoot.store), isEmpty);
  });

  // ── CONTROLS. Each violates the behaviour under test, "every record in the
  // live package's file reaches 1.1.1's store", and must be REPORTED by
  // _losses. A control that stays silent is a bad control, not a pass.

  test('CONTROL 1: one record removed from the store after migration is '
      'reported as LOST', () async {
    await File('${support.path}/shared_preferences.json').writeAsString(_prefsFile());
    await boot(support);
    expect(StorageBoot.isSqlite, isTrue);
    final victim = _expected[1].id;
    final n = await StorageBoot.database!.delete('event', where: 'id = ?', whereArgs: [victim]);
    expect(n, 1, reason: 'CONTROL did not remove a row, so it violates nothing');
    final got = await _losses(SqliteEventStore(StorageBoot.database!));
    // ignore: avoid_print
    print('   CONTROL 1 losses: $got');
    expect(got, contains('$victim: LOST'));
  });

  test('CONTROL 2: 1.1.1 reading prefs from a different folder than the live '
      'package wrote reports every record LOST', () async {
    // The live package's file is in an OTHER directory, as it would be if the
    // RoamingAppData subfolder (Runner.rc CompanyName/ProductName) changed.
    final other = await Directory('${root.path}/other/epilepsyrecorder')
        .create(recursive: true);
    await File('${other.path}/shared_preferences.json').writeAsString(_prefsFile());
    await boot(support);
    final got = await _losses(StorageBoot.store);
    // ignore: avoid_print
    print('   CONTROL 2 state=${StorageBoot.outcome!.state.name} losses: $got');
    for (final x in _expected) {
      expect(got, contains('${x.id}: LOST'));
    }
  });
}
