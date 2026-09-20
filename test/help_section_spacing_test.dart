import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/screens/help_screen.dart';
import 'package:medical_event_recorder/theme/mer_theme.dart';

/// BRIEF 64 — the Help screen's section spacing, semantics and expander.
///
/// ⛔ **THIS TEST IS ONLY VALID BECAUSE THE PLATFORM CONDITIONAL IS GONE, AND
/// A FUTURE READER WHO RE-INTRODUCES ONE MUST KNOW THAT.**
///
/// The defect it pins was **invisible to this test's own harness**. The fourth
/// gap sat inside `if (Platform.isWindows)`, and the CLI host IS Windows — so a
/// widget test rendered the branch that was already correct, measured
/// `12, 12, 12, 12`, and reported uniform. On Android the same screen measured
/// **12, 12, 12, 0**, photographed on the tablet as two 1px card borders at
/// y=549 and y=550 with no page background between them.
///
/// ⭐ **THE FIX AND ITS VERIFIABILITY WERE THE SAME CHANGE.** Removing the
/// guard leaves ONE code path, so this test now exercises what Android runs.
/// ⚠️ **Re-introduce any platform conditional around Help's spacing and this
/// test silently stops covering the case it was written for** — it will keep
/// passing, on the branch the host happens to be. `help_no_platform_gap_test`
/// exists to make that impossible to do quietly.
///
/// ⛔ **NOT VERIFIED BY A RE-CAPTURED BASELINE, DELIBERATELY.** A baseline
/// records what is and blesses it; had one been taken while the gap was 0 it
/// would now guard the defect and go red on the fix. Baselines catch
/// regressions and never catch a thing that was born wrong.

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// The bordered container of every section, top to bottom.
  List<Rect> sectionBoxes(WidgetTester tester) {
    final out = <Rect>[];
    for (final e in tester.allElements) {
      final w = e.widget;
      if (w is! Container) continue;
      final d = w.decoration;
      if (d is! BoxDecoration) continue;
      if (d.border == null || d.borderRadius == null) continue;
      final ro = e.renderObject;
      if (ro is! RenderBox || !ro.hasSize) continue;
      out.add(ro.localToGlobal(Offset.zero) & ro.size);
    }
    out.sort((a, b) => a.top.compareTo(b.top));
    return out;
  }

  Future<void> pump(WidgetTester tester,
      {double w = 800, double scale = 1.0}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(w, 4000);
    await tester.pumpWidget(MaterialApp(
      theme: MERTheme.light,
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: const HelpScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  List<double> gapsOf(WidgetTester tester) {
    final b = sectionBoxes(tester);
    return <double>[
      for (var i = 0; i + 1 < b.length; i++) b[i + 1].top - b[i].bottom,
    ];
  }

  testWidgets('1. every inter-section gap is EQUAL TO THE OTHERS',
      (tester) async {
    addTearDown(tester.view.reset);
    await pump(tester);
    final gaps = gapsOf(tester);

    expect(gaps, isNotEmpty,
        reason: 'CONTROL: sections were found at all. An empty list would make '
            'the equality below vacuously true');
    expect(gaps.length, greaterThanOrEqualTo(4),
        reason: 'COVERAGE: the screen has five sections and therefore four '
            'gaps. A short list means the collector missed a section and the '
            'verdict is over an unstated denominator');
    expect(gaps.toSet(), hasLength(1),
        reason: 'THE DEFECT: the gaps were 12, 12, 12 and 0 on Android, '
            'because the fourth sat inside `if (Platform.isWindows)`. They '
            'must all be the same. Measured: $gaps');
  });

  testWidgets('2. and that shared value is the named constant, not a literal',
      (tester) async {
    addTearDown(tester.view.reset);
    await pump(tester);
    final gaps = gapsOf(tester);
    expect(gaps.first, 12.0,
        reason: 'the sections are spaced by `_kSectionGap`. Equal-but-wrong '
            'would satisfy test 1 alone, so the value is pinned too');
  });

  testWidgets('3. the gaps survive expansion and text scale', (tester) async {
    addTearDown(tester.view.reset);
    for (final scale in <double>[1.0, 2.0]) {
      for (final w in <double>[375, 800]) {
        await pump(tester, w: w, scale: scale);
        expect(gapsOf(tester).toSet(), hasLength(1),
            reason: 'collapsed @${scale}x w=$w');

        await tester.tap(find.byType(InkWell).first);
        await tester.pumpAndSettle();
        expect(gapsOf(tester).toSet(), hasLength(1),
            reason: 'EXPANDED @${scale}x w=$w — expanding a section must not '
                'move its neighbours apart. The gaps are siblings in the '
                'Column, not padding inside the sections');
      }
    }
  });

  group('B-4 — the headers carry a role', () {
    testWidgets('4. every section header is a HEADER, and expandable ones are '
        'controls', (tester) async {
      addTearDown(tester.view.reset);
      final handle = tester.ensureSemantics();
      await pump(tester);

      var root = tester.getSemantics(find.byType(HelpScreen));
      while (root.parent != null) {
        root = root.parent!;
      }

      final headers = <String>[];
      final buttons = <String>[];
      void walk(SemanticsNode n) {
        final d = n.getSemanticsData();
        final label = d.label.trim();
        if (label.isNotEmpty && d.flagsCollection.isHeader) headers.add(label);
        if (label.isNotEmpty && d.flagsCollection.isButton) buttons.add(label);
        n.visitChildren((c) {
          walk(c);
          return true;
        });
      }

      walk(root);

      // ⛔ MEASURED BEFORE THE FIX: all five announced as bare `[tappable]`,
      // zero headers among them, and the only HEADER on the screen was the
      // app-bar title.
      for (final title in <String>[
        'RECORDING EVENTS',
        'HISTORY & EXPORT',
        'GETTING HELP',
      ]) {
        expect(headers, contains(title),
            reason: 'a screen reader needs heading structure to navigate by. '
                '"$title" announced no role at all before Brief 64');
        expect(buttons, contains(title),
            reason: 'and an expandable section IS a control — "$title" '
                'expands, so it must say so');
      }

      handle.dispose();
    });
  });

  group('B-5 — a section with nothing to reveal is not an expander', () {
    testWidgets('5. the non-expandable section has no chevron and no tap',
        (tester) async {
      addTearDown(tester.view.reset);
      await pump(tester);

      // ⚠️ ON THIS HOST that section is the WINDOWS quick-log replacement,
      // which is declared `children: []`. On Android the quick-log section has
      // real children and IS expandable — so this test measures whichever
      // platform it runs on, and the assertion is about the RULE rather than
      // about one section.
      final chevrons = find.byIcon(Icons.expand_more).evaluate().length +
          find.byIcon(Icons.expand_less).evaluate().length;
      final taps = <InkWell>[
        for (final e in tester.allElements)
          if (e.widget is InkWell) e.widget as InkWell,
      ].where((w) => w.onTap != null).length;

      expect(chevrons, taps,
          reason: 'EXACTLY the sections that can be tapped show a chevron. '
              'Before Brief 64 the Windows replacement section showed one and '
              'revealed nothing — tapping added 18.0 of empty padding and '
              'flipped the glyph. A control that reveals nothing is worse '
              'than no control: a user cannot tell whether the content is '
              'missing or the feature is absent.\n\n'
              'chevrons=$chevrons tappable=$taps');

      if (Platform.isWindows) {
        expect(find.text('Not available on Windows'), findsOneWidget,
            reason: 'CONTROL: the replacement section is still PRESENT and its '
                'content still visible. B-5 changes how it presents, never '
                'whether it exists — the replacement-section pattern stands');
        expect(chevrons, 4,
            reason: 'four expandable sections on Windows, five sections in '
                'total: the quick-log replacement is the one that is content');
      }
    });
  });
}
