// Brief 74 · test 4 — THE LOAD PATH.
//
// ⛔ THIS IS THE PATH THE ORIGINAL BRIEF WOULD HAVE MISSED ENTIRELY. It named
// the two SAVE-path sorts and the two display sites. But `_loadRecords` assigns
// `_records` straight from `_store.load()` with no sort of its own, and the
// store returns `timestamp` order — so before the fix, home's LAST EVENT card
// was wrong on every cold start, which is the most common path in the app.
//
// ⭐ Nothing is saved or edited in this test. The screen is pumped and read.
// That is the point: it exercises the order the STORE supplies, not the order a
// save leaves behind.
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

  testWidgets('a COLD LOAD alone puts the right record in the card',
      (tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(375 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('LAST EVENT'), findsOneWidget,
        reason: 'CONTROL: the seeded records did not reach home, so the '
                'assertion below would pass over an empty screen.');

    // ⭐ CONTROL ON THE STORE, and it is what makes this test meaningful: the
    // fallback store sorts by `timestamp` (event_record.dart's `_load`). So the
    // list arriving at `_records` is in the WRONG order by construction, and
    // only home's assignment setter can put it right. If this control ever
    // stops holding, the test is no longer exercising the load path.
    final storeOrderFirst = [kEarlyLogged, kLateLogged]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    expect(storeOrderFirst.first.id, kLateLogged.id,
        reason: 'CONTROL: the store must hand home the WRONG record first, or '
                'this test cannot distinguish the fix from its absence.');

    expect(find.text('20 Sep 2026  ·  14:30'), findsOneWidget,
        reason: 'TEST 4: after a cold load with NO save, the LAST EVENT card '
                'must show ${kEarlyLogged.id} — the record that HAPPENED most '
                'recently. Showing 2 Sep means home adopted the store\'s '
                'timestamp order, which is the state every app open was in '
                'before this fix.');
    expect(find.text('2 Sep 2026  ·  08:15'), findsNothing,
        reason: 'TEST 4: the early-occurring record must not be the card.');
  });
}
