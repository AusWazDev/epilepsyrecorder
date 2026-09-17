import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/vocabulary.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/log_event_screen.dart';
import 'package:medical_event_recorder/theme/mer_theme.dart';
import 'package:medical_event_recorder/theme/mer_type.dart';

/// ⛔ THE FIVE BEHAVIOURS `_SelectionWrap` CARRIES, ASSERTED BEFORE THE IDIOM
/// CHANGES SO THEY ARE A BEFORE-AND-AFTER GUARD RATHER THAN A DESCRIPTION.
///
/// S3 rebuilds the form's selection controls on the idiom the wizard already
/// uses. ⚠️ **Four of the five behaviours are invisible until their exact case
/// recurs**, which is the shape of every silent defect this build has found.
///
/// ⭐ **The test is not "does it look like a chip."** It is: does a retired
/// legacy value still appear, still selected, still pinned, still labelled
/// without its emoji, and still announced.
///
/// ## ⛔ BEHAVIOUR 3 IS THE OPPOSITE OF WHAT I FIRST WROTE, AND THE SOURCE
/// SETTLED IT
///
/// I asserted the chip must render the label WITHOUT the glyph. It must render
/// it WITH one. `VocabularyEntry.display` is
/// `emoji == null ? label : '$emoji $label'`, and the call site says so
/// plainly: *"displayFor, not labelFor: the glyph belongs on a chip and
/// nowhere a record is rendered."*
///
/// ⭐ **So the split runs the other way.** `display` is for PICKERS — a chip
/// can afford a glyph and it helps someone scanning a grid just after an
/// event. `label` is for RECORDS and exports, where an emoji-less text style
/// could mangle it.
///
/// ## What that makes testable, and it is sharper than the wrong version
///
/// Two fixtures, because the split has two directions:
///
///  * **modern** — stored value `Tired`, emoji `😴`, so the chip shows
///    `😴 Tired`. **The chip renders MORE than the stored string.**
///  * **legacy retired** — stored value `😴 Tired and weary`, whose seed sets
///    `label: 'Tired and weary'` with the glyph STRIPPED, precisely so
///    `display` does not double it. ⛔ **The chip must show one glyph, not
///    two.** That is the defect the split exists to prevent, and it is
///    invisible unless a record carries a legacy value.

/// Stored value and rendered display for the RETIRED LEGACY entry
/// (`kLegacyObservations`, `isActive: false`). The two are equal here only
/// because the seed strips the glyph from the label; a seed that did not would
/// render two.
const String kLegacyValue = '😴 Tired and weary';
const String kLegacyDisplay = '😴 Tired and weary';
const String kLegacyDoubled = '😴 😴 Tired and weary';

/// A MODERN entry: the stored value carries no glyph and the chip adds one.
///
/// ⚠️ **`Tired` was the obvious choice and is UNUSABLE, which is itself worth
/// recording.** `kSeedObservations:344` seeds `Tired` with `emoji: '😴'`, and
/// `kSeedTriggers:1525` seeds a *different* `Tired` with **no emoji at all** —
/// ICHD-3 prodrome, added in the migraine pass. So a bare `find.text('Tired')`
/// matches a live TRIGGER chip, and the negative below would have failed
/// against correct code.
///
/// ⭐ **The same word can be in two vocabularies with different glyph
/// treatment, so a finder keyed on a bare value is ambiguous across fields.**
/// `Memory gap` is seeded exactly once, in observations
/// (`vocabulary.dart:346`; the only other occurrence is a relevance list, not
/// a seed), so the negative means what it says.
const String kModernValue = 'Memory gap';
const String kModernDisplay = '🕳️ Memory gap';

EventRecord carryingLegacy() => EventRecord(
      id: 'legacy',
      timestamp: DateTime(2026, 8, 1, 9),
      duration: DurationCategory.oneToFive,
      durationSeconds: 120,
      detailsCompleted: true,
      // The record carries a value the vocabulary no longer offers.
      feelings: const <String>[kLegacyValue, kModernValue],
      triggers: const <String>[],
      referralRequired: false,
      notes: '',
      eventType: kTypeSeizure,
      severity: EventSeverity.mild,
    );

void main() {
  setUpAll(() async {
    // ⚠️ Roboto, because one assertion here is a HEIGHT and the harness font
    // is monospaced at one em per glyph.
    final path =
        '${Platform.environment['FLUTTER_ROOT'] ?? 'C:/Flutter/flutter'}'
        '/bin/cache/artifacts/material_fonts/roboto-regular.ttf';
    final file = File(path);
    if (!file.existsSync()) {
      fail('Roboto not found at $path — a height claim needs the real font');
    }
    final bytes = file.readAsBytesSync();
    final loader = FontLoader('Roboto')
      ..addFont(Future.value(bytes.buffer.asByteData()));
    await loader.load();
  });

  setUp(Vocabularies.debugReset);
  tearDown(Vocabularies.debugReset);

  Future<void> pump(WidgetTester tester) async {
    // Tall and wide, so the picker is not collapsed by the viewport and every
    // chip is in the tree. Behaviour 1 is about the CAP, not the viewport.
    tester.view.physicalSize = const Size(900, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: MERTheme.light,
      home: LogEventScreen(existing: carryingLegacy(), confirmOnSave: false),
    ));
    await tester.pumpAndSettle();
    for (var e = tester.takeException(); e != null; e = tester.takeException()) {}
  }

  /// The semantics node wrapping a given label, or null.
  SemanticsNode? nodeFor(WidgetTester tester, String label) {
    SemanticsNode? found;
    void walk(SemanticsNode n) {
      final d = n.getSemanticsData();
      if (d.label == label) found ??= n;
      n.visitChildren((c) {
        walk(c);
        return true;
      });
    }

    walk(tester.binding.pipelineOwner.semanticsOwner!.rootSemanticsNode!);
    return found;
  }

  testWidgets('1. a retired legacy value is PRESENT on the form',
      (tester) async {
    // ⛔ BEHAVIOUR 2: `options` is offerable-PLUS-CARRIED. Without it the chip
    // vanishes and the record silently loses a value the user can no longer
    // see or deselect.
    await pump(tester);
    // The entry is genuinely NOT offered, or this proves nothing.
    expect(
        Vocabularies.offerableObservations.map((e) => e.value),
        isNot(contains(kLegacyValue)),
        reason: 'positive control: the value really is retired, so its chip '
            'can only be here via the offerable-plus-carried path');
    expect(find.text(kLegacyDisplay), findsOneWidget,
        reason: 'the retired value keeps its chip. Without it the record '
            'silently loses a value the user can no longer see or deselect');
  });

  testWidgets('2. the value-vs-label split holds in BOTH directions',
      (tester) async {
    // ⛔ BEHAVIOUR 3. A chip renders `display`; a record renders `label`. The
    // glyph belongs on a chip and nowhere a record is rendered — so the chip
    // shows MORE than the stored value for a modern entry, and exactly ONE
    // glyph for a legacy value whose stored string already carries one.
    await pump(tester);
    // MODERN: the chip renders MORE than the stored string.
    expect(find.text(kModernDisplay), findsOneWidget,
        reason: 'a chip shows displayFor, which adds the glyph the stored '
            'value does not carry');
    expect(find.text(kModernValue), findsNothing,
        reason: 'and the bare stored value is not what is rendered');

    // LEGACY: exactly one glyph, never two.
    expect(find.text(kLegacyDisplay), findsOneWidget);
    expect(find.text(kLegacyDoubled), findsNothing,
        reason: 'the legacy seed strips the glyph from its LABEL so display '
            'cannot double it. This is the assertion that fails if that '
            'stripping is ever undone');
  });

  testWidgets('3. it is SELECTED, and announced as such', (tester) async {
    // ⛔ BEHAVIOUR 4: the Semantics block. Selection was carried by fill
    // colour, border colour, border width, font weight and text colour — all
    // VISUAL — so a screen reader announced every observation and never which
    // ones the record held.
    final handle = tester.ensureSemantics();
    await pump(tester);

    final node = nodeFor(tester, kLegacyDisplay);
    expect(node, isNotNull,
        reason: 'positive control: the chip has a semantics node at all');
    final data = node!.getSemanticsData();
    expect(data.hasFlag(SemanticsFlag.isButton), isTrue,
        reason: 'it is tappable and must announce as such');
    // Not web in the harness, so `selected` is the branch that carries it.
    expect(data.hasFlag(SemanticsFlag.isSelected), isTrue,
        reason: 'a screen reader must be able to tell WHICH observations this '
            'record holds, and this is the only non-visual signal');

    // And an unselected one must NOT claim to be selected, or the flag says
    // nothing.
    final other = nodeFor(tester, '🪫 Weak');
    expect(other, isNotNull, reason: 'positive control: another chip exists');
    expect(other!.getSemanticsData().hasFlag(SemanticsFlag.isSelected), isFalse,
        reason: 'the control that makes the assertion above mean something');
    handle.dispose();
  });

  testWidgets('4. it is PINNED, so a collapsed picker cannot hide it',
      (tester) async {
    // ⛔ BEHAVIOUR 1. Narrow and short enough that BoundedChipWrap collapses,
    // then the carried value must still be in the tree.
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: MERTheme.light,
      home: LogEventScreen(existing: carryingLegacy(), confirmOnSave: false),
    ));
    await tester.pumpAndSettle();
    for (var e = tester.takeException(); e != null; e = tester.takeException()) {}

    // The picker is collapsed here — the disclosure is showing.
    expect(find.textContaining('to choose from'), findsWidgets,
        reason: 'positive control: the picker really is collapsed, so pinning '
            'is what is being tested rather than a full list');
    expect(find.text(kLegacyDisplay), findsOneWidget,
        reason: 'a selected chip is PINNED past the cap. Without it the '
            'collapsed picker hides a value the record already carries');
  });

  testWidgets('5. onAdd null HIDES the add pill', (tester) async {
    // ⛔ BEHAVIOUR 5, and it is a NEGATIVE, so it gets the control.
    // `Vocabularies.canPersist` is false with no database, and an entry added
    // then could not survive a restart.
    await pump(tester);
    expect(Vocabularies.canPersist, isFalse,
        reason: 'precondition: no database in this harness, so onAdd is null');
    expect(find.text('Add something else'), findsNothing,
        reason: 'with no database the pill must not be offered at all');

    // ⛔ THE CONTROL: the same finder DOES see that label when it is rendered.
    // Without this, findsNothing passes just as well against a typo.
    await tester.pumpWidget(MaterialApp(
      theme: MERTheme.light,
      home: const Scaffold(body: Text('Add something else')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Add something else'), findsOneWidget,
        reason: 'the finder is live, so the absence above is a fact about the '
            'form rather than about the finder');
  });

  testWidgets('6. MEASUREMENT: the rendered chip height', (tester) async {
    // ⚠️ REPORTED, NOT ASSERTED. S1's floor is 48 and the arithmetic suggests
    // roughly 34 for the wrap and 44 for the row -- but that is arithmetic,
    // and S1's gain is real only if the measurement says so.
    await pump(tester);

    double? heightOf(String label) {
      final f = find.text(label);
      if (f.evaluate().isEmpty) return null;
      // The tappable box, not the text: walk up to the nearest ancestor with a
      // decoration, which is the pill.
      final box = find
          .ancestor(of: f, matching: find.byType(AnimatedContainer))
          .evaluate();
      if (box.isEmpty) {
        final chip = find.ancestor(of: f, matching: find.byType(InkWell));
        if (chip.evaluate().isEmpty) return null;
        return tester.getRect(chip.first).height;
      }
      return tester.getRect(
              find.ancestor(of: f, matching: find.byType(AnimatedContainer)).first)
          .height;
    }

    final wrap = heightOf(kLegacyDisplay);
    final row = heightOf(severityLabel(EventSeverity.mild));

    // ⛔ THE PAINTED BOX IS NOT THE TOUCH TARGET, AND S1'S FLOOR IS A TOUCH
    // RULE. `RawChip` with `MaterialTapTargetSize.padded` wraps itself in a
    // hit-test redirector that enlarges the TAPPABLE area without enlarging
    // anything drawn. Reporting only the painted height would understate the
    // chip against a floor the chip may already clear — the same
    // measuring-something-adjacent error this build keeps finding.
    double? tapTargetOf(Type chipType) {
      final f = find.byType(chipType);
      if (f.evaluate().isEmpty) return null;
      return tester.getRect(f.first).height;
    }

    final wrapTap = tapTargetOf(FilterChip);
    final rowTap = tapTargetOf(ChoiceChip);

    // ⚠️ THE RESOLVED LABEL SIZE, READ OFF THE RENDER TREE. The chip theme
    // sets `fontSize: MERType.caption` (12), so migrating LOOKED like it must
    // shrink the form's chip labels from body 14. The geometry said otherwise,
    // so the effective style is measured rather than inferred from the theme.
    double? labelSize(String text) {
      final f = find.text(text);
      if (f.evaluate().isEmpty) return null;
      return tester.renderObject<RenderParagraph>(f).text.style?.fontSize;
    }

    // ignore: avoid_print
    print('CHIP HEIGHT (Roboto, scale 1.0)\n'
        '                        painted   tap target\n'
        '  _SelectionWrap pill : ${wrap?.toStringAsFixed(1)}      '
        '${wrapTap?.toStringAsFixed(1)}\n'
        '  _SelectionRow pill  : ${row?.toStringAsFixed(1)}      '
        '${rowTap?.toStringAsFixed(1)}\n'
        '  S1 floor            : 48.0\n'
        '  label size (wrap)   : ${labelSize(kLegacyDisplay)}\n'
        '  label size (row)    : '
        '${labelSize(severityLabel(EventSeverity.mild))}\n'
        '  MERType.body        : ${MERType.body}\n'
        '  MERType.caption     : ${MERType.caption}');
    expect(wrap, isNotNull, reason: 'positive control: a pill was measured');
  });
}
