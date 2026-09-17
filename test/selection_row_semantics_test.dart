import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/log_event_screen.dart';

/// AUDIT.md §13(z) and §13(t) — `_SelectionRow` must announce WHICH option is
/// selected, and must not change a single pixel doing it.
///
/// ⭐ The five fields it carries are severity, rescue given, did-it-help,
/// second dose and referral. Every one is asserted, not one as a representative.
///
/// ⛔ THE RENDER COMPARISON IS THE POINT OF THE SECOND TEST. A `Semantics`
/// wrapper must be invisible; that is asserted against a baseline captured from
/// the UNPATCHED code at three widths, not assumed from the fact that
/// `Semantics` "does not paint".
///
/// ⚠️ No prefs here, so the one-prefs-test-per-process rule does not apply —
/// the same note `rescue_change_list_test.dart` carries. `Vocabularies.debugReset`
/// is the only shared state.

EventRecord record({
  EventSeverity severity = EventSeverity.mild,
  bool? given = true,
  RescueResponse? helped = RescueResponse.helped,
  bool? secondDose = false,
  bool referral = false,
}) =>
    EventRecord(
      id: 'sel-1',
      timestamp: DateTime(2026, 8, 20, 9, 0),
      duration: DurationCategory.oneToFive,
      durationSeconds: 90,
      eventType: 'seizure',
      severity: severity,
      feelings: const <String>[],
      triggers: const <String>[],
      rescueMedGiven: given,
      rescueMedHelped: helped,
      rescueMedSecondDose: secondDose,
      referralRequired: referral,
      notes: '',
      detailsCompleted: true,
    );

/// Every `_SelectionRow` option, as (label, isSelected) read from the SEMANTICS
/// tree rather than from the widget tree — the widget tree would only re-read
/// the flag this change sets.
List<(String, bool)> optionSemantics(WidgetTester tester) {
  var root = tester.getSemantics(find.byType(LogEventScreen));
  while (root.parent != null) {
    root = root.parent!;
  }
  final out = <(String, bool)>[];
  void walk(SemanticsNode n) {
    final d = n.getSemanticsData();
    final label = d.label.trim();
    // The option pills are the tappable leaves whose label is one of the
    // option words. Anything else on the screen is ignored by that test.
    if (label.isNotEmpty && d.hasAction(SemanticsAction.tap)) {
      // ⛔ THE ENUM VALUES ARE isTrue / isFalse / none, NOT 'selected'.
      // A first version compared against 'selected' and reported every option
      // as unselected even after the fix landed correctly -- the probe
      // encoding an assumption about the answer, per §13(az).
      out.add((label, d.flagsCollection.isSelected.toString() == 'Tristate.isTrue'));
    }
    n.visitChildren((c) {
      walk(c);
      return true;
    });
  }

  walk(root);
  return out;
}

/// The option labels _SelectionRow renders, and nothing else. Scoping the
/// geometry probe to these keeps the baseline small enough to read and stops it
/// drifting when an unrelated chip moves.
const kOptionLabels = <String>{
  // ⚠️ THE RESCUE FIELDS ANSWER IN THEIR OWN WORDS as of 17 Sep 2026.
  // Referral keeps 'Yes' / 'No'; it is a different question and never
  // shared this vocabulary except by an inline lambda written six times.
  'Mild', 'Moderate', 'Severe', 'Yes', 'No',
  'Given', 'Not given', 'Not needed',
  'Helped', 'Partly helped', "Didn't help"
};

/// Rect of every option pill's TEXT, in paint order — the geometry that must
/// not move. Measured on the Text rather than the AnimatedContainer because
/// there are 82 AnimatedContainers on this screen and only these are options.
List<Rect> pillRects(WidgetTester tester) {
  final out = <Rect>[];
  for (final e in tester.allElements) {
    final w = e.widget;
    final ro = e.renderObject;
    if (w is Text &&
        kOptionLabels.contains(w.data) &&
        ro is RenderBox &&
        ro.hasSize) {
      out.add(ro.localToGlobal(Offset.zero) & ro.size);
    }
  }
  return out;
}

void main() {
  setUp(Vocabularies.debugReset);
  tearDown(Vocabularies.debugReset);

  Future<void> pump(WidgetTester tester, EventRecord r, double w) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(w, 1400);
    await tester.pumpWidget(
        MaterialApp(home: LogEventScreen(existing: r, confirmOnSave: true)));
    await tester.pumpAndSettle();
  }

  testWidgets('1. selection state is announced, all five fields', (tester) async {
    final handle = tester.ensureSemantics();
    addTearDown(tester.view.reset);

    await pump(
        tester,
        record(
          severity: EventSeverity.severe,
          given: true,
          helped: RescueResponse.partly,
          secondDose: false,
          referral: true,
        ),
        430);

    final opts = optionSemantics(tester);
    final selected = opts.where((o) => o.$2).map((o) => o.$1).toList();
    final unselected = opts.where((o) => !o.$2).map((o) => o.$1).toList();
    // ignore: avoid_print
    print('  SELECTED  : $selected');
    // ignore: avoid_print
    print('  unselected: $unselected');

    // ⭐ THE COLLISION THIS TEST WAS WRITTEN AROUND IS GONE, 17 Sep 2026.
    //
    // It read: *'Yes' and 'No' each appear on more than one row, so the
    // assertion is on the multiset, not on membership alone* — and that
    // collision was S2's whole argument. Each rescue field now answers in its
    // own words, so a selected label identifies its row.
    //
    // ⛔ THE MULTISET ASSERTION IS KEPT, AND INVERTED: 'Yes' must now appear
    // EXACTLY ONCE. That is a stronger claim than membership, and it is what
    // fails if a rescue field ever borrows the yes/no pair back.
    expect(selected, contains('Severe'), reason: 'severity');
    expect(selected, contains('Given'), reason: 'rescue given');
    expect(selected, contains('Partly helped'), reason: 'did it help');
    expect(selected, contains('Not needed'), reason: 'second dose');
    expect(selected.where((s) => s == 'Yes').length, 1,
        reason: 'referral ALONE keeps Yes — if this is 2 a rescue field has '
            'taken the shared pair back and its answer no longer reads away '
            'from its question');
    expect(selected.where((s) => s == 'No').length, 0,
        reason: 'NOTHING answers No any more except referral, and referral is '
            'Yes in this fixture');
    expect(unselected, contains('Mild'), reason: 'an unselected option exists');
    // The Yes/No multiset, re-enumerated per row for the new wording so the
    // figure stays derived rather than guessed:
    //   severity      Severe selected        -> Mild, Moderate unselected
    //   rescue given  Given selected         -> Not given
    //   did it help   Partly helped selected -> Helped, Didn't help
    //   second dose   Not needed selected    -> Given
    //   referral      Yes selected           -> No
    // => unselected Yes x0, No x1. ⭐ The pair now belongs to ONE row.
    expect(unselected.where((s) => s == 'Yes').length, 0,
        reason: 'no rescue row offers Yes any more');
    expect(unselected.where((s) => s == 'No').length, 1,
        reason: 'referral ALONE still offers No');

    handle.dispose();
  });

  testWidgets('2. changing a selection changes what is announced', (tester) async {
    final handle = tester.ensureSemantics();
    addTearDown(tester.view.reset);
    await pump(tester, record(severity: EventSeverity.mild), 430);

    var sel = optionSemantics(tester).where((o) => o.$2).map((o) => o.$1);
    expect(sel, contains('Mild'));
    expect(sel, isNot(contains('Severe')));

    await tester.tap(find.text('Severe'));
    await tester.pumpAndSettle();

    sel = optionSemantics(tester).where((o) => o.$2).map((o) => o.$1);
    // ignore: avoid_print
    print('  after tapping Severe, selected: ${sel.toList()}');
    expect(sel, contains('Severe'),
        reason: 'a static correct value at first paint is not enough');
    expect(sel, isNot(contains('Mild')));

    handle.dispose();
  });

  testWidgets('3. THE RENDER IS UNCHANGED at 375, 430 and 800', (tester) async {
    addTearDown(tester.view.reset);
    // ⛔ RECAPTURED 17 September 2026 FOR S3, AND THE REASON THIS TEST GIVES
    // HAS CHANGED WITH IT. It was written to prove that ADDING a hand-written
    // `Semantics` wrapper moved no pixels — a claim that passed in both
    // states, which is what made it a proof. ⚠️ **That wrapper no longer
    // exists.** S3 migrated these chips to `FilterChip`/`ChoiceChip`, and
    // `RawChip` emits the identical semantics itself, so the thing the old
    // baseline guarded is gone and the baseline now guards the MIGRATED
    // geometry instead. It is a measurement re-taken, not a citation kept.
    //
    // ⚠️ **CAPTURED UNDER THE DEFAULT MATERIAL THEME, NOT THE APP'S.** This
    // file pumps `MaterialApp(home: ...)` with no `theme:`, so the chip label
    // resolves to Material's own 14, NOT `MERTheme`'s `MERType.caption` (12)
    // that a user actually sees. Stated because a reader will otherwise take
    // these rects for the shipped layout. Pre-existing, not introduced here.
    // ⛔ RECAPTURED 17 September 2026 FOR B1, which replaced the form's
    // event-type `GridView` of hand-rolled tiles with `ChoiceChip`s in a
    // `BoundedChipWrap`. That control sits ABOVE everything this baseline
    // measures.
    //
    // ⭐ **EVERY x AND EVERY SIZE IS UNCHANGED. ONLY y MOVED**, and by a
    // CONSTANT within each width: **+107.3 at 375 and 430, and −8.0 at 800**.
    // That is a pure vertical translation — the picker above got taller on a
    // phone and slightly shorter on a tablet — and it is the signal that B1
    // moved these chips without touching them. A change that had altered the
    // chips themselves would have moved a width or a size too.
    const baseline = <int, List<String>>{
      375: <String>[
        '53.0,648.0 52.3x20.0',
        '147.3,648.0 72.3x20.0',
        '261.7,648.0 72.3x20.0',
        '34.3,1384.0 126.9x20.0',
        '244.0,1384.0 70.5x20.0',
        '53.0,1480.0 52.3x20.0',
        '147.3,1480.0 72.3x20.0',
        '261.7,1480.0 72.3x20.0',
        '53.0,1576.0 109.5x20.0',
        '234.0,1576.0 70.5x20.0',
        '93.6,1692.0 28.2x20.0',
        '248.1,1692.0 42.3x20.0',
      ],
      430: <String>[
        '60.1,631.0 56.4x20.0',
        '165.7,631.0 90.7x20.0',
        '301.4,631.0 84.6x20.0',
        '48.0,1319.0 126.9x20.0',
        '285.3,1319.0 70.5x20.0',
        '53.0,1415.0 70.7x20.0',
        '165.7,1415.0 90.7x20.0',
        '298.3,1415.0 90.7x20.0',
        '53.0,1511.0 137.0x20.0',
        '275.3,1511.0 70.5x20.0',
        '107.4,1607.0 28.2x20.0',
        '289.4,1607.0 42.3x20.0',
      ],
      800: <String>[
        '204.5,554.0 56.4x20.0',
        '339.6,554.0 112.8x20.0',
        '527.0,554.0 84.6x20.0',
        '202.5,1188.0 126.9x20.0',
        '500.8,1188.0 70.5x20.0',
        '190.4,1284.0 84.6x20.0',
        '330.3,1284.0 131.3x20.0',
        '503.7,1284.0 131.3x20.0',
        '205.5,1380.0 141.0x20.0',
        '490.8,1380.0 70.5x20.0',
        '261.9,1476.0 28.2x20.0',
        '504.9,1476.0 42.3x20.0',
      ],
    };

    for (final w in <double>[375, 430, 800]) {
      await pump(tester, record(), w);
      final rects = pillRects(tester)
          .map((r) => '${r.left.toStringAsFixed(1)},${r.top.toStringAsFixed(1)}'
              ' ${r.width.toStringAsFixed(1)}x${r.height.toStringAsFixed(1)}')
          .toList();
      // ignore: avoid_print
      print('  RECTS w=$w  n=${rects.length}');
      for (final r in rects) {
        // ignore: avoid_print
        print('     $r');
      }
      if (baseline.containsKey(w.round())) {
        expect(rects, baseline[w.round()],
            reason: 'S3 moved a single-select chip at width $w');
      }
    }
  });
}
