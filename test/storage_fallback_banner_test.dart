import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/main.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/storage_migration.dart';

/// The storage-fallback banner — the one surface that tells a user their
/// history may be incomplete.
///
/// ## ⛔ WHY THIS FILE EXISTS
///
/// Until 7 September 2026 `StorageBoot.init()` could fall back to the
/// shared_preferences store and **nothing in `lib/` read the outcome** — not
/// `StorageBoot.outcome`, not `StorageBoot.isSqlite`, zero readers. The only
/// signal left the device to Sentry, so the person holding the phone saw a
/// working app with a short history and no explanation. Measured on a real
/// device that day: **42 of 58 records visible, 16 invisible.**
///
/// ## ⚠️ AND THE SEAM THAT MADE THIS UNTESTABLE
///
/// `StorageBoot.debugSet` accepted `MigrationOutcome? result` and **never
/// assigned it**, so no test could install a fallback state at all. Fixed in
/// the same pass. Any test written against the old seam would have passed
/// while exercising nothing — which is why the negative controls below matter
/// more than the positive case.

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 100),
  int maxTries = 60,
}) async {
  for (var i = 0; i < maxTries; i++) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return;
  }
}

/// A fallback outcome, exactly the shape `StorageBoot.init()` builds on the
/// observed failure: it threw before reading anything, so `sourceEntries` is 0.
MigrationOutcome failed() => const MigrationOutcome(
      state: MigrationState.error,
      sourceEntries: 0,
      loadableCount: 0,
      insertedCount: 0,
      distinctIds: 0,
      absentCounts: <String, int>{},
      error: "dlopen failed: have 'iOS-simulator', need 'iOS'",
    );

MigrationOutcome succeeded() => const MigrationOutcome(
      state: MigrationState.migrated,
      sourceEntries: 58,
      loadableCount: 58,
      insertedCount: 58,
      distinctIds: 58,
      absentCounts: <String, int>{},
    );

/// The banner's first line. Asserted as copy, deliberately: this is medical
/// safety wording and a paraphrase is a different claim.
const String kTitle = 'This launch could not open its stored records.';

void main() {
  setUp(() {
    // Both gates, or the app lands on the disclaimer or the walkthrough rather
    // than Home — see app_smoke_test for the full history of that trap.
    SharedPreferences.setMockInitialValues({
      'disclaimerAcceptedVersion': kDisclaimerVersion,
      kWalkthroughSeenVersionKey: kWalkthroughVersion,
    });
    StorageBoot.debugSet();
  });

  tearDown(() => StorageBoot.debugSet());

  testWidgets('1. a FAILED outcome renders the banner on Home, at 430 wide',
      (tester) async {
    StorageBoot.debugSet(result: failed());

    // ⚠️ 430x932 SPECIFICALLY, not the default 800x600 test view.
    //
    // A DEVICE RENDER OF THIS BANNER COULD NOT BE OBTAINED on 7 Sep 2026: the
    // tablet's display override refused to leave landscape across six attempts
    // (`base=430x932` while `cur=932x430` at ROTATION_90), and `screencap` then
    // returned a black frame from behind the keyguard.
    //
    // This sizing is the honest partial substitute. It does NOT show what the
    // banner looks like — that verification is still outstanding — but it does
    // exercise the one failure a phone-width render would have caught, which is
    // the three-line body overflowing its container.
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const AppBootstrap());
    await pumpUntilFound(tester, find.text('Record Event'));

    expect(find.text(kTitle), findsOneWidget,
        reason: 'the only user-facing signal that the history may be short');
    // ⛔ THE TWO LOAD-BEARING CLAUSES, ASSERTED SEPARATELY.
    //
    // ⚠️ This finder previously read 'Nothing has been deleted.' with a full
    // stop, and it FAILED when the body was revised on 7 Sep 2026 — which is
    // the test doing its job, not a breakage. The revision is recorded on
    // _StorageFallbackBanner: the old wording said the history "may look
    // shorter than it is", which is false on a post-migration fallback where
    // the list is empty and Total saved reads 0.
    expect(
      find.textContaining('not showing, or is showing only partly'),
      findsOneWidget,
      reason: 'covers BOTH fallback states — partial before the migration '
          'completed, empty after it — without asserting which one this is',
    );
    expect(
      find.textContaining('the records are still on this device'),
      findsOneWidget,
      reason: 'the "does not say lost" guarantee: pre-migration they are in '
          'epilepsy_event_records_v1, post-migration in the SQLite store, '
          'untouched and merely unopened',
    );

    // ⛔ NO OVERFLOW AT PHONE WIDTH. Flutter surfaces a RenderFlex overflow as
    // an exception during pump, so this fails loudly rather than rendering a
    // yellow-and-black stripe nobody looks at.
    expect(tester.takeException(), isNull,
        reason: 'the three-line body must fit its container at 430 wide');
  });

  testWidgets('2. ⛔ NEGATIVE CONTROL: a SUCCEEDED outcome renders nothing',
      (tester) async {
    // Without this, test 1 passes against a banner that is always shown.
    StorageBoot.debugSet(result: succeeded());

    await tester.pumpWidget(const AppBootstrap());
    await pumpUntilFound(tester, find.text('Record Event'));

    expect(find.text(kTitle), findsNothing);
  });

  testWidgets(
      '3. ⛔ NEGATIVE CONTROL: a NULL outcome renders nothing, so every other '
      'screen test is unaffected', (tester) async {
    // `outcome` is null whenever `init()` never ran, which is every widget test
    // in this suite. If null were treated as a fallback, this banner would
    // appear in all of them.
    StorageBoot.debugSet();
    expect(StorageBoot.outcome, isNull);

    await tester.pumpWidget(const AppBootstrap());
    await pumpUntilFound(tester, find.text('Record Event'));

    expect(find.text(kTitle), findsNothing);
  });

  test('4. the seam actually installs the outcome it is given', () {
    // ⛔ THE SEAM ITSELF, PINNED. `debugSet` accepted `result` and dropped it
    // until 7 Sep 2026, so tests 1 to 3 would all have passed against a seam
    // that did nothing — test 1 by never showing the banner and being wrong
    // about why, tests 2 and 3 by accident.
    StorageBoot.debugSet(result: failed());
    expect(StorageBoot.outcome, isNotNull);
    expect(StorageBoot.outcome!.succeeded, isFalse);

    StorageBoot.debugSet(result: succeeded());
    expect(StorageBoot.outcome!.succeeded, isTrue);

    StorageBoot.debugSet();
    expect(StorageBoot.outcome, isNull);
  });
}
