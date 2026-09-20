import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// BRIEF 64 B-3 — no layout spacing on the Help screen sits behind a platform
/// conditional.
///
/// ⛔ **THIS IS WHAT KEEPS `help_section_spacing_test` HONEST.** That test is a
/// widget test on a single host. It can only be trusted while Help's spacing
/// has ONE code path, because a host renders one branch and reports
/// confidently on it — which is exactly how the defect survived:
///
///     Android   gaps 12, 12, 12, 0     the defect
///     Windows   gaps 12, 12, 12, 12    what every test on this host saw
///
/// ⚠️ **THE BRANCH DID NOT MAKE THE TEST FAIL. IT MADE THE TEST IRRELEVANT**,
/// silently, while it went on passing. ⭐ **So the guard is not "don't write
/// this bug again" — it is "don't take the spacing test's coverage away
/// without anyone noticing".**
///
/// ⚠️ **SCOPE, STATED: Help's SPACING, not Help's platform conditionals.**
/// The screen legitimately branches on platform for CONTENT — the quick-log
/// section is genuinely different on Android, iOS and Windows, and the Windows
/// replacement section exists because of that. **This asserts only that no
/// spacing widget is inside such a branch.** A check that forbade platform
/// conditionals outright would be wrong about this screen and would be
/// deleted by the first person who needed one.

void main() {
  const path = 'lib/screens/help_screen.dart';

  /// Source lines with `//` comments removed, so an annotation QUOTING the
  /// retired pattern is not mistaken for the pattern.
  List<String> liveLines() {
    final raw = File(path).readAsLinesSync();
    return <String>[
      for (final l in raw)
        if (!l.trimLeft().startsWith('//')) l,
    ];
  }

  test('1. no SizedBox spacing sits inside a platform conditional', () {
    final lines = liveLines();
    final offenders = <String>[];

    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (!l.contains('SizedBox(height:')) continue;

      // Same line: `if (Platform.isX) const SizedBox(height: n)`.
      if (l.contains('Platform.')) {
        offenders.add('${i + 1}: ${l.trim()}');
        continue;
      }
      // Previous non-blank live line opening a platform conditional with no
      // brace — the shape the defect actually took was the single-line form,
      // but the two-line form is the same hazard.
      for (var b = i - 1; b >= 0 && b >= i - 2; b--) {
        final prev = lines[b].trim();
        if (prev.isEmpty) continue;
        if (prev.startsWith('if (') &&
            prev.contains('Platform.') &&
            !prev.endsWith('{')) {
          offenders.add('${i + 1}: ${l.trim()}   (guarded by line ${b + 1}: $prev)');
        }
        break;
      }
    }

    expect(offenders, isEmpty,
        reason: 'A SPACING WIDGET IS BEHIND A PLATFORM CONDITIONAL.\n\n'
            'That is the Brief 64 defect exactly: the fourth section gap was\n'
            '`if (Platform.isWindows) const SizedBox(height: 12)`, so Android\n'
            'and iOS never built it and the last two sections touched.\n\n'
            '⛔ AND IT TAKES THE SPACING TEST WITH IT. `help_section_spacing_test`\n'
            'runs on one host, renders one branch, and will keep passing while\n'
            'the other branch is wrong.\n\n'
            'REPAIR: make the spacing unconditional and use `_kSectionGap`. If\n'
            'a platform genuinely needs different spacing, that is a decision\n'
            'to record — and the spacing test needs a different design first.\n\n'
            'Found:\n  ${offenders.join("\n  ")}');
  });

  test('2. CONTROL: the scan can see the widgets it is scanning for', () {
    final lines = liveLines();
    final spacing = lines.where((l) => l.contains('SizedBox(height:')).length;
    final platform = lines.where((l) => l.contains('Platform.')).length;

    // ⭐ Without these, an empty offender list could mean the file moved, the
    // pattern changed, or the comment strip ate everything — all of which read
    // identically to "clean".
    expect(spacing, greaterThan(0),
        reason: 'the scan found NO spacing widgets at all in $path. A clean '
            'result over zero candidates is not a clean result');
    expect(platform, greaterThan(0),
        reason: 'the scan found NO platform conditionals in $path. Help '
            'legitimately branches on platform for CONTENT, so zero means the '
            'scan is not reading what it thinks it is reading');
  });

  test('3. the gaps use the shared constant, not literals', () {
    final lines = liveLines();
    final gapLines = lines
        .where((l) => l.contains('SizedBox(height: _kSectionGap)'))
        .length;
    expect(gapLines, 4,
        reason: 'four inter-section gaps, all drawing from `_kSectionGap`. '
            'They were four independent literal 12s, which is what let one of '
            'them diverge — found: $gapLines');

    expect(File(path).readAsStringSync(), contains('const double _kSectionGap'),
        reason: 'CONTROL: the constant is declared in this file, so the four '
            'references above resolve to something rather than to an import '
            'that could change under them');
  });
}
