import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/screens/event_wizard_screen.dart';

/// The wizard's step navigation must be REACHABLE WITHOUT SCROLLING.
///
/// ## ⛔ WHAT "THE FOLD" MEANS, BECAUSE TWO DIFFERENT FOLDS PRODUCE TWO
/// ## DIFFERENT ANSWERS AND ONE OF THEM IS NOT A DEFECT
///
///     THE SCREEN's bottom          667 at this size — what the USER can see
///     THE SCROLL VIEWPORT's bottom 591 — where the SCROLLING REGION ends
///
/// ⭐ **A PINNED FOOTER SITS BETWEEN THEM BY DESIGN.** `_footer` is a sibling
/// of the `Expanded(SingleChildScrollView(...))`, not a child of it, so it is
/// correctly *below the scroll viewport* and correctly *on the screen*.
///
/// ⛔ **`notes_reachability_test`'s FOLD CENSUS measures against the SCROLL
/// VIEWPORT**, which is right for the question it asks — whether raising the
/// notes field buries some other field inside the scrolling content. ⚠️ **Read
/// as a statement about what the USER can see, it reports the pinned footer as
/// "below the fold", and that reading is wrong.** This file measures against
/// the SCREEN, which is the question "can the user see it" actually asks.
///
/// ⛔ **THE CONTROL IS THE LOAD-BEARING PART.** A test that only ever passes is
/// indistinguishable from one that is not looking. The second test here runs
/// the SAME predicate against the SCROLL VIEWPORT's bottom and requires it to
/// FIRE — reproducing the 613-against-591 case exactly — so a pass in the first
/// test is evidence the predicate works rather than evidence it is asleep.

// ⛔ CONCRETE types, not `ButtonStyleButton`. `find.byType` matches the EXACT
// runtimeType, so the abstract base finds nothing and the positive control
// fires on a fault in the FINDER rather than in the layout. Caught that way.
const kControls = <(String, Type)>[('Back', OutlinedButton),
                                   ('Review', FilledButton)];

void main() {
  setUpAll(() async {
    final path =
        '${Platform.environment['FLUTTER_ROOT'] ?? 'C:/Flutter/flutter'}'
        '/bin/cache/artifacts/material_fonts/roboto-regular.ttf';
    final file = File(path);
    if (!file.existsSync()) {
      fail('Roboto not found at $path — the harness font would inflate every '
          'wrap, and wrapping decides where the footer ends up');
    }
    final bytes = file.readAsBytesSync();
    final loader = FontLoader('Roboto')
      ..addFont(Future.value(bytes.buffer.asByteData()));
    await loader.load();
  });

  /// Drives the wizard to its LAST step, where both controls are present.
  Future<void> toLastStep(WidgetTester tester, double scale) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(const MaterialApp(home: EventWizardScreen()));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    // ⛔ COLLECTED, NOT DRAINED. A blind `takeException` loop here would
    // swallow the one thing that could contradict this file's conclusion: the
    // footer does not grow at 200%, so if its labels no longer fit, the
    // evidence arrives as an overflow exception and nowhere else.
    final caught = <String>[];
    for (var e = tester.takeException(); e != null; e = tester.takeException()) {
      caught.add(e.toString().split('\n').first);
    }
    if (caught.isNotEmpty) {
      // ignore: avoid_print
      print('  ⚠️ EXCEPTIONS AT SCALE $scale (${caught.length}):');
      for (final c in caught) {
        // ignore: avoid_print
        print('      $c');
      }
    }
  }

  // ⛔ ONE SCALE PER TEST, not a loop inside one. A second `pumpWidget` in the
  // same test reuses the element for the same widget type, so the wizard is
  // still on its last step and `Next` is gone — the loop failed on its second
  // pass for that reason, not for a layout one.
  Future<void> checkAt(WidgetTester tester, double scale) async {
    {
      await toLastStep(tester, scale);

      final screen   = tester.view.physicalSize.height /
                       tester.view.devicePixelRatio;
      final scrollTo = tester.getRect(find.byType(Scrollable).first);

      // ── the measurements the brief asks for ──
      final footerHeight = screen - scrollTo.bottom;
      final usableBody   = scrollTo.height;

      // ⛔ THE HARNESS CONTROL, and it is not optional. The footer and viewport
      // figures come out IDENTICAL at 1.0 and 2.0, which is exactly the shape
      // this project treats as a harness fault until proven otherwise. So
      // measure something that MUST scale and prove it did — otherwise the
      // 200% row is fiction that happens to agree with the 100% row.
      final heading = tester.getRect(
          find.text('How were things afterwards?').first);
      final scaled = heading.height;

      // ignore: avoid_print
      print('WIZARD NAV @375x667, scale $scale, Roboto\n'
          '  screen bottom (the real fold)   : ${screen.toStringAsFixed(1)}\n'
          '  scroll viewport                 : '
          '${scrollTo.top.toStringAsFixed(1)}'
          '..${scrollTo.bottom.toStringAsFixed(1)}\n'
          '  ⭐ usable body height            : '
          '${usableBody.toStringAsFixed(1)}\n'
          '  ⭐ footer + inset below viewport : '
          '${footerHeight.toStringAsFixed(1)}\n'
          '  (footer height is derived from the viewport, not from a Row '
          'finder — an inner Row matches first)\n'
          '  CONTROL body heading height     : '
          '${scaled.toStringAsFixed(1)}  (must differ between scales, or the '
          'scale never reached the tree)');

      expect(scale == 1.0 ? scaled < 40.0 : scaled > 40.0, isTrue,
          reason: 'HARNESS CONTROL at scale $scale: the body heading measured '
              '$scaled. If this does not move between 1.0 and 2.0 the text '
              'scale is not reaching the widgets and every other number here '
              'is meaningless');

      for (final (label, type) in kControls) {
        final f = find.widgetWithText(type, label);
        expect(f, findsOneWidget,
            reason: 'positive control at scale $scale: "$label" is in the tree '
                'at all, so the geometry below is about something');

        final r = tester.getRect(f);
        // ignore: avoid_print
        print('    $label'.padRight(12) +
            ' top=${r.top.toStringAsFixed(1)}  '
            'bottom=${r.bottom.toStringAsFixed(1)}');

        expect(r.bottom, lessThanOrEqualTo(screen),
            reason: 'THE ASSERTION: "$label" must be fully on screen at scale '
                '$scale without scrolling. It ends at ${r.bottom} against a '
                'screen bottom of $screen');
      }
    }
  }

  testWidgets('every navigation control is ON SCREEN at 100%', (tester) async {
    await checkAt(tester, 1.0);
  });

  testWidgets('every navigation control is ON SCREEN at 200%', (tester) async {
    await checkAt(tester, 2.0);
  });

  testWidgets('CONTROL — the same predicate FIRES against the scroll viewport',
      (tester) async {
    // ⛔ This reproduces the 613-against-591 reading. It is not a defect; it is
    // the pinned footer doing its job. The test exists so that a pass above
    // cannot be mistaken for a predicate that never fires.
    await toLastStep(tester, 1.0);

    final viewportBottom = tester.getRect(find.byType(Scrollable).first).bottom;

    var firedFor = <String>[];
    for (final (label, type) in kControls) {
      final r = tester.getRect(find.widgetWithText(type, label));
      if (r.top >= viewportBottom) firedFor.add(label);
    }

    // ignore: avoid_print
    print('CONTROL — measured against the SCROLL VIEWPORT bottom '
        '${viewportBottom.toStringAsFixed(1)}\n'
        '  controls below it: ${firedFor.join(", ")}  '
        '(this is the 613-vs-591 case, and it is correct behaviour)');

    expect(firedFor, equals([for (final (label, _) in kControls) label]),
        reason: 'the predicate must be able to report a control as below a '
            'boundary — if this passes vacuously the assertion above proves '
            'nothing');
  });
}
