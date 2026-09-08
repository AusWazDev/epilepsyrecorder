import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/home_screen.dart';

import 'narrow_geometry.dart';

/// ⛔ HOME'S APP-BAR TITLE OVERFLOWS BELOW 408 LOGICAL. THE CAPTURE SET
/// CONTAINS 375. This checks the widths of REAL SHIPPED DEVICES rather than the
/// synthetic narrow-window widths §13(as) and §13(am) were about.
///
/// ⭐ If this overflows at 375, it is not a desktop narrow-window edge case at
/// all — it is every small phone, on the screen §7 calls "the best-composed
/// screen in the app", and it has been in the capture set the whole time.
///
/// One prefs-dependent test, per `CLAUDE.md`.

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

  testWidgets('HOME at real device widths', (tester) async {
    addTearDown(tester.view.reset);
    Widget build() => const MaterialApp(home: HomeScreen());

    // Real logical sizes. The first three are in the design-audit capture set;
    // 320 and 360 are shipped phone widths; 1012 is what the Windows build is
    // actually granted per §13(ak).
    const cases = <(String, double, double, double)>[
      ('iPhone SE 1st gen',        320, 568, 2.0),
      ('common Android phone',     360, 800, 3.0),
      ('iPhone 8 / SE2 - CAPTURED', 375, 667, 2.0),
      ('iPhone 15 Pro Max - CAPTURED', 430, 932, 3.0),
      ('tablet proxy - CAPTURED',  800, 1280, 1.0),
      ('Windows granted (13ak)',   1012, 546, 1.25),
    ];

    for (final (label, w, h, dpr) in cases) {
      final g = await measureAt(tester,
          platform: TargetPlatform.android, dpr: dpr,
          logicalW: w, logicalH: h, build: build);
      // ignore: avoid_print
      print('  DEVICE ${w.toStringAsFixed(0)}x${h.toStringAsFixed(0)} dpr=$dpr '
          '${g.flexOverflowed ? "OVERFLOW ${g.worstPx.toStringAsFixed(1)}px" : "clean"}'
          '  paras=${g.paragraphs} texts=${g.overflowingTexts}  $label');
      for (final o in g.overflows.take(2)) {
        // ignore: avoid_print
        print('       $o');
      }
    }

    // Windows too, at the same widths, so the platform control is explicit.
    for (final w in <double>[375, 430]) {
      final g = await measureAt(tester,
          platform: TargetPlatform.windows, dpr: 1.25,
          logicalW: w, logicalH: 667, build: build);
      // ignore: avoid_print
      print('  DEVICE-WINDOWS ${w.toStringAsFixed(0)} '
          '${g.flexOverflowed ? "OVERFLOW ${g.worstPx.toStringAsFixed(1)}px" : "clean"}');
    }

    // ⭐ THE MODEL, PREDICTED BEFORE MEASURING SO THE SWEEP CAN FALSIFY IT.
    // The title Row wants a fixed 336. Available width is `logicalW - actions`,
    // and the single action is 48 wide under `MaterialTapTargetSize.padded`
    // (Android, Fuchsia, iOS) against 40 under `shrinkWrap` (Windows) — §13(y).
    // So: Android threshold 336 + 80 = 416, Windows 336 + 72 = 408.
    // Four independent points already fit: 320/96, 360/56, 375/41 (android),
    // 375/33 (windows). This sweep tests the PREDICTED BOUNDARY.
    await sweep(tester,
        screen: 'home/FINE-android', platform: TargetPlatform.android, dpr: 3.0,
        logicalH: 800, build: build, from: 420, to: 410, step: 1);
    await sweep(tester,
        screen: 'home/FINE-ios', platform: TargetPlatform.iOS, dpr: 3.0,
        logicalH: 800, build: build, from: 420, to: 410, step: 1);

    expect(true, isTrue, reason: 'diagnostic; the print output is the result');
  });
}
