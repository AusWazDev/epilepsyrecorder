import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/medication_note.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/event_wizard_screen.dart';
import 'package:medical_event_recorder/screens/medication_screen.dart';
import 'package:medical_event_recorder/theme/mer_theme.dart';

/// ⛔ V4'S CAPTURE PASS, AND IT EXISTS BECAUSE THE EXISTING GATE DOES NOT
/// COVER WHERE V4 ACTUALLY CHANGED THINGS.
///
/// `type_scale_200_gate_test` covers seven screens: history, form, about,
/// help, home, disclaimer, your-data. ⚠️ **Seven of V4's eight strings are on
/// the WIZARD and the MEDICATION SHEET, neither of which it pumps.** Running
/// it and reporting "gate clean" would have been a true statement about
/// screens V4 did not touch — a clean result over the wrong denominator.
///
/// ⭐ **Uppercasing is the change most likely to truncate**: capitals are
/// wider than lowercase at the same size, so a label that fitted in sentence
/// case can stop fitting. `MEDICAL REFERRAL REQUIRED?` at 200% on a 375-wide
/// screen is the worst case in the set and is the reason this is measured
/// rather than reasoned about.
///
/// The instruments are the two the existing gate uses, for the reason it
/// gives: `RenderFlex ... OVERFLOWING` sees a row pushed past its bounds, and
/// `didExceedMaxLines` sees a paragraph that solved the same problem by
/// removing characters and so reports no overflow at all.

List<String> overflowingRows(WidgetTester tester) {
  for (var e = tester.takeException(); e != null; e = tester.takeException()) {}
  final out = <String>[];
  void visit(RenderObject o) {
    if (o is RenderFlex && o.toStringShort().contains('OVERFLOWING')) {
      out.add(o.toStringShort());
    }
    o.visitChildren(visit);
  }

  visit(tester.binding.renderViews.single);
  return out;
}

List<String> truncated(WidgetTester tester) {
  final out = <String>[];
  void visit(RenderObject o) {
    if (o is RenderParagraph && o.didExceedMaxLines) {
      final t = o.text.toPlainText();
      out.add(t.length > 40 ? '${t.substring(0, 40)}…' : t);
    }
    o.visitChildren(visit);
  }

  visit(tester.binding.renderViews.single);
  return out;
}

/// The eight strings V4 moved into the uppercase register, as RENDERED.
const kV4Strings = <String>[
  'COMPARED WITH THE OTHERS HERE',
  'MEDICAL REFERRAL REQUIRED?',
  'RESCUE MEDICATION',
  'DID IT HELP?',
  'SECOND DOSE',
  'WHAT HAPPENED?',
  'WHEN?',
  'WHEN IT HAPPENED',
];

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() async {
    // ⚠️ Roboto. The harness font is monospaced at one em per glyph and would
    // report truncation no device shows — and this file's whole subject is
    // whether wider glyphs still fit.
    final path =
        '${Platform.environment['FLUTTER_ROOT'] ?? 'C:/Flutter/flutter'}'
        '/bin/cache/artifacts/material_fonts/roboto-regular.ttf';
    final file = File(path);
    if (!file.existsSync()) {
      fail('Roboto not found at $path — a truncation claim needs the real font');
    }
    final loader = FontLoader('Roboto')
      ..addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
    await loader.load();
  });

  setUp(Vocabularies.debugReset);
  tearDown(Vocabularies.debugReset);

  /// Real-clock settle, for the one test here that touches a database.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// ⛔ STEP 4, NOT STEP 1. The wizard opens on step 1 and FOUR of V4's five
  /// wizard strings live on step 4 — the first version of this file pumped the
  /// wizard, measured step 1, found no truncation and passed. ⚠️ **It was
  /// measuring a screen that did not contain the thing it was testing**, and
  /// only the control below said so.
  Future<void> toStep4(WidgetTester tester, {required double scale}) async {
    await tester.pumpWidget(MaterialApp(
      theme: MERTheme.light,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: const EventWizardScreen(),
      ),
    ));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('the wizard step 4 at 200%, 375 wide', (tester) async {
    // ⚠ 375 WIDE IS THE MEASUREMENT; THE HEIGHT IS DELIBERATELY GENEROUS.
    // Truncation is a WIDTH question -- a label ellipsises because the line
    // ran out, not because the page did. At 667 high, step 4 at 200% extends
    // past the viewport and the reveal tap did not land, so two of the five
    // strings were never built and the pass read as complete at three.
    tester.view.physicalSize = const Size(375, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // ⛔ ALL FOUR STEPS, NOT JUST STEP 4. `COMPARED WITH THE OTHERS HERE` is
    // the LONGEST of the eight and it is not on step 4 — measuring step 4
    // alone would have covered four of the five wizard strings and reported
    // the result as though it covered them all.
    await tester.pumpWidget(MaterialApp(
      theme: MERTheme.light,
      home: const MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: EventWizardScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    final seen = <String>{};
    for (var step = 1; step <= 4; step++) {
      // ⛔ TWO of the five are BEHIND A REVEAL and do not exist until Given is
      // answered. Measuring step 4 as it opens would have covered three of
      // five and read as complete.
      if (step == 4) {
        await tester.tap(find.text('Given').first);
        await tester.pumpAndSettle();
      }
      final rows = overflowingRows(tester);
      final cut = truncated(tester);
      final here = kV4Strings.where((s) => find.text(s).evaluate().isNotEmpty);
      seen.addAll(here);

      // ignore: avoid_print
      print('V4 GATE wizard step $step @200% 375w\n'
          '  V4 strings here  : ${here.isEmpty ? 'none' : here.join(', ')}\n'
          '  overflowing rows : ${rows.isEmpty ? 'none' : rows.join(' | ')}\n'
          '  truncated text   : ${cut.isEmpty ? 'none' : cut.join(' | ')}');

      expect(rows, isEmpty,
          reason: 'step $step: uppercasing must not push a row past its bounds');
      expect(cut.where((t) => kV4Strings.any(t.startsWith)), isEmpty,
          reason: 'step $step: no string V4 recased may truncate at 200%');

      if (step < 4) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
    }

    // ⛔ THE DENOMINATOR. Without this the clean result above is clean over
    // whatever happened to be on screen.
    // ignore: avoid_print
    print('  COVERED: ${seen.length} of the 5 wizard strings — '
        '${seen.join(', ')}');
    expect(seen, containsAll(kV4Strings.where((s) =>
        s != 'WHAT HAPPENED?' && s != 'WHEN?' && s != 'WHEN IT HAPPENED')), 
        reason: 'all FIVE wizard strings were rendered and measured at 200%');
    expect(seen, containsAll(<String>[
      'COMPARED WITH THE OTHERS HERE',
      'MEDICAL REFERRAL REQUIRED?',
      'RESCUE MEDICATION',
    ]), reason: 'the wizard strings V4 moved were actually rendered and '
        'measured, rather than merely not found');
  });

  testWidgets('step 4 renders its labels as capitals, and the old casing is '
      'gone', (tester) async {
    tester.view.physicalSize = const Size(375, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await toStep4(tester, scale: 1.0);

    // Answering Given reveals the two children, so all four step-4 labels are
    // in the tree at once.
    await tester.tap(find.text('Given').first);
    await tester.pumpAndSettle();

    for (final s in <String>[
      'MEDICAL REFERRAL REQUIRED?',
      'RESCUE MEDICATION',
      'DID IT HELP?',
      'SECOND DOSE',
    ]) {
      expect(find.text(s), findsOneWidget, reason: '$s joined the register');
    }

    // ⛔ AND THE OLD CASING IS ABSENT. Asserting only the new string would
    // pass if BOTH were rendered — which is what a half-applied edit, or a
    // second copy of the label somewhere, would produce.
    for (final s in <String>[
      'Medical referral required?',
      'Rescue medication',
      'Did it help?',
      'Second dose',
    ]) {
      expect(find.text(s), findsNothing,
          reason: 'the sentence-case form of "$s" is gone from step 4, so the '
              'register moved rather than gaining a second member');
    }
  });

  testWidgets('the medication sheet at 200%, 375 wide', (tester) async {
    // ⛔ THE LAST TWO OF THE EIGHT. Without this the coverage claim would be
    // six of eight dressed up as "the gate is clean" — the denominator is the
    // part that makes a clean result mean anything.
    // ⛔ `runAsync`, NOT a bare await. A `testWidgets` body runs on a FAKE
    // CLOCK, and real sqflite I/O awaited inside one waits on a future that
    // clock never reaches. ⚠️ The first version of this test did exactly that
    // and hung for the full ten-minute timeout while the two tests above it
    // passed in one second — the third time this class has cost time in this
    // build, and it is written down in CLAUDE.md.
    final db = await tester.runAsync(() => databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
            version: 1,
            onCreate: (d, _) async => d.execute(createMedicationNoteSql))));
    addTearDown(() => tester.runAsync(() => db!.close()));
    final store = MedicationStore(db);

    tester.view.physicalSize = const Size(375, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: MERTheme.light,
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
        child: MedicationScreen(store: store),
      ),
    ));
    // ⚠ NOT pumpAndSettle. The screen shows a spinner until its real
    // sqflite load returns, and settling on a fake clock waits on I/O that
    // clock never reaches. Pump a fixed number of frames instead -- the same
    // fix, and the same reason, as `bulk_hide_test`'s `settle`.
    await settle(tester);

    // The sheet is modal, opened from the screen's own action.
    await tester.tap(find.text('Record a deviation').first);
    await settle(tester);

    expect(find.text('WHAT HAPPENED?'), findsOneWidget,
        reason: 'positive control: the sheet is open and carries its labels');
    expect(find.text('WHEN?'), findsOneWidget);
    expect(find.text('What happened?'), findsNothing);
    expect(find.text('When?'), findsNothing);

    final rows = overflowingRows(tester);
    final cut = truncated(tester);
    // ignore: avoid_print
    print('V4 GATE medication sheet @200% 375w\n'
        '  overflowing rows : ${rows.isEmpty ? 'none' : rows.join(' | ')}\n'
        '  truncated text   : ${cut.isEmpty ? 'none' : cut.join(' | ')}');

    expect(cut.where((t) => kV4Strings.any(t.startsWith)), isEmpty,
        reason: 'no string V4 recased may truncate at 200%');
  });
}
