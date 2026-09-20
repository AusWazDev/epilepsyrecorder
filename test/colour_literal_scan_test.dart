import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// NO COLOUR LITERAL OUTSIDE THE TOKEN SET — structure #7 of the Brief 57
/// sweep, built 20 September 2026.
///
/// ## ⛔ WHY THIS DID NOT EXIST UNTIL NOW
///
/// `DECISIONS.md` rule 1 has always read: *"One colour token per role, and no
/// widget names a colour directly. **A literal outside the token set fails a
/// check rather than being noticed.**"*
///
/// 🔴 **The second sentence was false.** `colour_system_test` verifies the
/// TOKENS' contrast ratios; it has never scanned for literals. ⚠️ **Rule 2
/// beside it — the type scale — has had exactly this scan the whole time.** So
/// this was not a hard problem left undone; it was a claim nobody checked,
/// sitting one line above a working example of the thing it claimed.
/// ⭐ Third instance of the `backupShare` class, and the first found in the
/// decision record itself.
///
/// ## ⚠️ WHAT COUNTS AS A VIOLATION, AND WHAT IS EXCLUDED
///
/// A violation is a `Color(0x…)` or `Colors.foo` OUTSIDE the theme. Exclusions
/// are enumerated here rather than applied silently, because an exclusion
/// nobody can see is an exclusion nobody can audit:
///
///   * `theme/mer_theme.dart` — **the token set itself is where colours live.**
///   * `Colors.transparent` — not a colour in the palette sense; it names the
///     ABSENCE of one, and no token could express it.
///
/// ⛔ Modelled on `type_system_test`, including its denominator assertion: a
/// null over an unstated denominator is indistinguishable from a scan that did
/// not run.

/// 🔴 A REAL VIOLATION, FOUND BY THIS SCAN ON ITS FIRST RUN, 20 September 2026.
///
/// `lib/main.dart:178` — the splash spinner:
///
///     color: Colors.white.withOpacity(0.5),
///
/// ⛔ **THIS IS A FINDING, NOT AN EXEMPTION.** Brief 60 forbids fixing a
/// divergence in the same pass that discovers it, so it is enumerated here and
/// recorded in `DECISIONS.md` rather than quietly corrected.
///
/// ⭐ **It is the proof the rule needed.** `DECISIONS.md` rule 1 claimed "a
/// literal outside the token set fails a check rather than being noticed" —
/// and for as long as that claim stood unchecked, this literal sat in the
/// app's FIRST SCREEN. ⚠️ The claim did not merely fail to catch it; the claim
/// is why nobody looked.
///
/// ⛔ **THE SET MUST SHRINK, NEVER GROW.** Any NEW path added here is a rule
/// being weakened, and needs a decision rather than an edit. Removing this
/// entry is a one-line change once a token is chosen for the splash spinner —
/// which is a colour decision, and therefore not the CLI's to make.
const _kKnownViolations = <String>{
  'lib/main.dart',
};

void main() {
  /// Every non-comment line of `lib/`, with the theme excluded.
  List<({String path, int line, String text})> scan() {
    final out = <({String path, int line, String text})>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final path = f.path.replaceAll(r'\', '/');
      if (path.endsWith('theme/mer_theme.dart')) continue;
      final lines = const LineSplitter().convert(f.readAsStringSync());
      for (var i = 0; i < lines.length; i++) {
        final t = lines[i].trimLeft();
        if (t.startsWith('//') || t.startsWith('///') || t.startsWith('*')) {
          continue;
        }
        out.add((path: path, line: i + 1, text: lines[i]));
      }
    }
    return out;
  }

  test('CONTROL: the scan reaches the tree', () {
    final files = scan().map((e) => e.path).toSet();
    expect(files.length, greaterThan(20),
        reason: 'the scan reached only ${files.length} files, so it did not '
            'run and every assertion below would pass vacuously');
  });

  test('CONTROL: the theme really does contain colour literals', () {
    // ⭐ Proves the exclusion is load-bearing. If the theme held no literals,
    // excluding it would be decoration and the scan below would look stricter
    // than it is.
    final theme = File('lib/theme/mer_theme.dart').readAsStringSync();
    expect(RegExp(r'Color\(0x').hasMatch(theme), isTrue);
  });

  test('no Color(0x…) literal outside the theme', () {
    final rx = RegExp(r'\bColor\(0x');
    final hits = [
      for (final e in scan())
        if (rx.hasMatch(e.text)) '${e.path}:${e.line}  ${e.text.trim()}',
    ];
    expect(hits, isEmpty,
        reason: 'DECISIONS rule 1: no widget names a colour directly. A raw '
            'literal cannot be checked for contrast, cannot be re-themed, and '
            'is invisible to every audit that reads the token set.\n'
            '  ${hits.join("\n  ")}');
  });

  test('no Colors.* constant outside the theme, except transparent', () {
    final rx = RegExp(r'\bColors\.(?!transparent\b)\w+');
    final hits = [
      for (final e in scan())
        if (rx.hasMatch(e.text) && !_kKnownViolations.contains(e.path))
          '${e.path}:${e.line}  ${e.text.trim()}',
    ];
    expect(hits, isEmpty,
        reason: 'DECISIONS rule 1. `Colors.transparent` is excluded because it '
            'names the ABSENCE of a colour rather than a palette choice; every '
            'other Material constant is a colour decision made outside the '
            'token set.\n  ${hits.join("\n  ")}');
  });
}
