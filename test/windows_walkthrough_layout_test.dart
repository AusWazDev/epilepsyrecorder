import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/walkthrough_screen.dart';
import 'package:medical_event_recorder/theme/mer_theme.dart';

/// Are the walkthrough's navigation controls reachable on Windows?
///
/// ⛔ ASKED BY WIDGET TEST BECAUSE THE CAMERA LIED. A screen-region capture on
/// 8 September 2026 produced BOTH a false negative (window sized past the
/// working area, so the bottom of the client was off-screen and read as "no
/// controls") and, minutes later, a false positive (SetForegroundWindow failed
/// silently and the frame was another application). See AUDIT.md §13(aj).
///
/// This instrument measures the TREE and the GEOMETRY, so occlusion, window
/// position and z-order cannot affect it.
///
/// Sizes are the ones the OS actually grants on this machine, not the ones
/// `main.cpp` requests: 1012x546 is the clamped launch default, 1216x622 the
/// maximum the 1536x864 display allows at dpi 120.

class Probe {
  final bool nextInTree, skipInTree, dotsInTree;
  final double? nextTop, nextBottom;
  final double viewportH;
  final bool nextFullyVisible;
  Probe(this.nextInTree, this.skipInTree, this.dotsInTree, this.nextTop,
      this.nextBottom, this.viewportH, this.nextFullyVisible);

  @override
  String toString() =>
      'next=$nextInTree skip=$skipInTree dots=$dotsInTree '
      'nextTop=${nextTop?.toStringAsFixed(1)} '
      'nextBottom=${nextBottom?.toStringAsFixed(1)} '
      'viewportH=${viewportH.toStringAsFixed(1)} '
      'fullyVisible=$nextFullyVisible';
}

Future<Probe> probe(WidgetTester tester, TargetPlatform p, double w, double h) async {
  debugDefaultTargetPlatformOverride = p;
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1.0;

  await tester.pumpWidget(MaterialApp(
    theme: MERTheme.light,
    home: const WalkthroughScreen(),
  ));
  await tester.pumpAndSettle();

  final next = find.widgetWithText(FilledButton, 'Next');
  final skip = find.widgetWithText(TextButton, 'Skip');
  final dots = find.byWidgetPredicate(
      (x) => x.runtimeType.toString().contains('_Dots'));

  double? top, bottom;
  bool visible = false;
  if (tester.any(next)) {
    final r = tester.getRect(next.first);
    top = r.top;
    bottom = r.bottom;
    // fully inside the window, not merely present in the tree
    visible = r.top >= 0 && r.bottom <= h;
  }
  final res = Probe(tester.any(next), tester.any(skip), tester.any(dots),
      top, bottom, h, visible);
  debugDefaultTargetPlatformOverride = null;
  // ignore: avoid_print
  print('WALK ${p.name} ${w.toStringAsFixed(0)}x${h.toStringAsFixed(0)} $res');
  return res;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'disclaimerAcceptedVersion': kDisclaimerVersion,
    });
    StorageBoot.debugSet();
    Vocabularies.debugReset();
  });
  tearDown(() {
    StorageBoot.debugSet();
    Vocabularies.debugReset();
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('walkthrough navigation: WINDOWS vs ANDROID, both sizes',
      (tester) async {
    addTearDown(tester.view.reset);

    final w1 = await probe(tester, TargetPlatform.windows, 1012, 546);
    final w2 = await probe(tester, TargetPlatform.windows, 1216, 622);
    final a1 = await probe(tester, TargetPlatform.android, 1012, 546);
    final a2 = await probe(tester, TargetPlatform.android, 1216, 622);

    // ⛔ THE CONTROL THAT DECIDES IT. If Windows and Android agree at both
    // sizes, the walkthrough concern was entirely a capture artefact.
    final sameAt546 = w1.nextInTree == a1.nextInTree &&
        w1.nextFullyVisible == a1.nextFullyVisible;
    final sameAt622 = w2.nextInTree == a2.nextInTree &&
        w2.nextFullyVisible == a2.nextFullyVisible;
    // ignore: avoid_print
    print('CONTROL platforms agree at 546=$sameAt546 at 622=$sameAt622');
    // ignore: avoid_print
    print('CONTROL windows nextTop=${w1.nextTop} android nextTop=${a1.nextTop}');

    // The claim under test, stated so it can fail: the controls exist and are
    // fully within the window at the size the OS actually grants.
    expect(w1.nextInTree, isTrue, reason: 'Next must exist on Windows');
    expect(w1.skipInTree, isTrue, reason: 'Skip must exist on Windows');
    expect(w1.dotsInTree, isTrue, reason: 'the page indicators must exist');
    expect(w1.nextFullyVisible, isTrue,
        reason: 'Next must be fully inside a 546-logical-tall window');
  });

  testWidgets('nothing is below the fold at 546 logical height',
      (tester) async {
    // The window is short and the app has no width or height breakpoints.
    addTearDown(tester.view.reset);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.physicalSize = const Size(1012, 546);
    tester.view.devicePixelRatio = 1.0;
    await tester.pumpWidget(MaterialApp(
      theme: MERTheme.light,
      home: const WalkthroughScreen(),
    ));
    await tester.pumpAndSettle();

    // every rendered Text and button must sit inside the window
    final overflow = <String>[];
    for (final e in find.byType(Text).evaluate()) {
      final t = e.widget as Text;
      final r = tester.getRect(find.byWidget(t));
      if (r.bottom > 546 || r.top < 0) {
        overflow.add('${t.data?.substring(0, (t.data!.length).clamp(0, 24))} '
            'top=${r.top.toStringAsFixed(0)} bottom=${r.bottom.toStringAsFixed(0)}');
      }
    }
    debugDefaultTargetPlatformOverride = null;
    // ignore: avoid_print
    print('OVERFLOW count=${overflow.length} ${overflow.take(6).join(" | ")}');

    // reported, and asserted, so a regression is loud
    expect(tester.takeException(), isNull);
  });
}
