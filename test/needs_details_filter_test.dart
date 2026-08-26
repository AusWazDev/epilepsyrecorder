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
