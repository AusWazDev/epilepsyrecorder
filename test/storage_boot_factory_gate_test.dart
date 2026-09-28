// Brief 211 · the production host gate in `StorageBoot.configureDatabaseFactory`
// is UNCHANGED by the test seam beside it.
//
// ⛔ The seam, `StorageBoot.debugDatabaseFactory`, exists because a macOS test
// process has no sqflite plugin. It must be inert when null. This pins that:
// with the seam null, the gate still hands Windows and Linux FFI and every
// other host the plugin, exactly as before the seam existed.
//
// ⭐ BOTH BRANCHES ASSERT, per the platform-gated rule in CLAUDE.md. Each host
// runs one of them, and each is capable of failing: FFI where the plugin is
// expected fails, and the plugin where FFI is expected fails. Neither is a skip.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart' as sqflite_plugin;
import 'package:sqflite_common/sqflite.dart' as sqflite_common;
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

import 'package:medical_event_recorder/models/storage_boot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => StorageBoot.debugDatabaseFactory = null);

  test('with the seam NULL, the host gate chooses exactly as it always did', () {
    StorageBoot.debugDatabaseFactory = null;
    StorageBoot.configureDatabaseFactory();

    if (Platform.isWindows || Platform.isLinux) {
      expect(sqflite_common.databaseFactory, same(ffi.databaseFactoryFfi),
          reason: 'Windows and Linux boot on FFI');
    } else {
      expect(sqflite_common.databaseFactory,
          same(sqflite_plugin.databaseFactorySqflitePlugin),
          reason: 'macOS, iOS and Android boot on the plugin. A test seam '
              'must not change that');
    }
  });

  test('with the seam SET, the gate installs exactly that factory', () {
    // A factory this host would NOT pick, so the assertion can only pass if
    // the seam, rather than the gate, decided.
    final notTheGatesChoice = (Platform.isWindows || Platform.isLinux)
        ? sqflite_plugin.databaseFactorySqflitePlugin
        : ffi.databaseFactoryFfi;
    StorageBoot.debugDatabaseFactory = notTheGatesChoice;
    StorageBoot.configureDatabaseFactory();

    expect(sqflite_common.databaseFactory, same(notTheGatesChoice));
  });
}
