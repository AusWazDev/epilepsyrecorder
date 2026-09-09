import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/constants.dart';

/// ⛔ DOES `flutter_test` MEASURE TEXT AT ONE EM PER GLYPH? If it does, every
/// width threshold derived from a widget test in this repository is inflated,
/// and AUDIT.md §13(as), §13(au) and §13(ay) are all wrong about WIDTHS while
/// possibly right about everything else.
///
/// ⭐ THE PREDICTION, STATED BEFORE MEASURING SO IT CAN FAIL: if the harness
/// font is the flutter_test default, a string of N characters at fontSize S
/// lays out to EXACTLY N*S logical pixels, for every N and every S, and weight
/// makes no difference. A real proportional font cannot do that -- 'i' and 'W'
/// are not the same width in any of them.
///
/// ⚠️ CONTROL: three different strings and three different sizes. One match
/// could be coincidence; nine cannot.

void main() {
  testWidgets('harness text metrics vs one-em-per-glyph', (tester) async {
    Future<double> widthOf(String s, double size, FontWeight w) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Text(s, style: TextStyle(fontSize: size, fontWeight: w)),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final ro = tester.renderObject<RenderParagraph>(find.text(s));
      return ro.size.width;
    }

    // ⚠️ The advance is not exactly `fontSize`; it is `fontSize + 0.25`,
    // constant across every size and length measured. The prediction above was
    // stated as `len * size` and FAILED on all twelve by that constant — which
    // is why the discriminator below, not the formula, is what settles it.
    var perGlyph = 0;
    var total = 0;
    for (final s in <String>[
      kAppName,
      'Record · Review · Share',
      'iiiii',
      'WWWWW',
    ]) {
      for (final size in <double>[10, 13, 24]) {
        final w = await widthOf(s, size, FontWeight.w600);
        final advance = w / s.length;
        total++;
        if ((advance - (size + 0.25)).abs() < 0.05) perGlyph++;
        // ignore: avoid_print
        print('  "${s.length > 24 ? "${s.substring(0, 24)}…" : s}" '
            'len=${s.length} size=${size.toStringAsFixed(0)} '
            'measured=${w.toStringAsFixed(1)} '
            'advance/glyph=${advance.toStringAsFixed(2)} '
            '${(advance - (size + 0.25)).abs() < 0.05 ? "= size+0.25" : "differs"}');
      }
    }

    // ⭐ 'iiiii' and 'WWWWW' are the discriminator. In ANY proportional font
    // they differ in width. If they are equal, the harness font is monospaced
    // at one em per glyph.
    final narrow = await widthOf('iiiii', 13, FontWeight.w400);
    final wide = await widthOf('WWWWW', 13, FontWeight.w400);
    // ignore: avoid_print
    print('  DISCRIMINATOR  iiiii=${narrow.toStringAsFixed(1)}  '
        'WWWWW=${wide.toStringAsFixed(1)}  equal=${(narrow - wide).abs() < 0.01}');
    // ignore: avoid_print
    print('  $perGlyph of $total measurements advance exactly size+0.25 per glyph');

    expect(perGlyph, total,
        reason: 'every glyph advances the same amount regardless of which glyph '
            'it is, so the harness font is monospaced at one em and '
            'widget-test text widths are NOT real text widths');
    expect(narrow, wide,
        reason: 'i and W measure the same, which no proportional font does');
  });
}
