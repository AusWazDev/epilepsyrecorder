import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contract #26 (scan half) — EVERY way of taking a backup goes through the ONE
/// place its contents are assembled.
///
/// ⛔ **THE DEFECT THIS EXISTS FOR.** Home's backup reminder called
/// `showBackupOptions(context, _records)` directly. Medication notes,
/// conditions and type assignments all defaulted to empty, so every backup it
/// produced omitted them, on every device, from 28 August 2026. Each time the
/// backup grew, the Your data call site was updated and the reminder's was not.
/// `backup_medication_notes_test` #15 already checked that `showBackupOptions`
/// FORWARDS its arguments; nothing checked what its CALLERS passed in.
///
/// ⭐ **ENTRY POINTS ARE FOUND BY WHAT THEY DO, NOT FROM A LIST.** The one thing
/// that turns records into backup content is `buildBackupJson`. This walks its
/// callers upward through `backupShare` / `backupSaveAs` and `showBackupOptions`
/// and requires every route to pass through `backUpFromDevice`. A new site that
/// produces a backup any other way fails here by name, including one nobody
/// thought to list.
///
/// ⚠️ **WHAT THIS CANNOT SEE:** what `backUpFromDevice` actually puts in the
/// file. That is the behaviour half, `backup_contents_contract_test`.

/// The enclosing top-level function of [offset], or null. Enough for the
/// top-level functions of `backup_service.dart`; class methods are not asked.
String? enclosingTopLevel(String src, int offset) {
  String? name;
  final def = RegExp(r'^(?:Future<[^>\n]*>|void|String|int|bool)\s+(\w+)\(',
      multiLine: true);
  for (final m in def.allMatches(src)) {
    if (m.start > offset) break;
    name = m.group(1);
  }
  return name;
}

/// Every CALL of [fn] in [src]: a call is `fn(` that is not the definition
/// line and not inside a `//` comment.
List<int> callsOf(String fn, String src) {
  final out = <int>[];
  for (final m in RegExp('\\b$fn\\(').allMatches(src)) {
    final lineStart = src.lastIndexOf('\n', m.start) + 1;
    final line = src.substring(lineStart, src.indexOf('\n', m.start));
    final before = src.substring(lineStart, m.start);
    if (before.contains('//')) continue; // a comment
    if (RegExp(r'^(?:Future<[^>]*>|void|String)\s+$').hasMatch(before)) {
      continue; // the definition itself
    }
    if (line.trimLeft().startsWith('///')) continue;
    out.add(m.start);
  }
  return out;
}

void main() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();
  final sources = {for (final f in files) f.path.replaceAll('\\', '/'): f.readAsStringSync()};

  /// Every call of [fn] across lib/, as (file, enclosing top-level function).
  List<(String, String?)> sitesOf(String fn) => [
        for (final e in sources.entries)
          for (final at in callsOf(fn, e.value))
            (e.key, enclosingTopLevel(e.value, at)),
      ];

  test('CONTROL: lib/ was read, and the builder is found where it lives', () {
    expect(sources.length, greaterThan(20),
        reason: 'lib/ was not read, so every rule below would pass over nothing');
    expect(sitesOf('buildBackupJson'), isNotEmpty,
        reason: 'the scan finds no call of buildBackupJson at all, so it '
            'cannot be looking');
  });

  test('#26 the content builder is reached only through backupShare / backupSaveAs',
      () {
    final bad = sitesOf('buildBackupJson')
        .where((s) => s.$1 != 'lib/services/backup_service.dart' ||
            !{'backupShare', 'backupSaveAs'}.contains(s.$2))
        .toList();
    expect(bad, isEmpty, reason: 'backup content built outside the sheet: $bad');
  });

  test('#26 backupShare / backupSaveAs are reached only from showBackupOptions',
      () {
    final bad = [...sitesOf('backupShare'), ...sitesOf('backupSaveAs')]
        .where((s) => s.$1 != 'lib/services/backup_service.dart' ||
            s.$2 != 'showBackupOptions')
        .toList();
    expect(bad, isEmpty, reason: 'a backup route that skips the sheet: $bad');
  });

  test('#26 showBackupOptions is reached ONLY from backUpFromDevice', () {
    final bad = sitesOf('showBackupOptions')
        .where((s) => s.$1 != 'lib/services/backup_service.dart' ||
            s.$2 != 'backUpFromDevice')
        .toList();
    expect(bad, isEmpty,
        reason: 'A BACKUP ENTRY POINT THAT DOES NOT GO THROUGH '
            'backUpFromDevice, so its contents are assembled somewhere else '
            'and can differ: $bad');
  });

  test('CONTROL: the entry points exist, so the rules above are not vacuous', () {
    final entries = sitesOf('backUpFromDevice');
    // Your data -> Back up, and Home's reminder -> Back up now.
    expect(entries.length, greaterThanOrEqualTo(2),
        reason: 'fewer than two entry points reach backUpFromDevice: $entries');
  });
}
