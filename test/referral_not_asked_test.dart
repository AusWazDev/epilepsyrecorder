import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/screens/event_wizard_screen.dart';
import 'package:medical_event_recorder/screens/log_event_screen.dart';

/// BRIEF 62 A — `referralRequired` can say NOT ASKED.
///
/// ⛔ **THE DEFECT WAS THAT THE FIELD WROTE, NOT THAT IT DISPLAYED.** The read
/// that gated this fix asked which, and the answer decided its severity:
/// `referralRequired` was a non-nullable `bool`, the wizard wrote `_referral`
/// into every record, SQLite stored `0`, and `buildCsv` wrote the literal word
/// `No`. **A one-tap capture asserted, in a medical export, that no medical
/// referral was needed — from a user who was shown no such question.**
///
/// ⚠️ **THIS CODEBASE HAD ALREADY FOUND IT TWICE AND COULD NOT FIX IT.**
/// §13(bl) finding 1 flagged the export claim on 10 September 2026 and routed
/// it to the adviser; §13(cd) costed it on 11 September and named the cause —
/// *"A non-nullable bool has no absent state at all … the `No` §13(bl) flagged
/// is not a bad rendering choice — it is the ONLY value the type can hold."*
/// ⭐ **So no renderer change could ever have fixed it. The missing state was
/// in the TYPE**, and that is what moved here.
///
/// ⚠️ **NOT BACK-FILLED, AND THAT IS ASSERTED BELOW.** A record already
/// holding `false` keeps it. That `false` means *either* "answered No" *or*
/// "never asked" and the two are not separable after the fact.
///
/// ⛔ **THE TWO EDITORS DIFFER DELIBERATELY, AND GROUP 5 IS WHY THIS FILE CAN
/// NO LONGER ASSERT ONE RULE FOR BOTH.** Amended 20 September 2026 (R3 §2)
/// after the developer supplied the v1 reasoning.
///
/// ⭐ **THE RULE: a value is written when the user was SHOWN the question.**
///
///     single form   "No" PRESELECTED - v1 stands. The form shows everything
///                   at once and is SCANNED, so the default is visible on the
///                   same screen and correctable in one tap
///     wizard        NEITHER preselected. It ASKS one question at a time, and
///                   a preselected answer on a screen built to put the
///                   question in front of someone is an answer nobody gave
///     quick-log     nothing written. The question is never displayed
///     Skip to end   nothing written. Same reason
///
/// 🔴 **A SINGLE "STARTS UNSET" ASSERTION WOULD BE RIGHT IN ONE EDITOR AND
/// WRONG IN THE OTHER, AND WOULD PASS WHILE HIDING EXACTLY WHAT THIS
/// SEPARATES.** Group 5 demonstrates both directions, and both were shown
/// failing before they were trusted.

void main() {
  group('1. the three states exist and are distinguishable', () {
    EventRecord withReferral(bool? v) => EventRecord(
          id: 'r',
          timestamp: DateTime(2026, 9, 20, 9, 0),
          duration: null,
          feelings: const <String>[],
          referralRequired: v,
          notes: '',
        );

    test('1a. null, false and true are three different records', () {
      // ⭐ THE CONTROL IS THE TEST. Before this change the type had TWO
      // inhabitants, so this assertion could not have been written — not
      // "would have failed", could not have compiled.
      expect(withReferral(null).referralRequired, isNull);
      expect(withReferral(false).referralRequired, isFalse);
      expect(withReferral(true).referralRequired, isTrue);
    });

    test('1b. the CSV writes all three differently', () {
      String cell(bool? v) {
        final csv = buildCsv([withReferral(v)]);
        final header = csv.split('\n').first.split(',');
        final row = csv.split('\n')[1].split(',');
        return row[header.indexOf('referral_required')];
      }

      expect(cell(true), 'Yes');
      expect(cell(false), 'No',
          reason: 'CONTROL: an ANSWERED no still writes No. If this ever reads '
              'Not Captured the change has gone too far and a real negative '
              'answer is being thrown away');
      expect(cell(null), 'Not Captured',
          reason: 'the whole point — a record nobody asked must not assert an '
              'answer in a medical export');
    });

    test('1c. the column set is UNCHANGED — this is a value change', () {
      // ⚠️ Pinned because the marker bump (v7 -> v8) is a MEANING change, and
      // a reader who assumes a bump means new columns would be wrong.
      final header = buildCsv([withReferral(null)]).split('\n').first;
      expect(header, contains('referral_required'));
      expect(header.split(',').length, 17);
      expect(kCsvShapeVersion, 'v8');
    });
  });

  // ⚠️ THE QUICK-LOG CAPTURE PATH IS NOT RE-TESTED HERE. `capture_inbox_test`
  // test 4 already asserts it, and its assertion changed from `isFalse` to
  // `isNull` in this same pass — reimplementing it here would make a second
  // implementation's bug the finding, which this repo's rules forbid.

  group('3. the wizard starts unset and stays unset unless answered', () {
    Future<void> pumpWizard(WidgetTester tester, {EventRecord? existing}) async {
      await tester.pumpWidget(MaterialApp(
        home: EventWizardScreen(existing: existing),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('3a. step 4 opens with NEITHER option selected', (tester) async {
      await pumpWizard(tester);
      await tester.tap(find.text('Skip to end'));
      await tester.pumpAndSettle();
      // Back off the summary onto step 4.
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      final yes = tester.widget<ChoiceChip>(find.ancestor(
          of: find.text('Yes'), matching: find.byType(ChoiceChip)));
      final no = tester.widget<ChoiceChip>(find.ancestor(
          of: find.text('No'), matching: find.byType(ChoiceChip)));

      expect(no.selected, isFalse,
          reason: 'THE DEFECT: `No` rendered filled with a tick before anyone '
              'touched it, visually identical to an answer the user gave');
      expect(yes.selected, isFalse,
          reason: 'CONTROL: and `Yes` was never selected either, so the '
              'assertion above is about the default and not about chips in '
              'general being unselected');
    });

    testWidgets('3b. an EXISTING answered record is carried, not reset',
        (tester) async {
      await pumpWizard(tester,
          existing: EventRecord(
            id: 'e',
            timestamp: DateTime(2026, 9, 20, 9, 0),
            duration: null,
            feelings: const <String>[],
            referralRequired: true,
            notes: '',
          ));
      await tester.tap(find.text('Skip to end'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      final yes = tester.widget<ChoiceChip>(find.ancestor(
          of: find.text('Yes'), matching: find.byType(ChoiceChip)));
      expect(yes.selected, isTrue,
          reason: 'a real answer must survive the round trip — the fix removes '
              'the DEFAULT, not the field');
    });
  });

  group('4. round trips preserve NOT ASKED', () {
    test('4a. backup JSON carries null through, and an absent key reads null',
        () {
      final r = EventRecord(
        id: 'r',
        timestamp: DateTime(2026, 9, 20, 9, 0),
        duration: null,
        feelings: const <String>[],
        referralRequired: null,
        notes: '',
      );
      final back = EventRecord.fromMap(r.toMap());
      expect(back!.referralRequired, isNull);

      final stripped = Map<String, dynamic>.from(r.toMap())
        ..remove('referralRequired');
      expect(EventRecord.fromMap(stripped)!.referralRequired, isNull,
          reason: 'an ABSENT key is NOT ASKED, the same rule detailsCompleted '
              'already followed. This line read `: false` until Brief 62 A');

      final answered = Map<String, dynamic>.from(r.toMap())
        ..['referralRequired'] = false;
      expect(EventRecord.fromMap(answered)!.referralRequired, isFalse,
          reason: 'CONTROL: an explicit false is still read as false, so the '
              'assertion above is about ABSENCE and not about the parser '
              'having stopped reading the key');
    });
  });

  group('5. ⛔ THE TWO EDITORS DIFFER, AND BOTH DIRECTIONS ARE PINNED', () {
    // The record every case below starts from: NOT ASKED.
    EventRecord unasked() => EventRecord(
          id: 'u',
          timestamp: DateTime(2026, 9, 20, 9, 0),
          duration: null,
          feelings: const <String>[],
          referralRequired: null,
          notes: '',
        );

    bool chipSelected(WidgetTester tester, String label) =>
        tester
            .widget<ChoiceChip>(find.ancestor(
                of: find.text(label), matching: find.byType(ChoiceChip)))
            .selected;

    testWidgets('5a. THE FORM preselects No on a record nobody was asked about',
        (tester) async {
      // A TALL VIEWPORT rather than a scroll: the whole form lays out at
      // once, so the chips are found without driving the scroller. The same
      // shape `selection_row_semantics_test` uses on this screen.
      addTearDown(tester.view.reset);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 2400);
      await tester.pumpWidget(MaterialApp(
        home: LogEventScreen(existing: unasked(), confirmOnSave: true),
      ));
      await tester.pumpAndSettle();

      expect(chipSelected(tester, 'No'), isTrue,
          reason: 'V1 STANDS ON THIS SURFACE. The form shows everything at '
              'once and is scanned, so a visible default is correctable in one '
              'tap — the decision made to minimise admin for a patient or '
              'carer, because most of the time no further attention happened');
      expect(chipSelected(tester, 'Yes'), isFalse,
          reason: 'CONTROL: only ONE option is preselected, so the assertion '
              'above is about the default and not about both chips reading '
              'as selected');
    });

    testWidgets('5b. THE WIZARD preselects nothing on the SAME record',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: EventWizardScreen(existing: unasked()),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip to end'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      expect(chipSelected(tester, 'No'), isFalse,
          reason: 'THE WIZARD ASKS. A preselected answer on a screen whose '
              'whole purpose is to put the question in front of someone is an '
              'answer nobody gave');
      expect(chipSelected(tester, 'Yes'), isFalse);
    });

    testWidgets('5c. ⛔ SKIP TO END WRITES NOTHING — the path c4d5d0a never '
        'named', (tester) async {
      EventRecord? saved;
      await tester.pumpWidget(MaterialApp(
        home: Navigator(onGenerateRoute: (_) {
          return MaterialPageRoute<EventRecord>(
            builder: (ctx) => TextButton(
              child: const Text('open'),
              onPressed: () async {
                saved = await Navigator.of(ctx).push<EventRecord>(
                  MaterialPageRoute(
                      builder: (_) => const EventWizardScreen()),
                );
              },
            ),
          );
        }),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip to end'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(saved, isNotNull,
          reason: 'CONTROL: a record WAS saved, so the null below is about the '
              'referral field and not about the save having failed');
      expect(saved!.detailsCompleted, isTrue,
          reason: 'CONTROL: and it saved as COMPLETE, which is what Skip to '
              'end plus Save means — so this is the real path, not a stall');
      expect(saved!.referralRequired, isNull,
          reason: 'the question was never displayed on any step the user saw, '
              'so nothing may be written for it. Skip to end jumps straight '
              'to the summary and materialises no draft');
    });
  });
}
