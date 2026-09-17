import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/screens/disclaimer_screen.dart';
import 'package:medical_event_recorder/screens/event_wizard_screen.dart';
import 'package:medical_event_recorder/screens/help_screen.dart';
import 'package:medical_event_recorder/screens/log_event_screen.dart';
import 'package:medical_event_recorder/theme/mer_theme.dart';

/// THE SPACING SCALE — `{0, 16, 24}` — AND WHY IT CANNOT BE FULLY ASSERTED.
///
/// ⛔ **THE HONEST RESULT, AND IT IS A NEGATIVE ONE: "a screen's horizontal
/// body inset" IS NOT A READABLE PROPERTY.** It is a STRUCTURAL fact — which
/// `Padding` is the body's — and neither of the two available instruments can
/// recover it. **Both were tried and both were wrong, on the same screens:**
///
///     INSTRUMENT            disclaimer   help    WHY IT FAILS
///     source parse          14           16      picks the wrong Padding; it
///     (Brief 46)                                 cannot tell the body's from
///                                                an inner card's
///     render: leftmost      14           31      measures the SUM of every
///     text vs viewport                           inset down to the content,
///     (this file, v1)                            and the body Padding may sit
///                                                OUTSIDE the Scrollable, so
///                                                the frame already contains it
///
/// ⭐ **`disclaimer` is `fromLTRB(16, 20, 16, 20)` in source and reads 14 from
/// the render** — its body `Padding` wraps the `Scrollable`, so the viewport's
/// own left edge already includes the inset and what remains is an inner card's
/// 14. **The number was real; it was a different number.**
///
/// ⛔ **SO THE SCALE IS A CONVENTION, NOT A RULE**, and that distinction is
/// recorded here rather than papered over with a gate that would pass by
/// accident. ⚠️ **What follows gates the TWO screens where the render measure
/// IS sound — those whose body padding is the scroll host's own, so the
/// viewport frame excludes it.** ⭐ **That classification is HAND-MADE, which
/// is precisely the admission this file exists to make.**
///
/// ⚠️ Measured under ROBOTO.

const kScale = <int>{0, 16, 24};

void main() {
  setUpAll(() async {
    final path =
        '${Platform.environment['FLUTTER_ROOT'] ?? 'C:/Flutter/flutter'}'
        '/bin/cache/artifacts/material_fonts/roboto-regular.ttf';
    final file = File(path);
    if (!file.existsSync()) {
      fail('Roboto not found at $path');
    }
    final bytes = file.readAsBytesSync();
    final loader = FontLoader('Roboto')
      ..addFont(Future.value(bytes.buffer.asByteData()));
    await loader.load();
  });

  Future<double> renderInset(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(theme: MERTheme.light, home: screen));
    await tester.pumpAndSettle();
    for (var e = tester.takeException(); e != null; e = tester.takeException()) {}

    final body = tester.getRect(find.byType(Scrollable).first);
    final texts = find.descendant(
        of: find.byType(Scrollable).first, matching: find.byType(Text));
    expect(texts, findsWidgets,
        reason: 'positive control: the screen rendered text at all');

    var leftMost = double.infinity;
    for (final e in texts.evaluate()) {
      final box = e.renderObject as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final l = box.localToGlobal(Offset.zero).dx;
      if (l < leftMost) leftMost = l;
    }
    return leftMost - body.left;
  }

  testWidgets('GATE — the two screens whose inset is readable are on the scale',
      (tester) async {
    // ⛔ HAND-CLASSIFIED, and that is the limit. These two put the body padding
    // on the SingleChildScrollView itself, so it lies INSIDE the Scrollable's
    // rect and the render measure recovers it. Screens that wrap the Scrollable
    // in a Padding do not have this property and are excluded below by name.
    final readable = <String, double>{
      'event_wizard': await renderInset(tester, const EventWizardScreen()),
      'log_event':
          await renderInset(tester, const LogEventScreen(confirmOnSave: false)),
    };

    // ignore: avoid_print
    print('SPACING SCALE @375x667, Roboto — scale ${kScale.toList()}\n'
        '  COVERAGE: ${readable.length} of 12 screens.\n'
        '  EXCLUDED, BY NAME AND REASON — an exclusion nobody can enumerate is\n'
        '  an exclusion nobody can audit:\n'
        '    disclaimer, history  body Padding wraps the Scrollable, so the\n'
        '                         viewport frame already contains the inset\n'
        '    help, your_data      inner Paddings sit between the host and the\n'
        '                         leftmost text, so the render reads the SUM\n'
        '    about                full-bleed hero — its 0 is deliberate and a\n'
        '                         reader cannot tell it from a drifted 0\n'
        '    conditions, vocabulary, medication   rows inset themselves; the\n'
        '                         body inset is 0 by design\n'
        '    walkthrough          its 24 is inside _StepPage, not a body inset\n'
        '    home                 needs a prefs fixture to mount');
    for (final e in readable.entries) {
      // ignore: avoid_print
      print('    ${e.key.padRight(14)} inset=${e.value.toStringAsFixed(1)}'
          '  ${kScale.contains(e.value.round()) ? "on scale" : "⛔ OFF SCALE"}');
    }

    for (final e in readable.entries) {
      expect(kScale.contains(e.value.round()), isTrue,
          reason: 'THE GATE: ${e.key} reads ${e.value}, which is not on the '
              'spacing scale ${kScale.toList()}');
    }
  });

  testWidgets('CONTROL — the instrument DOES disagree where it is unsound',
      (tester) async {
    // ⛔ This pins the negative result so it is not re-derived as a surprise.
    // Both screens are on the scale in SOURCE; the render measure returns
    // something else, and that is the evidence the property is not readable.
    final disclaimer = await renderInset(tester, const DisclaimerScreen());
    final help       = await renderInset(tester, const HelpScreen());

    // ignore: avoid_print
    print('CONTROL — where the render measure is UNSOUND\n'
        '  disclaimer  source=16  render=${disclaimer.toStringAsFixed(1)}\n'
        '  help        source=16  render=${help.toStringAsFixed(1)}\n'
        '  ⭐ Both are correct on the scale. The instrument is what is wrong.');

    expect(kScale.contains(disclaimer.round()), isFalse,
        reason: 'if this ever passes, the render measure has become sound for '
            'a Padding-wrapped body and the gate above can be widened');
    expect(kScale.contains(help.round()), isFalse,
        reason: 'same — a change here means the exclusion list can shrink');
  });
}
