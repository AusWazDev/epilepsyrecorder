import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/log_event_screen.dart';

import 'semantics_names.dart';

/// AUDIT.md §13(z), control 4 of 5 — the form's back arrow announced nothing.
///
/// ⭐ "Back" and not "Cancel" or "Discard": since §13(a)'s fix it PROMPTS when
/// the form is dirty and leaves silently when it is clean, so it reliably does
/// neither of those. Same string as the wizard's, which is the point — the two
/// edit paths agree.
///
/// ⛔ ONE SCREEN, ONE TEST. This control reported SILENT as the third pump of a
/// multi-screen test and `[Back]` when pumped alone. See `semantics_names.dart`.
///
/// ⚠️ No prefs here, so the one-prefs-test-per-process rule does not apply.

EventRecord record() => EventRecord(
      id: 'f1',
      timestamp: DateTime(2026, 8, 20, 9, 0),
      duration: DurationCategory.oneToFive,
      durationSeconds: 90,
      eventType: 'seizure',
      severity: EventSeverity.mild,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: false,
      notes: '',
      detailsCompleted: true,
    );

void main() {
  setUp(Vocabularies.debugReset);
  tearDown(Vocabularies.debugReset);

  testWidgets('form back announces "Back", and nothing moved', (tester) async {
    final handle = tester.ensureSemantics();
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(430, 1200);

    await tester.pumpWidget(
        MaterialApp(home: LogEventScreen(existing: record(), confirmOnSave: true)));
    await tester.pumpAndSettle();

    final names = announcedNames(tester);
    // ignore: avoid_print
    print('  form: "Back" announced = ${names.contains('Back')}');
    expect(names, contains('Back'),
        reason: 'the form back arrow must announce a name');

    // ⛔ BASELINE CAPTURED FROM UNPATCHED CODE.
    expect(iconRects(tester, const [Icons.arrow_back]),
        <String>['16.0,16.0 24.0x24.0'],
        reason: 'adding a tooltip must not move the icon');

    handle.dispose();
  });
}
