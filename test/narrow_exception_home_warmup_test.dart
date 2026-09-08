import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/home_screen.dart';

import 'narrow_probe.dart';

/// ⛔ IS THE 400-LOGICAL OVERFLOW A REAL FIRST-LAYOUT DEFECT, OR A PROCESS
/// WARM-UP ARTEFACT OF THE TEST HARNESS? This file discriminates, and the
/// answer decides whether §13(as) is a defect or a note.
///
/// The overflow owner is home's app-bar title `Row`, whose contents are
/// `const` — a fixed icon, a fixed gap and two fixed strings. ⭐ NOTHING IN IT
/// IS DATA-DEPENDENT, so "it overflows on the first pump and not the second"
/// cannot be explained by loading records or vocabularies.
///
/// ⭐ THE DISCRIMINATION, STATED BEFORE THE RESULT:
///   - pump a TRIVIAL widget first, then home at 400:
///       overflow GONE     -> the first pump in a PROCESS is the variable, so
///                            it is a harness warm-up artefact and no user
///                            layout is at fault
///       overflow PRESENT  -> home's own first layout overflows, which a real
///                            app also performs, and it is a real (if
///                            single-frame) defect
///
/// ⚠️ This is the rival-prediction rule from `CLAUDE.md` applied up front: the
/// two hypotheses predict OPPOSITE outcomes here, which is what the DPI-96 test
/// failed to arrange.

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

  testWidgets('HOME — trivial pump first, then 400 logical', (tester) async {
    addTearDown(tester.view.reset);

    // A trivial first pump, at the SAME metrics, so the only thing consumed is
    // whatever process-level warm-up exists.
    final warm = await probeAt(tester,
        platform: TargetPlatform.windows, dpr: 1.25,
        logicalW: 400, logicalH: 546,
        build: () => const MaterialApp(
            home: Scaffold(body: Center(child: Text('warm-up')))));
    // ignore: avoid_print
    print('  WARMUP trivial pump errors=${warm.errors.length}');

    final p = await probeAt(tester,
        platform: TargetPlatform.windows, dpr: 1.25,
        logicalW: 400, logicalH: 546,
        build: () => const MaterialApp(home: HomeScreen()));
    // ignore: avoid_print
    print('  AFTER-WARMUP home w=400 dpr=1.25 windows '
        'errors=${p.errors.length} overflowingTexts=${p.overflowingTexts} '
        'widestText=${p.widestText.toStringAsFixed(1)} '
        'first=${p.firstLines.isEmpty ? "-" : p.firstLines.first}');
    if (p.errors.isNotEmpty) dumpError('after-warmup home 400', p.errors.first);

    // And 94 after warm-up, to confirm the PERSISTENT fault is unaffected by
    // whatever the warm-up consumes.
    final n = await probeAt(tester,
        platform: TargetPlatform.windows, dpr: 1.25,
        logicalW: 94, logicalH: 546,
        build: () => const MaterialApp(home: HomeScreen()));
    // ignore: avoid_print
    print('  AFTER-WARMUP home w=94 errors=${n.errors.length} '
        'first=${n.firstLines.isEmpty ? "-" : n.firstLines.first}');

    expect(true, isTrue, reason: 'diagnostic file; the print output is the result');
  });
}
