import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/home_screen.dart';

import 'narrow_probe.dart';

/// The DPR control for `narrow_exception_home_test.dart`, in its own PROCESS.
///
/// ⛔ WHY A SEPARATE FILE: the variable under test is "the FIRST pump in a fresh
/// process", and that cannot be arranged twice in one file. This file's first
/// pump is DPR 1.0 at the same width where the other file's first pump — DPR
/// 1.25 — raised a RenderFlex overflow.
///
/// ⭐ THE DISCRIMINATION, stated before the result so it cannot be fitted
/// afterwards:
///   - first pump throws HERE too      -> the cause is ORDER, and DPR is
///                                        irrelevant
///   - first pump is CLEAN here        -> the cause involves DPR, because order
///                                        and width are held identical
///
/// ⚠️ Prefs-dependent, so exactly one test, per `CLAUDE.md`'s harness rule.

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

  testWidgets('HOME — DPR 1.0 as the FIRST pump in the process', (tester) async {
    addTearDown(tester.view.reset);
    Widget build() => const MaterialApp(home: HomeScreen());

    void report(String tag, Probe p) {
      // ignore: avoid_print
      print('  PROBE-DPR1 $tag w=${p.logicalW.toStringAsFixed(0)} dpr=${p.dpr} '
          '${p.platform.name} errors=${p.errors.length} '
          'overflowingTexts=${p.overflowingTexts} '
          'widestText=${p.widestText.toStringAsFixed(1)} '
          'first=${p.firstLines.isEmpty ? "-" : p.firstLines.first}');
    }

    final b1 = await probeAt(tester,
        platform: TargetPlatform.windows, dpr: 1.0,
        logicalW: 400, logicalH: 546, build: build);
    report('B1 first-pump dpr1.0', b1);
    if (b1.errors.isNotEmpty) dumpError('B1 home 400 windows dpr=1.0', b1.errors.first);

    // And the 1.25 case second, so this file also reports the reverse ordering.
    final b2 = await probeAt(tester,
        platform: TargetPlatform.windows, dpr: 1.25,
        logicalW: 400, logicalH: 546, build: build);
    report('B2 second-pump dpr1.25', b2);
    if (b2.errors.isNotEmpty) dumpError('B2 home 400 windows dpr=1.25', b2.errors.first);

    expect(true, isTrue, reason: 'diagnostic file; the print output is the result');
  });
}
