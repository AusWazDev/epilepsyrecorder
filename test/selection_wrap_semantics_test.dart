import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/log_event_screen.dart';

/// AUDIT.md §13(z) and §13(t) — `_SelectionWrap` must announce WHICH options are
/// selected, and must not change a single pixel doing it.
///
/// ⭐ MULTI-SELECT, unlike `_SelectionRow`: `Set<String> selected` and
/// `onToggle`. It serves the two pickers — observations (afterwards) and
/// triggers (beforehand).
///
/// ⚠️ THE MECHANISM IS NEVERTHELESS IDENTICAL, and that was READ rather than
/// assumed. `FilterChip` (which the wizard uses for these same two fields) and
/// `ChoiceChip` both pass `selected` to `RawChip` unchanged, and `RawChip` has
/// exactly ONE `Semantics(` block. The only difference between the two chips is
/// `showCheckmark`'s default, which is visual.
///
/// ⛔ SELECTION IS EXERCISED BY TAPPING, not by constructing a record with
/// stored values. The stored value and the display label differ for legacy
/// observation entries, so building the record would mean guessing at values
/// while the test's assertions are about labels.
///
/// ⚠️ No prefs, so the one-prefs-test-per-process rule does not apply.

EventRecord blank() => EventRecord(
      id: 'wrap-1',
      timestamp: DateTime(2026, 8, 20, 9, 0),
      duration: DurationCategory.oneToFive,
      durationSeconds: 90,
      eventType: 'seizure',
      severity: EventSeverity.mild,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: false,
      notes: '',
      detailsCompleted: true,
    );

/// Labels visible in the collapsed pickers, read from an earlier semantics dump
/// of this screen rather than guessed.
const kObs1 = '😴 Tired';
const kObs2 = '🪫 Weak';
const kTrig1 = 'Stress';

/// (label, isSelected) for every tappable labelled node.
List<(String, bool)> nodes(WidgetTester tester) {
  var root = tester.getSemantics(find.byType(LogEventScreen));
  while (root.parent != null) {
    root = root.parent!;
  }
  final out = <(String, bool)>[];
  void walk(SemanticsNode n) {
    final d = n.getSemanticsData();
    final label = d.label.trim();
    if (label.isNotEmpty && d.hasAction(SemanticsAction.tap)) {
      // ⛔ The enum values are isTrue / isFalse / none, NOT 'selected'.
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

bool announcedSelected(WidgetTester tester, String label) =>
    nodes(tester).any((n) => n.$1 == label && n.$2);

/// The chip labels whose geometry must not move. Scoped to a handful so the
/// baseline stays readable.
const kGeomLabels = <String>{kObs1, kObs2, kTrig1, 'Poor sleep'};

List<Rect> chipRects(WidgetTester tester) {
  final out = <Rect>[];
  for (final e in tester.allElements) {
    final w = e.widget;
    final ro = e.renderObject;
    if (w is Text &&
        kGeomLabels.contains(w.data) &&
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

  Future<void> pump(WidgetTester tester, double w) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(w, 1400);
    await tester.pumpWidget(MaterialApp(
        home: LogEventScreen(existing: blank(), confirmOnSave: true)));
    await tester.pumpAndSettle();
  }

  testWidgets('1. observations: nothing selected announces as selected',
      (tester) async {
    final handle = tester.ensureSemantics();
    addTearDown(tester.view.reset);
    await pump(tester, 430);

    final sel = nodes(tester).where((n) => n.$2).map((n) => n.$1).toList();
    // ignore: avoid_print
    print('  with an empty record, SELECTED = $sel');
    // â SCOPED TO THIS WIDGET'S CHIPS. The whole-tree set is NOT empty on a
    // blank record and must not be asserted so: `_SelectionRow` -- fixed on
    // 9 Sep -- correctly announces the severity default (Mild) and referral
    // (No). A first version asserted isEmpty and failed on its own sibling's
    // correct output.
    expect(sel.where(kGeomLabels.contains), isEmpty,
        reason: 'no observation or trigger chip is selected on a blank record');
    handle.dispose();
  });

  testWidgets('2. MULTI-select: selecting TWO announces BOTH', (tester) async {
    final handle = tester.ensureSemantics();
    addTearDown(tester.view.reset);
    await pump(tester, 430);

    // ⭐ TWO, not one. A single-selection assertion would pass on a broken
    // multi-select that only ever marks the most recent tap.
    await tester.tap(find.text(kObs1));
    await tester.pumpAndSettle();
    await tester.tap(find.text(kObs2));
    await tester.pumpAndSettle();

    final sel = nodes(tester).where((n) => n.$2).map((n) => n.$1).toList();
    // ignore: avoid_print
    print('  after tapping two observations, SELECTED = $sel');
    expect(announcedSelected(tester, kObs1), isTrue, reason: 'first observation');
    expect(announcedSelected(tester, kObs2), isTrue, reason: 'second observation');
    expect(sel.where(kGeomLabels.contains).length, 2,
        reason: 'exactly the two chips tapped, nothing else from this widget');
    handle.dispose();
  });

  testWidgets('3. triggers announce too, and de-selecting re-announces',
      (tester) async {
    final handle = tester.ensureSemantics();
    addTearDown(tester.view.reset);
    await pump(tester, 430);

    await tester.tap(find.text(kTrig1));
    await tester.pumpAndSettle();
    expect(announcedSelected(tester, kTrig1), isTrue,
        reason: 'the SECOND field this widget serves, not just the first');

    await tester.tap(find.text(kTrig1));
    await tester.pumpAndSettle();
    // ignore: avoid_print
    print('  after de-selecting, SELECTED = '
        '${nodes(tester).where((n) => n.$2).map((n) => n.$1).toList()}');
    expect(announcedSelected(tester, kTrig1), isFalse,
        reason: 'de-selecting must stop announcing, not only selecting start');
    handle.dispose();
  });

  testWidgets('4. THE RENDER IS UNCHANGED at 375, 430 and 800', (tester) async {
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
        '33.0,802.0 98.7x20.0',
        '173.7,802.0 84.6x20.0',
        '33.0,1122.0 84.6x20.0',
        '159.6,1122.0 141.0x20.0',
      ],
      430: <String>[
        '33.0,765.0 98.7x20.0',
        '173.7,765.0 84.6x20.0',
        '33.0,1071.0 84.6x20.0',
        '159.6,1071.0 141.0x20.0',
      ],
      800: <String>[
        '157.0,671.0 98.7x20.0',
        '297.7,671.0 84.6x20.0',
        '157.0,940.0 84.6x20.0',
        '283.6,940.0 141.0x20.0',
      ],
    };

    for (final w in <double>[375, 430, 800]) {
      await pump(tester, w);
      final rects = chipRects(tester)
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
            reason: 'S3 moved an observation or trigger chip at width $w');
      }
    }
  });
}
