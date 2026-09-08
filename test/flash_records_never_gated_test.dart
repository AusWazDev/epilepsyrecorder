import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/home_screen.dart';
import 'package:medical_event_recorder/theme/mer_theme.dart';

/// EVERY TAP STILL CREATES A RECORD, at every interval. AUDIT.md §13(ah).
///
/// ⛔ SEPARATE FILE, AND THE REASON IS THE RULE IN `CLAUDE.md`: these two
/// tests read the app's own "Total saved" figure, so they depend on
/// `SharedPreferences` state -- and `setMockInitialValues` does not take effect
/// once an instance exists earlier in the same file. Run alongside the rate
/// tests they returned -1 for the count, because by the fifth test the prefs
/// were whatever the first test left behind. ONE STATE PER PROCESS.
///
/// The rate tests live in `flash_rate_bound_test.dart` and need no prefs state
/// beyond reaching Home once.
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

  testWidgets('5. ⛔ EVERY TAP STILL CREATES A RECORD, at 150 ms',
      (tester) async {
    // The standing rule, and it outranks the fix. 150 ms is inside the hold,
    // so every one of these taps is display-suppressed or merged.
    await pumpHome(tester);
    final before = recordsOnScreen(tester);
    expect(before, greaterThanOrEqualTo(0), reason: 'the counter must work');
    final (onsets, taps) = await run(tester, intervalMs: 150);
    await tester.pumpAndSettle();
    final after = recordsOnScreen(tester);
    // ignore: avoid_print
    print('RECORDS 150ms taps=$taps onsets=$onsets before=$before after=$after');
    expect(after - before, taps,
        reason: 'EVERY tap records. The flash is decorative; the record is not');
  });
}
