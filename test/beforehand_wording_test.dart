import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'afterwards_wording_test.dart' show kAfterwardsHeading;

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/screens/event_wizard_screen.dart';
import 'package:medical_event_recorder/screens/log_event_screen.dart';

/// One field, one wording, on whichever screen a record happens to open in.
///
/// The trigger field is asked for on TWO screens - the guided wizard for a
/// partial, the single page for a completed or legacy record - and for a while
/// they disagreed: "What was happening beforehand?" against "Possible
/// triggers". Which one a user saw depended on a routing decision that has
/// nothing to do with the field.
///
/// TWO SEPARATE CLAIMS, and they need separate assertions because either can
/// hold without the other:
///   * the two screens AGREE with each other;
///   * what they agree on does not imply CAUSATION.
/// Agreeing on "Possible triggers" would satisfy the first and fail the point.
///
/// WHY THE CAUSATION RULE: several sources warn that a recorded trigger is
/// often the event already starting - food cravings, thirst, neck stiffness
/// and light sensitivity commonly occur in the hours BEFORE pain rather than
/// causing it. A field labelled "what caused this" collects the same taps and
/// asserts something the data does not support.

/// The one wording. Changing it here should be the only edit a rename needs -
/// and this file then proves every screen followed.
const String kBeforehandHeading = 'What was happening beforehand?';

/// Labels that assert a cause. None may appear in the UI.
const List<String> kCausalLabels = <String>[
  'Possible triggers',
  'POSSIBLE TRIGGERS',
  'What caused this?',
  'Triggers updated',
];

EventRecord legacyRecord() => EventRecord(
      id: 'legacy',
      timestamp: DateTime(2026, 8, 20, 9, 0),
      duration: DurationCategory.oneToFive,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: false,
      notes: '',
      // NULL - predates the wizard, so it opens on the single page. This is
      // the majority case on the device, which is why the form's wording
      // matters more than the wizard's.
      detailsCompleted: null,
    );

void main() {
  testWidgets('1. the SINGLE PAGE asks the non-causal question', (tester) async {
    await tester.pumpWidget(
        MaterialApp(home: LogEventScreen(existing: legacyRecord())));
    await tester.pumpAndSettle();

    // _SectionLabel uppercases, so the rendered string is the uppercase form.
    expect(find.text(kBeforehandHeading.toUpperCase()), findsOneWidget);
    expect(find.text('Not a cause — just what was going on.'), findsOneWidget,
        reason: 'the hint denies causation explicitly rather than leaving it '
            'to be inferred from the heading');
  });

  testWidgets('2. the WIZARD asks the same question, word for word',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: EventWizardScreen()));
    await tester.pumpAndSettle();

    // Step 0 is duration; the beforehand step is two Nexts along.
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    expect(find.text(kBeforehandHeading), findsOneWidget);
  });

  testWidgets('3. NEGATIVE CONTROL: no causal label survives on either screen',
      (tester) async {
    // Without this, tests 1 and 2 pass just as well against a screen that
    // shows BOTH - the new heading added and the old label left in place,
    // which is the likeliest way a rename half-lands.
    await tester.pumpWidget(
        MaterialApp(home: LogEventScreen(existing: legacyRecord())));
    await tester.pumpAndSettle();

    for (final causal in kCausalLabels) {
      expect(find.text(causal), findsNothing,
          reason: '"$causal" asserts the recorded thing caused the event');
    }

    await tester.pumpWidget(const MaterialApp(home: EventWizardScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    for (final causal in kCausalLabels) {
      expect(find.text(causal), findsNothing);
    }
  });

  testWidgets(
      '4. POSITIVE CONTROL: the matcher can see a label on these screens',
      (tester) async {
    // Test 3 is a null result, and a null proves nothing unless the apparatus
    // is known to work. These are labels that ARE present, found the same way.
    await tester.pumpWidget(
        MaterialApp(home: LogEventScreen(existing: legacyRecord())));
    await tester.pumpAndSettle();

    expect(find.text('SEVERITY'), findsOneWidget);
    // ⚠️ THIS CONTROL HAS MOVED THREE TIMES, and it is worth reading as a
    // record rather than as churn: it tracked the observation label through
    // "How are you feeling?" -> "How did you feel afterwards?" ->
    // "Afterwards" -> and back -> "How were things afterwards?" (29 Aug,
    // the PERSON dropped so a carer is not addressed as the patient).
    // Two of those changes were justified by claims about the surrounding
    // UI that turned out to be false, and both were reversed. The control
    // caught every move. See afterwards_wording_test, which now pins the
    // CLAIMS as well as the wording.
    //
    // ⚠️ DERIVED FROM THE CONSTANT NOW, uppercased the way the single page
    // renders it. This line held a FOURTH hand-written copy of the heading
    // and broke on the rename — the copy afterwards_wording_test exists to
    // make unnecessary.
    //
    // A positive control that never moves is a positive control nothing is
    // testing.
    expect(find.text(kAfterwardsHeading.toUpperCase()), findsOneWidget);
  });

  test('5. the CSV never labels the field at all', () {
    // A clinician reads the export, so a causal column heading there would be
    // the most consequential place to get this wrong.
    //
    // ⚠️ IT ONCE COULD NOT HAPPEN, AND THEN IT DID. The seven one-hot columns
    // were the OPTION NAMES themselves with no group heading over them, so the
    // export had no place to name the field. The delimited change removed that
    // structural protection - one column must have one heading - and the first
    // implementation of it named the column `triggers`. THIS TEST IS WHAT
    // CAUGHT IT, on the run that introduced it. The heading is now
    // `beforehand`, the word already on both screens.
    //
    // Read as a standing example: a property that holds because of how
    // something is SHAPED stops holding when the shape changes, and nothing
    // announces that. The check has to outlive the structure it was written
    // against.
    final header = buildCsv(const <EventRecord>[]).split('\n').first;
    final columns = header.split(',');

    for (final c in columns) {
      expect(c.toLowerCase().contains('trigger'), isFalse,
          reason: 'column "$c" would label the field causally in the export');
    }

    // POSITIVE CONTROL: the field's VALUES are exported, so the absence above
    // is a naming fact and not a missing field.
    //
    // It reads the ROW now, not the header. The options stopped being columns
    // when they became one delimited cell - and a control that had been left
    // pointing at the header would have gone on passing while measuring
    // nothing, because `containsAll` over a list that no longer holds them
    // fails loudly, but the version of this that checked only the header for
    // ABSENCE would not have.
    final row = buildCsv(<EventRecord>[
      EventRecord(
        id: 'r',
        timestamp: DateTime(2026, 8, 26, 9, 0),
        duration: null,
        feelings: const <String>[],
        triggers: kTriggerOptionsForTest,
        notes: '',
        referralRequired: false,
      )
    ]).trim().split('\n').last;

    for (final option in kTriggerOptionsForTest) {
      expect(row, contains(option), reason: 'the options are the values');
    }
  });
}

/// The trigger options as the CSV writes them, kept here rather than imported
/// so the test states what it expects instead of agreeing with the source by
/// construction.
const List<String> kTriggerOptionsForTest = <String>[
  'Stress',
  'Poor sleep',
  'Missed medication',
  'Alcohol',
  'Flashing lights',
  'Illness',
  'Unknown',
];
