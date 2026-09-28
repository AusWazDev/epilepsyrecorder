// Brief 215, 28 September 2026: the device-transfer rebuild, stood up for real.
//
// ⭐ THE RESTORED STATE IS PRODUCED, NOT DESCRIBED. [firstLife] boots a
// pre-migration device through the real `StorageBoot.init()`, lets it migrate,
// then does ordinary SQLite-era work through the real store: a new record, an
// edit, a hide, and a second record under an id that already exists. [transfer]
// then does what an iOS restore does to this app under `10c2f7c`: the standard
// UserDefaults plist travels (prefs are left exactly as the first life left
// them), and Application Support (the database and the pre-migration backup)
// does not. The App Group container is also excluded, and this app on Windows
// has none, so it has nothing to drop.
//
// ⚠️ `10c2f7c` is written from Apple's documentation and is UNCOMPILED and
// UNVERIFIED on a device. This fixture models what it is meant to do.

import 'dart:convert';
import 'dart:io';

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';

class TransferDirs extends PathProviderPlatform with MockPlatformInterfaceMixin {
  TransferDirs(this.root);
  final String root;
  String get support => '$root/support';
  @override
  Future<String?> getApplicationSupportPath() async => support;
  @override
  Future<String?> getApplicationDocumentsPath() async => '$root/documents';
  @override
  Future<String?> getTemporaryPath() async => '$root/tmp';
  @override
  Future<String?> getLibraryPath() async => support;
}

EventRecord tRec(String id, int day, {String? notes, bool hidden = false}) =>
    EventRecord(
      id: id,
      timestamp: DateTime(2026, 9, day, 10),
      duration: DurationCategory.lt1,
      durationSeconds: 40,
      eventType: 'seizure',
      severity: EventSeverity.mild,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: false,
      notes: notes ?? 'note $id',
      detailsCompleted: true,
      hidden: hidden,
    );

/// The legacy list as it stood when the device first migrated.
/// ⚠️ Carries non-ASCII, because the fingerprint covers bytes.
final List<EventRecord> kAtMigration = <EventRecord>[
  tRec('alpha', 1, notes: 'café alpha'),
  tRec('bravo', 2),
  tRec('charlie', 3),
  tRec('pair', 4, notes: 'pair, first copy'),
];

/// Sets up prefs, directories and the factory seam. Call from `setUp`.
Future<Directory> prepareDevice() async {
  final root = await Directory.systemTemp.createTemp('mer_b215_');
  await Directory('${root.path}/support').create();
  await Directory('${root.path}/documents').create();
  await Directory('${root.path}/tmp').create();
  PathProviderPlatform.instance = TransferDirs(root.path);
  StorageBoot.debugDatabaseFactory = databaseFactoryFfi;
  SharedPreferences.setMockInitialValues(<String, Object>{
    kEventStorageKey: jsonEncode(kAtMigration.map((r) => r.toMap()).toList()),
  });
  return root;
}

Future<void> tearDownDevice(Directory root) async {
  await StorageBoot.database?.close();
  StorageBoot.debugSet();
  StorageBoot.debugDatabaseFactory = null;
  Vocabularies.debugReset();
  try {
    if (await root.exists()) await root.delete(recursive: true);
  } catch (_) {}
}

/// Boot, migrate, then live on SQLite for a while. Returns the records as the
/// device held them just before the transfer.
Future<List<EventRecord>> firstLife() async {
  final outcome = await StorageBoot.init();
  if (!StorageBoot.isSqlite) {
    throw StateError('first life must run on SQLite; outcome=$outcome');
  }
  final loaded = await StorageBoot.store.load();
  final after = <EventRecord>[
    for (final r in loaded)
      if (r.id == 'bravo')
        tRec('bravo', 2, notes: 'bravo EDITED after migration')
      else if (r.id == 'charlie')
        r.withHidden(true, at: DateTime(2026, 9, 20))
      else
        r,
    tRec('delta', 21, notes: 'delta, recorded after migration'),
    // A second record under an id the device already holds (§13(bk), §13(br):
    // event.id is deliberately non-unique).
    tRec('pair', 22, notes: 'pair, SECOND copy, after migration'),
  ];
  await StorageBoot.store.save(after);
  return StorageBoot.store.load();
}

/// What the transfer does: prefs travel, Application Support does not.
/// [keepDatabase] is the CONTROL: a device whose database survived.
Future<void> transfer(Directory root, {bool keepDatabase = false}) async {
  await StorageBoot.database?.close();
  StorageBoot.debugSet();
  Vocabularies.debugReset();
  if (keepDatabase) return;
  final support = Directory('${root.path}/support');
  await support.delete(recursive: true);
  await support.create();
}
