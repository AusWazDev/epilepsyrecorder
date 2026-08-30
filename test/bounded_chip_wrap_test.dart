import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/vocabulary.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/event_wizard_screen.dart';
import 'package:medical_event_recorder/screens/log_event_screen.dart';
import 'package:medical_event_recorder/theme/mer_theme.dart';
import 'package:medical_event_recorder/widgets/bounded_chip_wrap.dart';

/// The bounded chip picker, and the ONE RULE that makes it safe.
///
/// ## ⛔ WHY SELECTED-ALWAYS-VISIBLE IS THE LOAD-BEARING TEST
///
/// A cap that can hide a SELECTED value turns the edit path into a liar: the
/// record holds the value, the CSV exports it, and the screen that claims to
/// show what was recorded does not. That is worse than the unbounded wall it
/// replaces, because a wall at least tells the truth if you scroll.
///
/// The wizard already had half this rule — the orphan chip, which renders a
/// value no longer offered so it cannot vanish from a record MER revised the
/// vocabulary under. The cap needed the other half: rendering is no longer
/// enough, the chip must also survive the row limit.
void main() {
  /// A row of chips wide enough that exactly two fit per row at 400pt, so
  /// "row 4" is unambiguous and the cap is testable without font maths.
  Widget harness({
    required int count,
    required Set<int> selected,
    bool withAdd = false,
    double width = 400,
  }) {
    final chips = <Widget>[];
    final pinned = <bool>[];
    for (var i = 0; i < count; i++) {
      pinned.add(selected.contains(i));
      chips.add(SizedBox(width: 180, height: 40, child: Text('chip$i')));
    }
    if (withAdd) {
      pinned.add(true);
      chips.add(const SizedBox(width: 180, height: 40, child: Text('ADD')));
    }
    return MaterialApp(
      theme: MERTheme.light,
      home: Scaffold(
        body: SizedBox(
          width: width,
          child: BoundedChipWrap(
            chips: chips,
            pinned: pinned,
            totalCount: count,
            selectedCount: selected.length,
          ),
        ),
      ),
    );
  }

  List<bool> visibility(WidgetTester t) =>
      (t.renderObject(find.byType(BoundedWrap)) as RenderBoundedWrap)
          .childVisibility;

  group('THE CAP', () {
    testWidgets('1. collapsed draws three rows and no more', (t) async {
      // 20 chips, two per row = 10 rows. Three rows is six chips.
      await t.pumpWidget(harness(count: 20, selected: const {}));
      await t.pumpAndSettle();
      final v = visibility(t);
      expect(v.take(6), everyElement(isTrue), reason: 'first three rows drawn');
      expect(v.skip(6), everyElement(isFalse), reason: 'the rest withheld');
    });

    testWidgets('2. expanded draws everything', (t) async {
      await t.pumpWidget(harness(count: 20, selected: const {}));
      await t.pumpAndSettle();
      await t.tap(find.text('Show all'));
      await t.pumpAndSettle();
      expect(visibility(t), everyElement(isTrue));
      expect(find.text('Show fewer'), findsOneWidget);
    });

    testWidgets('3. nothing is withheld when it all fits, and then there '
        'is no disclosure at all', (t) async {
      // 4 chips at 2 per row = 2 rows, under the cap.
      await t.pumpWidget(harness(count: 4, selected: const {}));
      await t.pumpAndSettle();
      expect(visibility(t), everyElement(isTrue));
      expect(find.text('Show all'), findsNothing,
          reason: 'offering to show all of an already-complete list is the '
              'same defect as hiding the count');
    });
  });

  group('⛔ SELECTED IS NEVER WITHHELD', () {
    testWidgets('4. a selected chip in row 9 is still drawn', (t) async {
      await t.pumpWidget(harness(count: 20, selected: const {17}));
      await t.pumpAndSettle();
      final v = visibility(t);
      expect(v[17], isTrue, reason: 'selected, far past the cap');
      expect(v[16], isFalse, reason: 'its unselected neighbour is not');
      expect(v[18], isFalse);
    });

    testWidgets('5. nine selected observations all render, and the picker '
        'grows past three rows to do it', (t) async {
      const nine = {2, 5, 8, 11, 13, 15, 16, 18, 19};
      await t.pumpWidget(harness(count: 20, selected: nine));
      await t.pumpAndSettle();
      final v = visibility(t);
      for (final i in nine) {
        expect(v[i], isTrue, reason: 'selected chip $i must render');
      }
      final drawn = v.where((e) => e).length;
      expect(drawn, greaterThan(6),
          reason: 'the cap bounds what is UNANSWERED, not what is answered');
    });

    testWidgets('6. the add pill survives the cap — it is an action, not an '
        'entry', (t) async {
      await t.pumpWidget(
          harness(count: 20, selected: const {}, withAdd: true));
      await t.pumpAndSettle();
      expect(visibility(t).last, isTrue);
    });

    testWidgets('7. a withheld chip is not TAPPABLE', (t) async {
      // Painting is not the whole rule: an invisible chip that still toggles
      // a value would write to the record without showing it.
      await t.pumpWidget(harness(count: 20, selected: const {}));
      await t.pumpAndSettle();
      expect(visibility(t)[15], isFalse);
      bool inPath(String label) {
        final target = t.renderObject(find.text(label));
        final hit = t.hitTestOnBinding(t.getCenter(find.text(label)));
        return hit.path.any((e) => identical(e.target, target));
      }

      // POSITIVE CONTROL first, so the negative below cannot pass vacuously.
      expect(visibility(t)[0], isTrue);
      expect(inPath('chip0'), isTrue, reason: 'a drawn chip IS hit-testable');
      expect(inPath('chip15'), isFalse,
          reason: 'a withheld chip must be out of the hit-test path');
    });
  });

  group('THE DISCLOSURE STATES THE COUNT IN BOTH STATES', () {
    testWidgets('8. with nothing selected it says how many there are',
        (t) async {
      await t.pumpWidget(harness(count: 20, selected: const {}));
      await t.pumpAndSettle();
      expect(find.text('20 to choose from'), findsOneWidget,
          reason: 'a closed picker must never read as "three is all there is"');
    });

    testWidgets('9. with some selected it still states the size', (t) async {
      await t.pumpWidget(harness(count: 20, selected: const {1, 4}));
      await t.pumpAndSettle();
      expect(find.text('2 of 20 selected'), findsOneWidget);
    });

    testWidgets('10. and it still states it when open', (t) async {
      await t.pumpWidget(harness(count: 20, selected: const {}));
      await t.pumpAndSettle();
      await t.tap(find.text('Show all'));
      await t.pumpAndSettle();
      expect(find.text('20 to choose from'), findsOneWidget);
    });
  });

  /* ===========================
     THE REAL SCREENS
     =========================== */

  group('THE EDIT PATH CANNOT HIDE A RECORDED ANSWER', () {
    setUp(Vocabularies.debugReset);
    tearDown(Vocabularies.debugReset);

    /// A value the vocabulary no longer offers, carried by an old record.
    /// This is the orphan case the wizard already handled — now it must also
    /// beat the cap.
    EventRecord recordCarrying(List<String> feelings) => EventRecord(
          id: 'r1',
          timestamp: DateTime(2026, 8, 30, 9),
          duration: null,
          durationSeconds: 90,
          eventType: 'Seizure',
          severity: EventSeverity.moderate,
          feelings: feelings,
          referralRequired: false,
          notes: '',
        );

    Future<void> pump(WidgetTester t, Widget home) async {
      t.view.physicalSize = const Size(1290, 2796);
      t.view.devicePixelRatio = 3.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(theme: MERTheme.light, home: home));
      await t.pumpAndSettle();
    }

    testWidgets('11. WIZARD: a late-ordered observation the record carries is '
        'drawn while collapsed', (t) async {
      // Last in the seeded order, so far below three rows on any phone.
      final late = kSeedObservations.last.value;
      await pump(t, EventWizardScreen(existing: recordCarrying([late])));
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();

      final wrap = find.byType(BoundedWrap);
      final v = (t.renderObject(wrap.first) as RenderBoundedWrap)
          .childVisibility;
      expect(v.where((e) => e).length, lessThan(v.length),
          reason: 'the picker really is collapsed');

      final chipIndex = Vocabularies.offerableObservations
          .indexWhere((e) => e.value == late);
      expect(chipIndex, greaterThanOrEqualTo(0));
      expect(v[chipIndex], isTrue,
          reason: 'a value this record holds must render');
    });

    testWidgets('12. WIZARD: an ORPHAN value — retired from the vocabulary '
        'entirely — is drawn while collapsed', (t) async {
      await pump(t, EventWizardScreen(existing: recordCarrying(['Zombified'])));
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();

      final v = (t.renderObject(find.byType(BoundedWrap).first)
              as RenderBoundedWrap)
          .childVisibility;
      // Orphans are appended after the offerable entries, so the orphan sits
      // past the offerable count — well beyond three rows.
      final orphanIndex = Vocabularies.offerableObservations.length;
      expect(v[orphanIndex], isTrue,
          reason: 'MER revising its own vocabulary must not blank a record');
      expect(find.text('Zombified'), findsOneWidget);
    });

    testWidgets('13. FORM: a carried value survives the cap there too',
        (t) async {
      final late = kSeedObservations.last.value;
      await pump(t, LogEventScreen(existing: recordCarrying([late])));

      final v = (t.renderObject(find.byType(BoundedWrap).first)
              as RenderBoundedWrap)
          .childVisibility;
      expect(v.where((e) => e).length, lessThan(v.length),
          reason: 'the observation picker is collapsed on the form');
      final idx = Vocabularies.offerableObservations
          .indexWhere((e) => e.value == late);
      expect(v[idx], isTrue);
    });

    testWidgets('14. FORM: both pickers are bounded, not just the first',
        (t) async {
      await pump(t, const LogEventScreen());
      final wraps = find.byType(BoundedWrap);
      expect(t.widgetList(wraps).length, 2,
          reason: 'observations AND beforehand');
      for (var i = 0; i < 2; i++) {
        final v =
            (t.renderObject(wraps.at(i)) as RenderBoundedWrap).childVisibility;
        expect(v.where((e) => e).length, lessThan(v.length),
            reason: 'picker $i must be capped');
      }
    });
  });
}
