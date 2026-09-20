import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/screens/event_wizard_screen.dart';

/// BRIEF 62 B — the summary reviews EVERY field the wizard asked about.
///
/// ⛔ **THIS IS THE REVIEW STEP BEFORE A WRITE WITH NO DELETE PATH.** MER
/// cannot delete an event; hiding is the only removal. So "Check and save" is
/// the last point at which a mistake is cheap, and it showed Duration plus
/// only the fields that happened to have answers — on an untouched record,
/// two lines for a four-step questionnaire.
///
/// 🔴 **THE FAILURE WAS THAT OMITTED AND UNANSWERED RENDERED IDENTICALLY** —
/// as nothing — **and only one of them is recoverable by tapping Back.** A
/// user could not tell "I skipped severity" from "severity was never asked".
///
/// ⚠️ **IT REVERSES A RECORDED DECISION, AND THE OLD REASON WAS RIGHT ABOUT
/// THE WORD IT OBJECTED TO.** The comment read *"A summary that said 'Event
/// type: unknown' would read as a finding."* True — `unknown` is a value in
/// this app's vocabulary. ⭐ **"not recorded" is not a value, it is the
/// absence of one**, and Duration has rendered it on this very screen since
/// the summary existed. The objection does not reach the line that replaced it.

void main() {
  Future<void> pumpTo(WidgetTester tester, {EventRecord? existing}) async {
    await tester.pumpWidget(MaterialApp(home: EventWizardScreen(existing: existing)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Skip to end'));
    await tester.pumpAndSettle();
  }

  /// Every bullet the summary rendered, in order.
  List<String> bullets(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .where((s) => s.startsWith('• '))
      .map((s) => s.substring(2))
      .toList();

  testWidgets('1. an untouched record reviews EVERY question it was asked',
      (tester) async {
    await pumpTo(tester);
    final got = bullets(tester);

    // ⛔ DERIVED FROM THE WIZARD'S OWN STEPS, not from a list someone believed.
    // Step 1 duration · step 2 type + severity · step 3 beforehand ·
    // step 4 afterwards + rescue + referral + notes.
    const expected = <String>[
      'Duration: not recorded',
      'Event type: not recorded',
      'Severity: not recorded',
      'Beforehand: not recorded',
      'Afterwards: not recorded',
      'Rescue medication: not recorded',
      'Further medical attention: not recorded',
      'Notes: not recorded',
    ];
    for (final line in expected) {
      expect(got, contains(line),
          reason: 'the summary must account for every field the wizard asked '
              'about. Missing: "$line"');
    }
    expect(got, hasLength(expected.length),
        reason: 'COVERAGE, not just presence: ${got.length} bullets against '
            '${expected.length} expected. A clean pass over an unstated '
            'denominator is indistinguishable from no pass at all.\n'
            'Actually rendered: $got');
  });

  testWidgets('2. the GATED children are absent, not listed as gaps',
      (tester) async {
    await pumpTo(tester);
    final got = bullets(tester).join('\n');

    // ⛔ THE ONE PLACE "every field appears" MUST NOT BE READ LITERALLY.
    // "Did it help" and "Second dose" are only ASKED once rescue medication is
    // Yes. Listing them as "not recorded" would assert a gap in a question
    // nobody was entitled to be asked — the same defect in the other
    // direction. §13(cd) calls this Not Applicable.
    expect(got, isNot(contains('Did it help')),
        reason: 'never asked, because rescue medication is unanswered');
    expect(got, isNot(contains('Second dose')));
    expect(got, contains('Rescue medication: not recorded'),
        reason: 'CONTROL: the PARENT question was asked and does appear, so '
            'the two absences above are the gate working rather than the '
            'whole rescue section having vanished');
  });

  testWidgets('3. the children DO appear once the parent is answered Yes',
      (tester) async {
    await pumpTo(tester,
        existing: EventRecord(
          id: 'r',
          timestamp: DateTime(2026, 9, 20, 9, 0),
          duration: null,
          feelings: const <String>[],
          notes: '',
          rescueMedGiven: true,
        ));
    final got = bullets(tester).join('\n');
    expect(got, contains('Rescue medication: Given'));
    expect(got, contains('Did it help: not recorded'),
        reason: 'now it WAS asked, so an unanswered child is a real gap and '
            'must be shown as one');
    expect(got, contains('Second dose: not recorded'));
  });

  testWidgets('4. an ANSWERED field shows its value, not "not recorded"',
      (tester) async {
    await pumpTo(tester,
        existing: EventRecord(
          id: 'r',
          timestamp: DateTime(2026, 9, 20, 9, 0),
          duration: DurationCategory.oneToFive,
          feelings: const <String>[],
          notes: 'hit head',
          eventType: kTypeSeizure,
          severity: EventSeverity.severe,
          referralRequired: true,
        ));
    final got = bullets(tester).join('\n');

    // ⭐ THE CONTROL FOR TEST 1. Without this, a summary that printed
    // "not recorded" on every line unconditionally would pass test 1
    // perfectly — the bug being asserted against would still be present in
    // the opposite direction and nothing would say so.
    expect(got, contains('Severity: Severe'));
    expect(got, contains('Further medical attention: Yes'));
    expect(got, contains('Notes: hit head'));
    expect(got, isNot(contains('Severity: not recorded')));
  });
}
