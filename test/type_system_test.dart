import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/theme/mer_type.dart';

/// ⛔ RULE 1, ENFORCED OVER `lib/` RATHER THAN DESCRIBED.
///
/// **One type step per element class, and no literal size or weight outside
/// `MERType`.** ⚠️ **This checker did not exist.** The deploy gate named "the
/// colour checker and the type checker" as a pair; only the colour one was
/// ever installed, and the type rule had been asserted as satisfied on the
/// strength of the SIZE half alone. The size half was in fact clean — zero
/// literal `fontSize` anywhere outside `MERType`. **The weight half was
/// violated twenty times and nothing detected it.**
///
/// ⭐ That is the same class `CLAUDE.md` already records: *a check that lives
/// in a transcript is not installed.* A rule stated in a decisions document
/// and enforced nowhere is a rule that has already started drifting.
///
/// ## ⚠️ THE ALLOWLIST IS KEYED ON SOURCE TEXT, NOT A LINE NUMBER
///
/// `colour_system_test` keys its one entry on `lib/main.dart:185`, and that
/// key has already drifted once — to `:178`, when the type scale removed seven
/// lines above it. Its own comment says keying on the quoted source would not
/// have drifted. ⭐ **This checker does that instead**, so the entry survives
/// anything that moves the line and fails only if the line itself changes.
void main() {
  /// Weights that are not literals: the three `MERType` names.
  const namedWeights = <String>{
    'MERType.regular',
    'MERType.emphasis',
    'MERType.strong',
  };

  /// ⛔ THE RESIDUE, BY QUOTED SOURCE. Each survivor carries the reason it
  /// survives. A new literal fails; removing one ALSO fails, so the list
  /// cannot rot in either direction.
  const allowed = <String, String>{
    'fontWeight:    FontWeight.w800,':
        'lib/main.dart — the splash MER wordmark. It sits at letterSpacing 4, '
            'and mer_theme records the ls-4 register as BRAND rather than '
            'screen furniture, explicitly outside the type scale. w800 is not '
            'one of the three weights and is not meant to be.',
  };

  test('1. the apparatus — MERType really does name the three weights', () {
    // ⛔ A POSITIVE CONTROL ON THE SCAN BELOW. If these names stopped
    // resolving, the scan would report a clean lib/ because nothing matched,
    // not because nothing was wrong.
    expect(MERType.regular.value, 400);
    expect(MERType.emphasis.value, 600);
    expect(MERType.strong.value, 700);
    expect(namedWeights.length, 3);
  });

  test('2. no literal fontSize outside MERType', () {
    final size = RegExp(r'\bfontSize:\s*[0-9]');
    final hits = <String>[];
    var scanned = 0;

    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final path = f.path.replaceAll(r'\', '/');
      if (path.endsWith('theme/mer_type.dart')) continue;
      scanned++;
      final lines = const LineSplitter().convert(f.readAsStringSync());
      for (var i = 0; i < lines.length; i++) {
        final t = lines[i].trimLeft();
        if (t.startsWith('//') || t.startsWith('///') || t.startsWith('*')) {
          continue;
        }
        if (size.hasMatch(lines[i])) hits.add('$path:${i + 1}  ${t.trim()}');
      }
    }

    // ⛔ THE DENOMINATOR. A null over an unstated denominator is
    // indistinguishable from a scan that did not run.
    expect(scanned, greaterThan(20),
        reason: 'the scan reached only $scanned files, so it did not run');

    expect(hits, isEmpty,
        reason: 'rule 1: a literal font size outside MERType.\n'
            '  ${hits.join("\n  ")}');
  });

  test('3. no literal FontWeight outside MERType', () {
    final weight = RegExp(r'\bFontWeight\.(w[0-9]00|bold|normal|w[0-9]+)');
    final hits = <String, String>{};
    var scanned = 0;

    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final path = f.path.replaceAll(r'\', '/');
      if (path.endsWith('theme/mer_type.dart')) continue;
      scanned++;
      final lines = const LineSplitter().convert(f.readAsStringSync());
      for (var i = 0; i < lines.length; i++) {
        final t = lines[i].trimLeft();
        if (t.startsWith('//') || t.startsWith('///') || t.startsWith('*')) {
          continue;
        }
        if (weight.hasMatch(lines[i])) hits[t.trimRight()] = '$path:${i + 1}';
      }
    }

    expect(scanned, greaterThan(20),
        reason: 'the scan reached only $scanned files, so it did not run');

    final unexpected = hits.keys.where((k) => !allowed.containsKey(k)).toList();
    expect(unexpected, isEmpty,
        reason: 'rule 1: a literal font weight outside MERType. Use '
            'MERType.regular / emphasis / strong, or allowlist it with its '
            'reason:\n'
            '  ${unexpected.map((k) => "${hits[k]}  $k").join("\n  ")}');

    // ⛔ AND THE OTHER DIRECTION, which is what keeps the list honest.
    final gone = allowed.keys.where((k) => !hits.containsKey(k)).toList();
    expect(gone, isEmpty,
        reason: 'the allowlist names a line that no longer carries a literal '
            'weight. Delete the entry — a stale allowlist hides the next '
            'one:\n  ${gone.join("\n  ")}');
  });

  test('4. the checker can actually fail', () {
    // ⛔ DEMONSTRATED, NOT ASSERTED. The two scans above return empty lists,
    // and an empty list is what a broken scan returns too. This runs the same
    // patterns over a fixture that is KNOWN to contain both violations.
    const fixture = '''
      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w300),
      // fontSize: 99 — a comment, and must NOT be flagged
    ''';
    final size = RegExp(r'\bfontSize:\s*[0-9]');
    final weight = RegExp(r'\bFontWeight\.(w[0-9]00|bold|normal|w[0-9]+)');

    final live = const LineSplitter()
        .convert(fixture)
        .where((l) => !l.trimLeft().startsWith('//'))
        .toList();

    expect(live.any(size.hasMatch), isTrue,
        reason: 'the size pattern fires on a real literal');
    expect(live.any(weight.hasMatch), isTrue,
        reason: 'the weight pattern fires on a real literal');
    expect(live.length, 2,
        reason: 'and the comment line was excluded, which is the behaviour '
            'that stops this checker flagging its own documentation');
  });
}
