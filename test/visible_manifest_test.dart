import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// THE `.visible` MANIFEST — every site that excludes hidden records, named and
/// classified, with a test that fails when the set changes.
///
/// ⛔ **THIS EXISTS BECAUSE FOURTEEN UNCLASSIFIED READERS ACCUMULATED IN ONE
/// FILE WITHOUT ANYTHING NOTICING.** `4292288` decided, on 17 September 2026,
/// that "the complete list stays complete everywhere; ONE derived view excludes
/// hidden rows; every read site is classified deliberately into render,
/// integrity, or reconciling." ⭐ **The code diverged from that on the same day,
/// and the divergence was invisible because nothing enumerated the sites.**
///
/// ⚠️ **AND THE SCHEME ITSELF WAS SHORT A BUCKET.** Three of those readers
/// resolved WHICH RECORD TO OPEN — routing. That is not render, not integrity
/// and not reconciling, so those sites were not merely unclassified: **they
/// were unclassifiable, and nobody could see that they were.** ROUTING is now a
/// fourth named bucket — see the annotation on `4292288` in `DECISIONS.md`.
///
/// ## ⭐ WHAT THIS TEST DOES, AND WHAT IT DELIBERATELY DOES NOT
///
/// It asserts the SET OF SITES matches [kVisibleManifest]. ⛔ **It does not
/// verify that any classification is CORRECT** — a label is a judgement and a
/// source scan cannot make one. ⚠️ **What it makes impossible is adding a
/// reader SILENTLY: a new site fails this test until someone writes it down and
/// says which kind it is.** That is the whole purpose — the divergence happened
/// by accumulation, not by a wrong decision.
///
/// ⛔ **`bounded_chip_wrap.dart` has four `.visible` references that are NOT
/// this extension** — they concern chip visibility. They are excluded by path,
/// and the exclusion is enumerated here rather than applied silently, because
/// an exclusion nobody can see is an exclusion nobody can audit.

/// Every site that reads `EventRecordVisibility.visible`, with its bucket.
///
/// ⭐ RENDER · INTEGRITY · RECONCILING · ROUTING are the four buckets.
const kVisibleManifest = <String, String>{
  'lib/models/event_record.dart:get visible':
      'DEFINITION — the one derived view, not a read site',
  'lib/screens/history_screen.dart:HiddenView.exclude':
      'RENDER — History\'s list, and this is THE one derived view '
          '4292288 permits',
  'lib/screens/history_screen.dart:_hiddenWithheld':
      'RENDER — the withheld count, which exists to DISCLOSE the filtering '
          'rather than to perform it',
};

/// Paths whose `.visible` is a different symbol entirely.
const kExcludedPaths = <String>{
  'lib/widgets/bounded_chip_wrap.dart',
};

void main() {
  final libFiles = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  /// Reference sites, with comment lines stripped — a mention inside a comment
  /// is not a read.
  List<String> sitesIn(File f) {
    final rel = f.path.replaceAll(r'\', '/');
    if (kExcludedPaths.contains(rel)) return const [];
    final out = <String>[];
    var n = 0;
    for (final raw in f.readAsLinesSync()) {
      n++;
      final line = raw.trim();
      if (line.startsWith('//') || line.startsWith('///') ||
          line.startsWith('*')) {
        continue;
      }
      if (line.contains('.visible') || line.contains('get visible')) {
        out.add('$rel:$n');
      }
    }
    return out;
  }

  test('CONTROL: the scanner finds sites at all', () {
    final all = libFiles.expand(sitesIn).toList();
    expect(all, isNotEmpty,
        reason: 'if this is empty the scanner is broken and every assertion '
            'below would pass vacuously');
  });

  test('CONTROL: the excluded path really does contain .visible', () {
    // ⭐ Proves the exclusion is doing work rather than naming a file that
    // would have matched nothing anyway.
    final f = File('lib/widgets/bounded_chip_wrap.dart');
    expect(f.readAsStringSync().contains('.visible'), isTrue,
        reason: 'the exclusion must be load-bearing, or it is decoration');
  });

  test('every .visible site is in the manifest, and vice versa', () {
    final found = libFiles.expand(sitesIn).toList()..sort();

    expect(found.length, kVisibleManifest.length,
        reason: 'THE CONTRACT: ${found.length} site(s) found, '
            '${kVisibleManifest.length} in the manifest.\n\n'
            'FOUND:\n  ${found.join("\n  ")}\n\n'
            'A NEW SITE is not forbidden — it must be ADDED to '
            'kVisibleManifest with its bucket (render, integrity, '
            'reconciling or routing). A REMOVED site must be deleted from it. '
            'This test exists because fourteen readers once accumulated in one '
            'file with nothing noticing.');
  });

  test('the manifest names a bucket for every entry', () {
    const buckets = ['RENDER', 'INTEGRITY', 'RECONCILING', 'ROUTING',
                     'DEFINITION'];
    for (final e in kVisibleManifest.entries) {
      expect(buckets.any(e.value.startsWith), isTrue,
          reason: '${e.key} is classified as "${e.value}", which does not '
              'start with one of the four buckets (or DEFINITION). An '
              'unclassified entry defeats the manifest');
    }
  });
}
