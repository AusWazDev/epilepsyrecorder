import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/models/vocabulary.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/event_wizard_screen.dart';
import 'package:medical_event_recorder/screens/log_event_screen.dart';
import 'package:medical_event_recorder/theme/mer_theme.dart';
import 'package:medical_event_recorder/widgets/bounded_chip_wrap.dart';

/// ⛔ THE EVENT-TYPE BOUND — the shipped set must be discoverable at 375
/// without a disclosure.
///
/// ⭐ **The reason is specific to this site and does not generalise.** Event
/// type is the only bounded vocabulary whose entries are RECORD KINDS rather
/// than descriptors: a missed observation costs a less complete record of the
/// right kind, a missed event type costs a record of the WRONG kind — or a
/// user who never learns the app records that kind at all.
///
/// ⚠️ **The bound is NOT removed.** Event types are user-extensible
/// (`onAdd: Vocabularies.canPersist` is live on the form), so the vocabulary
/// grows and the bound is what stops growth swamping the screen. A user who
/// has added their own types still meets it.
///
/// ## ⚠️ A DATABASE IS REQUIRED TO MEASURE THIS HONESTLY
///
/// The form gates its add affordance on `Vocabularies.canPersist`, so without
/// a database the picker is four chips rather than five and the measurement
/// would be of a picker no user sees. `CLAUDE.md` allows one database-dependent
/// test per file; this is it.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  setUpAll(() async {
    // ⚠️ Roboto. Every figure here is a WIDTH or a ROW COUNT, and the harness
    // font is monospaced at one em per glyph.
    final path =
        '${Platform.environment['FLUTTER_ROOT'] ?? 'C:/Flutter/flutter'}'
        '/bin/cache/artifacts/material_fonts/roboto-regular.ttf';
    final file = File(path);
    if (!file.existsSync()) fail('Roboto not found at $path');
    final loader = FontLoader('Roboto')
      ..addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
    await loader.load();
  });

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1, onCreate: (d, _) async {
      await createAndSeedVocabularies(d);
      await createAndSeedTriggers(d);
    }));
    await Vocabularies.load(db);
  });

  tearDown(() async {
    await db.close();
    Vocabularies.debugReset();
  });

  /// Real-clock settle — this file does real sqflite I/O.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  /// The event-type wrap is the one whose entry count matches the event-type
  /// vocabulary. ⛔ DERIVED, not positional — `bounded_chip_wrap_test` 13 has
  /// already been caught by a `.first` that silently meant something else.
  ({int index, List<bool> visible}) eventTypeWrap(WidgetTester tester) {
    final wraps = find.byType(BoundedWrap);
    final want = Vocabularies.offerableEventTypes.length;
    for (var i = 0; i < tester.widgetList(wraps).length; i++) {
      final v =
          (tester.renderObject(wraps.at(i)) as RenderBoundedWrap).childVisibility;
      // types, optionally an orphan, optionally the add pill.
      if (v.length >= want && v.length <= want + 2) {
        return (index: i, visible: v);
      }
    }
    fail('no wrap matched the event-type vocabulary size ($want)');
  }

  /// Distinct row count of the chips, read from their y positions.
  int rowsOf(WidgetTester tester, List<String> labels) {
    final tops = <double>{};
    for (final l in labels) {
      final f = find.text(l);
      if (f.evaluate().isEmpty) continue;
      tops.add(tester.getTopLeft(f.first).dy);
    }
    return tops.length;
  }

  testWidgets('MEASURE: which chip is hidden at 375, and how many rows the '
      'seeded set needs', (tester) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: MERTheme.light,
      home: const LogEventScreen(),
    ));
    await settle(tester);

    expect(Vocabularies.canPersist, isTrue,
        reason: 'positive control: the database is live, so the ADD pill is '
            'offered and the picker measured here is the one users see');

    final w = eventTypeWrap(tester);
    final labels = Vocabularies.offerableEventTypes.map((e) => e.label).toList();

    // ⛔ NAME THE HIDDEN CHIP, do not assume it is `Other / custom`.
    final hidden = <String>[];
    for (var i = 0; i < w.visible.length; i++) {
      if (w.visible[i]) continue;
      hidden.add(i < labels.length ? labels[i] : '<add affordance>');
    }

    // ignore: avoid_print
    print('EVENT TYPE at 375, form\n'
        '  seeded types      : ${labels.join(" | ")}\n'
        '  chips in the wrap : ${w.visible.length} '
        '(${labels.length} types + add pill)\n'
        '  visible           : ${w.visible.where((e) => e).length}\n'
        '  ⛔ HIDDEN         : ${hidden.isEmpty ? "none" : hidden.join(", ")}');

    // Expand and count the rows the full set actually needs.
    // ⛔ SCOPED TO THE EVENT-TYPE PICKER. Three pickers on this screen each
    // carry their own disclosure, so a bare `find.text('Show all')` is
    // ambiguous -- and tapping the wrong one would expand a different control
    // while the measurement still looked like it worked.
    final showAll = find.descendant(
        of: find.byType(BoundedChipWrap).at(w.index),
        matching: find.text('Show all'));
    if (showAll.evaluate().isNotEmpty) {
      await tester.tap(showAll);
      await tester.pumpAndSettle();
    }
    final rows = rowsOf(tester, <String>[...labels, 'Add your own']);
    // ignore: avoid_print
    print('  ⭐ ROWS NEEDED for all ${labels.length} types + add pill : $rows');
  });

  testWidgets('MEASURE: the fold, before and after expanding — the escape '
      'clause evidence', (tester) async {
    // ⛔ 375x667, the narrowest supported geometry. The question is whether
    // showing the full set displaces something that currently fits.
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: MERTheme.light,
      home: const LogEventScreen(),
    ));
    await settle(tester);

    final scrollable = find.byType(Scrollable).first;
    final fold = tester.getRect(scrollable).bottom;

    List<String> visibleLabels() {
      final out = <String>[];
      void visit(RenderObject o) {
        if (o is RenderParagraph) {
          final t = o.text.toPlainText();
          if (RegExp(r'[A-Za-z]').hasMatch(t) &&
              o.localToGlobal(Offset.zero).dy < fold) {
            out.add(t.length > 30 ? '${t.substring(0, 30)}…' : t);
          }
        }
        o.visitChildren(visit);
      }

      visit(tester.binding.renderViews.single);
      return out;
    }

    final before = visibleLabels();
    final mildBefore = tester.getTopLeft(find.text('Mild').first).dy;

    final et = eventTypeWrap(tester);
    final showAll = find.descendant(
        of: find.byType(BoundedChipWrap).at(et.index),
        matching: find.text('Show all'));
    final couldExpand = showAll.evaluate().isNotEmpty;
    if (couldExpand) {
      await tester.tap(showAll);
      await tester.pumpAndSettle();
    }
    final after = visibleLabels();

    // ⛔ THE DISPLACEMENT, STATED AS A COORDINATE rather than as a list
    // membership. "Mild" is severity's first option and the field's proxy.
    final mildAfter = tester.getTopLeft(find.text('Mild').first).dy;

    final lost = before.where((b) => !after.contains(b)).toList();
    // ignore: avoid_print
    print('FOLD at 375x667, form — fold y=${fold.toStringAsFixed(1)}\n'
        '  above the fold BEFORE : ${before.length} paragraphs\n'
        '  above the fold AFTER  : ${after.length} paragraphs\n'
        '  ⛔ DISPLACED below    : ${lost.isEmpty ? "none" : lost.join(" | ")}\n'
        '  severity "Mild" BEFORE: ${mildBefore.toStringAsFixed(1)} '
        '(${mildBefore < fold ? "ABOVE" : "below"} the fold)\n'
        '  severity "Mild" AFTER : ${mildAfter.toStringAsFixed(1)} '
        '(${mildAfter < fold ? "above" : "BELOW"} the fold)');

    // ⛔ THIS IS WHY `maxRows` WAS NOT RAISED AT THIS SITE, PINNED SO THE
    // REASON OUTLIVES THE DECISION. Showing all four seeded types at 375
    // needs FIVE rows, and the two extra rows push SEVERITY — a field that
    // currently fits — below the fold. The disclosure is the lesser cost.
    //
    // ⚠️ IF THIS TEST EVER FAILS, THE CONSTRAINT HAS CHANGED AND THE DECISION
    // CAN BE REVISITED. That is the point of asserting it rather than printing
    // it: a later layout change that buys back 56 points here should surface
    // as a prompt to reconsider, not pass silently.
    expect(mildBefore, lessThan(fold),
        reason: 'severity fits above the fold as shipped');
    expect(mildAfter, greaterThan(fold),
        reason: 'and expanding the event-type picker pushes it below — which '
            'is the measured reason the bound was left at its default here');
  });

  testWidgets('MEASURE: the wizard fold at 375x667 — the other path',
      (tester) async {
    // ⛔ THE CLAUSE SAYS "ON EITHER PATH", so the wizard is measured too rather
    // than inferred from the form's result. Brief 29 established that step 4
    // has no room to give; this is step 1 and a different screen.
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: MERTheme.light,
      home: const EventWizardScreen(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    final fold = tester.getRect(find.byType(Scrollable).first).bottom;
    final w = eventTypeWrap(tester);
    final before = tester.getTopLeft(find.text('Mild').first).dy;

    final showAll = find.descendant(
        of: find.byType(BoundedChipWrap).at(w.index),
        matching: find.text('Show all'));
    if (showAll.evaluate().isNotEmpty) {
      await tester.tap(showAll);
      await tester.pumpAndSettle();
    }
    final after = tester.getTopLeft(find.text('Mild').first).dy;

    // ignore: avoid_print
    print('WIZARD step 1 at 375x667 — fold y=${fold.toStringAsFixed(1)}\n'
        '  severity "Mild" BEFORE: ${before.toStringAsFixed(1)} '
        '(${before < fold ? "ABOVE" : "below"} the fold)\n'
        '  severity "Mild" AFTER : ${after.toStringAsFixed(1)} '
        '(${after < fold ? "above" : "BELOW"} the fold)');

    // ⭐ THE WIZARD HAS THE ROOM AND THE FORM DOES NOT, which is the whole
    // reason this was measured on both rather than inferred from one. The
    // clause is "on EITHER path", so one failure stops it — and applying the
    // raise to the wizard alone would re-open exactly the form/wizard
    // divergence B1 closed.
    expect(after, lessThan(fold),
        reason: 'the wizard could carry the full set at 375; it is not raised '
            'because the form cannot, and the two paths stay alike');
  });

  testWidgets('MEASURE: the wizard, same question', (tester) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: MERTheme.light,
      home: const EventWizardScreen(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    final w = eventTypeWrap(tester);
    final labels = Vocabularies.offerableEventTypes.map((e) => e.label).toList();
    final hidden = <String>[];
    for (var i = 0; i < w.visible.length; i++) {
      if (w.visible[i]) continue;
      hidden.add(i < labels.length ? labels[i] : '<add affordance>');
    }

    // ignore: avoid_print
    print('EVENT TYPE at 375, wizard step 1\n'
        '  chips in the wrap : ${w.visible.length}\n'
        '  visible           : ${w.visible.where((e) => e).length}\n'
        '  ⛔ HIDDEN         : ${hidden.isEmpty ? "none" : hidden.join(", ")}');
  });
}
