import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/vocabulary.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/log_event_screen.dart';
import 'package:medical_event_recorder/theme/mer_theme.dart';

/// The FORM's scroll distance at 375x667 — the last unmeasured figure.
///
/// ⛔ **`maxScrollExtent` SATURATES WHEN THE CONTENT FITS**, which is why
/// `step4_density_test` measures from the last element instead and says so.
/// ⭐ **It does NOT saturate here**, and that is asserted rather than assumed:
/// the form at 375x667 overflows by a wide margin, so `maxScrollExtent` is a
/// real number and is reported as the primary instrument. **The assertion is
/// what makes that claim checkable** — if the form ever shrinks to fit, this
/// test fails loudly instead of quietly reporting the viewport height.
///
/// ## ⚠️ THREE INSTRUMENTS, ON PURPOSE — AND THE THIRD IS HERE TO SHOW A LIMIT
///
///     A  maxScrollExtent                     the scroll distance, directly
///     B  last element bottom + offset        step4_density's technique, aimed
///                                            at the TRUE last child
///     C  TextField.last bottom + offset      step4_density's technique aimed
///                                            the way IT aims it
///
/// ⛔ **C UNDER-REPORTS ON THIS SCREEN AND IS PRINTED SO THE GAP IS VISIBLE.**
/// On the wizard's step 4 the notes field IS the last child. On the form it is
/// not: `SizedBox(28)`, Save (52), `SizedBox(10)`, Cancel (44) and
/// `SizedBox(16)` all follow it. **A technique that is correct on one screen is
/// not correct on the next, and copying it without re-deriving the last child
/// would have lost ~150 points silently.**
///
/// ⚠️ Measured under ROBOTO. The harness font is monospaced at one em per
/// glyph and would inflate every wrap, and wrapping is what content height IS.
///
/// ⛔ THIS FILE MEASURES AND PRINTS. It asserts only that its own instruments
/// are live. No layout compensation, no threshold, no gate.

EventRecord withRescue() => EventRecord(
      id: 'r',
      timestamp: DateTime(2026, 8, 1, 9),
      duration: DurationCategory.oneToFive,
      durationSeconds: 120,
      detailsCompleted: true,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: false,
      notes: '',
      eventType: kTypeSeizure,
      severity: EventSeverity.mild,
      // ⛔ TRUE, so the rescue children are revealed — the same fixture
      // `rescue_fold_position_test` uses, so the two figures are comparable.
      rescueMedGiven: true,
      rescueMedHelped: RescueResponse.partly,
      rescueMedSecondDose: false,
    );

void main() {
  setUpAll(() async {
    final path =
        '${Platform.environment['FLUTTER_ROOT'] ?? 'C:/Flutter/flutter'}'
        '/bin/cache/artifacts/material_fonts/roboto-regular.ttf';
    final file = File(path);
    if (!file.existsSync()) {
      fail('Roboto not found at $path — the harness font would inflate every '
          'wrap, and wrapping is what this measures');
    }
    final bytes = file.readAsBytesSync();
    final loader = FontLoader('Roboto')
      ..addFont(Future.value(bytes.buffer.asByteData()));
    await loader.load();
  });

  setUp(Vocabularies.debugReset);
  tearDown(Vocabularies.debugReset);

  Future<void> report(WidgetTester tester, double scale) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(MaterialApp(
      theme: MERTheme.light,
      home: LogEventScreen(existing: withRescue(), confirmOnSave: false),
    ));
    await tester.pumpAndSettle();
    for (var e = tester.takeException(); e != null; e = tester.takeException()) {}

    final scrollable = find.byType(Scrollable).first;
    final pos        = tester.state<ScrollableState>(scrollable).position;
    final viewRect   = tester.getRect(scrollable);

    // ── A — the scroll distance, directly ──
    final distance = pos.maxScrollExtent;
    final viewport = pos.viewportDimension;
    final content  = viewport + distance;

    // ── B — the TRUE last child: the Cancel button ──
    final cancel     = find.widgetWithText(OutlinedButton, 'Cancel');
    final lastBottom = cancel.evaluate().isEmpty
        ? null
        : tester.getRect(cancel).bottom + pos.pixels - viewRect.top;

    // ── C — step4_density's technique, aimed as IT aims it ──
    final notes       = find.byType(TextField).last;
    final notesBottom =
        tester.getRect(notes).bottom + pos.pixels - viewRect.top;

    String f(double? v) => v == null ? 'NOT FOUND' : v.toStringAsFixed(1);

    // ignore: avoid_print
    print('FORM SCROLL DISTANCE @375x667, scale $scale, Roboto\n'
        '  viewport (the fold is its bottom) : ${f(viewport)}\n'
        '  ⭐ A  maxScrollExtent              : ${f(distance)}\n'
        '     A  content  = viewport + above  : ${f(content)}\n'
        '     B  last child (Cancel) bottom   : ${f(lastBottom)}\n'
        '     C  TextField.last bottom        : ${f(notesBottom)}\n'
        '     C under-reports B by            : '
        '${lastBottom == null ? "n/a" : f(lastBottom - notesBottom)}\n'
        '     trailing padding (A content - B): '
        '${lastBottom == null ? "n/a" : f(content - lastBottom)}');

    // ── the controls: each says one instrument is live ──
    expect(distance, greaterThan(0.0),
        reason: 'CONTROL A: maxScrollExtent is not saturated — the form does '
            'overflow at 375x667, so the figure above is a real scroll '
            'distance and not the viewport height in disguise');
    expect(lastBottom, isNotNull,
        reason: 'CONTROL B: the Cancel button is in the tree, so B measured '
            'the last child rather than silently returning null');
    expect(notesBottom, lessThan(lastBottom!),
        reason: 'CONTROL C: the notes field really does sit above the last '
            'child, which is the whole reason C under-reports here');
  }

  testWidgets('the form, at 100%', (tester) async {
    await report(tester, 1.0);
  });

  testWidgets('the form, at 200%', (tester) async {
    await report(tester, 2.0);
  });
}
