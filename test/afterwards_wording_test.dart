import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/event_wizard_screen.dart';
import 'package:medical_event_recorder/screens/log_event_screen.dart';

/// The observation field: one wording, on every surface that names it.
///
/// Sibling of `beforehand_wording_test.dart`, and it exists because the trigger
/// alignment MISSED one. That pass hunted causal words — "Possible triggers",
/// "what caused this" — and `'Feelings updated'` in the Confirm-changes list is
/// not a causal word, so it survived as a FOURTH wording of a field that was
/// being unified at the time.
///
/// The lesson that shape teaches: an alignment pass that searches for the
/// SYMPTOM finds only the instances that share it. Enumerate every place the
/// field is NAMED instead, which is what this file pins.
///
/// ## Why a noun and not a question
///
/// Three wordings have now been tried and each was wrong for a different
/// reason, which is worth recording so a fourth is not reached for:
///
///   "How are you feeling?"        PRESENT TENSE. Someone logging live read it
///                                 as right now, someone logging days later as
///                                 then. One field, two meanings, and nothing
///                                 in the record said which.
///   "How did you feel afterwards?" Correct in meaning, wrong in FORM. On the
///                                 single page it is a question sitting in a
///                                 column of nouns (EVENT TYPE, DURATION,
///                                 SEVERITY); in the wizard it is a step
///                                 heading, so the sentence under it restated
///                                 the heading in different words.
///   "Afterwards" + a hint         The noun names the field; the hint carries
///                                 the temporal meaning the noun cannot. Still
///                                 the SINGLE PAGE's wording.
///   nothing at all                 OPTION A, 26-Aug-26, WIZARD ONLY. A step
///                                 that opens with chips and no label, because
///                                 a heading plus a field label saying the same
///                                 thing had appeared on three of the last four
///                                 screens.
///
/// ⚠️ **THE WIZARD AND THE SINGLE PAGE NOW DIFFER ON PURPOSE**, which reverses
/// the rule the sibling file pins for triggers. It is a deliberate exception,
/// not drift, and the reason is that the two screens are not the same kind of
/// thing: the single page is a flat form with no surrounding context, so its
/// section needs a name; the wizard step is one screen with one subject.
///
/// ⚠️ **AND THE TEMPORAL MEANING IS NOW ABSENT FROM THE WIZARD.** "After the
/// event" was the whole point of the label work. The single page still says it,
/// and most records open there — legacy and completed both — but a partial
/// walked through the wizard is never told.

/// The one wording. Changing it here should be the only edit a rename needs.
const String kAfterwardsHeading = 'Afterwards';
const String kAfterwardsHint =
    'How you felt in the minutes and hours after it ended.';

/// Every wording this field has worn. None may appear in the UI.
const List<String> kRetiredWordings = <String>[
  'How are you feeling?',
  'HOW ARE YOU FEELING?',
  'How did you feel afterwards?',
  'HOW DID YOU FEEL AFTERWARDS?',
  'Feelings updated',
];

EventRecord legacyRecord() => EventRecord(
      id: 'legacy',
      timestamp: DateTime(2026, 8, 20, 9, 0),
      duration: DurationCategory.oneToFive,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: false,
      notes: '',
      detailsCompleted: null,
    );

void main() {
  setUp(Vocabularies.debugReset);
  tearDown(Vocabularies.debugReset);

  testWidgets('1. the SINGLE PAGE names it with the noun plus a hint',
      (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: LogEventScreen(existing: legacyRecord())));
    await tester.pumpAndSettle();

    // _SectionLabel uppercases, so the rendered string is the uppercase form.
    expect(find.text(kAfterwardsHeading.toUpperCase()), findsOneWidget);
    expect(find.text(kAfterwardsHint), findsOneWidget,
        reason: 'the noun alone does not say the field means AFTER the event');
  });

  testWidgets(
      '2. the WIZARD step renders NOTHING above the chips — Option A',
      (tester) async {
    // The opposite assertion to the one this test made a build ago, and the
    // reversal is the decision rather than a regression: a heading plus a
    // field label saying the same thing had appeared on three of the last four
    // screens, so the fourth answer was to stop labelling it in the wizard.
    //
    // The single page still carries it — see test 1. Most records open there.
    await tester.pumpWidget(const MaterialApp(home: EventWizardScreen()));
    await tester.pumpAndSettle();

    // Step 0 duration, 1 what happened, 2 beforehand, 3 afterwards.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }

    // POSITIVE CONTROL FIRST. Without it, "nothing rendered" passes just as
    // well against a step that failed to build at all — which is the one way
    // this assertion could be satisfied for the wrong reason.
    expect(find.text('Tired'), findsOneWidget,
        reason: 'the observation chips must actually be on screen');
    expect(find.text('Medical referral required?'), findsOneWidget,
        reason: 'and the rest of the step with them');

    expect(find.text(kAfterwardsHeading), findsNothing,
        reason: 'Option A: nothing above the chips');
    expect(find.text(kAfterwardsHint), findsNothing);
  });

  testWidgets(
      '3a. NEGATIVE CONTROL: the OTHER steps still have their headings',
      (tester) async {
    // Step 4 is now the only step without one. Asserted so that a future change
    // stripping every heading — or restoring this one by accident — is visible
    // rather than silent.
    await tester.pumpWidget(const MaterialApp(home: EventWizardScreen()));
    await tester.pumpAndSettle();
    expect(find.text('How long did it last?'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('What happened?'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('What was happening beforehand?'), findsOneWidget);
  });

  testWidgets('3. and the wizard SUMMARY uses the same noun', (tester) async {
    // The third surface, and the one most easily forgotten because it renders
    // only when something was selected.
    await tester.pumpWidget(const MaterialApp(home: EventWizardScreen()));
    await tester.pumpAndSettle();

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Tired'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    expect(find.textContaining('$kAfterwardsHeading:'), findsOneWidget);
  });

  testWidgets('4. NEGATIVE CONTROL: no retired wording survives anywhere',
      (tester) async {
    // Without this, the tests above pass just as well against a screen showing
    // BOTH — the new label added and an old one left in place, which is the
    // likeliest way a rename half-lands and is exactly what happened to
    // 'Feelings updated'.
    await tester.pumpWidget(
        MaterialApp(home: LogEventScreen(existing: legacyRecord())));
    await tester.pumpAndSettle();
    for (final retired in kRetiredWordings) {
      expect(find.text(retired), findsNothing,
          reason: '"$retired" is a superseded wording of this field');
    }

    await tester.pumpWidget(const MaterialApp(home: EventWizardScreen()));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    for (final retired in kRetiredWordings) {
      expect(find.text(retired), findsNothing);
    }
    // And in the wizard, the CURRENT wording is absent too — Option A.
    expect(find.text(kAfterwardsHeading), findsNothing);
  });

  testWidgets('5. POSITIVE CONTROL: the matcher can see labels here',
      (tester) async {
    // Test 4 is a null result and proves nothing unless the apparatus works.
    await tester.pumpWidget(
        MaterialApp(home: LogEventScreen(existing: legacyRecord())));
    await tester.pumpAndSettle();

    expect(find.text('SEVERITY'), findsOneWidget);
    expect(find.text('DURATION'), findsOneWidget);
  });

  testWidgets(
      '6. the CONFIRM-CHANGES line names the field the same way — the one the '
      'trigger pass missed', (tester) async {
    // Reached by editing an existing record and changing an observation, which
    // is the only path that renders this string.
    final existing = EventRecord(
      id: 'e',
      timestamp: DateTime(2026, 8, 20, 9, 0),
      duration: null,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: false,
      notes: '',
      detailsCompleted: true,
    );

    await tester.pumpWidget(MaterialApp(
        home: LogEventScreen(existing: existing, confirmOnSave: true)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tired'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.textContaining('$kAfterwardsHeading updated'), findsOneWidget);
    expect(find.text('Feelings updated'), findsNothing,
        reason: 'the fourth wording, retired');
  });
}
