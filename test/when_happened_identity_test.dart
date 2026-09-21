// Brief 74 · test 3 — THE IDENTITY TEST.
//
// ⭐ This is the one worth writing. Every other test here asks WHAT TIME a
// record shows; this asks WHICH RECORD is shown. A wrong time reads as a bug.
// A record that appears to change identity reads as lost data.
//
// ⛔ It would have caught the whole cluster on 12 September, and nothing that
// existed then could have: the pass that day inspected one getter, and no test
// compared the two screens' notion of "latest" against each other.
//
// One prefs-dependent test in this file, per CLAUDE.md.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/history_screen.dart';
import 'package:medical_event_recorder/screens/home_screen.dart';

import 'when_happened_fixture.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'disclaimerAcceptedVersion': kDisclaimerVersion,
      kWalkthroughSeenVersionKey: kWalkthroughVersion,
      // Seeded in the order that makes `timestamp` sorting look plausible.
      kEventStorageKey: jsonFor([kEarlyLogged, kLateLogged]),
    });
    StorageBoot.debugSet();
    Vocabularies.debugReset();
  });
  tearDown(() {
    StorageBoot.debugSet();
    Vocabularies.debugReset();
  });

  testWidgets('home and history agree on WHICH record is the latest',
      (tester) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(375 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3.0;

    // CONTROL on the fixture: the two clocks must DISAGREE about the order, or
    // this test cannot tell a right answer from a lucky one.
    final byTimestamp = [kEarlyLogged, kLateLogged]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final byHappened = [kEarlyLogged, kLateLogged]
      ..sort((a, b) => b.whenHappened.compareTo(a.whenHappened));
    expect(byTimestamp.first.id, isNot(byHappened.first.id),
        reason: 'CONTROL: the fixture must be an INVERTED pair — one logged '
                'later but occurring earlier. If both clocks agree, this test '
                'passes against the defect too and proves nothing.');
    expect(byHappened.first.id, kEarlyLogged.id,
        reason: 'CONTROL: the correct answer is the early-LOGGED record, '
                'because it is the late-OCCURRING one.');

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text('LAST EVENT'), findsOneWidget,
        reason: 'CONTROL: the seeded records did not reach home.');

    // Home's answer: the date the LAST EVENT card prints.
    final homeShows = find
        .text('20 Sep 2026  ·  14:30')   // kEarlyLogged.occurredAt
        .evaluate()
        .isNotEmpty;
    expect(homeShows, isTrue,
        reason: 'TEST 3: home\'s LAST EVENT must be the record that HAPPENED '
                'most recently (${kEarlyLogged.id}, occurred 20 Sep). Showing '
                '${kLateLogged.id} instead means home ranked by the write '
                'clock, and the two screens then name different records as '
                '"the latest" with nothing reconciling them.');

    // History's answer, from the same seed, on its own screen.
    await tester.pumpWidget(MaterialApp(
      home: HistoryScreen(
        records: [kEarlyLogged, kLateLogged],
        onRecordsChanged: (_) async {},
        onEdit: (EventRecord r, {required bool confirmOnSave}) async {},
      ),
    ));
    await tester.pumpAndSettle();

    // The top row is the one with the smallest y among the rendered dates.
    double? yOf(String s) {
      final f = find.text(s);
      return f.evaluate().isEmpty ? null : tester.getTopLeft(f.first).dy;
    }
    // ⚠️ ASSERTED ON THE TIMES, NOT THE DAY HEADERS. History renders relative
    // headers — the late-occurring record currently groups under "YESTERDAY" —
    // and a test keyed on that passes today and fails tomorrow for a reason
    // that has nothing to do with the defect. The times do not move.
    final yEarly = yOf('2:30 PM');   // kEarlyLogged  — occurred 20 Sep 14:30
    final yLate = yOf('8:15 AM');    // kLateLogged   — occurred  2 Sep 08:15

    expect(yEarly, isNotNull,
        reason: 'CONTROL: history did not render the late-occurring record.');
    expect(yLate, isNotNull,
        reason: 'CONTROL: history did not render the early-occurring record.');

    expect(yEarly! < yLate!, isTrue,
        reason: 'TEST 3: history must ALSO rank ${kEarlyLogged.id} first, and '
                'home must agree with it. Both screens agreeing is the '
                'assertion; a shared wrong answer would be a different defect, '
                'not this one.');
  });
}
