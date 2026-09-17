import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/models/medication_note.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/event_wizard_screen.dart';
import 'package:medical_event_recorder/screens/medication_screen.dart';
import 'package:medical_event_recorder/theme/mer_theme.dart';

/// ⛔ §10 FIX 3 — NOTES IS A *RANKING* PROBLEM, AND THE RANKING IS MEASURED.
///
/// §6's finding is that notes is **most reachable in the secondary feature and
/// least reachable in the primary capture path**. ⚠️ **§6's own annotation
/// says its `78 %` and `two-thirds` were DESCRIBED, not measured.** So neither
/// figure is inherited here; both depths are measured directly.
///
/// ## The definition, stated so the next measurement is comparable
///
/// **DEPTH = how far down the field sits in its own scrollable**, as the
/// notes field's top offset from the top of that scrollable's content, in
/// logical pixels at 375 wide. ⭐ **Plus the number of SECTIONS above it**,
/// which is what a user actually counts past.
///
/// ⚠️ **Offset, not "is it visible"** — visibility depends on the viewport and
/// the fold has already moved twice in this build. An offset is a property of
/// the layout and does not move when the phone does.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() async {
    final path =
        '${Platform.environment['FLUTTER_ROOT'] ?? 'C:/Flutter/flutter'}'
        '/bin/cache/artifacts/material_fonts/roboto-regular.ttf';
    final file = File(path);
    if (!file.existsSync()) fail('Roboto not found at $path');
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

  /// Every text paragraph on screen with its offset, icons excluded.
  List<({String text, double top})> paragraphs(WidgetTester tester) {
    final out = <({String text, double top})>[];
    for (final e in tester.allElements) {
      final ro = e.renderObject;
      if (ro is! RenderParagraph) continue;
      final t = ro.text.toPlainText();
      if (!RegExp(r'[A-Za-z]').hasMatch(t)) continue;
      out.add((text: t, top: ro.localToGlobal(Offset.zero).dy));
    }
    out.sort((a, b) => a.top.compareTo(b.top));
    return out;
  }

  double notesTop(WidgetTester tester) =>
      tester.getRect(find.byType(TextField).last).top;

  testWidgets('DEPTH A — the medication add sheet', (tester) async {
    final db = await tester.runAsync(() => databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
            version: 1,
            onCreate: (d, _) async => d.execute(createMedicationNoteSql))));
    addTearDown(() => tester.runAsync(() => db!.close()));

    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: MERTheme.light,
      home: MedicationScreen(store: MedicationStore(db)),
    ));
    await settle(tester);

    var taps = 0;
    await tester.tap(find.text('Record a deviation').first);
    taps++;
    await settle(tester);

    expect(find.text('Notes (optional)'), findsOneWidget,
        reason: 'positive control: the sheet is open and the notes field is '
            'in it, so the offset below describes the real field');

    final sections = paragraphs(tester)
        .where((p) => p.text == RegExp(r'^[A-Z ?]+$').stringMatch(p.text))
        .map((p) => p.text)
        .toList();

    // ⛔ DISTANCE FROM THE CONTAINER'S FIRST ELEMENT, not a global y. The
    // sheet is a modal anchored to the bottom of the screen, so its global
    // position says where the SHEET is, not how far into it the field sits.
    // Only a distance from the container's own first element is comparable
    // with the wizard's.
    final firstTop = paragraphs(tester)
        .firstWhere((p) => p.text.startsWith('Record a deviation'))
        .top;

    // ignore: avoid_print
    print('DEPTH — MEDICATION ADD SHEET (375w)\n'
        '  taps from the screen            : $taps\n'
        '  answer groups above notes       : '
        '${sections.toSet().length}  ${sections.toSet().join(" | ")}\n'
        '  first element top               : '
        '${firstTop.toStringAsFixed(1)}\n'
        '  notes field top                 : '
        '${notesTop(tester).toStringAsFixed(1)}\n'
        '  ⭐ DEPTH (px into the container) : '
        '${(notesTop(tester) - firstTop).toStringAsFixed(1)}');
  });

  testWidgets('DEPTH B — the wizard, primary capture path', (tester) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      home: MaterialApp(home: EventWizardScreen()),
    ));
    await tester.pumpAndSettle();

    var taps = 0;
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      taps++;
      await tester.pumpAndSettle();
    }

    expect(find.text('Notes (optional)'), findsWidgets,
        reason: 'positive control: step 4 is showing and carries the notes '
            'field');

    final sections = paragraphs(tester)
        .where((p) => p.text == RegExp(r'^[A-Z ?]+$').stringMatch(p.text))
        .map((p) => p.text)
        .toList();

    // The same measure: distance from the step's own first element.
    final firstTop = paragraphs(tester)
        .firstWhere((p) => p.text.startsWith('How were things afterwards'))
        .top;

    // ignore: avoid_print
    print('DEPTH — WIZARD STEP 4 (375w)\n'
        '  taps from the wizard start      : $taps\n'
        '  answer groups above notes       : '
        '${sections.toSet().length}  ${sections.toSet().join(" | ")}\n'
        '  first element top               : '
        '${firstTop.toStringAsFixed(1)}\n'
        '  notes field top                 : '
        '${notesTop(tester).toStringAsFixed(1)}\n'
        '  ⭐ DEPTH (px into the container) : '
        '${(notesTop(tester) - firstTop).toStringAsFixed(1)}');
  });

  testWidgets('FOLD CENSUS — step 4 at 375x667, what sits below the fold',
      (tester) async {
    // ⛔ THE ESCAPE CLAUSE'S EVIDENCE. Raising notes must not push another
    // field below the fold — the fold has moved twice in this build and
    // trading one buried field for another is not a fix. This names what is
    // below it BEFORE and is re-run AFTER.
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: EventWizardScreen()));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }

    final scrollable = find.byType(Scrollable).first;
    final fold = tester.getRect(scrollable).bottom;

    final seen = <String>{};
    final above = <String>[];
    final below = <String>[];
    for (final p in paragraphs(tester)) {
      if (!seen.add(p.text)) continue;
      (p.top < fold ? above : below).add(
          '${p.text.length > 34 ? "${p.text.substring(0, 34)}…" : p.text}'
          ' @${p.top.toStringAsFixed(0)}');
    }

    // ignore: avoid_print
    print('FOLD CENSUS — wizard step 4, 375x667\n'
        '  fold (scroll viewport bottom)   : ${fold.toStringAsFixed(1)}\n'
        '  ABOVE (${above.length}):\n    ${above.join("\n    ")}\n'
        '  BELOW (${below.length}):\n    ${below.join("\n    ")}');
  });
}
