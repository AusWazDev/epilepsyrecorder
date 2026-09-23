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

  /// The PAINTED border of every section, top to bottom.
  ///
  /// ⭐ RE-POINTED 23 September 2026, AND IT IS NOT A LOOSENING. This walked
  /// `Container` ELEMENTS and took their render objects. A `Container` with a
  /// `margin` builds that margin INSIDE its own render object, so the outer box
  /// swallows the spacing and reports the card as ending where its margin ends.
  /// `_StatusBand` — the notifications/previews band, which renders on every
  /// platform but Windows — spaces itself with `margin: EdgeInsets.only(bottom:
  /// 12)` while every real section uses a sibling `SizedBox`. So this collector
  /// measured 0.0 above the first section and called it a defect.
  ///
  /// ⛔ IT WAS MEASURING A PROXY FOR THE THING IT CLAIMS TO TEST. The subject
  /// is whether a user sees page background between two cards; the proxy was a
  /// render box that need not coincide with the painted edge. Now it walks
  /// `RenderDecoratedBox` and takes the box that actually PAINTS the border,
  /// which is the boundary the Brief 64 photograph scanned.
  ///
  /// ⚠️ `_StatusBand`'s margin is a legitimate idiom and was left alone. The
  /// instrument changed, not the subject.
  List<Rect> sectionBoxes(WidgetTester tester) {
    final out = <Rect>[];
    void walk(RenderObject r) {
      if (r is RenderDecoratedBox) {
        final d = r.decoration;
        if (d is BoxDecoration && d.border != null && d.borderRadius != null) {
          out.add(r.localToGlobal(Offset.zero) & r.size);
        }
      }
      r.visitChildren(walk);
    }
    walk(tester.binding.rootElement!.renderObject!);
    out.sort((a, b) => a.top.compareTo(b.top));
    return out;
  }

  Future<void> pump(WidgetTester tester,
      {double w = 800, double scale = 1.0}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(w, 4000);
    // ⛔ A FRESH ELEMENT TREE EVERY TIME, 23 September 2026. `pumpWidget` with
    // the same widget type UPDATES the existing elements rather than rebuilding
    // them, so `_Section._open` survived from one iteration of test 3 to the
    // next: the first tap expanded a section, the second COLLAPSED it, and the
    // "expanded" assertion then measured a collapsed screen on every even pass.
    // ⚠️ That was true on every host, Windows included — it is not part of
    // the platform divergence. It surfaced only once an anti-vacuity control
    // was added; before that the assertion passed either way.
    await tester.pumpWidget(const SizedBox.shrink());
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

        // ⛔ A NAMED SECTION HEADER, NOT `InkWell.first`, 23 September 2026 —
        // AND THIS HALF OF THE TEST WAS VACUOUS ON ONE HOST. `_StatusBand`
        // renders on every platform but Windows and its row is the FIRST
        // InkWell on the screen, so off Windows this tapped the notifications
        // row, expanded nothing, and then asserted that the gaps had not moved
        // — which they trivially had not, because nothing had happened.
        // Measured: expanded sections 0 before the tap and 0 after.
        //
        // ⚠️ ON WINDOWS IT WAS A REAL TEST, because `_StatusBand` is absent
        // there and `first` WAS a section header. The same instrument, the
        // same commit, honest on one machine and empty on the other.
        await tester.tap(find.ancestor(
          of: find.text('RECORDING EVENTS'),
          matching: find.byType(InkWell),
        ).first);
        await tester.pumpAndSettle();

        // ⭐ THE ANTI-VACUITY CONTROL, and the thing whose absence hid the
        // above. An assertion about the EXPANDED state is worth nothing until
        // something has actually expanded.
        expect(find.byIcon(Icons.expand_less), findsWidgets,
            reason: 'CONTROL @${scale}x w=$w: the tap must actually have '
                'expanded a section. Without this the assertion below passes '
                'against a screen where nothing happened at all.');

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
      // ⭐ BOTH IDIOMS, 23 September 2026, AND WIDENING THIS MAKES THE TEST
      // HARDER TO SATISFY, NOT EASIER. Help uses two chevrons for two
      // meanings: `expand_more`/`expand_less` reveal content in place, and
      // `chevron_right` goes somewhere. This counted only the first, so a
      // tappable row wearing the SECOND read as a control with no affordance
      // at all — which is how `_StatusRow` sat at chevrons=4 tappable=5 while
      // carrying the correct glyph for what it does. The assertion below says
      // "exactly the sections that can be tapped show a chevron"; it now
      // counts every chevron that says so.
      final chevrons = find.byIcon(Icons.expand_more).evaluate().length +
          find.byIcon(Icons.expand_less).evaluate().length +
          find.byIcon(Icons.chevron_right).evaluate().length;
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
