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
    // ⚠️ RECAPTURED 17 September 2026 FOR THE ANSWER WORDING, and the
    // change is a HEIGHT change rather than a move. Two chips — *Partly
    // helped* and *Didn't help* — now WRAP TO TWO LINES at 375: a rect of
    // 105.3x19.0 becomes 105.3x38.0.
    //
    // ⛔ NOT A TRUNCATION — the 200% gate's ellipsis census is clean, and
    // wrapping is what a chip is supposed to do with a longer label. But
    // the block grows by roughly 19 points, and V5 already has it landing
    // 268 below the fold, so S3 inherits a slightly taller block than it
    // was scoped against.
    // ⛔ BASELINE CAPTURED FROM THE UNPATCHED CODE and pasted here. Regenerate
    // by running this test on a tree without the Semantics wrapper and reading
    // the printed rects.
    const baseline = <int, List<String>>{
      375: <String>[
        '17.5,555.7 103.3x19.0',
        '130.8,546.2 105.3x38.0',
        '245.2,555.7 105.3x19.0',
        '16.5,1270.2 162.5x19.0',
        '189.0,1270.2 160.5x19.0',
        '17.5,1372.7 103.3x19.0',
        '130.8,1363.2 105.3x38.0',
        '245.2,1363.2 105.3x38.0',
        '17.5,1475.2 160.5x19.0',
        '188.0,1475.2 162.5x19.0',
        '17.5,1589.2 160.5x19.0',
        '188.0,1589.2 162.5x19.0',
      ],
      430: <String>[
        '17.5,543.4 121.7x19.0',
        '149.2,543.4 123.7x19.0',
        '281.8,543.4 123.7x19.0',
        '16.5,1189.4 190.0x19.0',
        '216.5,1189.4 188.0x19.0',
        '17.5,1291.9 121.7x19.0',
        '149.2,1282.4 123.7x38.0',
        '281.8,1282.4 123.7x38.0',
        '17.5,1394.4 188.0x19.0',
        '215.5,1394.4 190.0x19.0',
        '17.5,1488.4 188.0x19.0',
        '215.5,1488.4 190.0x19.0',
      ],
      800: <String>[
        '141.5,565.5 162.3x19.0',
        '313.8,565.5 164.3x19.0',
        '487.2,565.5 164.3x19.0',
        '140.5,1172.5 251.0x19.0',
        '401.5,1172.5 249.0x19.0',
        '141.5,1275.0 162.3x19.0',
        '313.8,1265.5 164.3x38.0',
        '487.2,1275.0 164.3x19.0',
        '141.5,1377.5 249.0x19.0',
        '400.5,1377.5 251.0x19.0',
        '141.5,1471.5 249.0x19.0',
        '400.5,1471.5 251.0x19.0',
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
            reason: 'the Semantics wrapper moved something at width $w');
      }
    }
  });
}
