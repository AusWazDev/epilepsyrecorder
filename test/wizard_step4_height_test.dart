import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/screens/event_wizard_screen.dart';

/// Wizard step 4's content height at 375×667 — the before/after instrument for
/// the spacing-scale change, and a standing measurement afterwards.
///
/// ⭐ **THE HYPOTHESIS THIS EXISTS TO TEST:** `event_wizard`'s body inset goes
/// 20 → 16, giving the content **8 more logical points of width**, and wider
/// content may let the observation chips wrap into FEWER ROWS — which would
/// reduce VERTICAL height on the screen where the vertical budget is worst.
///
/// ⛔ **IT IS A HYPOTHESIS AND THIS FILE DOES NOT ASSUME IT.** If the height is
/// unchanged, that is a clean result and the spacing change stands on
/// consistency alone.
///
/// ⚠️ **`maxScrollExtent` is the instrument, and that it is not saturated is
/// ASSERTED** — it reads zero whenever content fits, which would report the
/// viewport height for a full step and an empty one alike.
///
/// ⚠️ Measured under ROBOTO. Chip wrapping is the whole subject, and the
/// harness font is monospaced at one em per glyph.

void main() {
  setUpAll(() async {
    final path =
        '${Platform.environment['FLUTTER_ROOT'] ?? 'C:/Flutter/flutter'}'
        '/bin/cache/artifacts/material_fonts/roboto-regular.ttf';
    final file = File(path);
    if (!file.existsSync()) {
      fail('Roboto not found at $path — chip wrapping is what this measures');
    }
    final bytes = file.readAsBytesSync();
    final loader = FontLoader('Roboto')
      ..addFont(Future.value(bytes.buffer.asByteData()));
    await loader.load();
  });

  Future<void> measure(WidgetTester tester, double scale) async {
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

    final scrollable = find.byType(Scrollable).first;
    final pos        = tester.state<ScrollableState>(scrollable).position;
    final viewRect   = tester.getRect(scrollable);

    final distance = pos.maxScrollExtent;
    final viewport = pos.viewportDimension;
    final content  = viewport + distance;

    // ⭐ THE ROW COUNT, which is what the hypothesis is actually about. Chips
    // on the same wrap row share a `top`, so counting DISTINCT tops counts
    // rows without needing to know how the Wrap is built.
    final tops = <String>{};
    for (final e in find.byType(RawChip).evaluate()) {
      final box = e.renderObject! as RenderBox;
      tops.add(box.localToGlobal(Offset.zero).dy.toStringAsFixed(1));
    }

    // ⛔ THE CONTROL THAT MAKES AN UNCHANGED HEIGHT MEAN SOMETHING. The
    // before/after figures came out identical, which this project treats as a
    // harness fault until proven otherwise. So measure the width the content
    // ACTUALLY gets: 375 − 2×20 = 335 under the old inset, 375 − 2×16 = 343
    // under the new one. If this reads 343 the change reached the tree and the
    // unchanged height is a real result rather than an unapplied edit.
    final firstChip = tester.getRect(find.byType(RawChip).first);
    final contentLeft = firstChip.left;

    // ignore: avoid_print
    print('WIZARD STEP 4 @375x667, scale $scale, Roboto\n'
        '  ⭐ CONTROL content left edge     : '
        '${contentLeft.toStringAsFixed(1)}  '
        '(16 = new inset applied, 20 = not applied)\n'
        '  viewport                        : ${viewport.toStringAsFixed(1)}\n'
        '  ⭐ content height                : ${content.toStringAsFixed(1)}\n'
        '  ⭐ scroll distance               : ${distance.toStringAsFixed(1)}\n'
        '  ⭐ chip wrap rows (distinct tops): ${tops.length}\n'
        '  chips counted                   : '
        '${find.byType(RawChip).evaluate().length}\n'
        '  content region width            : '
        '${viewRect.width.toStringAsFixed(1)}');

    expect(distance, greaterThan(0.0),
        reason: 'CONTROL: maxScrollExtent is not saturated at scale $scale, so '
            'the content figure is real and not the viewport in disguise');
    expect(tops, isNotEmpty,
        reason: 'CONTROL: chips were found, so the row count is about '
            'something');
  }

  testWidgets('step 4 height at 100%', (tester) async {
    await measure(tester, 1.0);
  });

  testWidgets('step 4 height at 200%', (tester) async {
    await measure(tester, 2.0);
  });
}
