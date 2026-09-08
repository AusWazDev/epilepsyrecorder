import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/vocabulary.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/log_event_screen.dart';

/// The Confirm-changes list must name the RESCUE fields.
///
/// `_hasChanges` checks eleven fields; `_buildChangeList` covered eight. The
/// three it missed — rescue given, did it help, second dose — are the ones
/// recording whether emergency medication was administered, whether it worked,
/// and whether a second dose was needed. So a rescue-only edit passed the
/// no-op guard and then rendered *"Save the following changes?"* above an
/// EMPTY list: the user confirmed a change the dialog did not name.
///
/// AUDIT.md section 13(m). Live in the published build since `0de48d1`,
/// 21 March 2026.
///
/// ## Why the finders are scoped by ROW and not by text
///
/// `rescueResponseLabel` returns 'Yes' / 'Partly' / 'No' — the SAME strings the
/// two boolean rows use. With the rescue children visible, 'Yes' appears four
/// times on this screen (rescue given, did it help, second dose, referral).
/// Only 'Partly' is unique. Each test therefore asserts the expected NUMBER of
/// boolean selection rows before tapping one by index, so a layout change fails
/// the test loudly instead of silently tapping a different field.
///
/// No `SharedPreferences` anywhere in this file, so the one-state-per-process
/// rule does not apply. `Vocabularies.debugReset` is the only shared state.

/// A complete record with rescue medication answered. `detailsCompleted: true`
/// so `wantsWizard` would route it here in production, which is the population
/// the defect affects.
EventRecord rescueRecord({
  bool? given = true,
  RescueResponse? helped = RescueResponse.helped,
  bool? secondDose = false,
}) =>
    EventRecord(
      id: 'rescue-1',
      timestamp: DateTime(2026, 8, 20, 9, 0),
      duration: DurationCategory.oneToFive,
      durationSeconds: 90,
      eventType: 'seizure',
      severity: EventSeverity.mild,
      feelings: const <String>[],
      triggers: const <String>[],
      rescueMedGiven: given,
      rescueMedHelped: helped,
      rescueMedSecondDose: secondDose,
      referralRequired: false,
      notes: '',
      detailsCompleted: true,
    );

/// Every boolean selection row on the screen, in tree order.
Finder boolRows() => find.byWidgetPredicate(
    (w) => w.runtimeType.toString() == '_SelectionRow<bool>');

Future<void> openSaveDialog(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Save changes'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Save changes'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(Vocabularies.debugReset);
  tearDown(Vocabularies.debugReset);

  testWidgets('1. rescue given, changed alone, is NAMED in the change list',
      (tester) async {
    // given: false -> the children are gated off, so exactly TWO boolean rows
    // exist: rescue given, then referral.
    await tester.pumpWidget(MaterialApp(
      home: LogEventScreen(
        existing: rescueRecord(given: false, helped: null, secondDose: null),
        confirmOnSave: true,
      ),
    ));
    await tester.pumpAndSettle();

    expect(boolRows(), findsNWidgets(2),
        reason: 'rescue given + referral; the children are gated off at '
            'given == false. If this fails the index below taps the wrong row.');

    final yes = find.descendant(of: boolRows().at(0), matching: find.text('Yes'));
    expect(yes, findsOneWidget);
    await tester.ensureVisible(yes);
    await tester.pumpAndSettle();
    await tester.tap(yes);
    await tester.pumpAndSettle();

    await openSaveDialog(tester);

    // The dialog opened at all, so _hasChanges saw the edit.
    expect(find.text('Confirm changes'), findsOneWidget,
        reason: 'the no-op guard must NOT have short-circuited');
    expect(find.text('No changes to save.'), findsNothing);

    // And it must NAME the change. This is the assertion that failed before
    // the fix, with an empty list under the prompt.
    expect(find.textContaining('Rescue medication'), findsOneWidget);
  });

  testWidgets('2. did it help, changed alone, is NAMED — and rendered as the '
      'ENUM, not a bool', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LogEventScreen(
        existing: rescueRecord(),
        confirmOnSave: true,
      ),
    ));
    await tester.pumpAndSettle();

    // 'Partly' is the one rescue label that cannot collide with a boolean row.
    final partly = find.text('Partly');
    expect(partly, findsOneWidget);
    await tester.ensureVisible(partly);
    await tester.pumpAndSettle();
    await tester.tap(partly);
    await tester.pumpAndSettle();

    await openSaveDialog(tester);

    expect(find.text('Confirm changes'), findsOneWidget);
    // Rendered through rescueResponseDisplay, so the arrow carries the enum's
    // own labels. A bool rendering would read "Yes -> No" and lose 'Partly'
    // entirely, which is the third of three values.
    expect(find.textContaining('Did it help: Yes → Partly'), findsOneWidget);
  });

  testWidgets('3. second dose, changed alone, is NAMED', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: LogEventScreen(
        existing: rescueRecord(),
        confirmOnSave: true,
      ),
    ));
    await tester.pumpAndSettle();

    // given == true, so the children are drawn: rescue given, second dose,
    // referral. Second dose is index 1.
    expect(boolRows(), findsNWidgets(3),
        reason: 'rescue given + second dose + referral');

    final yes = find.descendant(of: boolRows().at(1), matching: find.text('Yes'));
    expect(yes, findsOneWidget);
    await tester.ensureVisible(yes);
    await tester.pumpAndSettle();
    await tester.tap(yes);
    await tester.pumpAndSettle();

    await openSaveDialog(tester);

    expect(find.text('Confirm changes'), findsOneWidget);
    expect(find.textContaining('Second dose'), findsOneWidget);
  });

  testWidgets('4. NEGATIVE CONTROL: with nothing changed the guard still '
      'short-circuits and no dialog opens', (tester) async {
    // Proves tests 1-3 are detecting the CHANGE and not merely the presence of
    // a rescue section on the screen.
    await tester.pumpWidget(MaterialApp(
      home: LogEventScreen(
        existing: rescueRecord(),
        confirmOnSave: true,
      ),
    ));
    await tester.pumpAndSettle();

    await openSaveDialog(tester);

    expect(find.text('Confirm changes'), findsNothing);
    expect(find.textContaining('Rescue medication'), findsNothing);
    expect(find.text('No changes to save.'), findsOneWidget);
  });

  testWidgets('5. REGRESSION CONTROL: a non-rescue field is still named',
      (tester) async {
    // The eight entries that already worked must keep working. Severity is one
    // of them and shares the display-helper shape the rescue enum now uses.
    await tester.pumpWidget(MaterialApp(
      home: LogEventScreen(
        existing: rescueRecord(),
        confirmOnSave: true,
      ),
    ));
    await tester.pumpAndSettle();

    final severe = find.text(severityLabel(EventSeverity.severe));
    await tester.ensureVisible(severe);
    await tester.pumpAndSettle();
    await tester.tap(severe);
    await tester.pumpAndSettle();

    await openSaveDialog(tester);

    expect(find.text('Confirm changes'), findsOneWidget);
    expect(find.textContaining('Severity:'), findsOneWidget);
    // and rescue is NOT named, because rescue did not change
    expect(find.textContaining('Rescue medication'), findsNothing);
  });
}
