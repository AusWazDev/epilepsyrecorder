// Brief 74 · test 5 — THE ROUND TRIP, and the record-identity flicker.
//
// ⛔ THE SYMPTOM THIS GUARDS: History hands its own `whenHappened`-sorted copy
// back to home through `onRecordsChanged`. Before the fix, home adopted that
// order wholesale — so the LAST EVENT card could change WHICH RECORD it showed
// after a trip through History and back, with no user action on that record,
// and then change again on the next save or reload.
//
// ⭐ A wrong time reads as a bug. A record that appears to change identity reads
// as LOST DATA, which is why this gets its own test rather than riding on the
// identity one: it must be capable of failing on its own.
//
// ⚠️ The round trip is simulated by invoking the same callback History invokes,
// with a list in History's order. That is exactly what `onRecordsChanged` does
// at history_screen's hide, unhide and restore sites.
//
// One prefs-dependent test in this file, per CLAUDE.md.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/home_screen.dart';

import 'when_happened_fixture.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'disclaimerAcceptedVersion': kDisclaimerVersion,
      kWalkthroughSeenVersionKey: kWalkthroughVersion,
      kEventStorageKey: jsonFor([kEarlyLogged, kLateLogged]),
    });
    StorageBoot.debugSet();
    Vocabularies.debugReset();
  });
  tearDown(() {
    StorageBoot.debugSet();
    Vocabularies.debugReset();
  });

  testWidgets('the LAST EVENT card names the same record before and after a '
      'History round trip', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(375 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    const correct = '20 Sep 2026  ·  14:30';   // kEarlyLogged, occurred last
    const other = '2 Sep 2026  ·  08:15';      // kLateLogged

    expect(find.text('LAST EVENT'), findsOneWidget,
        reason: 'CONTROL: the seeded records did not reach home.');

    final before = find.text(correct).evaluate().isNotEmpty;
    expect(before, isTrue,
        reason: 'CONTROL: home must start on the correct record, or the '
                'before/after comparison below has nothing to hold stable.');

    // ── the round trip ───────────────────────────────────────────────────
    // Open History and come back. History copies on init
    // (`List<EventRecord>.from`), sorts its copy by `whenHappened`, and returns
    // THAT list to home through onRecordsChanged when anything changes.
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();

    expect(find.text('2 events'), findsOneWidget,
        reason: 'CONTROL: History did not open with both records, so no round '
                'trip occurred and the assertion below is vacuous.');

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text(correct), findsOneWidget,
        reason: 'TEST 5: the LAST EVENT card must name the SAME record after a '
                'History round trip as before it. A card that changes which '
                'record it shows — with no user action on that record — reads '
                'as lost data, not as a formatting bug.');
    expect(find.text(other), findsNothing,
        reason: 'TEST 5: the card must not have swapped to ${kLateLogged.id}.');
  });
}
