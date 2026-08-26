import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';

/// `isIncomplete` — where the line falls, and why it is not `detailsCompleted`.
///
/// ## The two questions
///
/// `detailsCompleted` records whether someone WALKED the guided flow.
/// `isIncomplete` records whether the record HAS anything. A user hunting for
/// gaps before an appointment is asking the second, and the two disagree in a
/// state reachable in three taps.

EventRecord rec({
  DurationCategory? bucket,
  int? secs,
  String? type,
  EventSeverity? severity,
  List<String> feelings = const <String>[],
  List<String> triggers = const <String>[],
  String notes = '',
  bool referral = false,
  bool? completed,
}) =>
    EventRecord(
      id: 'r',
      timestamp: DateTime(2026, 8, 26, 9, 0),
      duration: bucket,
      durationSeconds: secs,
      eventType: type,
      severity: severity,
      feelings: feelings,
      triggers: triggers,
      notes: notes,
      referralRequired: referral,
      detailsCompleted: completed,
    );

/// A record with every in-scope field supplied.
EventRecord complete() =>
    rec(secs: 90, type: 'seizure', severity: EventSeverity.mild);

void main() {
  group('WHERE THE LINE FALLS', () {
    test('1. a fully supplied record is COMPLETE', () {
      // The positive control everything below is measured against. Without it,
      // the tests that expect `true` pass just as well against a predicate
      // that always returns true.
      expect(isIncomplete(complete()), isFalse);
      expect(missingFields(complete()), isEmpty);
    });

    test('2. IN SCOPE: duration, type, severity — each alone is enough', () {
      // CATCH-ALL. A record missing only its severity is still incomplete,
      // because "incomplete" is what is being asked.
      expect(isIncomplete(rec(type: 'seizure', severity: EventSeverity.mild)),
          isTrue,
          reason: 'no duration');
      expect(isIncomplete(rec(secs: 90, severity: EventSeverity.mild)), isTrue,
          reason: 'no type');
      expect(isIncomplete(rec(secs: 90, type: 'seizure')), isTrue,
          reason: 'no severity');
    });

    test('3. duration counts EITHER half — a legacy bucket is an answer', () {
      // The three-state duration: a number, a legacy range, or nothing. A
      // record carrying "1-5 minutes" was answered, in the vocabulary of the
      // day, and must not be dragged into a list of things to go and fill in.
      final legacy =
          rec(bucket: DurationCategory.oneToFive,
              type: 'seizure', severity: EventSeverity.mild);
      expect(isIncomplete(legacy), isFalse);
      expect(missingFields(legacy), isEmpty);
    });

    test('4. OUT OF SCOPE: empty feelings and triggers are ANSWERS', () {
      // "Nothing beforehand" is data. An empty list is not an absent value,
      // and a filter that treated it as one would show every record forever.
      expect(isIncomplete(complete()), isFalse,
          reason: 'complete() has both lists empty');
    });

    test('5. OUT OF SCOPE: notes and referral', () {
      // Notes: absence of notes is not incompleteness. Referral: a
      // non-nullable bool has no absent state at all.
      final noNotes = complete();
      expect(noNotes.notes, isEmpty);
      expect(noNotes.referralRequired, isFalse);
      expect(isIncomplete(noNotes), isFalse);
    });

    test('6. NEGATIVE CONTROL: the out-of-scope fields would flip it if wrong',
        () {
      // Tests 4 and 5 are null results — they pass against a predicate that
      // ignores those fields AND against one that ignores everything. This
      // shows the predicate is looking: same record, one IN-SCOPE field
      // removed, and the answer changes.
      expect(isIncomplete(complete()), isFalse);
      expect(isIncomplete(rec(secs: 90, type: 'seizure')), isTrue,
          reason: 'the only difference is severity, which IS in scope');
    });
  });

  group('IT IS NOT detailsCompleted, AND THEY DISAGREE', () {
    test('7. THE DISAGREEMENT: completed AND empty', () {
      // Reachable in three taps: open the wizard, Skip to end, Save. The flag
      // says finished; every field is null.
      final skipped = rec(completed: true);

      expect(skipped.detailsCompleted, isTrue);
      expect(isIncomplete(skipped), isTrue,
          reason: 'this is the record a user is hunting for, and the flag '
              'would have hidden it');
      expect(missingFields(skipped), <String>['duration', 'type', 'severity']);
    });

    test('8. AND THE OTHER WAY: not completed, but nothing missing', () {
      // Someone filled everything in on the single page, which does not set
      // the flag to true from a partial. Complete in substance, "unfinished"
      // by the flag.
      final r = rec(
          secs: 90,
          type: 'seizure',
          severity: EventSeverity.mild,
          completed: false);

      expect(r.detailsCompleted, isFalse);
      expect(isIncomplete(r), isFalse,
          reason: 'a filter driven by the flag would list a record with '
              'nothing to add');
    });

    test('9. NULL never enters into it', () {
      // The strongest argument for field inspection: it removes a decision
      // rather than making one. `detailsCompleted == null` on the 71 legacy
      // records would have needed a ruling either way; here it is simply not
      // consulted.
      final completeLegacy = complete();
      final incompleteLegacy = rec(type: 'seizure');

      expect(completeLegacy.detailsCompleted, isNull);
      expect(incompleteLegacy.detailsCompleted, isNull);
      expect(isIncomplete(completeLegacy), isFalse);
      expect(isIncomplete(incompleteLegacy), isTrue,
          reason: 'same flag, opposite answers — decided by CONTENT');
    });
  });

  group('missingFields READS BACK', () {
    test('10. in the order the guided flow asks them', () {
      // So the list doubles as the route through, rather than needing to be
      // reordered by whoever renders it.
      expect(missingFields(rec()), <String>['duration', 'type', 'severity']);
    });

    test('11. and names only what is actually missing', () {
      expect(missingFields(rec(secs: 90, type: 'seizure')),
          <String>['severity']);
    });
  });
}
