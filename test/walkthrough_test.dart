import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/screens/walkthrough_screen.dart';

/// The first-run walkthrough. See `docs/WALKTHROUGH-SPEC.md`.
///
/// ## What is actually at risk here
///
/// Not the copy — the RULES. Four of them are load-bearing and each has a
/// failure mode that looks fine on a developer's device:
///
///  * **Not interactive.** An invitation to tap Record Event would create the
///    junk record the walkthrough exists to prevent — and a junk record is now
///    BLANK, so it is indistinguishable from a real deferred capture.
///  * **Nothing gated.** If the seen-flag were written on completion rather
///    than presentation, force-quitting on step 3 would re-show the walkthrough
///    on every launch until it was finished. That is a gate.
///  * **Independent of the disclaimer.** Sharing that signal would replay a
///    five-step introduction whenever `kDisclaimerVersion` is bumped.
///  * **Platform instructions are opposite and both correct.** The Android
///    build shipped the iOS wording until CR-43.

Future<void> pumpWalkthrough(WidgetTester tester, {bool markSeen = true}) async {
  tester.view.physicalSize = const Size(800, 1280);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (c) => Scaffold(
        body: Center(
          child: ElevatedButton(
            onPressed: () => Navigator.of(c).push(MaterialPageRoute(
              builder: (_) => WalkthroughScreen(markSeen: markSeen),
            )),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

/// Walks to the last page and returns how many pages there were.
Future<int> walkToEnd(WidgetTester tester) async {
  var pages = 1;
  while (find.text('Next').evaluate().isNotEmpty) {
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    pages++;
  }
  return pages;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  group('THE SHAPE', () {
    testWidgets('1. five steps, walked start to finish — four on Windows',
        (tester) async {
      // ⚠️ THE COUNT IS PLATFORM-DEPENDENT AND THAT IS THE RULE, not a
      // concession to the test host. Windows has no notification path
      // (`NotificationService.init()` returns at its first line), so step 2
      // would describe something absent and is dropped.
      //
      // Expressed as "skip step 2, the count follows" rather than a literal,
      // because the previous spec hardcoded "four steps become three" and that
      // stopped being true the moment a fifth step landed.
      final expected = Platform.isWindows ? 4 : 5;

      await pumpWalkthrough(tester);
      expect(find.text('Record an event the moment it happens'), findsOneWidget);

      final pages = await walkToEnd(tester);

      expect(pages, expected);
      expect(find.text('Finishing a record'), findsOneWidget);
      expect(find.text('Get started'), findsOneWidget,
          reason: 'the last page ends rather than continuing');
    });

    testWidgets('1a. and step 2 is present exactly when the platform has one',
        (tester) async {
      // The positive half of the rule. Without it, test 1 passes against a
      // build that dropped step 2 everywhere.
      await pumpWalkthrough(tester);
      var found = false;
      for (var i = 0; i < 5; i++) {
        if (find.text(kNotificationStepTitle).evaluate().isNotEmpty) {
          found = true;
        }
        if (find.text('Next').evaluate().isNotEmpty) {
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
        }
      }
      expect(found, !Platform.isWindows,
          reason: Platform.isWindows
              ? 'Windows has no notification path to describe'
              : 'the most important step is missing');
    });

    testWidgets('2. the steps are in the specced order', (tester) async {
      // Order is a decision, not an accident: step 4 is the data-safety step
      // and ending on it was deliberate, so the completion loop goes AFTER it
      // rather than being grouped with step 1 for tidiness.
      // ⚠️ MATCHED AGAINST THE KNOWN TITLES, not "the first Text longer than
      // twenty characters". That heuristic was the first version of this and it
      // silently picked a BODY PARAGRAPH on the last page, because "Finishing a
      // record" is eighteen characters. It reported the wrong string
      // confidently rather than failing — the plausible-output failure this
      // codebase keeps recording.
      const titles = <String>[
        'Record an event the moment it happens',
        kNotificationStepTitle,
        'Your history, and what to bring to an appointment',
        'It is on this device, and only here',
        'Finishing a record',
      ];

      await pumpWalkthrough(tester);
      final seen = <String>[];
      for (var i = 0; i < 6; i++) {
        for (final t in titles) {
          if (find.text(t).evaluate().isNotEmpty && !seen.contains(t)) {
            seen.add(t);
          }
        }
        if (find.text('Next').evaluate().isNotEmpty) {
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
        }
      }

      final expected = Platform.isWindows
          ? titles.where((t) => t != kNotificationStepTitle).toList()
          : titles;
      expect(seen, expected,
          reason: 'the completion loop closes the walkthrough, and step 4 — '
              'the data-safety step — keeps its place before it');
    });
  });

  group('NOT INTERACTIVE', () {
    testWidgets('3. no step invites the user to record anything',
        (tester) async {
      // THE RULE THAT PROTECTS THE DATA. A walkthrough that says "try tapping
      // Record Event" manufactures a fake seizure in a medical history.
      await pumpWalkthrough(tester);
      const forbidden = <String>[
        'try tapping',
        'Try tapping',
        'tap it now',
        'give it a go',
        'have a go',
      ];
      for (var i = 0; i < 5; i++) {
        final texts = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '')
            .join(' ');
        for (final phrase in forbidden) {
          expect(texts.contains(phrase), isFalse,
              reason: 'step ${i + 1} invites an action: "$phrase"');
        }
        if (find.text('Next').evaluate().isNotEmpty) {
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('4. and there is no button that records anything',
        (tester) async {
      // The stronger form of test 3: copy could avoid the phrase and still
      // ship a control. The only actions are navigation.
      await pumpWalkthrough(tester);
      expect(find.text('Record Event'), findsNothing,
          reason: 'the red button must be DESCRIBED, never present');
    });
  });

  group('SKIPPABLE AND UNGATED', () {
    testWidgets('5. Skip is present on step ONE', (tester) async {
      await pumpWalkthrough(tester);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('6. Skip is present on EVERY step, not just the first',
        (tester) async {
      // "Not buried, not on the last step" — so it must survive paging.
      await pumpWalkthrough(tester);
      for (var i = 0; i < 5; i++) {
        expect(find.text('Skip'), findsOneWidget, reason: 'step ${i + 1}');
        if (find.text('Next').evaluate().isNotEmpty) {
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
        }
      }
    });

    testWidgets('7. skipping from step one leaves a working app',
        (tester) async {
      await pumpWalkthrough(tester);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.text('open'), findsOneWidget,
          reason: 'back to what was underneath, not to a dead end');
    });

    testWidgets('8. Back appears from step two and NOT on step one',
        (tester) async {
      await pumpWalkthrough(tester);
      expect(find.text('Back'), findsNothing,
          reason: 'a disabled control on step one reads as a fault');
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Back'), findsOneWidget);
    });
  });

  group('THE SEEN FLAG', () {
    testWidgets('9. records the VERSION, on PRESENTATION not completion',
        (tester) async {
      // ⛔ THE UNGATED RULE, MEASURED. Written at the end instead, someone who
      // force-quits on step 3 meets the walkthrough again every launch until
      // they finish it.
      await pumpWalkthrough(tester);
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kWalkthroughSeenVersionKey), kWalkthroughVersion,
          reason: 'set on step ONE, before anything was completed');
      expect(await shouldShowWalkthrough(), isFalse);
    });

    testWidgets('10. a re-run does NOT write it', (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      await pumpWalkthrough(tester, markSeen: false);
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kWalkthroughSeenVersionKey), isNull);
      expect(await shouldShowWalkthrough(), isTrue,
          reason: 'still unseen - a replay is not a first run');
    });

    test('11. a stored version means seen', () async {
      SharedPreferences.setMockInitialValues(
          <String, Object>{kWalkthroughSeenVersionKey: kWalkthroughVersion});
      expect(await shouldShowWalkthrough(), isFalse);
    });

    test('12. ⛔ A DIFFERENT VERSION DOES NOT RE-SHOW IT', () async {
      // THE DECISION, PINNED. The version is stored so the option exists; the
      // trigger is "never seen", not "version differs". Someone who has used
      // MER for a year does not want a five-step tour because a step gained a
      // sentence.
      //
      // Changing this must be a deliberate decision with its own reasoning -
      // this test is what makes that a decision rather than a drift.
      SharedPreferences.setMockInitialValues(
          <String, Object>{kWalkthroughSeenVersionKey: '0-ancient'});
      expect(await shouldShowWalkthrough(), isFalse,
          reason: 'an OLD version is still a version that was seen');
    });

    test('13. NEGATIVE CONTROL: an EMPTY value is not "seen"', () async {
      // Test 12 passes against a gate that returns false unconditionally.
      // This is the case that must still show it.
      SharedPreferences.setMockInitialValues(
          <String, Object>{kWalkthroughSeenVersionKey: ''});
      expect(await shouldShowWalkthrough(), isTrue);

      SharedPreferences.setMockInitialValues(<String, Object>{});
      expect(await shouldShowWalkthrough(), isTrue,
          reason: 'absent, the genuine first run');
    });

    test('14. the LEGACY bool is honoured, and upgraded in place', () async {
      // Build 37 wrote a bool. Ignoring it would re-show the walkthrough to
      // someone who had already seen it - the one thing the flag exists to
      // prevent, reintroduced by the change that made the flag better.
      SharedPreferences.setMockInitialValues(
          <String, Object>{kWalkthroughSeenLegacyBoolKey: true});

      expect(await shouldShowWalkthrough(), isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kWalkthroughSeenVersionKey), kWalkthroughVersion,
          reason: 'upgraded in place, so the legacy read runs at most once');
    });

    test('15. and a legacy FALSE is not "seen"', () async {
      SharedPreferences.setMockInitialValues(
          <String, Object>{kWalkthroughSeenLegacyBoolKey: false});
      expect(await shouldShowWalkthrough(), isTrue);
    });

    test('16. INDEPENDENT of the disclaimer version', () async {
      // ⛔ The disclaimer gate IS a version comparison, so bumping
      // kDisclaimerVersion sends every user back through the disclaimer. A
      // shared signal would replay the walkthrough on every disclaimer change.
      SharedPreferences.setMockInitialValues(<String, Object>{
        kWalkthroughSeenVersionKey: kWalkthroughVersion,
        'disclaimerAcceptedVersion': '0.9-something-old',
      });
      expect(await shouldShowWalkthrough(), isFalse,
          reason: 'a stale disclaimer version must not resurrect it');
      expect(kWalkthroughSeenVersionKey, isNot('disclaimerAcceptedVersion'));
      expect(kWalkthroughVersion, isNot(kDisclaimerVersion),
          reason: 'two independent version lines, not one');
    });

    test('17. and it SURVIVES AN UPGRADE, because nothing re-shows it',
        () async {
      // SharedPreferences persists across app updates. What would lose it is a
      // KEY that changes with the app, or a trigger that compares versions.
      // Neither is the case.
      expect(kWalkthroughSeenVersionKey, 'walkthroughSeenVersion');
      SharedPreferences.setMockInitialValues(
          <String, Object>{kWalkthroughSeenVersionKey: kWalkthroughVersion});
      expect(await shouldShowWalkthrough(), isFalse);
    });
  });

  group('STEP 2: THE TWO INSTRUCTIONS ARE OPPOSITE AND BOTH CORRECT', () {
    // ⛔ TESTED AS A PURE FUNCTION OF THE PLATFORM, not by reading the screen.
    //
    // A test runs on ONE host — Windows here — so a screen-level assertion
    // exercises exactly one branch and the other is never checked by anybody's
    // machine. The branch that shipped wrong until CR-43 would be the branch
    // nobody tests. `notificationInstruction(isIOS:)` takes the platform as an
    // argument precisely so both can be.

    test('14. iOS needs the long-press; Android does not', () {
      final ios = notificationInstruction(isIOS: true);
      final android = notificationInstruction(isIOS: false);

      expect(ios, contains('long-press'));
      expect(android, isNot(contains('long-press')),
          reason: 'Android shows the action directly — this is the one that '
              'shipped wrong');
      expect(android, contains('find the MER notification'));
    });

    test('15. NEGATIVE CONTROL: they are not the same string', () {
      // The failure mode is UNIFICATION — one wording used for both. Test 14
      // would still pass if someone made both say "long-press".
      expect(notificationInstruction(isIOS: true),
          isNot(notificationInstruction(isIOS: false)));
    });

    test('16. both name the action button by its real label', () {
      for (final isIOS in <bool>[true, false]) {
        expect(notificationInstruction(isIOS: isIOS), contains('Log Event Now'),
            reason: 'the label on the notification, isIOS=$isIOS');
      }
    });

    test('17. the lead claims STARTING only, never ending', () {
      // Ending from a locked device works on Android and NOT on iOS, so one
      // shared lead cannot claim it. Help carries the iOS-only caveat.
      expect(kNotificationStepLead, contains('start an event'));
      expect(kNotificationStepLead, isNot(contains('end an event')));
      expect(kNotificationStepLead, isNot(contains('start and end')),
          reason: 'the exact wording the feasibility read found false on iOS');
    });
  });

  group('STEP 1 SAYS WHAT A QUICK RECORD IS', () {
    testWidgets('16. it states that nothing is guessed', (tester) async {
      // The promise changed when the fields became nullable: "add the details
      // later" went from a convenience to the ONLY way they get values.
      await pumpWalkthrough(tester);
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join(' ');
      expect(texts.contains('nothing guessed'), isTrue);
    });

    testWidgets('17. and no word implies the record is deficient',
        (tester) async {
      // Tapping a button during a seizure and filling the rest in afterwards
      // is the app working as intended, not a shortfall. This is the rule that
      // is easiest to break by accident while editing copy.
      await pumpWalkthrough(tester);
      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .join(' ')
          .toLowerCase();
      for (final word in <String>[
        'incomplete',
        'unfinished',
        'missing',
        'you should',
        'don\'t forget',
      ]) {
        expect(texts.contains(word), isFalse,
            reason: 'step 1 must describe the record, never judge it: "$word"');
      }
    });
  });
}
