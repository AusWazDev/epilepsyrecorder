import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/home_screen.dart';

import 'narrow_probe.dart';

/// AUDIT.md §13(as) on HOME.
///
/// ⛔ THE FIRST RUN OF THIS FILE PRODUCED A CONTRADICTION, AND IT IS THE WHOLE
/// FINDING. Probing 400 logical as the FIRST pump in the process raised
/// "A RenderFlex overflowed by 8.0 pixels on the right." Sweeping down to the
/// SAME width later in the same test raised nothing, with an identical
/// `widestText` of 313. Same width, same height, same platform, opposite
/// verdicts.
///
/// ⭐ SO PUMP ORDER IS A CANDIDATE CAUSE ALONGSIDE WIDTH AND DPR, and a
/// threshold measured without settling that would be a number attached to the
/// wrong variable. Phase A discriminates before Phase B measures.
///
/// ⚠️ `FlutterError.onError` captures errors raised in EVERY frame of pump and
/// settle, including transient intermediate ones. A first pump of HomeScreen
/// loads vocabularies and records; later pumps in the same process reuse them.
/// That is the mechanism this file tests for.
///
/// ⛔ ONE PREFS-DEPENDENT TEST IN THIS FILE, per `CLAUDE.md`. The DPR control
/// that must run FIRST in a process lives in
/// `narrow_exception_home_dpr1_test.dart`, because "first pump in a fresh
/// process" cannot be arranged twice in one file.

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

  testWidgets('HOME — order vs width vs DPR, then thresholds', (tester) async {
    addTearDown(tester.view.reset);
    Widget build() => const MaterialApp(home: HomeScreen());

    Future<void> report(String tag, Probe p) async {
      // ignore: avoid_print
      print('  PROBE $tag w=${p.logicalW.toStringAsFixed(0)} dpr=${p.dpr} '
          '${p.platform.name} errors=${p.errors.length} '
          'overflowingTexts=${p.overflowingTexts} '
          'widestText=${p.widestText.toStringAsFixed(1)} '
          'types=${p.types.join("|")} '
          'first=${p.firstLines.isEmpty ? "-" : p.firstLines.first}');
    }

    // ================= PHASE A — discriminate order, width, DPR =============
    // A1-A3: the same width three times. If only the first throws, the cause is
    // ORDER (a transient first-load frame), not width.
    final a1 = await probeAt(tester,
        platform: TargetPlatform.windows, dpr: 1.25,
        logicalW: 400, logicalH: 546, build: build);
    await report('A1 first-pump', a1);
    if (a1.errors.isNotEmpty) dumpError('A1 home 400 windows dpr=1.25', a1.errors.first);

    await report('A2 repeat', await probeAt(tester,
        platform: TargetPlatform.windows, dpr: 1.25,
        logicalW: 400, logicalH: 546, build: build));
    await report('A3 repeat', await probeAt(tester,
        platform: TargetPlatform.windows, dpr: 1.25,
        logicalW: 400, logicalH: 546, build: build));

    // A4: DPR 1.0 at the same width, AFTER the first pump. Compare against the
    // dpr-1.0-first file to separate DPR from order.
    await report('A4 dpr1.0', await probeAt(tester,
        platform: TargetPlatform.windows, dpr: 1.0,
        logicalW: 400, logicalH: 546, build: build));

    // A5: android at the same width, so platform is controlled too.
    await report('A5 android', await probeAt(tester,
        platform: TargetPlatform.android, dpr: 1.25,
        logicalW: 400, logicalH: 546, build: build));

    // A6: the other named width from §13(as).
    final a6 = await probeAt(tester,
        platform: TargetPlatform.windows, dpr: 1.25,
        logicalW: 94, logicalH: 546, build: build);
    await report('A6 w=94', a6);
    if (a6.errors.isNotEmpty) dumpError('A6 home 94 windows dpr=1.25', a6.errors.first);

    // A7: a comfortable width, as the ordering control.
    await report('A7 w=1200', await probeAt(tester,
        platform: TargetPlatform.windows, dpr: 1.25,
        logicalW: 1200, logicalH: 546, build: build));

    // ================= PHASE B — DELIBERATELY REMOVED =======================
    // ⛔ A THRESHOLD SWEEP PREDICATED ON `threw` IS INVALID AND ITS OUTPUT WAS
    // MISLEADING. It ran here and reported every width from 1200 down to 100 as
    // CLEAN, on all four platform/DPR combinations, with `failing=null` — while
    // the layout was overflowing by 8 px at 400 the whole time.
    //
    // The cause is in `narrow_geometry.dart`: `RenderFlex` reports an overflow
    // ONCE per render-object instance per process, so Phase A above had already
    // consumed the report before Phase B started sweeping.
    //
    // ⭐ IT IS REMOVED RATHER THAN KEPT AS A CURIOSITY, because a test that
    // prints "clean" for a width that overflows is exactly the wrong-but-
    // well-formed output this repository keeps being caught by. The valid
    // measurement lives in `narrow_geometry_home_test.dart` and reports the
    // boundary at 408 (Windows) and 416 (Android/iOS).
    //
    // Phase A is KEPT: it is the evidence for the once-per-instance finding.

    final control = await probeAt(tester,
        platform: TargetPlatform.windows, dpr: 1.25,
        logicalW: 1200, logicalH: 546, build: build);
    expect(control.errors, isEmpty,
        reason: 'a comfortable width must still be clean AFTER the sweep');
  });
}
