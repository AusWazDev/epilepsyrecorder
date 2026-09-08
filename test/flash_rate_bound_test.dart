import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/home_screen.dart';
import 'package:medical_event_recorder/theme/mer_theme.dart';

/// The Record Event flash is rate-bounded. AUDIT.md §13(ah).
///
/// `_buttonFlash` swaps the fill to white — a 76.4% of full-scale luminance
/// change against `MERColours.alert`. With only the 200 ms hold, taps spaced
/// 200-333 ms apart produced FOUR onsets per second, over WCAG 2.3.1's
/// three-per-second threshold. Flutter's own `kDoubleTapTimeout` is 300 ms,
/// which falls inside that band.
///
/// ⛔ THE RECORD IS NEVER GATED. Test 5 is the standing rule and it outranks
/// the fix: a tap must create a record at every interval, including 150 ms.
///
/// ⭐ The onset counter samples the button's ACTUAL FILL COLOUR frame by frame
/// and counts alert->white transitions. It does not read `_buttonFlash`, which
/// is private, and it does not trust the timer — it measures what is painted.

/// Samples the button's fill every [stepMs] and counts alert->white edges.
class OnsetCounter {
  int onsets = 0;
  bool? wasWhite;

  void sample(WidgetTester tester) {
    final btn = find.textContaining('Record Event');
    if (!tester.any(btn)) return;
    final material = find
        .ancestor(of: btn.first, matching: find.byType(Material))
        .evaluate()
        .map((e) => e.widget as Material)
        .where((m) => m.color != null)
        .toList();
    if (material.isEmpty) return;
    final c = material.first.color!;
    final isWhite = c.value == Colors.white.value;
    if (wasWhite == false && isWhite) onsets++;
    if (wasWhite == null && isWhite) onsets++;
    wasWhite = isWhite;
  }
}

/// Taps Record Event every [intervalMs] for [spanMs], sampling every 10 ms,
/// and returns (onsets, taps).
Future<(int, int)> run(WidgetTester tester,
    {required int intervalMs, int spanMs = 1000}) async {
  final counter = OnsetCounter();
  final btn = find.textContaining('Record Event');
  int taps = 0;
  int sinceTap = intervalMs; // tap on the first step
  for (int t = 0; t < spanMs; t += 10) {
    if (sinceTap >= intervalMs) {
      await tester.tap(btn.first, warnIfMissed: false);
      taps++;
      sinceTap = 0;
    }
    await tester.pump(const Duration(milliseconds: 10));
    counter.sample(tester);
    sinceTap += 10;
  }
  return (counter.onsets, taps);
}

/// The app's own "Total saved" figure, located by GEOMETRY rather than by
/// position in the widget list.
///
/// ⚠️ A first version scanned backwards through `tester.widgetList<Text>` from
/// the 'Total saved' label and returned -1, because list order does not follow
/// visual order. The value sits directly ABOVE its label, so the integer Text
/// whose centre is nearest above it is the one wanted.
int recordsOnScreen(WidgetTester tester) {
  final label = find.text('Total saved');
  if (!tester.any(label)) return -1;
  final lr = tester.getRect(label.first);
  int best = -1;
  double bestDy = 1e9;
  for (final e in find.byType(Text).evaluate()) {
    final t = e.widget as Text;
    final v = int.tryParse(t.data ?? '');
    if (v == null) continue;
    final r = tester.getRect(find.byWidget(t));
    // same column, above the label
    if (r.bottom > lr.top) continue;
    if ((r.center.dx - lr.center.dx).abs() > 40) continue;
    final dy = lr.top - r.bottom;
    if (dy < bestDy) {
      bestDy = dy;
      best = v;
    }
  }
  return best;
}

Future<void> pumpHome(WidgetTester tester) async {
  tester.view.physicalSize = const Size(430, 932);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: MERTheme.light,
    home: const HomeScreen(),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'disclaimerAcceptedVersion': kDisclaimerVersion,
      kWalkthroughSeenVersionKey: kWalkthroughVersion,
    });
    StorageBoot.debugSet();
    Vocabularies.debugReset();
  });
  tearDown(() {
    StorageBoot.debugSet();
    Vocabularies.debugReset();
  });

  testWidgets('1. taps at 250 ms produce AT MOST 2 onsets per second',
      (tester) async {
    await pumpHome(tester);
    final (onsets, taps) = await run(tester, intervalMs: 250);
    // ignore: avoid_print
    print('RATE 250ms taps=$taps onsets=$onsets');
    expect(onsets, lessThanOrEqualTo(2),
        reason: 'unpatched this was 4, over the three-per-second threshold');
    expect(taps, 4, reason: 'and all four taps still happened');
  });

  testWidgets('2. taps at 300 ms produce AT MOST 2 onsets per second',
      (tester) async {
    await pumpHome(tester);
    final (onsets, taps) = await run(tester, intervalMs: 300);
    // ignore: avoid_print
    print('RATE 300ms taps=$taps onsets=$onsets');
    expect(onsets, lessThanOrEqualTo(2),
        reason: 'unpatched this was 4. kDoubleTapTimeout is 300 ms, so this '
            'is the interval the framework itself treats as a double tap');
    expect(taps, 4);
  });

  testWidgets('3. A SINGLE TAP STILL FLASHES', (tester) async {
    // ⭐ If this fails the affordance is gone and the fix became a removal.
    await pumpHome(tester);
    final (onsets, taps) = await run(tester, intervalMs: 5000, spanMs: 300);
    // ignore: avoid_print
    print('RATE single taps=$taps onsets=$onsets');
    expect(taps, 1);
    expect(onsets, 1, reason: 'the flash must survive the bound');
  });

  testWidgets('4. taps at 600 ms flash EVERY time', (tester) async {
    await pumpHome(tester);
    final (onsets, taps) = await run(tester, intervalMs: 600, spanMs: 1800);
    // ignore: avoid_print
    print('RATE 600ms taps=$taps onsets=$onsets');
    expect(taps, 3);
    expect(onsets, 3,
        reason: 'the bound is 500 ms, so 600 ms spacing must not be '
            'suppressed -- legitimate feedback survives');
  });
}
