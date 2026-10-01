// Brief 318 · the undo must still reach the store when HOME is gone too.
//
// ⛔ THE DEFECT. `_unhide` in History has guarded its own `setState` since
// 2985ea1, and then awaits `widget.onRecordsChanged`. The callback it awaits is
// HomeScreen's, built in `_openHistory`, and that one ran `setState` with no
// mounted check before `await _persist()`. So once Home has been torn down the
// Undo throws inside Home's callback, and the write after the throw never
// starts: the record stays hidden in storage. The same crash-plus-missed-undo
// that `undo_after_dispose_test.dart` pinned, one frame further up.
//
// ⛔ WHY A SECOND TEST AND NOT AN EDIT TO THAT ONE. Both existing Undo tests
// pump History on its own and STUB `onRecordsChanged` with a plain store save.
// That stub is exactly where this defect lives, so a test that stubs it cannot
// fail. This one pumps the real `HomeScreen`, opens History through Home's own
// "All history" control, and so drives the real callback.
//
// ⭐ BOTH HALVES ARE ASSERTED, for the reason the sibling test gives: a test
// asserting only "does not throw" would pass against a fix that returns early
// when unmounted, which skips the write just as completely.
//
// ⚠️ ONE PREFS-DEPENDENT TEST PER PROCESS, and `HomeScreen` reads prefs, so
// this file holds one test. Store setup is in `setUp` on the real clock; every
// storage read goes through `tester.runAsync`. See CLAUDE.md.

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({
    'disclaimerAcceptedVersion': kDisclaimerVersion,
    kWalkthroughSeenVersionKey: kWalkthroughVersion,
  });
  sqfliteFfiInit();
  // In-process: HomeScreen does its own database I/O inside `pumpWidget`, and
  // the fake clock cannot service an isolate's port messages.
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

  testWidgets('Undo after HomeScreen is disposed still unhides the record '
      'through Home\'s own callback, and does not throw', (tester) async {
    void mark(String step) => debugPrint('    >>> $step');
    mark('START');
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(375 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3.0;

    /// Hidden flags straight out of storage, by id. Real I/O, real clock.
    Future<Map<String, bool>> hiddenInStore() async =>
        (await tester.runAsync(() async {
          final rows = await db.query('event');
          return {
            for (final r in rows) '${r['id']}': (r['hidden'] as int? ?? 0) == 1,
          };
        }))!;

    /// Alternate real-clock and fake-clock turns until storage satisfies
    /// [done], or give up. There is no stub to count writes with here: the
    /// writer is Home's real `_persist`, so storage itself is the signal.
    Future<Map<String, bool>> settleStore(
        bool Function(Map<String, bool>) done) async {
      var now = await hiddenInStore();
      for (var i = 0; i < 200 && !done(now); i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
        now = await hiddenInStore();
      }
      return now;
    }

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    // HomeScreen's first load needs a moment of real time, or `_loadState`
    // never completes and `persistEvents` withholds every write (CLAUDE.md).
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    mark('1 Home pumped, reading initial store');
    expect(await hiddenInStore(), {'alpha': false, 'beta': false},
        reason: 'CONTROL: nothing may start hidden, or "it was unhidden" '
            'cannot be told from "it was never hidden".');

    // ── 1 · open the REAL History through Home's own control ──────────────
    final allHistory = find.text('All history');
    expect(allHistory, findsOneWidget,
        reason: 'CONTROL: Home did not render its History entry point.');
    await tester.ensureVisible(allHistory);
    await tester.tap(allHistory);
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget,
        reason: 'CONTROL: History is not open, so the callback under test '
            'was never handed to it.');

    // ── 2 · hide a record through its own control ─────────────────────────
    mark('2 hiding a record');
    final hideControl = find.byIcon(Icons.visibility_off_outlined);
    expect(hideControl, findsWidgets,
        reason: 'CONTROL: History did not render a hide control.');
    await tester.tap(hideControl.first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Hide'));
    // Not `pumpAndSettle`: the SnackBar's own dismissal timer would run out.
    await tester.pump();

    final afterHide =
        await settleStore((s) => s.values.where((h) => h).length == 1);
    expect(afterHide.values.where((h) => h).length, 1,
        reason: 'CONTROL: Home\'s real callback must have written exactly one '
            'hidden record to STORAGE before the undo, or the assertion '
            'after it is vacuous.');
    final hiddenId = afterHide.entries.firstWhere((e) => e.value).key;

    // ── 3 · capture the live Undo, then destroy Home and History ──────────
    await tester.pump(const Duration(milliseconds: 400));
    mark('3 capturing undo action');
    expect(find.byType(SnackBarAction), findsOneWidget,
        reason: 'CONTROL: the undo bar is not on screen.');
    final undo = tester.widget<SnackBarAction>(find.byType(SnackBarAction));
    expect(undo.label, 'Undo',
        reason: 'CONTROL: the captured action is not the Undo.');

    mark('4 tearing the tree down');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(find.byType(HomeScreen), findsNothing,
        reason: 'CONTROL: Home must really be gone, or this is testing the '
            'ordinary undo path.');
    expect(find.byType(HistoryScreen), findsNothing,
        reason: 'CONTROL: History must be gone too.');

    // ── 4 · press Undo with Home disposed ─────────────────────────────────
    mark('5 pressing undo with Home disposed');
    undo.onPressed();
    await tester.pump();

    mark('6 settling any write the undo started');
    // ⚠️ Not asserted to converge here: against the unfixed code the throw
    // comes BEFORE the write starts, so the loop runs out and the storage
    // assertion below names the defect rather than the harness.
    final afterUndo = await settleStore((s) => !s.values.any((h) => h));

    mark('6b checking for a throw');
    expect(tester.takeException(), isNull,
        reason: '⛔ THE CRASH. Home\'s `onRecordsChanged` called `setState` '
            'with no mounted check, which throws once HomeScreen is '
            'disposed.');

    expect(afterUndo, {'alpha': false, 'beta': false},
        reason: '⛔ AND THE MISSED UNDO. `$hiddenId` is still hidden in '
            'STORAGE. The throw in Home\'s callback came before '
            '`await _persist()`, so the unhide never reached the store.');
    mark('7 DONE');
  }, timeout: const Timeout(Duration(seconds: 90)));
}
