// Brief 205 · shared fixture for the migration-marker tests.
//
// ⛔ ONE PREFS-DEPENDENT TEST PER FILE. Each marker test lives in its own file
// for the reason in CLAUDE.md ("ONE PREFS-DEPENDENT TEST PER PROCESS"); this
// file holds only what they share, and touches no preferences itself.

import 'dart:convert';
import 'dart:io';

import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';

class MarkerDirProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  MarkerDirProvider(this.support, this.temp);
  final String support;
  final String temp;

  @override
  Future<String?> getApplicationSupportPath() async => support;
  @override
  Future<String?> getApplicationDocumentsPath() async => temp;
  @override
  Future<String?> getTemporaryPath() async => temp;
  @override
  Future<String?> getLibraryPath() async => support;
  @override
  Future<String?> getDownloadsPath() async => temp;
}

EventRecord markerRec(String id, int day) => EventRecord(
      id: id,
      timestamp: DateTime(2026, 9, day),
      duration: DurationCategory.lt1,
      durationSeconds: 40,
      eventType: 'seizure',
      severity: EventSeverity.mild,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: false,
      // Non-ASCII on purpose: the fingerprint is over UTF-8 BYTES, and an
      // ASCII-only payload cannot tell bytes from characters.
      notes: 'Müdigkeit — tired',
      detailsCompleted: true,
    );

/// A pre-migration device's legacy payload.
String legacyPayload() =>
    jsonEncode([markerRec('alpha', 1).toMap(), markerRec('beta', 2).toMap()]);

/// A temp root with a `support` directory the provider points at.
///
/// Pass [supportIsFile] to make the support path a regular FILE, so
/// `openDatabase` beneath it fails and boot takes the fallback path.
Future<Directory> markerRoot({bool supportIsFile = false}) async {
  final root = await Directory.systemTemp.createTemp('mer_b205_');
  final temp = await Directory('${root.path}/tmp').create();
  final supportPath = '${root.path}/support';
  if (supportIsFile) {
    await File(supportPath).writeAsString('not a directory');
  } else {
    await Directory(supportPath).create();
  }
  PathProviderPlatform.instance = MarkerDirProvider(supportPath, temp.path);
  return root;
}

Future<void> markerTearDown(Directory root) async {
  // Windows will not delete a directory holding an open database file.
  await StorageBoot.database?.close();
  StorageBoot.debugSet();
  try {
    if (await root.exists()) await root.delete(recursive: true);
  } catch (_) {
    // A temp directory that will not delete must not mask the result above.
  }
}

/// An INDEPENDENT FNV-1a 32, in BigInt with the plain multiply, so a test
/// checks the production hash against something that does not share its
/// split-multiplication trick. Checked against known vectors in
/// `migration_marker_fingerprint_test.dart`.
String referenceFnv1a32(List<int> bytes) {
  var h = BigInt.from(0x811c9dc5);
  final prime = BigInt.from(0x01000193);
  final mask = BigInt.from(0xffffffff);
  for (final b in bytes) {
    h = ((h ^ BigInt.from(b)) * prime) & mask;
  }
  return h.toRadixString(16).padLeft(8, '0');
}

Future<String?> readMarker() async =>
    (await SharedPreferences.getInstance()).getString(kLegacyMigrationMarkerKey);

Future<String?> readLegacy() async =>
    (await SharedPreferences.getInstance()).getString(kEventStorageKey);
