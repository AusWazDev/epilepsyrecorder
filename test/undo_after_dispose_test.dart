// Brief 132 D/E · the undo must still work when its screen is gone.
//
// ⛔ THE DEFECT. `_unhide` is reached from the Undo on the "Event hidden"
// SnackBar. The bar is shown through `ScaffoldMessenger`, which sits ABOVE the
// Navigator, so it outlives the screen that raised it and its Undo closure
// targets a `State` that may already be disposed. `_unhide` then called
// `setState` unconditionally, which throws after dispose — and the throw
// happened BEFORE `await widget.onRecordsChanged(...)`, so the record was
// never unhidden either. A crash AND a silently missed undo.
//
// ⚠️ NAVIGATION IS ALREADY COVERED AND THIS IS NOT THAT CASE. `build`'s
// `PopScope` closes the bar in `onPopInvokedWithResult`, so a user who taps
// back loses the bar with the screen. What that hook cannot see is a disposal
// that is NOT a pop — a tree teardown, a replaced route, a rebuilt Navigator.
// `dispose`'s own comment says so: *"the condition that matters is the user
// navigated away from History, not this State was disposed — a test tearing
// the tree down is not navigation."* ⭐ This test tears the tree down, which is
// precisely the uncovered half.
//
// ⛔ WHY NOT `if (!mounted) return;` AT THE TOP. That is the obvious fix and it
// is the wrong one: it makes the Undo silently do nothing, which is today's
// outcome minus the crash report. The contract is:
//     1. the in-memory correction happens
//     2. setState runs ONLY if mounted
//     3. the store write happens EITHER WAY
//
// ⭐ THIS TEST ASSERTS BOTH HALVES ON PURPOSE. A test asserting only "does not
// throw" would pass against the wrong fix above. The store assertion is what
// makes the difference visible.
//
// ⚠️ Store setup is in `setUp`, on the real clock, and storage read-back goes
// through `tester.runAsync` — a `testWidgets` body runs on a fake clock that
// never delivers real I/O completions. See CLAUDE.md.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/history_screen.dart';

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({
    'disclaimerAcceptedVersion': kDisclaimerVersion,
    kWalkthroughSeenVersionKey: kWalkthroughVersion,
  });
  sqfliteFfiInit();
  // In-process: the fake clock cannot service an isolate's port messages.
  databaseFactory = databaseFactoryFfiNoIsolate;

  late Database db;
  late SqliteEventStore store;
  final seed = [rec('alpha', 1), rec('beta', 2)];

  setUp(() async {
    Vocabularies.debugReset();
    db = await databaseFactory.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: kSqliteSchemaVersion,
          onCreate: (d, v) async => createSchema(d),
        ));
    await db.delete('event'); // shared per process
    store = SqliteEventStore(db);
    await store.save(seed);
    StorageBoot.debugSet(store: store, db: db);
  });

  tearDown(() async {
    await db.close();
    Vocabularies.debugReset();
  });

  testWidgets('Undo after the History State is disposed still unhides the '
      'record, and does not throw', (tester) async {
    // ⛔ STANDING RULE (CLAUDE.md): every reproduction carries an explicit
    // timeout and step markers, so a hang arrives as a located failure rather
    // than as silence. Added after this test hung for 400 s with no output.
    void mark(String step) => debugPrint('    >>> $step');
    mark('START');
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(375 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3.0;

    // How many store writes the screen has COMPLETED.
    //
    // ⚠️ TWO HARNESS TRAPS WERE HIT HERE IN SUCCESSION, and the second was
    // caused by the fix for the first. Recorded because the shape recurs.
    //
    //   1. READING TOO EARLY. A read taken straight after `pumpAndSettle` saw
    //      pre-write state: `onRecordsChanged` had ENTERED with the record
    //      correctly marked hidden, and its save returned only afterwards. The
    //      control failed "Expected: 1, Actual: 0", which reads exactly like
    //      "the hide did not work". ⭐ It had worked.
    //
    //   2. THEN AWAITING THE WRITE INSIDE `runAsync` — WHICH DEADLOCKS. The
    //      save is started from the FAKE-clock zone, so its continuations need
    //      the fake clock pumped. `runAsync` blocks the test in the REAL zone
    //      while it waits, so the future it awaits can never advance. The test
    //      hung with no output and the `Timeout` could not fire, because the
    //      clock that would fire it was the one being blocked.
    //
    // ⭐ SO NEITHER CLOCK ALONE IS ENOUGH: the underlying I/O needs real-clock
    // turns and the awaiting code needs fake-clock pumps, ALTERNATELY. That is
    // what `settleWrites` does, and it ASSERTS it got there rather than
    // trusting a fixed number of pumps.
    var writesDone = 0;

    Future<void> settleWrites(int target, String where) async {
      for (var i = 0; i < 200 && writesDone < target; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
      }
      expect(writesDone, greaterThanOrEqualTo(target),
          reason: 'HARNESS CONTROL ($where): the screen\'s store write never '
              'completed, so every storage assertion after this point would '
              'be reading stale rows and reporting them as a result.');
    }

    /// Hidden flags straight out of storage, by id. Real I/O, real clock.
    Future<Map<String, bool>> hiddenInStore() async =>
        (await tester.runAsync(() async {
          final rows = await db.query('event');
          return {
            for (final r in rows) '${r['id']}': (r['hidden'] as int? ?? 0) == 1,
          };
        }))!;

    final live = List<EventRecord>.of(seed);

    await tester.pumpWidget(MaterialApp(
      home: HistoryScreen(
        records: live,
        onRecordsChanged: (updated) async {
          await store.save(updated);
          writesDone++;
        },
        onEdit: (existing, {required confirmOnSave}) async {},
      ),
    ));
    await tester.pumpAndSettle();

    mark('1 pumped, reading initial store');
    expect(await hiddenInStore(), {'alpha': false, 'beta': false},
        reason: 'CONTROL: nothing may start hidden, or "it was unhidden" '
            'cannot be told from "it was never hidden".');

    // ── 1 · hide a record through its own control ─────────────────────────
    final hideControl = find.byIcon(Icons.visibility_off_outlined);
    expect(hideControl, findsWidgets,
        reason: 'CONTROL: History did not render a hide control, so the undo '
            'below has nothing to undo.');
    await tester.tap(hideControl.first);
    await tester.pumpAndSettle();
    // Hiding confirms — "Hide this event?" — and the confirm is what commits.
    final confirm = find.widgetWithText(FilledButton, 'Hide');
    if (confirm.evaluate().isNotEmpty) {
      await tester.tap(confirm);
      await tester.pumpAndSettle();
    }

    mark('2 hide confirmed, settling the write');
    await settleWrites(1, 'after the hide');
    final afterHide = await hiddenInStore();
    expect(afterHide.values.where((h) => h).length, 1,
        reason: 'CONTROL: exactly one record must be hidden in STORAGE before '
            'the undo, or the assertion after it is vacuous.');
    final hiddenId =
        afterHide.entries.firstWhere((e) => e.value).key;

    // ── 2 · capture the live Undo, then destroy the screen ────────────────
    // ⭐ The closure is taken BEFORE teardown because that is what the running
    // app holds: the SnackBar is owned by the ScaffoldMessenger, not by
    // History, and its action keeps working after History is gone.
    // ⚠️ NOT `pumpAndSettle` HERE. A SnackBar schedules its own dismissal, so
    // settling would advance the fake clock past the bar's display duration and
    // remove the very control this test needs. Pump just past the entrance
    // animation instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    mark('3 capturing undo action');
    expect(find.byType(SnackBarAction), findsOneWidget,
        reason: 'CONTROL: the undo bar is not on screen, so there is no live '
            'control to press after the teardown below.');
    final undo = tester.widget<SnackBarAction>(find.byType(SnackBarAction));
    expect(undo.label, 'Undo',
        reason: 'CONTROL: the captured action is not the Undo — pressing it '
            'below would prove nothing about the undo path.');

    // A teardown, NOT a pop. `PopScope` never fires, so the bar's closure
    // survives against a disposed State — the uncovered case.
    mark('4 tearing the tree down');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsNothing,
        reason: 'CONTROL: the screen must really be gone, or this is testing '
            'the ordinary undo path.');

    // ── 3 · press Undo on the disposed screen ─────────────────────────────
    mark('5 pressing undo on a disposed screen');
    undo.onPressed();
    await tester.pumpAndSettle();

    mark('6 undo pressed, settling any write it started');
    // ⚠️ NOT asserted to reach 2: against the UNFIXED code the throw happens
    // BEFORE the write is ever started, so demanding a second write here would
    // fail in the harness rather than at the assertion that names the defect.
    for (var i = 0; i < 200 && writesDone < 2; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    mark('6b checking for a throw');
    expect(tester.takeException(), isNull,
        reason: '⛔ THE CRASH. `_unhide` called `setState` unconditionally, '
            'which throws once the State is disposed. Reported from a real '
            'device as MEDICAL-EVENT-RECORDER-D.');

    expect(await hiddenInStore(), {'alpha': false, 'beta': false},
        reason: '⛔ AND THE HALF A `mounted` GUARD WOULD NOT FIX. `$hiddenId` '
            'is still hidden in STORAGE, so the undo did nothing. The throw '
            'happened BEFORE `await widget.onRecordsChanged(...)`, and an '
            '`if (!mounted) return;` at the top of `_unhide` would skip that '
            'write just as completely — today\'s outcome minus the crash '
            'report. The store write must happen whether or not the screen '
            'is still there.');
    mark('7 DONE');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
