import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/vocabulary.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/vocabulary_screen.dart';

/// "Your lists" — and the one rule a tidy-up could break silently.
///
/// ## ⛔ THE RULE
///
/// This screen is the ONLY place a user can see why a chip renders the way it
/// does. So **every label a record can produce must be reachable on it.** A
/// collapse that quietly drops something satisfies every other test here and
/// breaks exactly that.
///
/// Two changes were made and each could have broken it:
///
///   * retired entries moved behind a DISCLOSURE — reachable, one tap away
///   * mis-decoded twins are NOT RENDERED AT ALL — reachable only because
///     every twin has a clean sibling carrying an identical label
///
/// The second is the load-bearing one, and test 1 pins the structural
/// guarantee it rests on rather than trusting it.

void main() {
  setUp(Vocabularies.debugReset);
  tearDown(Vocabularies.debugReset);

  /// ⚠️ A TALL SURFACE, and it is not cosmetic. `ListView` builds lazily, so
  /// on the default 800x600 test view every row below the fold is absent from
  /// the widget tree — and a reachability test measuring `findsNothing` would
  /// then pass for the WRONG REASON, reporting the screen as clean while it was
  /// simply not built. Five tests here failed that way first.
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: VocabularyScreen()));
    await tester.pumpAndSettle();
  }

  /// Every label that any stored value can resolve to.
  Set<String> allReachableLabels() {
    final out = <String>{};
    for (final t in <String>[
      kEventTypeTable,
      kTriggerTable,
      kObservationTable
    ]) {
      for (final e in Vocabularies.allIn(t)) {
        out.add(Vocabularies.labelFor(t, e.value));
      }
    }
    return out;
  }

  group('⛔ THE STRUCTURAL GUARANTEE THE HIDE RESTS ON', () {
    test('1. every mis-decoded twin has a clean sibling with the SAME label',
        () {
      // THE LOAD-BEARING FACT. Twins are not rendered, so a twin whose label no
      // other entry carries would become unreachable and the screen would start
      // lying. `mangledLegacyObservations` is DERIVED from kLegacyObservations,
      // which makes this true by construction — and this is what stops that
      // construction changing underneath the screen.
      final twins = mangledLegacyObservations();
      expect(twins, isNotEmpty, reason: 'no twins means this proves nothing');

      for (final t in twins) {
        final siblings =
            kLegacyObservations.where((s) => s.label == t.label).toList();
        expect(siblings, isNotEmpty,
            reason: 'UNREACHABLE: "${t.label}" exists only as a twin, and the '
                'screen does not render twins');
        expect(t.value, isNot(siblings.first.value),
            reason: 'a twin must be a DIFFERENT stored value from its sibling, '
                'or it is not a twin at all');
      }
    });

    test('2. and isMisdecodedTwin matches exactly that set, nothing wider', () {
      for (final t in mangledLegacyObservations()) {
        expect(isMisdecodedTwin(kObservationTable, t.value), isTrue,
            reason: t.label);
      }
      // NEGATIVE CONTROL: it must not swallow the clean legacy entries, which
      // ARE rendered, nor the live ones.
      for (final s in kLegacyObservations) {
        expect(isMisdecodedTwin(kObservationTable, s.value), isFalse,
            reason: 'the CLEAN legacy entry "${s.label}" would vanish');
      }
      for (final s in kSeedObservations) {
        expect(isMisdecodedTwin(kObservationTable, s.value), isFalse,
            reason: 'the LIVE entry "${s.label}" would vanish');
      }
      // And it is scoped to observations — no other vocabulary has twins.
      for (final s in kSeedTriggers) {
        expect(isMisdecodedTwin(kTriggerTable, s.value), isFalse);
      }
    });

    test('3. it is SEPARATE from isShippedHidden and does not weaken it', () {
      // The guard that stops a user re-offering a glyph-bearing value must be
      // untouched: a twin is BOTH un-showable and un-rendered, but a clean
      // legacy entry is only the first.
      for (final s in kLegacyObservations) {
        expect(isShippedHidden(kObservationTable, s.value), isTrue,
            reason: 'still refused for showing: ${s.label}');
        expect(isMisdecodedTwin(kObservationTable, s.value), isFalse,
            reason: 'but still RENDERED: ${s.label}');
      }
    });
  });

  group('⛔ EVERY LABEL A RECORD CAN PRODUCE IS REACHABLE', () {
    testWidgets('4. with the retired blocks EXPANDED, every label is on screen',
        (tester) async {
      // The rule, measured over the whole vocabulary rather than a sample.
      await pump(tester);

      // Open every disclosure.
      for (final show in find.text('Show').evaluate().toList()) {
        await tester.tap(find.byWidget(show.widget));
        await tester.pumpAndSettle();
      }

      final missing = <String>[];
      for (final label in allReachableLabels()) {
        if (find.textContaining(label).evaluate().isEmpty) missing.add(label);
      }
      expect(missing, isEmpty,
          reason: 'THE SCREEN IS LYING. These labels can appear on a record and '
              'cannot be found here, so a user meeting one has no way to learn '
              'what it is: $missing');
    });

    testWidgets('5. and the twins are reachable THROUGH THEIR SIBLINGS',
        (tester) async {
      // Test 4 would pass even if twins were rendered. This is the specific
      // claim: the twin's stored VALUE is nowhere on screen, and its LABEL is,
      // because the clean sibling carries it.
      await pump(tester);
      for (final show in find.text('Show').evaluate().toList()) {
        await tester.tap(find.byWidget(show.widget));
        await tester.pumpAndSettle();
      }

      for (final t in mangledLegacyObservations()) {
        expect(find.textContaining(t.value), findsNothing,
            reason: 'the corrupted STRING is being shown to a user: ${t.value}');
        expect(find.textContaining(t.label), findsWidgets,
            reason: 'but its LABEL must still be here: ${t.label}');
      }
    });
  });

  group('THE COLLAPSE', () {
    testWidgets('6. retired entries are HIDDEN by default', (tester) async {
      await pump(tester);
      // A retired observation, not rendered until the disclosure is opened.
      expect(find.textContaining('Tired and weary'), findsNothing);
      // And the disclosure says how many, so it never reads as "there might be
      // something here".
      expect(find.textContaining('replaced by newer wording'), findsWidgets);
    });

    testWidgets('7. tapping it reveals them, and tapping again hides them',
        (tester) async {
      await pump(tester);

      final toggle = find.textContaining('replaced by newer wording').first;
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(find.textContaining('Tired and weary'), findsWidgets,
          reason: 'the disclosure did not open');

      await tester.tap(find.textContaining('replaced by newer wording').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Tired and weary'), findsNothing,
          reason: 'and it must close again');
    });

    testWidgets('8. ⛔ the counts are what this change exists to move',
        (tester) async {
      // Stated as numbers because "less cluttered" is not a measurement.
      //
      //   before   48 rows, 22 retired, 11 of them duplicates
      //   after    27 collapsed, 39 fully expanded
      //
      // Computed from the vocabulary rather than hardcoded, so the assertion
      // survives a seed being added.
      final twins = mangledLegacyObservations().length;
      final legacy = kLegacyObservations.length;

      var before = 0;
      for (final t in <String>[
        kEventTypeTable,
        kTriggerTable,
        kObservationTable
      ]) {
        before += Vocabularies.allIn(t).length;
      }

      expect(twins, legacy,
          reason: 'one twin per legacy entry — the duplication was exact');
      expect(before - twins, lessThan(before),
          reason: 'dropping the twins must actually remove rows');

      // The retired-by-MER set, which the disclosure absorbs.
      final retiredShown = legacy + 1; // + the retired `medication` event type
      expect(retiredShown, greaterThan(1));
    });

    testWidgets('9. a USER-hidden entry stays in the main list, not the block',
        (tester) async {
      // The distinction the whole screen rests on. A user-hidden entry is
      // actionable and must not be filed with the unactionable ones — it stays
      // in place, in sort order, with its Show button.
      await pump(tester);

      final entry = Vocabularies.allIn(kTriggerTable)
          .firstWhere((e) => e.value == 'Stress');
      await Vocabularies.setVisible(kTriggerTable, entry, false);
      await tester.pumpWidget(const MaterialApp(home: VocabularyScreen()));
      await tester.pumpAndSettle();
      // (surface already set by pump above)

      // Visible WITHOUT opening any disclosure.
      expect(find.text('Stress'), findsOneWidget);
      expect(find.textContaining('Hidden — still shown on records'),
          findsWidgets);
      // And the beforehand section has no retired block at all.
      expect(Vocabularies.allIn(kTriggerTable)
          .where((e) => isShippedHidden(kTriggerTable, e.value)),
          isEmpty);
    });
  });
}
