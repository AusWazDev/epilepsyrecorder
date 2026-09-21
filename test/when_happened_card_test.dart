// Brief 74 · tests 1 and 2 — the LAST EVENT card's time, and Days since.
//
// ⛔ ONE PREFS-DEPENDENT TEST IN THIS FILE, per CLAUDE.md. `setMockInitialValues`
// does not take effect once an instance exists earlier in the same PROCESS, and
// a Dart test file is one process — so a second prefs-dependent test here would
// silently read this one's state. That rule cost three files to learn.
//
// Both assertions live in one test for that reason, and each carries its own
// `reason:` so a control that breaks one is attributable to it.

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
      kEventStorageKey: jsonFor([kBackdated]),
    });
    StorageBoot.debugSet();
    Vocabularies.debugReset();
  });
  tearDown(() {
    StorageBoot.debugSet();
    Vocabularies.debugReset();
  });

  testWidgets('the card shows when it HAPPENED, and Days since counts from it',
      (tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(375 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3.0;
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    // CONTROL on the harness: the record must actually have loaded, or both
    // assertions below are vacuous over an empty screen.
    expect(find.text('LAST EVENT'), findsOneWidget,
        reason: 'CONTROL: the seeded record did not reach the home screen, so '
                'nothing below is testing anything.');

    // ── 1 · the rendered time ────────────────────────────────────────────
    // occurredAt = 11 Sep 2026 22:17   timestamp = 20 Sep 2026 22:17
    expect(find.text('11 Sep 2026  ·  22:17'), findsOneWidget,
        reason: 'TEST 1: the LAST EVENT card must render `whenHappened`. '
                'Finding "20 Sep 2026  ·  22:17" instead means it is printing '
                'the logging clock — the time the user typed it, not the time '
                'they said it happened.');
    expect(find.text('20 Sep 2026  ·  22:17'), findsNothing,
        reason: 'TEST 1: the logging time must not appear on this card at all.');

    // ── 2 · Days since ───────────────────────────────────────────────────
    // Counted from occurredAt (11 Sep), not timestamp (20 Sep). The exact
    // number moves with the clock, so the ASSERTION IS THE DIFFERENCE between
    // the two readings, which is fixed at 9 days and cannot drift.
    final fromOccurred = DateTime.now().difference(kBackdated.occurredAt!).inDays;
    final fromLogged = DateTime.now().difference(kBackdated.timestamp).inDays;
    expect(fromOccurred - fromLogged, 9,
        reason: 'CONTROL on the fixture: the two clocks must be 9 days apart, '
                'or the assertion below cannot discriminate.');
    expect(find.text('$fromOccurred'), findsWidgets,
        reason: 'TEST 2: Days since must count from `whenHappened`. Rendering '
                '$fromLogged instead means a seizure backdated nine days reads '
                'as "Days since 0" on the day it was typed.');
  });
}
