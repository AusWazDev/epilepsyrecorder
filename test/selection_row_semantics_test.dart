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
  'Mild', 'Moderate', 'Severe', 'Yes', 'No', 'Partly'
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

    // severity = Severe; rescue given = Yes; helped = Partly; second dose = No;
    // referral = Yes. 'Yes' and 'No' each appear on more than one row, so the
    // assertion is on the multiset, not on membership alone.
    expect(selected, contains('Severe'), reason: 'severity');
    expect(selected, contains('Partly'), reason: 'did it help');
    expect(selected.where((s) => s == 'Yes').length, 2,
        reason: 'rescue given = Yes and referral = Yes are BOTH selected');
    expect(selected.where((s) => s == 'No').length, 1,
        reason: 'second dose = No is selected');
    expect(unselected, contains('Mild'), reason: 'an unselected option exists');
    // The unselected Yes/No multiset, enumerated per row so the figure is
    // derived rather than guessed:
    //   severity      Severe selected  -> Mild, Moderate unselected
    //   rescue given  Yes selected     -> No
    //   did it help   Partly selected  -> Yes, No
    //   second dose   No selected      -> Yes
    //   referral      Yes selected     -> No
    // => unselected Yes x2, No x3.
    expect(unselected.where((s) => s == 'Yes').length, 2,
        reason: "did-it-help's Yes and second-dose's Yes are both unselected");
    expect(unselected.where((s) => s == 'No').length, 3,
        reason: "rescue-given, did-it-help and referral each have No unselected");

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
        '17.5,1364.2 103.3x19.0',
        '130.8,1364.2 105.3x19.0',
        '245.2,1364.2 105.3x19.0',
        '17.5,1478.2 160.5x19.0',
        '188.0,1478.2 162.5x19.0',
        '17.5,1592.2 160.5x19.0',
        '188.0,1592.2 162.5x19.0',
      ],
      430: <String>[
        '17.5,543.4 121.7x19.0',
        '149.2,543.4 123.7x19.0',
        '281.8,543.4 123.7x19.0',
        '16.5,1189.4 190.0x19.0',
        '216.5,1189.4 188.0x19.0',
        '17.5,1283.4 121.7x19.0',
        '149.2,1283.4 123.7x19.0',
        '281.8,1283.4 123.7x19.0',
        '17.5,1377.4 188.0x19.0',
        '215.5,1377.4 190.0x19.0',
        '17.5,1471.4 188.0x19.0',
        '215.5,1471.4 190.0x19.0',
      ],
      800: <String>[
        '141.5,565.5 162.3x19.0',
        '313.8,565.5 164.3x19.0',
        '487.2,565.5 164.3x19.0',
        '140.5,1172.5 251.0x19.0',
        '401.5,1172.5 249.0x19.0',
        '141.5,1266.5 162.3x19.0',
        '313.8,1266.5 164.3x19.0',
        '487.2,1266.5 164.3x19.0',
        '141.5,1360.5 249.0x19.0',
        '400.5,1360.5 251.0x19.0',
        '141.5,1454.5 249.0x19.0',
        '400.5,1454.5 251.0x19.0',
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
