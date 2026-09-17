import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/theme/mer_theme.dart';

/// Free text measurement at 200%, for the type scale and for S2's wording.
///
/// ⛔ **A `TextPainter` LAID OUT FREE, NOT A WIDTH READ OFF A RENDERED
/// PARAGRAPH.** `CLAUDE.md` records why: a paragraph that has already
/// ellipsised reports the SLOT width rather than its own, so the number looks
/// plausible and says nothing. That cost two probes on the app-bar question.
///
/// ⛔ **AND UNDER ROBOTO, NOT THE HARNESS FONT**, which is monospaced at one em
/// per glyph and inflated real widths by roughly 1.8x at 13 px. Any width claim
/// made without naming the font is a number without units.
///
/// ## ⚠️ HOW 200% IS APPLIED, AND THE ONE PART THAT DOES NOT SCALE
///
/// `TextScaler.linear(2.0)` scales `fontSize`. It does **not** scale
/// `letterSpacing`, which is in logical pixels — so a style carrying letter
/// spacing does not simply double. `labelLarge` carries `letterSpacing: 0.8`
/// and that is exactly the style the S2 ceiling was measured on, which is why
/// the figures here are measured rather than computed from a ratio.
///
/// This file measures and PRINTS. It asserts only what it can establish
/// independently of a design decision — the slot arithmetic, and that the
/// apparatus is live.

/// The form's content slot at 375 logical.
///
/// Derived from the widgets rather than taken from the "roughly 343" in the
/// S2 note: `log_event_screen` lays its body out inside a `Padding` of 16 a
/// side within a `SafeArea`, so the text slot is 375 - 32 = 343. Stated here
/// so a reader can check the derivation rather than the number.
const double kSlot375 = 375.0 - 32.0;

double widthOf(String text, TextStyle style, {double scale = 2.0}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.linear(scale),
    maxLines: 1,
  )..layout();
  return tp.width;
}

void main() {
  setUpAll(() async {
    final path =
        '${Platform.environment['FLUTTER_ROOT'] ?? 'C:/Flutter/flutter'}'
        '/bin/cache/artifacts/material_fonts/roboto-regular.ttf';
    final file = File(path);
    if (!file.existsSync()) {
      fail('Roboto not found at $path — a width claim without its font is a '
          'number without units');
    }
    final bytes = file.readAsBytesSync();
    final loader = FontLoader('Roboto')
      ..addFont(Future.value(bytes.buffer.asByteData()));
    await loader.load();
  });

  /// Every style named with an explicit family, so nothing silently resolves to
  /// the engine default — the trap that defeated three probes on the app bar.
  TextStyle style(double size, FontWeight weight, {double? letterSpacing}) =>
      TextStyle(
        fontFamily: 'Roboto',
        fontSize: size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
      );

  test('0. POSITIVE CONTROL: the apparatus discriminates size and font', () {
    final small = widthOf('WAS A SECOND DOSE NEEDED?', style(11, FontWeight.w600));
    final large = widthOf('WAS A SECOND DOSE NEEDED?', style(16, FontWeight.w600));
    expect(large, greaterThan(small),
        reason: 'if these are equal the font did not load and every figure '
            'below is the one-em-per-glyph harness font');
    expect(widthOf('iiiii', style(13, FontWeight.w400)),
        lessThan(widthOf('WWWWW', style(13, FontWeight.w400))),
        reason: 'the harness font measures these identically; Roboto does not');
    // ignore: avoid_print
    print('CONTROL  slot@375 = $kSlot375');
  });

  test('1. REPORT (a): the widget carrying the 335.7 ceiling', () {
    // ⛔ The uppercase rendering comes from `_SectionLabel` in
    // `log_event_screen.dart`, which takes `textTheme.labelLarge` and carries
    // NO local TextStyle — so it is not one of the 122 band-1 sites at all.
    const s = 'WAS A SECOND DOSE NEEDED?';
    final today = MERTheme.light.textTheme.labelLarge!;
    final now = widthOf(s, style(today.fontSize!, today.fontWeight!,
        letterSpacing: today.letterSpacing));

    // The two candidate steps under Amendment 1.
    final asFieldLabel = widthOf(s, style(12, FontWeight.w600,
        letterSpacing: today.letterSpacing));
    final asSectionHeading = widthOf(s, style(14, FontWeight.w600,
        letterSpacing: today.letterSpacing));
    // And with the letter spacing dropped, for reference only.
    final noSpacing = widthOf(s, style(12, FontWeight.w600));

    // ignore: avoid_print
    print('REPORT-A  "$s"\n'
        '  today   labelLarge ${today.fontSize}/${today.fontWeight} '
        'ls=${today.letterSpacing}  -> ${now.toStringAsFixed(1)} of $kSlot375\n'
        '  caption 12/w600  (field label)    -> '
        '${asFieldLabel.toStringAsFixed(1)}\n'
        '  body    14/w600  (section head)   -> '
        '${asSectionHeading.toStringAsFixed(1)}\n'
        '  caption 12/w600, no letterSpacing -> '
        '${noSpacing.toStringAsFixed(1)}');

    expect(now, greaterThan(0), reason: 'apparatus live');
  });

  test('2. S2 item 2: the replacement question strings at the NEW step', () {
    final today = MERTheme.light.textTheme.labelLarge!;
    const strings = <String>[
      'RESCUE MEDICATION GIVEN?',
      'RESCUE MEDICATION',
      'DID IT HELP?',
      'WAS A SECOND DOSE NEEDED?',
      'SECOND DOSE',
    ];
    // ignore: avoid_print
    print('REPORT-S2-Q  slot $kSlot375, uppercase, letterSpacing '
        '${today.letterSpacing}');
    for (final s in strings) {
      final at11 = widthOf(s, style(11, FontWeight.w600,
          letterSpacing: today.letterSpacing));
      final at12 = widthOf(s, style(12, FontWeight.w600,
          letterSpacing: today.letterSpacing));
      final at14 = widthOf(s, style(14, FontWeight.w600,
          letterSpacing: today.letterSpacing));
      // ignore: avoid_print
      print('  ${s.padRight(26)} 11:${at11.toStringAsFixed(1).padLeft(6)}'
          '  12:${at12.toStringAsFixed(1).padLeft(6)}'
          '  14:${at14.toStringAsFixed(1).padLeft(6)}'
          '  ${at12 > kSlot375 ? "OVER at 12" : ""}'
          '${at14 > kSlot375 ? " OVER at 14" : ""}');
    }
    expect(strings, isNotEmpty);
  });

  test('3. S2 item 3: every answer string on a chip at 200%', () {
    // A chip's text slot is the chip width minus its own horizontal padding.
    // `_SelectionWrap`/`_SelectionRow` use 20-radius pills with symmetric
    // padding; the binding constraint is the WRAP width, which is the same 343
    // slot, so a chip may take at most 343 minus its padding.
    const chipHPadding = 14.0 * 2; // measured from the pill's EdgeInsets
    const chipSlot = kSlot375 - chipHPadding;
    const answers = <String>[
      'Yes', 'No',
      'Given', 'Not given', 'Not needed',
      'Helped', "Didn't help", 'Not sure',
      'Seizure / fit', 'Add your own',
    ];
    // ignore: avoid_print
    print('REPORT-S2-A  chip text slot $chipSlot (343 wrap - 28 pill padding)');
    for (final s in answers) {
      final at13 = widthOf(s, style(13, FontWeight.w400));
      final at13b = widthOf(s, style(13, FontWeight.w600));
      final at14 = widthOf(s, style(14, FontWeight.w400));
      final at14b = widthOf(s, style(14, FontWeight.w600));
      // ignore: avoid_print
      print('  ${s.padRight(14)} 13/w400:${at13.toStringAsFixed(1).padLeft(6)}'
          '  13/w600:${at13b.toStringAsFixed(1).padLeft(6)}'
          '  14/w400:${at14.toStringAsFixed(1).padLeft(6)}'
          '  14/w600:${at14b.toStringAsFixed(1).padLeft(6)}'
          '  ${at14b > chipSlot ? "OVER" : "fits"}');
    }
    expect(answers, isNotEmpty);
  });

  test('4. the classes that MOVE UP, measured on their longest live string',
      () {
    // app-bar title 13/15 -> 16, and body prose 12/13 -> 14. These are the two
    // that SPEND headroom, so they are where a new truncation would appear.
    //
    // ⚠️ The app bar is CLAMPED at 1.34, not 2.0 — `app_bar.dart`'s
    // `_kMaxTitleTextScaleFactor`. Measuring it at 2.0 would report an
    // overflow no device shows.
    const appBarSlot = 375.0 - 56.0 - 96.0; // leading back + 2 actions
    const titles = <String>[
      'Medical Event Recorder', 'History', 'Your data', 'What you track',
      'Log new event', 'Your lists', 'Medication', 'Help', 'About',
    ];
    // ignore: avoid_print
    print('REPORT-UP  app-bar title at 1.34 clamp, slot ~$appBarSlot');
    for (final s in titles) {
      final now13 = widthOf(s, style(13, FontWeight.w600), scale: 1.34);
      final at16 = widthOf(s, style(16, FontWeight.w600), scale: 1.34);
      // ignore: avoid_print
      print('  ${s.padRight(24)} 13:${now13.toStringAsFixed(1).padLeft(6)}'
          '  16:${at16.toStringAsFixed(1).padLeft(6)}'
          '  ${at16 > appBarSlot ? "OVER" : "fits"}');
    }
    expect(titles, isNotEmpty);
  });
}
