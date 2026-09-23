// Brief 135R · THE SHARED CONTRACT, in one place, run against each store.
//
// ⛔ WHY THIS IS A SUPPORT FILE AND NOT A PARAMETERISED TEST. The two cases
// both depend on SharedPreferences, and CLAUDE.md's standing rule is ONE
// prefs-dependent TEST per PROCESS — a Dart test FILE is one process, and the
// plugin caches its instance for the life of it. Two cases in one file is the
// documented harness fault, not a style choice.
//
// ⚠️ AND IT IS NOT HYPOTHETICAL HERE. Run together, the second case hung for
// its full 45-second timeout, localised by marker to `SqliteEventStore.save` —
// the one call in its setup that goes through `EventStore.serialise`, the
// STATIC queue shared by both stores. The first case's last save ran inside a
// `testWidgets` fake-async zone; when that test ended its continuation was
// stranded, so the tail of the static queue never completed and every later
// `serialise` waited on it forever. ⛔ SEPARATE PROCESSES, SEPARATE STATICS.
//
// ⭐ THE ASSERTION LIVES HERE SO IT CANNOT DIVERGE. Per-store setup differs —
// how the store is installed, how its storage is read back — and that is the
// only thing allowed to. The two `save` implementations reach this contract by
// DIFFERENT mechanisms (SQLite by rowid, prefs by an id set), which is exactly
// why both are pinned rather than one.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/capture_instruction.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/home_screen.dart';

EventRecord rec(String id, int day) => EventRecord(
      id: id,
      timestamp: DateTime(2026, 9, day),
      duration: DurationCategory.lt1,
      durationSeconds: 40,
      eventType: 'seizure',
      severity: EventSeverity.mild,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: false,
      notes: '',
      detailsCompleted: true,
    );

/// The two records both stores start from.
final List<EventRecord> kSeed = [rec('alpha', 1), rec('beta', 2)];

String jsonFor(List<EventRecord> rs) =>
    jsonEncode(rs.map((e) => e.toMap()).toList());

/// Called ONCE per process, before anything touches SharedPreferences.
void seedPrefs() {
  SharedPreferences.setMockInitialValues({
    'disclaimerAcceptedVersion': kDisclaimerVersion,
    kWalkthroughSeenVersionKey: kWalkthroughVersion,
    kEventStorageKey: jsonFor(kSeed),
  });
}

/// One store case: how to install it, how to read its storage back, and how to
/// let it go.
class StoreCase {
  const StoreCase(this.name, this.install, this.storedIds, this.dispose);
  final String name;
  final Future<void> Function() install;
  final Future<List<String>> Function() storedIds;
  final Future<void> Function() dispose;
}

/// Declares the contract for one store.
///
/// ⛔ WHAT THIS PROVES, and it is a CONTRACT not an implementation: a user
/// action in History that changes ONE record must not be capable of removing a
/// record History never knew about. Dated 23 September 2026.
///
/// THE LIFECYCLE IS DRIVEN, NOT SIMULATED. The new record arrives through the
/// REAL path: an inbox instruction is written, and a REAL resume
/// (`handleAppLifecycleStateChanged`) drives `_handleResume` -> `_loadRecords`
/// -> the drain. `_records` is never poked.
///
/// ⛔ WHY THE REAL I/O IS NOT IN THE TEST BODY. A `testWidgets` body runs on a
/// FAKE CLOCK, and real I/O awaited inside one waits on a completion that clock
/// never delivers — see the standing rule in CLAUDE.md. Two consequences, and
/// BOTH are about WHEN code runs, never about WHAT is driven:
///   · store SETUP is in a per-test `setUp`, which runs on the real clock;
///   · storage READ-BACK goes through `tester.runAsync`, which lends the real
///     clock to one observation.
/// ⭐ The driving — pumpWidget, the drawer, the lifecycle resume, the hide tap
/// — runs inside the fake clock exactly as it always did.
///
/// ⚠️ `setUp`, not `setUpAll`: this test's whole subject is state that must not
/// travel between runs.
void registerClobberContract(StoreCase c) {
  group('[${c.name}]', () {
    // ── REAL CLOCK. Everything that does real I/O lives here. ────────────
    setUp(() async {
      Vocabularies.debugReset();
      await c.install();
    });

    tearDown(() async {
      await c.dispose();
      Vocabularies.debugReset();
    });

    testWidgets(
        'a whole-list write from History does not drop a record drained '
        'while History was open', (tester) async {
      // ⛔ BRIEF 138 · STANDING RULE: every reproduction carries an explicit
      // timeout, so a hang arrives as a FAILURE WITH A LOCATION rather than as
      // silence. It earned that on its first outing and again on its second.
      void mark(String step) => debugPrint('    >>> [${c.name}] $step');

      /// The one observation that needs the real clock, SHARED by both cases.
      /// ⭐ It reads storage. It drives nothing.
      Future<List<String>> ids() async => (await tester.runAsync(c.storedIds))!;

      mark('START');
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(375 * 3, 1600 * 3);
      tester.view.devicePixelRatio = 3.0;

      // ── 1 · HomeScreen with a known set ────────────────────────────────
      mark('1 store installed, about to pump');
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();

      expect(await ids(), containsAll(<String>['alpha', 'beta']),
          reason: '[${c.name}] CONTROL: the seeded records are not in this '
              'store, so every assertion below would pass over an empty '
              'corpus.');

      // ── 2 · History pushed, taking its snapshot ────────────────────────
      mark('2 home settled, opening drawer');
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.visibility_off_outlined), findsWidgets,
          reason: '[${c.name}] CONTROL: History did not open with hideable '
              'rows, so step 4 cannot drive the real control.');

      // ── 3 · A record arrives by the REAL resume/drain path ─────────────
      mark('3 History open, seeding inbox');
      final prefs = await tester.runAsync(SharedPreferences.getInstance);
      await tester.runAsync(() => writeStartInstruction(prefs!,
          id: 'gamma', at: DateTime(2026, 9, 23, 10)));
      mark('3b instruction written, driving RESUME');
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      // ⭐ POSITIVE CONTROL ON STEP 3. Without this the final assertion could
      // be vacuously green because nothing ever arrived.
      expect(await ids(), contains('gamma'),
          reason: '[${c.name}] POSITIVE CONTROL: the resume did not drain the '
              'inbox, so no record arrived while History was open and nothing '
              'below is testing the clobber.');

      // ── 4 · History writes its snapshot back, through the real control ──
      mark('4 drain asserted, tapping hide');
      await tester.tap(find.byIcon(Icons.visibility_off_outlined).first);
      await tester.pumpAndSettle();
      final confirm = find.widgetWithText(FilledButton, 'Hide');
      if (confirm.evaluate().isNotEmpty) {
        await tester.tap(confirm);
        await tester.pumpAndSettle();
      }

      // ── 5 · What is in STORAGE ─────────────────────────────────────────
      mark('5 hide written, reading storage');
      expect(await ids(), contains('gamma'),
          reason: '⛔ [${c.name}] THE CLOBBER. A record that arrived by the '
              'drain while History held an OLDER snapshot is gone from storage '
              'after History wrote that snapshot back. `save` must be '
              'add-or-update: removal is an operation (`clearAll`), never a '
              'side effect of a save.');

      // ⭐ THE FIX ITSELF, asserted in the same run: add-or-update must still
      // ADD. `gamma` was never in the snapshot History wrote, and the hide
      // must still have landed on `alpha`.
      expect(await ids(), containsAll(<String>['alpha', 'beta']),
          reason: '[${c.name}] the pre-existing records must survive too — a '
              'merge that kept only the new record would pass the assertion '
              'above and still be wrong.');
      mark('6 DONE');
    }, timeout: const Timeout(Duration(seconds: 45)));
  });
}
