import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/vocabulary_screen.dart';

/// AUDIT.md §13(z) — "Your lists"' selection checkbox must announce WHAT it
/// selects, not only its checked state.
///
/// ⚠️ ITS OWN FILE, and for two reasons. It needs a much taller surface than
/// the other four controls, and it is the one dynamic string, so its assertions
/// are about the ENTRY rather than about a constant. It was also the only one
/// of the five that would not reproduce inside a four-screen test — the reason
/// was never established, and the isolated harness works, so it is isolated
/// rather than diagnosed.
///
/// ⛔ A TALL SURFACE IS REQUIRED. `vocabulary_screen_test.dart` records why:
/// `ListView` builds lazily, so on a short view every row below the fold is
/// ABSENT from the tree and an assertion about them passes for the wrong
/// reason — five of that file's tests failed that way first. At 430x1200 this
/// screen yields ZERO checkboxes.

void main() {
  setUp(Vocabularies.debugReset);
  tearDown(Vocabularies.debugReset);

  Future<void> pumpSelecting(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: VocabularyScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Select'), findsWidgets,
        reason: 'Your lists must offer a Select control to enter selection mode');
    await tester.tap(find.text('Select').first);
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsWidgets,
        reason: 'selection mode must render checkboxes, or nothing below means '
            'anything');
  }

  /// Every name a reader could hear on this screen.
  Set<String> announced(WidgetTester tester) {
    var root = tester.getSemantics(find.byType(MaterialApp));
    while (root.parent != null) {
      root = root.parent!;
    }
    final out = <String>{};
    void walk(SemanticsNode n) {
      final d = n.getSemanticsData();
      if (d.label.trim().isNotEmpty) out.add(d.label.trim());
      if (d.tooltip.trim().isNotEmpty) out.add(d.tooltip.trim());
      n.visitChildren((c) {
        walk(c);
        return true;
      });
    }

    walk(root);
    return out;
  }

  testWidgets('the checkbox announces the ENTRY it selects, not a constant',
      (tester) async {
    final handle = tester.ensureSemantics();
    await pumpSelecting(tester);

    // ⛔ `contains`, NOT `startsWith`. The label MERGES with the row's own
    // text: the node reads the entry name FIRST and then Select <entry>.
    // A startsWith matcher found exactly one hit (Select entries, the
    // selection-bar text) and reported the fix as absent when it was
    // working. The probe encoded an assumption about where the answer
    // lives, per section 13(az).
    final selects = announced(tester)
        .where((s) => s.contains('Select ') && !s.startsWith('Select entries'))
        .map((s) => s.substring(s.indexOf('Select ')))
        .toList()
      ..sort();
    // ignore: avoid_print
    print('  checkboxes: ${tester.widgetList(find.byType(Checkbox)).length}');
    // ignore: avoid_print
    print('  "Select …" names found: ${selects.length}');
    // ignore: avoid_print
    print('  first five: ${selects.take(5).toList()}');

    // ⭐ TWO DISTINCT, not one. A constant `semanticLabel: 'Select'` would
    // satisfy a single-entry assertion and tell a reader nothing about WHICH
    // entry. This is the assertion that makes the string's dynamism load-bearing.
    expect(selects.toSet().length, greaterThanOrEqualTo(2),
        reason: 'two different entries must announce differently, or the label '
            'is a constant dressed as a name');

    // And the plain 'Select' mode toggle must not be mistaken for one of them.
    expect(selects, isNot(contains('Select')),
        reason: 'the bare "Select" is the mode toggle, not a checkbox name');

    handle.dispose();
  });

  testWidgets('THE RENDER IS UNCHANGED — first three checkbox rects',
      (tester) async {
    await pumpSelecting(tester);

    // ⛔ CAPTURED FROM UNPATCHED CODE, so this passes in BOTH states. That is
    // what makes it a proof rather than a formality — the shape that has now
    // caught the difference three times.
    const baseline = <String>[
      '1144.0,302.0 48.0x48.0',
      '1144.0,370.5 48.0x48.0',
      '1144.0,496.5 48.0x48.0',
    ];

    final rects = <String>[];
    for (final e in tester.allElements) {
      final w = e.widget;
      final ro = e.renderObject;
      if (w is Checkbox && ro is RenderBox && ro.hasSize && rects.length < 3) {
        final r = ro.localToGlobal(Offset.zero) & ro.size;
        rects.add('${r.left.toStringAsFixed(1)},${r.top.toStringAsFixed(1)} '
            '${r.width.toStringAsFixed(1)}x${r.height.toStringAsFixed(1)}');
      }
    }
    // ignore: avoid_print
    print('  RECTS $rects');
    expect(rects, baseline,
        reason: 'the semanticLabel moved a checkbox, which it must not');
  });
}
