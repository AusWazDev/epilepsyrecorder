import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/screens/event_wizard_screen.dart';
import 'package:medical_event_recorder/theme/mer_theme.dart';

/// BRIEF 62 C — the wizard's progress bar shows progress COMPLETED.
///
/// ⭐ **THE VALUE WAS NEVER WRONG, AND THAT IS WHY THIS SURVIVED.**
/// `(_step + 1) / (_lastStep + 1)` is .25 / .50 / .75 / 1.00 — correct on
/// every step. Nothing about the arithmetic looks suspicious, so a reader
/// checking the code found nothing.
///
/// ⛔ **THE DEFECT WAS ENTIRELY CHROMATIC.** With no colours given, M3 takes
/// the filled portion from `colorScheme.primary` — `#0D4F82`, **the same navy
/// as the AppBar directly above** — and the track from a light container. So
/// the portion that GREW was invisible and the portion that SHRANK was the
/// visible one: on the tablet the bright region started at x≈200, then 400,
/// then 600, and at step 4, where the value is a correct 1.0, the strip became
/// a seamless extension of the AppBar and read as no progress bar at all.
///
/// ⚠️ **CONTRAST, MEASURED — and one figure does NOT reach 3:1:**
///
///     filled focusRing #1A8FCB vs track infoContainer #E3F2FD   3.15:1  ✅
///     filled                   vs the page below      #F4F7F9   8.02:1  ✅
///     filled                   vs the AppBar above    #0D4F82   2.37:1  ⛔
///
/// ⛔ **THE THIRD IS UNREACHABLE, NOT UNATTEMPTED, and the arithmetic is
/// pinned in test 4 so nobody re-opens it as an oversight.** Clearing 3:1
/// against the AppBar needs relative luminance ≥ 0.3187; clearing 3:1 against
/// any light track needs ≤ 0.2784. **The demands do not overlap**, so no
/// colour whatever satisfies both while the track stays light. The exits are a
/// dark track — which makes the REMAINING portion loud again, reinstating the
/// defect — or separating the strip from the chrome. ⚠️ **That is a design
/// decision and was not taken here.** The boundary that actually carries the
/// state information is filled-against-track, and it clears.

double _lum(int rgb) {
  double ch(int v) {
    final c = v / 255.0;
    return c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * ch((rgb >> 16) & 0xFF) +
      0.7152 * ch((rgb >> 8) & 0xFF) +
      0.0722 * ch(rgb & 0xFF);
}

double contrast(int a, int b) {
  final la = _lum(a), lb = _lum(b);
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  Future<LinearProgressIndicator?> bar(WidgetTester tester) async {
    final f = find.byType(LinearProgressIndicator);
    if (f.evaluate().isEmpty) return null;
    return tester.widget<LinearProgressIndicator>(f.first);
  }

  Future<void> pump(WidgetTester tester, double scale) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: const EventWizardScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final scale in <double>[1.0, 2.0]) {
    testWidgets('1. @${scale}x — the FILLED portion is not the AppBar colour',
        (tester) async {
      await pump(tester, scale);
      final b = (await bar(tester))!;

      expect(b.color, isNotNull,
          reason: 'inheriting the colour is what caused this: M3 hands the '
              'filled portion colorScheme.primary, which IS the AppBar');
      expect(b.color, MERColours.focusRing);
      expect(b.color, isNot(MERColours.primary),
          reason: 'THE DEFECT: the filled portion was #0D4F82, identical to '
              'the AppBar one pixel above it, so progress was invisible and '
              'a full bar read as no bar');
      expect(b.backgroundColor, MERColours.infoContainer);
    });

    testWidgets('2. @${scale}x — the value RISES to a full bar on the last step',
        (tester) async {
      await pump(tester, scale);
      final seen = <double>[];
      for (var i = 0; i < 4; i++) {
        final b = await bar(tester);
        expect(b, isNotNull, reason: 'step ${i + 1} must still show a bar');
        seen.add(b!.value!);
        if (i < 3) {
          // 'Next' on steps 0-2; the button only reads 'Review' ON step 3,
          // which is where the walk ends, so it is never tapped here.
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
        }
      }
      expect(seen, <double>[0.25, 0.5, 0.75, 1.0],
          reason: 'the value was ALWAYS right — pinned so a future reader does '
              'not "fix" the arithmetic looking for a defect that was in the '
              'colours');
      expect(seen.last, 1.0,
          reason: 'step 4 shows a FULL bar. It always did; it was navy on '
              'navy and therefore invisible');
    });
  }

  test('3. the contrast figures this fix rests on', () {
    const filled = 0x1A8FCB; // focusRing
    const track = 0xE3F2FD; // infoContainer
    const appBar = 0x0D4F82; // primary
    const page = 0xF4F7F9;

    expect(contrast(filled, track), greaterThanOrEqualTo(3.0),
        reason: 'the boundary carrying the state information must clear '
            '1.4.11. Measured 3.15:1');
    expect(contrast(filled, page), greaterThanOrEqualTo(3.0),
        reason: 'and the strip must be visible against the page. 8.02:1');

    // ⛔ STATED AS A FAILING FIGURE ON PURPOSE. Asserting it clears would be
    // false; asserting nothing would let a reader assume it does.
    expect(contrast(filled, appBar), lessThan(3.0),
        reason: 'HONEST LIMIT: 2.37:1 against the AppBar. If a future change '
            'makes this clear 3.0, that is an improvement — update this test '
            'and the comment, do not delete them');
  });

  test('4. and that limit is ARITHMETIC, not a failure to search', () {
    // Clearing 3:1 against the AppBar sets a floor on the fill's luminance;
    // clearing 3:1 against any light track sets a ceiling. They do not meet.
    const appBar = 0x0D4F82;
    const lightestTrack = 0xE3F2FD;
    final floor = 3 * (_lum(appBar) + 0.05) - 0.05;
    final ceiling = (_lum(lightestTrack) + 0.05) / 3 - 0.05;
    expect(floor, greaterThan(ceiling),
        reason: 'NO colour satisfies both while the track stays light — floor '
            '${floor.toStringAsFixed(4)} above ceiling '
            '${ceiling.toStringAsFixed(4)}. This is why the limit above is '
            'accepted rather than optimised away');
  });
}
