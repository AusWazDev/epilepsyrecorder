import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/vocabulary.dart';
import 'package:medical_event_recorder/screens/event_wizard_screen.dart';

/// The guided wizard.
///
/// Three things it must never do, and each has a control here:
///   * treat a legacy RANGE as if it were an answer, and skip the one step
///     that could give that record a real number;
///   * lose what the user entered when they back out part-way;
///   * claim a record is finished when it is not.

EventRecord rec({
  String id = 'r',
  DurationCategory? bucket,
  int? secs,
  bool? completed,
  String notes = '',
  String type = kTypeSeizure,
  // NULLABLE, defaulting to NULL — matching the model since severity stopped
  // fabricating. A fixture that quietly supplied `mild` would make every
  // record in this file complete on that axis and hide the routing case.
  EventSeverity? severity,
}) =>
    EventRecord(
      id: id,
      timestamp: DateTime(2026, 8, 26, 9, 0),
      duration: bucket,
      durationSeconds: secs,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: false,
      notes: notes,
      eventType: type,
      severity: severity,
      detailsCompleted: completed,
    );

void main() {
  group('THE TRAP: a range is not an answer', () {
    test('1. a MEASURED record is the only one that reads as answered', () {
      expect(durationAnswerOf(rec(secs: 187)), DurationAnswer.measured);
    });

    test('2. a BUCKET-ONLY record reads as unanswered', () {
      expect(durationAnswerOf(rec(bucket: DurationCategory.oneToFive)),
          DurationAnswer.bucketOnly);
    });

    test('3. an EMPTY record reads as unanswered', () {
      expect(durationAnswerOf(rec()), DurationAnswer.none);
      expect(durationAnswerOf(null), DurationAnswer.none);
    });

    test(
        '4. NEGATIVE CONTROL: the naive predicate WOULD skip the bucket-only '
        'record, and that is the defect', () {
      // Without this the tests above prove nothing: they pass just as well
      // against an implementation that asks EVERY record, which would be a
      // different bug (re-asking someone who already answered).
      //
      // So both halves are asserted - the naive check disagrees on exactly one
      // of the three cases, and it is the one that matters.
      final legacy = rec(bucket: DurationCategory.oneToFive);
      final measured = rec(secs: 187);
      final empty = rec();

      bool naive(EventRecord r) => r.duration != null; // the defect

      expect(naive(legacy), isTrue,
          reason: 'the naive check calls a range answered');
      expect(durationAnswerOf(legacy) == DurationAnswer.measured, isFalse,
          reason: 'the real check does not - this is the whole point');

      // ... and it agrees on the other two, so the difference is not noise.
      expect(naive(measured), isFalse);
      expect(durationAnswerOf(measured) == DurationAnswer.measured, isTrue);
      expect(naive(empty), isFalse);
      expect(durationAnswerOf(empty) == DurationAnswer.measured, isFalse);
    });

    test('5. a record with BOTH skips: it already carries a number', () {
      expect(durationAnswerOf(rec(bucket: DurationCategory.gt5, secs: 90)),
          DurationAnswer.measured);
    });
  });

  group('ROUTING: a partial OR anything incomplete goes to the wizard', () {
    // ⚠️ THE CONTRACT WIDENED with the "Needs details" filter. It was
    // `detailsCompleted == false` alone; it is now that OR `isIncomplete`.
    //
    // These tests changed with it, and the change is the decision rather than
    // a regression: the filtered list is what a user works through to COMPLETE
    // their history, and routing them from it into the dense single page sends
    // them to the screen the guided flow was built to replace.
    //
    // A record is COMPLETE here only if it has a duration, a type AND a
    // severity — so the fixtures below have to say so explicitly.
    EventRecord full({bool? completed}) =>
        rec(secs: 90, completed: completed, severity: EventSeverity.mild);

    test('6. a partial routes to the wizard', () {
      expect(wantsWizard(rec(completed: false)), isTrue);
    });

    test('7. COMPLETE and finished routes to the single page', () {
      expect(wantsWizard(full(completed: true)), isFalse);
    });

    test('8. COMPLETE and NULL routes to the single page', () {
      // A legacy record with nothing missing. It predates the concept and has
      // nothing to fill in, so it keeps the screen it has always opened in.
      final r = full();
      expect(r.detailsCompleted, isNull, reason: 'the default');
      expect(isIncomplete(r), isFalse, reason: 'and nothing is missing');
      expect(wantsWizard(r), isFalse);
    });

    test('9. NEGATIVE CONTROL: a two-state read would send COMPLETE NULLs in',
        () {
      // If the check were `!= true`, a legacy record with every field filled
      // would route into the wizard — the failure the three-state field exists
      // to prevent, and still prevented after the widening.
      bool twoState(EventRecord r) => r.detailsCompleted != true; // the defect
      final r = full();

      expect(twoState(r), isTrue, reason: 'the defect routes it in');
      expect(wantsWizard(r), isFalse, reason: 'the real check does not');
    });

    test('10. INCOMPLETE routes to the wizard WHATEVER the flag says', () {
      // The gap the flag alone could not close. Three taps reach this state:
      // open the wizard, Skip to end, Save — `detailsCompleted` is true and
      // every field is null. That record appears in the "needs details" list,
      // so it must open where the details are supplied.
      final skipped = rec(completed: true);
      expect(skipped.detailsCompleted, isTrue);
      expect(isIncomplete(skipped), isTrue);
      expect(wantsWizard(skipped), isTrue,
          reason: 'completed-but-empty is exactly the record being hunted for');
    });

    test('11. and a legacy record MISSING one field routes there too', () {
      // Catch-all: any unset field qualifies. Severity alone is enough.
      final r = rec(secs: 90);
      expect(r.severity, isNull);
      expect(wantsWizard(r), isTrue);
    });
  });

  group('the wizard on screen', () {
    Future<void> open(WidgetTester tester, EventRecord? existing,
        {required void Function(EventRecord?) onDone}) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  final r = await Navigator.of(context).push<EventRecord>(
                    MaterialPageRoute(
                      builder: (_) => EventWizardScreen(existing: existing),
                    ),
                  );
                  onDone(r);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('10. a NEW event opens on the duration step', (tester) async {
      await open(tester, null, onDone: (_) {});
      expect(find.text('How long did it last?'), findsOneWidget);
    });

    testWidgets('11. a MEASURED record SKIPS the duration step',
        (tester) async {
      await open(tester, rec(secs: 187), onDone: (_) {});
      expect(find.text('How long did it last?'), findsNothing);
      expect(find.text('What happened?'), findsOneWidget);
    });

    testWidgets(
        '12. a BUCKET-ONLY record is ASKED, with its range shown as context',
        (tester) async {
      await open(tester, rec(bucket: DurationCategory.oneToFive),
          onDone: (_) {});
      expect(find.text('How long did it last?'), findsOneWidget,
          reason: 'the trap: it looks answered and is not');
      expect(
          find.text('Recorded as ${durationLabel(DurationCategory.oneToFive)}'),
          findsOneWidget);
    });

    testWidgets('13. an existing record PRE-FILLS what it has', (tester) async {
      await open(tester, rec(secs: 187, type: kTypeAbsence),
          onDone: (_) {});
      // Duration was skipped, so what is on screen is step 1 - and the type
      // it carries must already be selected.
      final chip = tester.widget<ChoiceChip>(find.ancestor(
        of: find.text(eventTypeLabel(kTypeAbsence)),
        matching: find.byType(ChoiceChip),
      ));
      expect(chip.selected, isTrue);
    });

    testWidgets('14. backing out of an UNTOUCHED new event returns NOTHING',
        (tester) async {
      EventRecord? result;
      var called = false;
      await open(tester, null, onDone: (r) {
        result = r;
        called = true;
      });

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(called, isTrue);
      expect(result, isNull,
          reason: 'opening and closing the wizard must not create a record');
    });

    testWidgets('15. backing out AFTER answering keeps the partial',
        (tester) async {
      EventRecord? result;
      await open(tester, null, onDone: (r) => result = r);

      await tester.enterText(find.byType(TextField).first, '3');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Back to step 0, then out.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(result, isNotNull, reason: 'the answer must survive');
      expect(result!.durationSeconds, 180);
      expect(result!.detailsCompleted, isFalse,
          reason: 'answered, not finished');
    });

    testWidgets('16. abandoning at EVERY step preserves what exists',
        (tester) async {
      for (var stopAfter = 1; stopAfter <= 4; stopAfter++) {
        EventRecord? result;
        await open(tester, null, onDone: (r) => result = r);

        await tester.enterText(find.byType(TextField).first, '2');
        for (var i = 0; i < stopAfter; i++) {
          await tester.tap(find.text(i == 3 ? 'Review' : 'Next'));
          await tester.pumpAndSettle();
        }

        // Straight out via the system pop, from wherever we stopped.
        final nav = tester.state<NavigatorState>(find.byType(Navigator));
        nav.maybePop();
        await tester.pumpAndSettle();

        expect(result, isNotNull, reason: 'stopped after $stopAfter step(s)');
        expect(result!.durationSeconds, 120,
            reason: 'the answer given at step 0 survives to step $stopAfter');
        expect(result!.detailsCompleted, isFalse,
            reason: 'never finished, at any step');
      }
    });

    testWidgets('17. detailsCompleted becomes TRUE only on Save',
        (tester) async {
      EventRecord? result;
      await open(tester, null, onDone: (r) => result = r);

      for (final label in ['Next', 'Next', 'Next', 'Review']) {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      expect(find.text('Check and save'), findsWidgets);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.detailsCompleted, isTrue);
    });

    testWidgets('18. NEGATIVE CONTROL: Skip to end does NOT complete',
        (tester) async {
      // Skip reaches the SAME summary screen as Next-Next-Next-Review. If the
      // completion flag were set on arriving at the summary rather than on
      // Save, this would pass as true and test 17 would not notice.
      //
      // ⚠️ SOMETHING IS ENTERED FIRST, and that is a real change to this test.
      // It previously skipped from an UNTOUCHED wizard and relied on a record
      // being materialised anyway — which is the defect fixed in test 18a
      // below, not a property worth depending on. The CLAIM being tested is
      // unchanged: reaching the summary does not mark a record complete.
      EventRecord? result;
      await open(tester, null, onDone: (r) => result = r);

      await tester.enterText(find.byType(TextField).first, '2');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip to end'));
      await tester.pumpAndSettle();
      expect(find.text('Check and save'), findsWidgets);

      final nav = tester.state<NavigatorState>(find.byType(Navigator));
      nav.maybePop();
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.detailsCompleted, isFalse,
          reason: 'reaching the summary is not finishing');
    });

    testWidgets('18a. ⛔ NEXT through an UNTOUCHED wizard creates NOTHING',
        (tester) async {
      // THE DEFECT. `_next()` called `_capture()` unconditionally, so the two
      // exits from an identical untouched state disagreed: backing out created
      // nothing (test 14) and pressing Next created a junk record. Found on the
      // device, where an export went 72 -> 73 after navigation alone — the
      // "learning by exploring leaves junk behind" hazard the walkthrough
      // exists to prevent, arriving by a different door.
      EventRecord? result;
      var called = false;
      await open(tester, null, onDone: (r) {
        result = r;
        called = true;
      });

      // All the way through, touching nothing. ⚠️ The LAST step's button says
      // "Review", not "Next" — walking on 'Next' alone stops one step short of
      // the summary and the precondition below is what caught that.
      for (var i = 0; i < 6; i++) {
        final next = find.text('Next');
        final review = find.text('Review');
        if (next.evaluate().isNotEmpty) {
          await tester.tap(next);
        } else if (review.evaluate().isNotEmpty) {
          await tester.tap(review);
        } else {
          break;
        }
        await tester.pumpAndSettle();
      }
      expect(find.text('Check and save'), findsWidgets,
          reason: 'precondition: Next really did walk to the summary');

      tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await tester.pumpAndSettle();

      expect(called, isTrue);
      expect(result, isNull,
          reason: 'A JUNK RECORD. Opening the wizard to see what is in it must '
              'leave nothing behind, exactly as backing out already does');
    });

    testWidgets('18b. and SKIP through an untouched wizard creates NOTHING',
        (tester) async {
      // Skip is the FASTEST route to the summary, so an unguarded Skip would
      // keep the defect on the shortest path to it.
      EventRecord? result;
      var called = false;
      await open(tester, null, onDone: (r) {
        result = r;
        called = true;
      });

      await tester.tap(find.text('Skip to end'));
      await tester.pumpAndSettle();

      tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await tester.pumpAndSettle();

      expect(called, isTrue);
      expect(result, isNull);
    });

    testWidgets('18c. ⛔ CONTROL: ONE keystroke and Next DOES save it',
        (tester) async {
      // The other half, and without it 18a/18b are satisfied by a wizard that
      // never saves anything. The partial-save rule is the thing being
      // protected here, not overridden: someone who entered something and
      // stopped keeps it, and keeps the moment they opened the screen.
      EventRecord? result;
      await open(tester, null, onDone: (r) => result = r);

      await tester.enterText(find.byType(TextField).first, '3');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await tester.pumpAndSettle();

      expect(result, isNotNull,
          reason: 'THE PARTIAL-SAVE RULE WAS BROKEN — a moment that cannot be '
              'reconstructed was discarded');
      expect(result!.durationSeconds, 180);
    });

    testWidgets('18d. an EXISTING record is captured by Next even untouched',
        (tester) async {
      // `_draft` is non-null from initState for an existing record, so the
      // guard passes on the first clause. A user opening an incomplete record
      // from the queue and pressing Next must not have it dropped.
      EventRecord? result;
      await open(tester, rec(id: 'existing', completed: false),
          onDone: (r) => result = r);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.id, 'existing');
    });

    testWidgets('18e. ⛔ the SUMMARY renders LABELS, not stored values',
        (tester) async {
      // The summary joined the raw strings, so a record holding the retired
      // `😵 Confused` — or its mis-decoded twin, which is what ALL THREE
      // observation records on the device actually hold — showed the user
      // something other than the chip they had just tapped.
      //
      // The twin is derived the way the app derives it rather than pasted, so
      // this fixture cannot drift from the real value.
      final mangled = latin1Mangled('\u{1F635} Confused')!;
      final existing = EventRecord(
        id: 'legacy',
        timestamp: DateTime(2026, 8, 22, 20, 38),
        duration: DurationCategory.lt1,
        feelings: <String>[mangled],
        triggers: const <String>['Poor sleep'],
        referralRequired: false,
        notes: '',
        eventType: kTypeSeizure,
        severity: EventSeverity.mild,
        detailsCompleted: false,
      );
      await open(tester, existing, onDone: (_) {});

      await tester.tap(find.text('Skip to end'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Afterwards: Confused'), findsOneWidget,
          reason: 'THE RAW STORED STRING REACHED THE SUMMARY. This Text style '
              'has no emoji coverage, which is what rendered mojibake in '
              'History rows on the tablet');
      expect(find.textContaining('Beforehand: Poor sleep'), findsOneWidget);

      // NEGATIVE CONTROL: the mangled value must appear NOWHERE on screen.
      // Asserting the label is present would pass just as well if BOTH were
      // rendered somewhere.
      expect(find.textContaining(mangled), findsNothing,
          reason: 'the stored string is still being shown somewhere');
      expect(find.textContaining('\u{1F635}'), findsNothing,
          reason: 'and no glyph either — labelFor, not displayFor');
    });

    testWidgets('19. an EXISTING record keeps its id and timestamp',
        (tester) async {
      EventRecord? result;
      final original = rec(id: 'keep-me', completed: false);
      await open(tester, original, onDone: (r) => result = r);

      await tester.tap(find.text('Skip to end'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(result!.id, 'keep-me');
      expect(result!.timestamp, original.timestamp);
    });

    testWidgets(
        '20. a BUCKET-ONLY record answered in the wizard KEEPS its range',
        (tester) async {
      // Both facts are kept: the range is what was recorded then, the number
      // is what the user supplies now. Neither is derived from the other.
      EventRecord? result;
      await open(tester, rec(bucket: DurationCategory.oneToFive),
          onDone: (r) => result = r);

      await tester.enterText(find.byType(TextField).first, '4');
      await tester.tap(find.text('Skip to end'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(result!.durationSeconds, 240);
      expect(result!.duration, DurationCategory.oneToFive,
          reason: 'the bucket is not erased by the number');
    });

    testWidgets('21. leaving duration blank records UNKNOWN, never zero',
        (tester) async {
      EventRecord? result;
      await open(tester, null, onDone: (r) => result = r);

      await tester.tap(find.text('Skip to end'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(result!.durationSeconds, isNull,
          reason: 'blank is unknown; 0 would be a measurement nobody made');
      expect(result!.duration, isNull);
      expect(
          durationDisplay(result!.duration, result!.durationSeconds), isNull);
    });
  });
}
