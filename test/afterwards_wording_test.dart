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
///                                 the temporal meaning the noun cannot.

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

  testWidgets('2. the WIZARD step names it identically', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: EventWizardScreen()));
    await tester.pumpAndSettle();

    // Step 0 duration, 1 what happened, 2 beforehand, 3 afterwards.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }

    expect(find.text(kAfterwardsHeading), findsOneWidget);
    expect(find.text(kAfterwardsHint), findsOneWidget);
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
