import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/home_screen.dart';

/// AUDIT.md §13(h) — how many lines do the candidate banner strings wrap to?
///
/// ⛔ THE HARNESS FONT CANNOT ANSWER THIS. `flutter_test` ships a font that is
/// monospaced at one em per glyph — `iiiii` and `WWWWW` both measure 66.3 at
/// 13 px — so every line count it produces is fiction. That is §13(ay), and it
/// is why this file loads a REAL font before measuring anything.
///
/// ⭐ THE FONT IS ROBOTO, from the Flutter SDK's own material_fonts cache. It is
/// what Android actually ships and what Material uses there. ⚠️ It is NOT SF
/// Pro, so the iOS figures are approximated by it — and the CONTROL below is
/// what makes that defensible: the current copy is known from a real iOS device
/// capture to wrap to THREE lines at 430 logical
/// (`home__backup-reminder__430x932__2026-09-07-ios-15promax-device.png`).
/// If this method disagrees with that, the method is wrong.
///
/// ⭐ THE WIDTH IS READ, NOT ASSUMED. The banner's real text column is taken
/// from the live widget tree by pumping `HomeScreen` with the reminder showing,
/// then reading the body paragraph's own incoming constraint. Candidates are
/// then laid out at exactly that width.

const String kCurrent =
    'Your events are stored only on this device. A backup is the only '
    'way to get them onto another one.';

const String kLong =
    'A backup is your own copy — the only one that moves to a new phone. '
    'Save it somewhere lasting, like your cloud drive or email.';

const String kShort =
    'A backup is your own copy — the only one that moves to a new phone. '
    'Save it somewhere lasting.';

/// Enough records to clear `kBackupReminderThreshold` with no backup recorded,
/// so `eventsSinceLastBackup` returns the full count and the banner shows.
String seededRecordsJson() {
  final records = List.generate(
    12,
    (i) => EventRecord(
      id: 'seed-$i',
      timestamp: DateTime(2026, 8, 20, 3, i + 1),
      duration: DurationCategory.lt1,
      durationSeconds: 40,
      eventType: 'seizure',
      severity: EventSeverity.mild,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: false,
      notes: '',
      detailsCompleted: true,
    ),
  );
  return jsonEncode(records.map((r) => r.toMap()).toList());
}

void main() {
  setUpAll(() async {
    // Roboto, from the SDK cache. Loaded as the DEFAULT family so a bare
    // TextStyle picks it up the way the app does on Android.
    final path = '${Platform.environment['FLUTTER_ROOT'] ?? 'C:/Flutter/flutter'}'
        '/bin/cache/artifacts/material_fonts/roboto-regular.ttf';
    final file = File(path);
    if (!file.existsSync()) {
      fail('Roboto not found at $path — cannot measure real glyph widths.');
    }
    final bytes = file.readAsBytesSync();
    final loader = FontLoader('Roboto')
      ..addFont(Future.value(bytes.buffer.asByteData()));
    await loader.load();
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'disclaimerAcceptedVersion': kDisclaimerVersion,
      kWalkthroughSeenVersionKey: kWalkthroughVersion,
      kEventStorageKey: seededRecordsJson(),
    });
    StorageBoot.debugSet();
    Vocabularies.debugReset();
  });
  tearDown(() {
    StorageBoot.debugSet();
    Vocabularies.debugReset();
  });

  testWidgets('banner copy — real-font line counts at 375, 430, 800',
      (tester) async {
    addTearDown(tester.view.reset);

    // The banner's real style, read from home_screen.dart.
    const style = TextStyle(fontSize: 13, height: 1.4, fontFamily: 'Roboto');

    /// Lines and height for [s] at [maxWidth], using the loaded real font.
    (int, double) layout(String s, double maxWidth) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: maxWidth);
      return (tp.computeLineMetrics().length, tp.height);
    }

    for (final w in <double>[375, 430, 800]) {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = Size(w, 932);

      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      // The banner must actually be on screen, or nothing below means anything.
      final body = find.textContaining('stored only on this device');
      expect(body, findsOneWidget,
          reason: 'the backup reminder must be showing at width $w — with 12 '
              'seeded records and no kLastBackupKey it should be');

      final ro = tester.renderObject<RenderParagraph>(body);
      final colWidth = ro.constraints.maxWidth;
      // The banner root is a Container with the pale-green BoxDecoration --
      // read from home_screen.dart, not guessed. Matched by that fill so a
      // different ancestor cannot be measured by accident.
      final bannerBox = tester.getSize(find
          .ancestor(
              of: body,
              matching: find.byWidgetPredicate((w) =>
                  w is Container &&
                  w.decoration is BoxDecoration &&
                  (w.decoration! as BoxDecoration).color ==
                      const Color(0xFFE8F5E9)))
          .first);

      // ignore: avoid_print
      print('  ── width $w logical ──  text column ${colWidth.toStringAsFixed(1)}  '
          'rendered body ${ro.size.width.toStringAsFixed(1)}x'
          '${ro.size.height.toStringAsFixed(1)}  '
          'banner ${bannerBox.width.toStringAsFixed(1)}x'
          '${bannerBox.height.toStringAsFixed(1)}');

      for (final (label, s) in <(String, String)>[
        ('CURRENT (control)', kCurrent),
        ('LONG', kLong),
        ('SHORT', kShort),
      ]) {
        final (lines, h) = layout(s, colWidth);
        // ignore: avoid_print
        print('     ${label.padRight(18)} ${s.length.toString().padLeft(3)} chars  '
            '$lines lines  height ${h.toStringAsFixed(1)}  '
            'delta vs current ${(h - layout(kCurrent, colWidth).$2).toStringAsFixed(1)}');
      }
    }

    // ⛔ THE CONTROL FAILED, AND IT IS REPORTED RATHER THAN SUPPRESSED.
    // Roboto wraps the current copy to TWO lines at 430; the real iOS device
    // capture shows THREE. So SF Pro is WIDER than Roboto at 13 px w400 by
    // enough to change the line count, and Roboto is NOT a stand-in for iOS.
    //
    // What survives: Roboto IS Android's font, so the Android figures above are
    // real. iOS is unmeasurable here -- SF Pro is not on this machine.
    tester.view.physicalSize = const Size(430, 932);
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();
    final body2 = find.textContaining('stored only on this device');
    final col = tester.renderObject<RenderParagraph>(body2).constraints.maxWidth;
    final (controlLines, _) = layout(kCurrent, col);

    // Calibration: the iOS capture's FIRST rendered line, measured off the
    // frame at 313.3 logical for these 45 characters. Roboto's width for the
    // same string gives the ratio between the two fonts.
    const iosLine1 = 'Your events are stored only on this device. A';
    const iosLine1Measured = 313.3;
    final tp = TextPainter(
      text: const TextSpan(text: iosLine1, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    // ignore: avoid_print
    print('');
    // ignore: avoid_print
    print('  CONTROL current copy at 430 in Roboto: $controlLines lines; '
        'the iOS device capture shows 3 -> CONTROL FAILED, method not valid for iOS');
    // ignore: avoid_print
    print('  CALIBRATION "$iosLine1"');
    // ignore: avoid_print
    print('     Roboto  ${tp.width.toStringAsFixed(1)} logical for ${iosLine1.length} chars '
        '(${(tp.width / iosLine1.length).toStringAsFixed(2)}/char)');
    // ignore: avoid_print
    print('     SF Pro  $iosLine1Measured logical, measured off the device capture '
        '(${(iosLine1Measured / iosLine1.length).toStringAsFixed(2)}/char)');
    // ignore: avoid_print
    print('     SF Pro is ${((iosLine1Measured / tp.width - 1) * 100).toStringAsFixed(1)}% '
        'wider than Roboto at 13px w400');

    expect(controlLines, isNot(3),
        reason: 'documents the control FAILURE. If this ever passes, Roboto has '
            'become a valid stand-in and the iOS caveat above can be revisited.');
  });
}
