import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/home_screen.dart';

import 'narrow_geometry.dart';

/// HOME — flex-overflow geometry across width, for §13(as) and D2.
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

  testWidgets('HOME geometry sweep', (tester) async {
    addTearDown(tester.view.reset);
    Widget build() => const MaterialApp(home: HomeScreen());

    // The two widths §13(as) names, reported in full first.
    for (final w in <double>[400, 94]) {
      final g = await measureAt(tester,
          platform: TargetPlatform.windows, dpr: 1.25,
          logicalW: w, logicalH: 546, build: build);
      // ignore: avoid_print
      print('  NAMED home w=${w.toStringAsFixed(0)} '
          'texts=${g.overflowingTexts} flexOverflows=${g.overflows.length}');
      for (final o in g.overflows) {
        // ignore: avoid_print
        print('     $o');
      }
    }

    // Windows and Android, DPR 1.25, so platform is controlled.
    for (final p in <TargetPlatform>[TargetPlatform.windows, TargetPlatform.android]) {
      await sweep(tester,
          screen: 'home', platform: p, dpr: 1.25, logicalH: 546, build: build);
    }
    // DPR control on windows.
    await sweep(tester,
        screen: 'home', platform: TargetPlatform.windows, dpr: 1.0,
        logicalH: 546, build: build);

    // ⭐ FINE BAND. The title Row wants a fixed 336 and receives
    // `logicalW - 72`, so the boundary should be 408 exactly. Predicted BEFORE
    // measuring, so the sweep can falsify it rather than be fitted to it.
    await sweep(tester,
        screen: 'home/FINE', platform: TargetPlatform.windows, dpr: 1.25,
        logicalH: 546, build: build, from: 415, to: 400, step: 1);

    expect(true, isTrue, reason: 'diagnostic; the print output is the result');
  });
}
