import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';
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
  EventSeverity severity = EventSeverity.mild,
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

  group('ROUTING: only an explicit false goes to the wizard', () {
    test('6. false routes to the wizard', () {
      expect(wantsWizard(rec(completed: false)), isTrue);
    });

    test('7. true routes to the single page', () {
      expect(wantsWizard(rec(completed: true)), isFalse);
    });

    test('8. NULL routes to the single page - the existing records', () {
      // The state every record on the device carries today. It must not be
      // read as "incomplete": nothing back-fills it, and sending records that
      // predate the concept into a wizard that does not describe them is the
      // failure this three-state field exists to prevent.
      expect(rec().detailsCompleted, isNull, reason: 'the default');
      expect(wantsWizard(rec()), isFalse);
    });

    test('9. NEGATIVE CONTROL: a two-state read would send NULL to the wizard',
        () {
      // If the field were a bool defaulting to false, or the check were
      // `!= true`, every legacy record would route into the wizard.
      bool twoState(EventRecord r) => r.detailsCompleted != true; // the defect

      expect(twoState(rec()), isTrue, reason: 'the defect routes NULL in');
      expect(wantsWizard(rec()), isFalse, reason: 'the real check does not');
      // And the two agree on the case that SHOULD route in, so the difference
      // is confined to null.
      expect(twoState(rec(completed: false)), isTrue);
      expect(wantsWizard(rec(completed: false)), isTrue);
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
      EventRecord? result;
      await open(tester, null, onDone: (r) => result = r);

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
