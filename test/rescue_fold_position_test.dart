import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/vocabulary.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/log_event_screen.dart';
import 'package:medical_event_recorder/theme/mer_theme.dart';

/// Where the rescue block sits relative to the fold, RE-MEASURED.
///
/// ⛔ **V5's figure predates two chips wrapping to two lines.** *Partly helped*
/// and *Didn't help* went from 105.3 × 19.0 to 105.3 × 38.0 when the answer
/// wording landed, and the type scale moved every paragraph again after that.
/// S3 and V5 are both scoped against a number that has moved twice.
///
/// ## ⚠️ WHAT "THE FOLD" MEANS HERE, STATED BECAUSE IT DECIDES THE NUMBER
///
/// The fold is the bottom of the scroll viewport. The figure reported is the
/// distance from there to the TOP of the rescue section's label — so a
/// positive number is how far the user must scroll before the block's first
/// pixel appears.
///
/// ⚠️ Measured under ROBOTO. The harness font is monospaced at one em per
/// glyph and would inflate every wrap, which is the one thing this measurement
/// is about.
///
/// ⛔ NO LAYOUT COMPENSATION IS APPLIED HERE. This file measures and prints.

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
      // ⛔ TRUE, so `rescueChildrenVisible` reveals DID IT HELP? and SECOND
      // DOSE. Only 1 of 45 form-eligible records on the device carries this,
      // which is why the branch is easy to miss entirely.
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
          'wrap, which is the one thing this measures');
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

    // The viewport's bottom edge IS the fold.
    final viewport = tester.getRect(find.byType(Scrollable).first);

    Rect? rectOf(String label) {
      final f = find.text(label);
      return f.evaluate().isEmpty ? null : tester.getRect(f);
    }

    // The section labels render UPPERCASE through `_SectionLabel`.
    final blockTop = rectOf('RESCUE MEDICATION');
    final helped = rectOf('DID IT HELP?');
    final second = rectOf('SECOND DOSE');
    final referral = rectOf('MEDICAL REFERRAL REQUIRED?');

    String line(String name, Rect? r) => r == null
        ? '  ${name.padRight(28)} NOT FOUND'
        : '  ${name.padRight(28)} top=${r.top.toStringAsFixed(1)}  '
            'below fold by ${(r.top - viewport.bottom).toStringAsFixed(1)}';

    // ignore: avoid_print
    print('FOLD @375x667, scale $scale, Roboto\n'
        '  viewport ${viewport.top.toStringAsFixed(1)}'
        '..${viewport.bottom.toStringAsFixed(1)}'
        '  (the fold is ${viewport.bottom.toStringAsFixed(1)})\n'
        '${line("RESCUE MEDICATION", blockTop)}\n'
        '${line("DID IT HELP?", helped)}\n'
        '${line("SECOND DOSE", second)}\n'
        '${line("MEDICAL REFERRAL REQUIRED?", referral)}');

    expect(blockTop, isNotNull,
        reason: 'positive control: the rescue block is on the screen at all, '
            'so the figure above is about something');
  }

  testWidgets('the rescue block, at 100%', (tester) async {
    await report(tester, 1.0);
  });

  testWidgets('the rescue block, at 200%', (tester) async {
    await report(tester, 2.0);
  });
}
