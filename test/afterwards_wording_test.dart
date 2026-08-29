import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/vocabulary.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/event_wizard_screen.dart';
import 'package:medical_event_recorder/screens/log_event_screen.dart';

/// The observation field: one wording, on every surface that names it.
///
/// Sibling of `beforehand_wording_test.dart`, and it exists because the trigger
/// alignment MISSED one. That pass hunted causal words — "Possible triggers",
/// "what caused this" — and `'Feelings updated'` in the Confirm-changes list is
/// not a causal word, so it survived as a fourth wording of a field that was
/// being unified at the time. An alignment pass that searches for the SYMPTOM
/// finds only the instances that share it. Enumerate every place the field is
/// NAMED instead, which is what this file pins.
///
/// ## Four wordings, and why the last two were wrong
///
///   1. "How are you feeling?"         PRESENT TENSE. Someone logging live read
///                                     it as right now, someone logging days
///                                     later as then. One field, two meanings,
///                                     and nothing in the record said which.
///   2. "How did you feel afterwards?" Fixed the TENSE, left the PERSON.
///                                     First person, addressed to whoever had
///                                     the event, while the store listing says
///                                     "individuals and carers". Superseded
///                                     29 Aug 2026.
///   5. "How were things afterwards?" CURRENT, on both surfaces. Names
///                                     nobody, so it serves a patient and a
///                                     carer without addressing either.
///   3. "Afterwards"                   A noun, justified as fitting "a column of
///                                     nouns" on the single page. THE COLUMN IS
///                                     NOT NOUNS — see test 7, which enumerates
///                                     it. The reason was wrong, so the change
///                                     it justified was wrong.
///   4. Nothing at all                 Removed from the wizard entirely, on two
///                                     premises that did not hold: a per-step
///                                     title in the AppBar (there is none) and a
///                                     RadioGroup label being duplicated (there
///                                     is neither). Nothing was duplicated, so
///                                     what was removed was the ONLY label the
///                                     field had. Reversed the same day.
///
/// ⚠️ **What the last two share is not about wording.** Both were justified by
/// a claim about the surrounding UI; both claims were false; neither was checked
/// before acting. Tests 7 and 9 exist so those claims are checkABLE — they are
/// the only assertions here that are about the argument rather than the result.

/// The one wording. Changing it here should be the only edit a rename needs —
/// and this file then proves every surface followed.
// ⛔ CHANGED FOR THE OBSERVER VOICE, 29 Aug 2026. It read "How did you feel
// afterwards?" — first person, addressed to the person who had the event,
// while the live App Store listing says "Designed for individuals and carers".
// A carer recording someone else was writing in the wrong voice.
//
// The TENSE was fixed by the observation revision; the PERSON was not, and
// nothing noticed for three weeks because the two are separate defects in one
// sentence. This file existing as a single constant is what made the rename
// one edit — see the note below.
const String kAfterwardsHeading = 'How were things afterwards?';
const String kAfterwardsHint = 'In the minutes and hours after it ended.';

/// The noun used where a question does not fit: a bulleted summary line and a
/// change-log entry. Deliberately different in FORM, identical in meaning.
const String kAfterwardsNoun = 'Afterwards';

/// Every wording this field has worn and shed. None may appear as a LABEL.
const List<String> kRetiredWordings = <String>[
  'How are you feeling?',
  'HOW ARE YOU FEELING?',
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

/// The chip text for a seeded observation, built FROM THE SEED rather than
/// hardcoded — a chip now shows `<glyph> <label>`, and hardcoding the glyph
/// would make these tests break every time one is reconsidered. The glyphs are
/// a proposal; the label is the contract.
String chipFor(String value) {
  final seed = kSeedObservations.firstWhere((s) => s.value == value);
  return seed.emoji == null ? seed.label : '${seed.emoji} ${seed.label}';
}

/// Walks the wizard to step 4.
Future<void> toAfterwardsStep(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: EventWizardScreen()));
  await tester.pumpAndSettle();
  for (var i = 0; i < 3; i++) {
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
  }
}

void main() {
  setUp(Vocabularies.debugReset);
  tearDown(Vocabularies.debugReset);

  testWidgets('1. the SINGLE PAGE names it, with the hint', (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: LogEventScreen(existing: legacyRecord())));
    await tester.pumpAndSettle();

    // _SectionLabel uppercases, so the rendered string is the uppercase form.
    expect(find.text(kAfterwardsHeading.toUpperCase()), findsOneWidget);
    expect(find.text(kAfterwardsHint), findsOneWidget,
        reason: 'the heading says AFTERWARDS; the hint says how long after');
  });

  testWidgets('2. the WIZARD step names it identically', (tester) async {
    await toAfterwardsStep(tester);

    expect(find.text(kAfterwardsHeading), findsOneWidget);
    expect(find.text(kAfterwardsHint), findsOneWidget);
  });

  testWidgets('3. the wizard SUMMARY uses the noun', (tester) async {
    // The one place a question does not fit — a bulleted list of values.
    await toAfterwardsStep(tester);
    await tester.tap(find.text(chipFor('Tired')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    expect(find.textContaining('$kAfterwardsNoun:'), findsOneWidget);
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

    await toAfterwardsStep(tester);
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

    // ensureVisible BEFORE the tap, the same discipline this file already
    // applies to 'Save changes' two lines down. The tap here started MISSING
    // when a field was added above -- the chip stayed in the tree and moved
    // out from under the finger, and `tap` does not throw for that, it warns.
    await tester.ensureVisible(find.text(chipFor('Tired')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(chipFor('Tired')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.textContaining('$kAfterwardsNoun updated'), findsOneWidget);
    expect(find.text('Feelings updated'), findsNothing,
        reason: 'the wording the trigger pass missed, retired');
  });

  testWidgets(
      '7. THE CLAIM THAT JUSTIFIED WORDING 3: the single page is NOT a column '
      'of nouns', (tester) async {
    // Makes the argument checkable instead of assertable. It was asserted, it
    // was wrong, and the change it justified had to be reversed.
    await tester.pumpWidget(
        MaterialApp(home: LogEventScreen(existing: legacyRecord())));
    await tester.pumpAndSettle();

    for (final q in <String>[
      'WHAT HAPPENED?',
      'WHAT WAS HAPPENING BEFOREHAND?',
      'MEDICAL REFERRAL REQUIRED?',
    ]) {
      expect(find.text(q), findsOneWidget,
          reason: 'the column already contains this question');
    }

    // And the section directly BELOW this field is one of them, so a question
    // here is not the odd one out.
    final afterwards =
        tester.getTopLeft(find.text(kAfterwardsHeading.toUpperCase()));
    final beforehand =
        tester.getTopLeft(find.text('WHAT WAS HAPPENING BEFOREHAND?'));
    expect(beforehand.dy, greaterThan(afterwards.dy),
        reason: 'the next section down is a question');
  });

  group('EVERY WIZARD STEP HAS A HEADING', () {
    // Step 4 was briefly the only one without. Pinned for all four so that
    // stripping any of them — or stripping them all — is visible rather than
    // silent.

    const headings = <String>[
      'How long did it last?',
      'What happened?',
      'What was happening beforehand?',
      kAfterwardsHeading,
    ];

    testWidgets('8. all four steps, in order', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: EventWizardScreen()));
      await tester.pumpAndSettle();

      for (var i = 0; i < headings.length; i++) {
        expect(find.text(headings[i]), findsOneWidget,
            reason: 'step ${i + 1} must open with its heading');
        if (i < headings.length - 1) {
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets(
        '9. THE CLAIM THAT JUSTIFIED WORDING 4: the AppBar carries NO per-step '
        'title', (tester) async {
      // The removal was justified by "the step heading already says
      // Afterwards", meaning the AppBar. It does not. The body heading is the
      // ONLY thing naming the step, which is why removing it took the field
      // label with it.
      await tester.pumpWidget(const MaterialApp(home: EventWizardScreen()));
      await tester.pumpAndSettle();

      for (var i = 0; i < headings.length; i++) {
        expect(find.text('Add details'), findsOneWidget,
            reason: 'same AppBar on every step, including step ${i + 1}');
        if (i < headings.length - 1) {
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('10. step 4 labels BOTH its fields, not one of two',
        (tester) async {
      // The asymmetry that made the removal visible on the device: the chips
      // had nothing above them while "Medical referral required?" two rows
      // below kept its label, which read as an omission rather than a choice.
      await toAfterwardsStep(tester);

      expect(find.text(kAfterwardsHeading), findsOneWidget);
      expect(find.text('Medical referral required?'), findsOneWidget);

      final obs = tester.getTopLeft(find.text(kAfterwardsHeading));
      final referral =
          tester.getTopLeft(find.text('Medical referral required?'));
      expect(referral.dy, greaterThan(obs.dy),
          reason: 'both labelled, in order, on the same step');
    });
  });
}
