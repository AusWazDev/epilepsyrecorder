// Brief 166 · the pre-migration backup is written to the SUPPORT directory,
// not the DOCUMENTS directory.
//
// ⛔ WINDOWS-SPECIFIC, AND THE REASON MUST NOT BE OVERSTATED. On Windows
// `path_provider` maps Documents to `WindowsKnownFolder.Documents`, which
// OneDrive's Known Folder Move redirects into a synced folder — measured on
// the developer's machine, `MyDocuments` resolves under `OneDrive\Documents`
// while `RoamingAppData` does not. This file is the user's entire
// pre-migration history in plaintext, so the old destination put a medical
// record into cloud sync on that platform.
//
// ⚠️ IT CHANGES NOTHING ON ANDROID OR iOS. There both directories sit inside
// the app container and both are eligible for platform backup. This test
// pins a destination; it does not pin a privacy property.
//
// ⭐ THIS TEST DRIVES THE REAL CALL SITE. `StorageBoot.init()` is what chooses
// the directory, so a test that called `writeMigrationBackup` directly would
// pin the helper and not the decision — and would pass against the old code,
// which is exactly the failure this test exists to avoid.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';

/// Two distinct directories, so "which one did it choose" is answerable.
class _TwoDirProvider extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _TwoDirProvider(this.support, this.documents, this.temp);
  final String support;
  final String documents;
  final String temp;

  @override
  Future<String?> getApplicationSupportPath() async => support;
  @override
  Future<String?> getApplicationDocumentsPath() async => documents;
  @override
  Future<String?> getTemporaryPath() async => temp;
  @override
  Future<String?> getLibraryPath() async => support;
  @override
  Future<String?> getDownloadsPath() async => documents;
}

EventRecord rec(String id, int day) => EventRecord(
      id: id,
      timestamp: DateTime(2026, 9, day),
      duration: DurationCategory.lt1,
      durationSeconds: 40,
      eventType: 'seizure',
      severity: EventSeverity.mild,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: false,
      notes: '',
      detailsCompleted: true,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory root;
  late Directory support;
  late Directory documents;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mer_b166_');
    support = await Directory('${root.path}/support').create();
    documents = await Directory('${root.path}/documents').create();
    final temp = await Directory('${root.path}/tmp').create();
    PathProviderPlatform.instance =
        _TwoDirProvider(support.path, documents.path, temp.path);

    // A pre-migration device: records under the legacy key, no database yet.
    SharedPreferences.setMockInitialValues(<String, Object>{
      kEventStorageKey: jsonEncode([rec('alpha', 1).toMap()]),
    });
  });

  tearDown(() async {
    // The database lives in the support directory and is still open, and
    // Windows will not delete a directory holding an open file. Closing it is
    // cleanup, not part of the subject.
    await StorageBoot.database?.close();
    StorageBoot.debugSet();
    try {
      if (await root.exists()) await root.delete(recursive: true);
    } catch (_) {
      // A temp directory that will not delete must not fail the run or mask
      // the assertion result above it.
    }
  });

  List<String> backupsIn(Directory d) => d
      .listSync()
      .whereType<File>()
      .map((f) => f.uri.pathSegments.last)
      .where((n) => n.startsWith('mer_pre_sqlite_backup_'))
      .toList();

  test('the pre-migration backup lands in SUPPORT, not DOCUMENTS', () async {
    // CONTROL: both directories must start empty, or "it is in support" could
    // be true of a file that was already there.
    expect(backupsIn(support), isEmpty,
        reason: 'CONTROL: support must start with no backup file.');
    expect(backupsIn(documents), isEmpty,
        reason: 'CONTROL: documents must start with no backup file.');

    await StorageBoot.init();

    final inSupport = backupsIn(support);
    final inDocuments = backupsIn(documents);

    // ⭐ CONTROL ON THE RUN ITSELF: if no backup was written anywhere, both
    // assertions below would pass vacuously and the test would be green over
    // a migration that never happened.
    expect(inSupport.length + inDocuments.length, 1,
        reason: 'CONTROL: exactly one backup must have been written '
            'somewhere, or this test is asserting over a migration that did '
            'not run. support=$inSupport documents=$inDocuments');

    expect(inSupport, hasLength(1),
        reason: '⛔ THE DESTINATION. The pre-migration backup must be written '
            'to getApplicationSupportDirectory(). On Windows the documents '
            'directory is OneDrive-redirected by Known Folder Move, and this '
            'file is the whole history in plaintext.');
    expect(inDocuments, isEmpty,
        reason: '⛔ AND NOT TO DOCUMENTS. A copy left here is the thing the '
            'change removes; nothing deletes it afterwards.');
  });
}
