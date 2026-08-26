import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/event_wizard_screen.dart';
import 'package:medical_event_recorder/screens/history_screen.dart';

/// The "needs details" filter, end to end: the predicate, the skip logic, the
/// row, and the routing.
///
/// Sibling of `incomplete_predicate_test`, which covers where the line falls.
/// This file covers what the app DOES with it.

EventRecord rec(
  String id, {
  DurationCategory? bucket,
  int? secs,
  String? type,
  EventSeverity? severity,
  List<String> feelings = const <String>[],
  List<String> triggers = const <String>[],
  String notes = '',
  bool? completed,
}) =>
    EventRecord(
      id: id,
      timestamp: DateTime(2026, 8, 20, 9, 0),
      duration: bucket,
      durationSeconds: secs,
      eventType: type,
      severity: severity,
      feelings: feelings,
      triggers: triggers,
      notes: notes,
      referralRequired: false,
      detailsCompleted: completed,
    );

EventRecord full(String id, {bool? completed}) => rec(id,
    secs: 90, type: 'seizure', severity: EventSeverity.mild, completed: completed);

void main() {
  setUp(Vocabularies.debugReset);
  tearDown(Vocabularies.debugReset);

  group('EACH OF THE THREE QUALIFIES INDEPENDENTLY', () {
    // Walked as a table so a field dropped from the check fails HERE with its
    // name attached, rather than as one assertion among many.
    final cases = <String, EventRecord>{
      'duration': rec('d', type: 'seizure', severity: EventSeverity.mild),
      'type': rec('t', secs: 90, severity: EventSeverity.mild),
      'severity': rec('s', secs: 90, type: 'seizure'),
    };

    cases.forEach((field, r) {
      test('1.$field alone makes a record incomplete', () {
        expect(isIncomplete(r), isTrue,
            reason: '$field is unset and the filter is CATCH-ALL');
        expect(missingFields(r), <String>[field]);
      });
    });

    test('2. NEGATIVE CONTROL: dropping ONE field from the check would hide a '
        'record the filter exists to find', () {
      // ⚠️ THE HAZARD, made to happen — same shape as the applied-filters
      // line's control.
      //
      // The filter cannot be tested for a defect that does not exist yet, so
      // this SIMULATES the omission: for each field, it asks what a check
      // MISSING that field would conclude about a record whose ONLY gap is
      // that field. The answer is "complete", and the record vanishes from a
      // work queue built to surface it.
      //
      // Without this, group 1 passes just as well against a predicate wired to
      // a constant true.
      bool withoutDuration(EventRecord r) =>
          r.eventType == null || r.severity == null;
      bool withoutType(EventRecord r) =>
          (r.duration == null && r.durationSeconds == null) ||
          r.severity == null;
      bool withoutSeverity(EventRecord r) =>
          (r.duration == null && r.durationSeconds == null) ||
          r.eventType == null;

      expect(withoutDuration(cases['duration']!), isFalse,
          reason: 'a record missing only its duration would read as complete');
      expect(withoutType(cases['type']!), isFalse,
          reason: 'a record missing only its type would read as complete');
      expect(withoutSeverity(cases['severity']!), isFalse,
          reason: 'a record missing only its severity would read as complete');

      // And the real check disagrees with all three, so the difference is the
      // field and not the fixture.
      for (final r in cases.values) {
        expect(isIncomplete(r), isTrue);
      }
    });

    test('3. OBSERVATIONS AND TRIGGERS DO NOT QUALIFY', () {
      // "An event with no observed aftermath is a complete record of an event
      // with no observed aftermath." An empty list is an ANSWER.
      final r = full('x');
      expect(r.feelings, isEmpty);
      expect(r.triggers, isEmpty);
      expect(r.notes, isEmpty);
      expect(isIncomplete(r), isFalse);
    });

    test('4. and a LEGACY BUCKET counts as a duration', () {
      // The three-state duration. "1-5 minutes" was answered in the vocabulary
      // of the day and must not be dragged into a queue of things to fill in.
      expect(
          isIncomplete(rec('b',
              bucket: DurationCategory.oneToFive,
              type: 'seizure',
              severity: EventSeverity.mild)),
          isFalse);
    });
  });

  group('SKIP WHAT IS ALREADY ANSWERED', () {
    test('5. nothing answered opens on step 0', () {
      expect(firstUnansweredStep(rec('a')), 0);
      expect(firstUnansweredStep(null), 0, reason: 'a brand new record');
    });

    test('6. a measured duration skips to step 1', () {
      expect(firstUnansweredStep(rec('a', secs: 90)), 1);
    });

    test('7. duration AND type AND severity answered skips to step 2', () {
      // The legacy case the queue exists for: feelings and triggers are
      // already there, so walking all four steps would re-ask three questions
      // it knows the answers to.
      expect(firstUnansweredStep(full('a')), 2);
    });

    test('8. type answered but severity NOT still asks step 1', () {
      // Step 1 carries both, so either one unanswered means the step is due.
      expect(firstUnansweredStep(rec('a', secs: 90, type: 'seizure')), 1);
      expect(
          firstUnansweredStep(rec('a', secs: 90, severity: EventSeverity.mild)),
          1);
    });

    test(
        '9. ⚠️ THE LEGACY-DURATION TRAP: a bucket with no seconds still ASKS',
        () {
      // It LOOKS answered and is not answerable in a minutes-and-seconds
      // control — "1-5 minutes" contains no number. Only `measured` skips.
      final legacy = full('a');
      expect(isIncomplete(legacy), isFalse, reason: 'complete for the FILTER');

      final bucketOnly = rec('b',
          bucket: DurationCategory.oneToFive,
          type: 'seizure',
          severity: EventSeverity.mild);
      expect(isIncomplete(bucketOnly), isFalse,
          reason: 'and complete for the filter too');
      expect(firstUnansweredStep(bucketOnly), 0,
          reason: 'but the WIZARD still asks, because the value cannot be '
              'expressed in the control it would be shown in');
    });

    test('10. and NEITHER field has a twin of that trap', () {
      // Type and severity are two-state: null or a value. Neither has a
      // superseded representation the current control cannot express, so
      // "has a value" and "has an answerable value" are the same question.
      // A retired vocabulary entry is still a real answer.
      final retiredType = rec('r',
          secs: 90, type: 'a-type-no-longer-offered',
          severity: EventSeverity.mild);
      expect(firstUnansweredStep(retiredType), 2,
          reason: 'a value this vocabulary no longer offers is still an '
              'ANSWER, and re-asking would discard it');
    });
  });

  group('ROUTING', () {
    test('11. an incomplete record routes to the WIZARD', () {
      expect(wantsWizard(rec('a', type: 'seizure')), isTrue);
    });

    test('12. a complete record routes to the FORM, whatever the flag', () {
      expect(wantsWizard(full('a')), isFalse, reason: 'flag null');
      expect(wantsWizard(full('a', completed: true)), isFalse);
    });

    test('13. and a PARTIAL still routes to the wizard', () {
      expect(wantsWizard(full('a', completed: false)), isTrue,
          reason: 'complete in fields, but someone stopped part-way');
    });
  });

  group('BACKING OUT KEEPS THE CURRENT STEP', () {
    // ⚠️ THE DEFECT THE WORK QUEUE MADE PRIMARY. `_draft` was materialised only
    // by Next and by Skip, so anything chosen on the step being LEFT was
    // discarded. Found on the tablet, not in a test: pick a type and a
    // severity, back out, reopen, both gone.
    //
    // The queue makes that the main path — open an incomplete record, answer
    // the one missing thing, back out — so losing it defeats the feature. It
    // also made Help's "whatever you have entered is kept if you back out"
    // false.

    Future<EventRecord?> walk(
      WidgetTester tester,
      EventRecord? existing,
      Future<void> Function(WidgetTester) act,
    ) async {
      EventRecord? out;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  out = await Navigator.of(context).push<EventRecord>(
                    MaterialPageRoute(
                      builder: (_) => EventWizardScreen(existing: existing),
                    ),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await act(tester);
      tester.state<NavigatorState>(find.byType(Navigator)).maybePop();
      await tester.pumpAndSettle();
      return out;
    }

    testWidgets('17. a choice on the CURRENT step survives backing out',
        (tester) async {
      final existing = rec('a', secs: 90); // opens on step 1: type + severity
      final out = await walk(tester, existing, (t) async {
        await t.tap(find.text('Seizure / fit'));
        await t.pumpAndSettle();
        await t.tap(find.text('Mild'));
        await t.pumpAndSettle();
      });

      expect(out, isNotNull);
      expect(out!.eventType, 'seizure',
          reason: 'chosen on the step being left, with no Next in between');
      expect(out.severity, EventSeverity.mild);
      expect(isIncomplete(out), isFalse,
          reason: 'and the record leaves the queue, which is the point');
    });

    testWidgets(
        '18. NEGATIVE CONTROL: an UNTOUCHED new event still creates NOTHING',
        (tester) async {
      // The condition that keeps the fix honest. Capturing unconditionally on
      // exit would make opening and closing the wizard create a record.
      final out = await walk(tester, null, (t) async {});
      expect(out, isNull,
          reason: 'opening and closing the wizard must not create a record');
    });

    testWidgets('19. and one touch IS enough to keep it', (tester) async {
      // Shows test 18 passes because nothing was entered, not because the
      // capture is dead.
      final out = await walk(tester, null, (t) async {
        await t.enterText(find.byType(TextField).first, '3');
        await t.pumpAndSettle();
      });
      expect(out, isNotNull);
      expect(out!.durationSeconds, 180);
    });
  });

  group('THE COMPLETION ROUTE — filtered list to wizard and back', () {
    // ⚠️ THE REASON THE FILTER IS WORTH HAVING. A queue that surfaces records
    // and offers nothing to do about them is a list of complaints. The route
    // is: filter, tap a row, answer what is missing, and the record LEAVES the
    // queue.
    //
    // Tested end to end rather than in parts, because every part already
    // passed individually while the route as a whole was unverified: the
    // predicate, the chip, `wantsWizard` and `_editRecord` each had tests, and
    // none of them proved a completed record is PERSISTED and drops out.

    testWidgets(
        '17. tap an incomplete row, answer the gap, and it leaves the queue',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // The screen owns its list, so the harness holds the records and feeds
      // them back — which is also what proves the change was PERSISTED rather
      // than only rendered.
      var records = <EventRecord>[
        full('complete'),
        rec('gap', type: 'seizure', severity: EventSeverity.mild), // no duration
      ];
      List<EventRecord>? saved;

      Future<void> build() async {
        await tester.pumpWidget(MaterialApp(
          home: HistoryScreen(
            records: records,
            onRecordsChanged: (updated) async {
              saved = updated;
              records = updated;
            },
            onEdit: (_, {required confirmOnSave}) async {},
          ),
        ));
        await tester.pumpAndSettle();
      }

      await build();

      // Narrow to the queue.
      await tester.tap(find.byTooltip('Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(BottomSheet), matching: find.text('Needs details')));
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();

      expect(find.textContaining('Showing 1 of 2'), findsOneWidget);
      expect(find.textContaining('Needs: duration'), findsOneWidget);

      // Tap the row. The route is the wizard, and it opens on the step that
      // asks the missing question.
      await tester.tap(find.textContaining('Needs: duration'));
      await tester.pumpAndSettle();
      expect(find.text('How long did it last?'), findsOneWidget,
          reason: 'the completion route lands on the gap, not on step one');

      // Answer it and leave. No Next: backing out must keep it.
      await tester.enterText(find.byType(TextField).first, '2');
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator).first).maybePop();
      await tester.pumpAndSettle();

      expect(saved, isNotNull, reason: 'onRecordsChanged must have fired');
      final updated = saved!.firstWhere((r) => r.id == 'gap');
      expect(updated.durationSeconds, 120);
      expect(isIncomplete(updated), isFalse,
          reason: 'and it has left the queue');
    });

    testWidgets('18. NEGATIVE CONTROL: a COMPLETE row routes to the form',
        (tester) async {
      // Without this, test 17 passes just as well against a row that always
      // opens the wizard — which would send someone with nothing to add to a
      // four-step flow.
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: HistoryScreen(
          records: <EventRecord>[full('complete')],
          onRecordsChanged: (_) async {},
          onEdit: (_, {required confirmOnSave}) async {},
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('Mild'));
      await tester.pumpAndSettle();

      expect(find.text('How long did it last?'), findsNothing);
      expect(find.text('WHAT HAPPENED?'), findsOneWidget,
          reason: 'the single page, which uses uppercase section labels');
    });
  });

  group('THE ROW NAMES WHAT IS MISSING', () {
    Future<void> pump(WidgetTester tester, List<EventRecord> records) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: HistoryScreen(
          records: records,
          onRecordsChanged: (_) async {},
          onEdit: (_, {required confirmOnSave}) async {},
        ),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('14. a bare quick-record says all three', (tester) async {
      // Without this the row is a timestamp and nothing else, and a filtered
      // list of them differs only by time.
      await pump(tester, <EventRecord>[rec('a')]);
      expect(find.textContaining('Needs: duration, type, severity'),
          findsOneWidget);
    });

    testWidgets('15. and names ONLY what is missing', (tester) async {
      await pump(tester, <EventRecord>[rec('a', secs: 90, type: 'seizure')]);
      expect(find.textContaining('Needs: severity'), findsOneWidget);
      expect(find.textContaining('duration'), findsNothing);
    });

    testWidgets('16. NEGATIVE CONTROL: a complete row says nothing',
        (tester) async {
      // Otherwise test 14 passes against a row that annotates everything.
      await pump(tester, <EventRecord>[full('a')]);
      expect(find.textContaining('Needs:'), findsNothing);
    });
  });
}
