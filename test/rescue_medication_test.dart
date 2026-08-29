import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/backup.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/event_wizard_screen.dart';

/// Rescue medication: three nullable fields, one gate, and the exception to it.
///
/// ## The decision under test
///
/// The two follow-up questions are hidden unless rescue medication was given,
/// because "did it help: yes" beside "given: no" is a contradiction a reviewer
/// cannot resolve and the export carries it to a clinician who cannot ask.
///
/// **But the gate prevents the state being CREATED; it must never hide a value
/// that already exists.** Those are different rules and the difference is what
/// most of this file measures - a screen that silently withholds a stored
/// value is the worse of the two failures, because the value is still in the
/// export and the backup with nothing on screen corresponding to it.

EventRecord rec({
  bool? given,
  RescueResponse? helped,
  bool? second,
}) =>
    EventRecord(
      id: 'r',
      timestamp: DateTime(2026, 8, 27, 9, 0),
      duration: null,
      durationSeconds: 90,
      eventType: 'seizure',
      severity: EventSeverity.mild,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: false,
      notes: '',
      rescueMedGiven: given,
      rescueMedHelped: helped,
      rescueMedSecondDose: second,
    );

List<String> header(String csv) =>
    csv.split('\n').first.replaceFirst('﻿', '').trim().split(',');

List<String> cells(String csv) => csv.trim().split('\n').last.split(',');

void main() {
  setUp(Vocabularies.debugReset);
  tearDown(Vocabularies.debugReset);

  group('THE GATE', () {
    test('1. hidden when nothing was asked', () {
      expect(rescueChildrenVisible(rec()), isFalse);
    });

    test('2. hidden when rescue medication was NOT given', () {
      expect(rescueChildrenVisible(rec(given: false)), isFalse);
    });

    test('3. shown when it WAS given', () {
      expect(rescueChildrenVisible(rec(given: true)), isTrue);
    });
  });

  group('THE EXCEPTION: a stored value is never hidden', () {
    test('4. a child with a NO parent still renders', () {
      // The inconsistent state. It cannot be created by this app - the UI
      // clears the children when the parent goes to no - but it can arrive from
      // a restored backup written by another version, or a hand-edited file.
      expect(rescueChildrenVisible(rec(given: false, helped: RescueResponse.helped)),
          isTrue);
    });

    test('5. a child with a NULL parent still renders', () {
      expect(rescueChildrenVisible(rec(second: true)), isTrue);
    });

    test('6. NEGATIVE CONTROL: the naive gate would hide both', () {
      // Tests 4 and 5 pass against any function that returns true often
      // enough. This is the implementation they exist to rule out - the
      // obvious one - and it differs from the real gate on exactly the records
      // that matter.
      bool naive(EventRecord r) => r.rescueMedGiven == true;

      final orphanChild = rec(given: false, helped: RescueResponse.helped);
      final orphanSecond = rec(second: true);

      expect(naive(orphanChild), isFalse);
      expect(naive(orphanSecond), isFalse);
      expect(rescueChildrenVisible(orphanChild), isTrue);
      expect(rescueChildrenVisible(orphanSecond), isTrue);

      // And they agree everywhere else, so the difference is confined to the
      // case being defended rather than being a wholesale change.
      for (final r in <EventRecord>[rec(), rec(given: false), rec(given: true)]) {
        expect(naive(r), rescueChildrenVisible(r));
      }
    });
  });

  group('THE EXPORT CARRIES WHAT IS STORED, NOT WHAT THE SCREEN SHOWS', () {
    test('7. seventeen columns, the three sitting before referral', () {
      final h = header(buildCsv(<EventRecord>[rec()]));
      // 17 since `condition` landed. See csv_delimited_test's golden.
      expect(h.length, 17);
      // 11..13 since `condition` landed at index 4 and pushed
      // everything after it right by one.
      expect(h.sublist(11, 14), <String>[
        'rescue_med_given',
        'rescue_med_helped',
        'rescue_med_second_dose',
      ]);
      expect(h[14], 'referral_required');
    });

    test('8. unanswered exports BLANK, not "unknown"', () {
      // Different from severity deliberately. These are asked of almost no
      // event, so a column of the word "unknown" would be noise standing in for
      // a question that was never applicable.
      final c = cells(buildCsv(<EventRecord>[rec()]));
      expect(c.sublist(11, 14), <String>['', '', '']);
    });

    test('9. an inconsistent record exports its children anyway', () {
      // THE POINT OF THE WHOLE FILE. The screen would show these; so does the
      // file. If the two ever disagree, the file is the one a clinician reads.
      final c = cells(buildCsv(<EventRecord>[
        rec(given: false, helped: RescueResponse.partly, second: true)
      ]));
      expect(c.sublist(11, 14), <String>['No', 'Partly', 'Yes']);
    });

    test('10. and the three response values render as words', () {
      expect(rescueResponseCsv(RescueResponse.helped), 'Yes');
      expect(rescueResponseCsv(RescueResponse.partly), 'Partly');
      expect(rescueResponseCsv(RescueResponse.didNotHelp), 'No');
      expect(rescueResponseCsv(null), '');
    });
  });

  group('THE SHAPE MARKER TRACKS THE HEADER ROW', () {
    test('11. the filename says the current marker', () {
      expect(csvFilename(when: DateTime(2026, 8, 27, 15, 45, 0)),
          'medical_event_recorder_20260827_154500.$kCsvShapeVersion.csv');
    });

    test('12. and the constant matches the columns it describes', () {
      // The rule is mechanical: any change to the column set bumps the marker.
      // This is what makes that checkable rather than remembered - if someone
      // adds a column without bumping, the count here stops matching.
      // v5 since the CONDITION column landed, not because of this pass.
      expect(kCsvShapeVersion, 'v5');
      expect(header(buildCsv(<EventRecord>[rec()])).length, 17,
          reason: 'the marker is DEFINED as this header. Changing one without '
              'the other is the drift the rule exists to prevent');
    });
  });

  group('IT SURVIVES A ROUND TRIP, AND ABSENCE STAYS ABSENT', () {
    test('13. through the backup envelope', () {
      final r = rec(given: true, helped: RescueResponse.partly, second: false);
      final back = EventRecord.fromMap(r.toMap())!;

      expect(back.rescueMedGiven, isTrue);
      expect(back.rescueMedHelped, RescueResponse.partly);
      expect(back.rescueMedSecondDose, isFalse,
          reason: 'FALSE, not null — "no second dose" is an answer');
    });

    test('14. a payload predating the fields reads NULL, never false', () {
      // Every record on the device today. A false negative about rescue
      // medication is a clinical claim nobody made.
      final old = <String, dynamic>{
        'id': 'legacy',
        'timestamp': '2026-08-22T17:00:00.000',
        'duration': 'lt1',
        'feelings': <String>[],
        'referralRequired': false,
        'notes': '',
        'eventType': 'seizure',
        'severity': 'mild',
        'triggers': <String>[],
      };
      final back = EventRecord.fromMap(old)!;

      expect(back.rescueMedGiven, isNull);
      expect(back.rescueMedHelped, isNull);
      expect(back.rescueMedSecondDose, isNull);
      expect(back.severity, EventSeverity.mild,
          reason: 'positive control: the rest of the record still parses');
    });

    test('15. and a real backup file round-trips them', () {
      final json = buildBackupJson(<EventRecord>[
        rec(given: true, helped: RescueResponse.didNotHelp, second: true)
      ]);
      final parsed = parseBackup(json);

      expect(parsed.isValid, isTrue,
          reason: 'the envelope and its gates are unchanged by three new keys');
      expect(parsed.records.single.rescueMedHelped, RescueResponse.didNotHelp);
      expect(parsed.records.single.rescueMedSecondDose, isTrue);
    });
  });

  group('COMPLETENESS IS UNAFFECTED', () {
    testWidgets('16. rescue fields do NOT make a record incomplete',
        (tester) async {
      // If they joined `isIncomplete`, every record ever taken would become
      // incomplete overnight and the Needs-details queue would fill with 71
      // rows. They are optional questions, not missing answers.
      expect(isIncomplete(rec()), isFalse);
      expect(missingFields(rec()), isEmpty);
    });
  });

  group('THE WIZARD CLEARS THE CHILDREN', () {
    testWidgets('17. answering NO removes them from the screen',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        home: EventWizardScreen(
          existing: rec(given: true, helped: RescueResponse.helped),
        ),
      ));
      await tester.pumpAndSettle();

      // The record is complete, so `firstUnansweredStep` opens the wizard at
      // the beforehand step; one Next reaches the afterwards step that carries
      // this section. Navigated rather than jumped, because "Skip to end"
      // lands on the summary and the summary is not what is under test.
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Did it help?'), findsOneWidget,
          reason: 'precondition: the children are showing');

      // The NO chip under "Rescue medication given?".
      final noChip = find.descendant(
        of: find.byType(Wrap),
        matching: find.text('No'),
      );
      await tester.tap(noChip.first);
      await tester.pumpAndSettle();

      expect(find.text('Did it help?'), findsNothing);
      expect(find.text('Was a second dose needed?'), findsNothing);
    });
  });
}
