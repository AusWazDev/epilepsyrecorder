import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/event_wizard_screen.dart';
import 'package:medical_event_recorder/theme/mer_theme.dart';

/// ⛔ §10 FIX 2 AND FIX 3's SECOND HALF — the summary step must REVIEW.
///
/// ⭐ **A review step that omits a field the user filled in is a field they
/// cannot catch a mistake in.** §13(m) found exactly that with two rescue
/// fields; notes was the same defect with a different field.
void main() {
  setUp(Vocabularies.debugReset);
  tearDown(Vocabularies.debugReset);

  Future<void> toSummary(WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: MERTheme.light,
      home: const EventWizardScreen(),
    ));
    await tester.pumpAndSettle();
    // Three Nexts to step 4, then Review to the summary.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('fix 2: the step is named ONCE, by the app bar', (tester) async {
    await toSummary(tester);
    await tester.enterText(find.byType(TextField).last, 'bit my tongue');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    // ⛔ EXACTLY ONE. Two would be the duplication fix 2 removes; zero would
    // mean the step lost its name entirely, which is the opposite failure.
    expect(find.text('Check and save'), findsOneWidget,
        reason: 'the app bar names the step and the body no longer repeats it');

    // The hint survives — it is not the heading, and it states something the
    // app bar cannot.
    expect(
        find.text('Save to finish. What you have entered is kept either way.'),
        findsOneWidget,
        reason: 'removing the heading must not take the hint with it');
  });

  testWidgets('fix 3b: the summary echoes the notes TEXT, not a flag',
      (tester) async {
    await toSummary(tester);
    await tester.enterText(find.byType(TextField).last, 'bit my tongue');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    expect(find.textContaining('bit my tongue'), findsWidgets,
        reason: 'the review step must show what was written, or it is not a '
            'review of it');

    // ⛔ AND THE FLAG IS GONE. Asserting only the text would pass if BOTH were
    // rendered, which is what a half-applied change produces.
    expect(find.text('• Notes added'), findsNothing,
        reason: '"Notes added" told the user a thing existed without letting '
            'them check it, on the step whose job is checking');
  });

  testWidgets('fix 2 second half: backdating is legible on the summary',
      (tester) async {
    // ⚠️ REPORTED, NOT REBUILT. The brief asks whether a reader can tell from
    // the summary that a record is backdated. The control is on the summary
    // and states its own meaning in both states, so this pins what is already
    // there rather than changing it.
    await toSummary(tester);
    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    expect(find.text('WHEN IT HAPPENED'), findsOneWidget,
        reason: 'the occurredAt control is ON the summary step');

    // NOT SET is the default, and it says so in words rather than showing a
    // bare date the reader would have to interpret.
    expect(
        find.textContaining('The time this was recorded'), findsOneWidget,
        reason: 'unset says what the shown time MEANS — it is the log time, '
            'not a stated occurrence time');
    expect(find.text('Set'), findsOneWidget,
        reason: 'and the affordance to state one is right there');
  });
}
