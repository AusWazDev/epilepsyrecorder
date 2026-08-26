import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The single-writer guard, restated for SQLite.
///
/// The prefs-era guard greps `lib/` for `setString(kEventStorageKey` and
/// `writeEventPayload(`. SQLite has no equivalent string — there is no one
/// literal that every write shares — so that shape does not transfer, and left
/// alone it would keep passing while every SQLite write bypassed it: a check
/// that reports clean by construction on everything outside itself.
///
/// The property restated: **only the storage layer may reach the database.**
/// Expressed as an import rule, because a file cannot touch SQLite without
/// importing it, and an import is a single unambiguous token — unlike `insert(`
/// or `delete(`, which appear on lists, maps and SharedPreferences too.
///
/// The prefs guard in `capture_inbox_test.dart` is NOT retired. It still holds:
/// `PrefsEventStore` remains the fallback store and remains its one writer.

/// The only files permitted to reach SQLite.
///
/// Five, each doing one job: the store implements the interface, the migration
/// performs the one-shot conversion, the boot layer opens the database and
/// chooses which store this launch runs on, and the two vocabulary files own
/// the `event_type` and `observation` tables.
///
/// The vocabulary pair was ADDED deliberately rather than by relaxing the rule.
/// `vocabulary.dart` holds the DDL and the mutations; `vocabulary_store.dart`
/// caches the result. Nothing outside this set may hold a `Database`, which is
/// what stops a screen writing rows behind the store's back.
const Set<String> kStorageLayer = <String>{
  'lib/models/event_store_sqlite.dart',
  'lib/models/storage_migration.dart',
  'lib/models/storage_boot.dart',
  'lib/models/vocabulary.dart',
  'lib/models/vocabulary_store.dart',
};

const String kSqliteImportMarker = 'package:sqflite';

void main() {
  group('only the storage layer reaches the database', () {
    late List<File> files;

    setUp(() {
      files = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .toList();
    });

    test('positive control: files were scanned AND the matcher matches',
        () async {
      expect(files, isNotEmpty, reason: 'nothing was scanned');

      // The half the prefs guard lacks. Its control proves only that files
      // were read; it cannot tell a clean corpus from a broken pattern. Running
      // the SAME matcher over the files that are SUPPOSED to match proves the
      // matcher works, so a zero elsewhere means something.
      final matchedInLayer = <String>[];
      for (final file in files) {
        final path = file.path.replaceAll(Platform.pathSeparator, '/');
        final rel = path.substring(path.indexOf('lib/'));
        if (!kStorageLayer.contains(rel)) continue;
        if (file.readAsStringSync().contains(kSqliteImportMarker)) {
          matchedInLayer.add(rel);
        }
      }

      expect(matchedInLayer, unorderedEquals(kStorageLayer),
          reason: 'the matcher must find sqflite in every storage-layer file. '
              'A miss here means the pattern is broken, a file was renamed, or '
              'the layer moved — and the null below would be meaningless.');
    });

    test('no file outside the storage layer imports sqflite', () async {
      final offenders = <String>[];
      var scanned = 0;

      for (final file in files) {
        final path = file.path.replaceAll(Platform.pathSeparator, '/');
        final rel = path.substring(path.indexOf('lib/'));
        scanned++;
        if (kStorageLayer.contains(rel)) continue;
        if (file.readAsStringSync().contains(kSqliteImportMarker)) {
          offenders.add(rel);
        }
      }

      expect(offenders, isEmpty,
          reason: 'a second writer of the record store defeats the whole '
              'change. Scanned $scanned files under lib/; '
              '${kStorageLayer.length} are the permitted storage layer.');
    });

    test('the storage layer is exactly the files named here', () {
      // Guards the guard: if a storage file is added and not listed, the
      // control above fails; if one is listed and deleted, this fails. Neither
      // can drift silently into an exclusion nobody declared.
      for (final rel in kStorageLayer) {
        expect(File(rel).existsSync(), isTrue,
            reason: '$rel is named in the exclusion list but does not exist');
      }
    });
  });
}
