import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/vocabulary.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/log_event_screen.dart';

/// ⛔ AN EDIT STAMPS `updatedAt` AND LEAVES `timestamp` ALONE — OBSERVED
/// THROUGH THE SCREEN, not asserted about a hand-built record.
///
/// ## ⚠️ WHY THIS FILE EXISTS AT ALL
///
/// `updated_at_test.dart`'s 2a states the same property, and it is NOT a
/// control for it: it builds both records by hand, so a substitution inside
/// `log_event_screen` leaves it green. Measured — stamping `timestamp` in the
/// screen was substituted and the whole existing suite still passed.
///
/// ⭐ **A property test is not a control for the code that is supposed to have
/// the property.** The record has to come back FROM the screen.
///
/// ## The claim
///
/// `log_event_screen.dart` preserves the original log time on edit —
/// `widget.existing?.timestamp ?? DateTime.now()` — and `ios_capture_bridge`
/// does the same. That is correct for a clinical record: "logged at" must not
/// drift. ⛔ **And it is exactly why `updatedAt` is needed**, because without
/// it nothing on a record says when it was last changed.

/// A complete record with a log time firmly in the past, so a screen that
/// overwrote it with `now` could not pass by coincidence.
final DateTime kLogged = DateTime(2026, 8, 1, 9, 15);

EventRecord editable() => EventRecord(
      id: 'edit-me',
      timestamp: kLogged,
      occurredAt: DateTime(2026, 7, 30, 20, 5),
      duration: DurationCategory.oneToFive,
      durationSeconds: 120,
      detailsCompleted: true,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: false,
      notes: 'before',
      eventType: kTypeSeizure,
      severity: EventSeverity.mild,
      updatedAt: kLogged,
    );

void main() {
  setUp(Vocabularies.debugReset);
  tearDown(Vocabularies.debugReset);

  testWidgets('an edit stamps updatedAt and does NOT move timestamp',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    EventRecord? returned;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              child: const Text('OPEN'),
              onPressed: () async {
                returned = await Navigator.of(context).push<EventRecord>(
                  MaterialPageRoute(
                    builder: (_) => LogEventScreen(
                      existing: editable(),
                      confirmOnSave: false,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();

    // A real edit: severity mild -> severe, which is unambiguous on this
    // record and is the same handle `log_event_exit_test` uses to dirty it.
    final severe = find.text(severityLabel(EventSeverity.severe));
    await tester.ensureVisible(severe);
    await tester.pumpAndSettle();
    await tester.tap(severe);
    await tester.pumpAndSettle();

    final save = find.text('Save changes');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(returned, isNotNull,
        reason: 'positive control: the screen handed a record back, so the '
            'assertions below are about what it produced');
    expect(returned!.severity, EventSeverity.severe,
        reason: 'positive control: the edit was actually applied');

    // ⛔ THE CLAIM.
    expect(returned!.timestamp, kLogged,
        reason: 'the LOG TIME must not drift on an edit. A clinical record\'s '
            '"logged at" is a fact about when it was written down, and an '
            'edit is not a new writing-down');
    expect(returned!.updatedAt, isNotNull,
        reason: 'and the edit must be recorded somewhere');
    expect(returned!.updatedAt!.isAfter(kLogged), isTrue,
        reason: 'updatedAt moved to the moment of the edit while timestamp '
            'stayed put — which is the whole point of having both');
  });
}
