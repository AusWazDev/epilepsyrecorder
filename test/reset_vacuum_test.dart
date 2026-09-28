// Brief 208 Part B §3, 28 September 2026: Reset VACUUMs.
//
// ⭐ THE PROPERTY IS NOT "THE FILE GOT SMALLER". It is that deleted content
// stops being readable from the file's free pages (Brief 206, residue A′). So
// the load-bearing assertion reads the database file's RAW BYTES for a sentinel
// that only ever existed in record notes. The size check is the secondary one
// the brief asked for.
//
// Separate file from `reset_clears_everything_test` because both depend on
// prefs, and the harness rule is one prefs-dependent test per process.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';

class _Dirs extends PathProviderPlatform with MockPlatformInterfaceMixin {
  _Dirs(this.dir);
  final String dir;
  @override
  Future<String?> getApplicationSupportPath() async => dir;
  @override
  Future<String?> getApplicationDocumentsPath() async => dir;
  @override
  Future<String?> getTemporaryPath() async => dir;
  @override
  Future<String?> getLibraryPath() async => dir;
}

const String kSentinel = 'B208SENTINELzqxjv';

EventRecord rec(int i) => EventRecord(
      id: 'r$i',
      timestamp: DateTime(2026, 1, 1).add(Duration(hours: i)),
      duration: DurationCategory.lt1,
      durationSeconds: 40,
      eventType: 'seizure',
      severity: EventSeverity.mild,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: false,
      notes: '$kSentinel ${'x' * 1500} $i',
      detailsCompleted: true,
    );

bool fileHolds(File f, String s) =>
    latin1.decode(f.readAsBytesSync()).contains(s);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('mer_b208v_');
    PathProviderPlatform.instance = _Dirs(root.path);
    // Brief 211: FFI on every host. On macOS the production gate picks the
    // plugin, which a test process does not have, and every init() fell back.
    StorageBoot.debugDatabaseFactory = databaseFactoryFfi;
    SharedPreferences.setMockInitialValues(<String, Object>{
      kEventStorageKey: jsonEncode(<Object>[]),
    });
  });

  tearDown(() async {
    await StorageBoot.database?.close();
    StorageBoot.debugSet();
    StorageBoot.debugDatabaseFactory = null;
    try {
      if (await root.exists()) await root.delete(recursive: true);
    } catch (_) {}
  });

  test('Reset leaves no deleted record content in the file, and the file '
      'shrinks', () async {
    print('[b208v] boot');
    await StorageBoot.init();
    expect(StorageBoot.isSqlite, isTrue, reason: 'CONTROL: SQLite launch');
    final dbFile = File('${root.path}/$kSqliteDbFileName');

    print('[b208v] fill');
    await StorageBoot.store.save(<EventRecord>[for (var i = 0; i < 400; i++) rec(i)]);
    final before = dbFile.lengthSync();
    expect(fileHolds(dbFile, kSentinel), isTrue,
        reason: 'CONTROL: the sentinel must be in the file before Reset, or '
            'its absence afterwards proves nothing');

    print('[b208v] reset');
    await StorageBoot.store.clearAll();
    final after = dbFile.lengthSync();
    print('[b208v] bytes before=$before after=$after');

    expect(fileHolds(dbFile, kSentinel), isFalse,
        reason: 'RESIDUE: deleted record content must not remain readable in '
            'the database file after Reset');
    expect(after, lessThan(before ~/ 4),
        reason: 'SIZE: with ~600 KB of records removed the file must shrink '
            '(before=$before after=$after)');
  }, timeout: const Timeout(Duration(seconds: 90)));
}
