import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/models/backup.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/screens/history_screen.dart';

/// ⛔ `AUDIT.md` §13(cj) FAILURE MODE (a) — **THE BIN EMPTYING ITSELF** — GUARDED
/// BY BEHAVIOUR RATHER THAN BY A NOTE.
///
/// §13(cj)'s own classification table places `history_screen.dart:149` in the
/// "must FILTER hidden" column. **It is integrity.** `8785155` records the
/// trace; this file makes it fire.
///
///     history_screen.dart:149   _records = List.from(widget.records)
///     history_screen.dart:603   onRecordsChanged(_records)   after a delete
///     history_screen.dart:647   onRecordsChanged(_records)   after an edit
///     home_screen.dart:893      setState(() => _records = updated)
///     home_screen.dart:894      _persist()
///     home_screen.dart:496      persistEvents(_store, _records)
///
/// ⛔ **History's local list is not a view. It reaches `save`** — and
/// `SqliteEventStore.save` is a full delete-and-reinsert of whatever list it is
/// handed. Filter at `:149` and the next History delete or edit writes the
/// filtered list to storage, **destroying every hidden record permanently**.
/// Retention is FOREVER; the hidden set is not deletion.
///
/// ## ⭐ WHY THIS IS A WIDGET TEST AND NOT A UNIT ONE
///
/// The defect is not in any one function. It is in **which list crosses the
/// boundary**, and the boundary is a screen's callback. A unit test over
/// `persistEvents` would pass under the very substitution this exists to catch,
/// because by then the filtering has already happened one frame earlier.
///
/// ⚠️ `home_screen` is deliberately NOT pumped. `onRecordsChanged` here is
/// literally what `home_screen.dart:893-894` does — assign, then persist — and
/// pumping home would drag the notification channel, the drain and the
/// walkthrough gate into a test about one list crossing one callback. The two
/// lines it stands in for are quoted above so the substitution is visible.
///
/// ## ⛔ TWO HARNESS RULES THIS FILE COST TWO HANGS TO LEARN
///
/// **1. Every database call inside a `testWidgets` body goes through
/// `tester.runAsync`.** The body runs on a FAKE CLOCK and `sqflite_common_ffi`
/// does real I/O on another isolate, so a bare `await db.query(...)` waits on a
/// future the fake clock never reaches — the test hangs with no output rather
/// than failing. `bulk_hide_test.dart:54` records the same mechanism for
/// `pumpAndSettle`; it applies to the awaits as well.
///
/// **2. ONE serialise-driving widget test per FILE**, which is why the
/// flag-intact half lives in `hidden_flag_survives_history_write_test.dart`.
/// `EventStore.serialise` chains on a STATIC queue:
///
///     final result = _queue.then((_) => operation());
///     _queue = result.then((_) {}, onError: (_) {});
///
/// That `.then` registers its continuation in whatever zone is current. The
/// `persistEvents` below runs inside this test's fake-async zone, so once the
/// test ends `_queue` terminates in a continuation bound to a DEAD ZONE — and
/// the next `serialise` call anywhere in the process waits on it forever. A
/// second store-backed widget test in this file hung at 04:55 with this one
/// already green, twice, before the cause was found. ⭐ Same class as the
/// one-prefs-test-per-process rule in `CLAUDE.md`: a static that outlives the
/// zone it was last touched from.
///
///
/// ## ⚠️ WHAT THE ROW CONTROL DOES CHANGED, AND THE CLAIM DID NOT
///
/// Until 17 September 2026 the row control DELETED. It now HIDES, so the
/// assertions below say *all three rows are still in storage* where they
/// once said *two*. ⛔ **The claim this file makes is unchanged**: whatever
/// list crosses `onRecordsChanged` is what survives, so a filter at `:149`
/// destroys the hidden record. The control substitution still fires — only
/// the count on the right-hand side moved.

EventRecord rec(String id, int minute, {bool hidden = false}) => EventRecord(
      id: id,
      timestamp: DateTime(2026, 8, 20, 9, minute),
      duration: DurationCategory.lt1,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: false,
      notes: 'note $id',
      eventType: 'seizure',
      severity: EventSeverity.mild,
      detailsCompleted: true,
      hidden: hidden,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tmp;
  late Database db;
  late SqliteEventStore store;

  // Opened in setUp, which runs OUTSIDE the fake-async zone, so this one await
  // needs no wrapping. Everything inside a test body does.
  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('mer_seam_');
    db = await databaseFactoryFfi.openDatabase(
      '${tmp.path}/mer.db',
      options: OpenDatabaseOptions(
        version: kSqliteSchemaVersion,
        onCreate: (d, _) => createSchema(d),
        onUpgrade: upgradeSchema,
      ),
    );
    store = SqliteEventStore(db);
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  /// ⛔ NOT `pumpAndSettle`. Lifted from `bulk_hide_test.dart:54`, which states
  /// it plainly: these actions do real sqflite-ffi writes, and a widget test
  /// runs on a fake clock, so settling waits on I/O the clock never reaches.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  group('a History write must not destroy a hidden record', () {
    testWidgets('1. DELETE: the hidden record is still in storage afterwards',
        (tester) async {
      // The hidden record sits in the MIDDLE, so a loss shows as a gap rather
      // than only as a shorter list.
      final seed = <EventRecord>[
        rec('visible-a', 1),
        rec('HIDDEN', 2, hidden: true),
        rec('visible-b', 3),
      ];
      await tester.runAsync(() => store.save(seed));

      Future<List<String>> idsInStorage() async {
        final rows = await db.query('event',
            columns: <String>['id'], orderBy: 'ordinal ASC');
        return rows.map((r) => r['id'] as String).toList();
      }

      final before = await tester.runAsync(idsInStorage);
      expect(before, hasLength(3),
          reason: 'precondition: all three are in the table before anything '
              'touches the screen');

      await tester.pumpWidget(MaterialApp(
        home: HistoryScreen(
          records: seed,
          // ⛔ EXACTLY what home_screen.dart:893-894 does. The setState is not
          // reproduced because it changes no list contents — the list handed
          // to persistEvents is the one History passed out.
          onRecordsChanged: (updated) async => persistEvents(store, updated),
          onEdit: (_, {required confirmOnSave}) async {},
        ),
      ));
      await settle(tester);

      // Positive control on the fixture: the hidden record must NOT be on
      // screen, or this test is about three visible rows.
      expect(find.text('note HIDDEN'), findsNothing,
          reason: 'positive control: the derived view excludes it');
      expect(find.byIcon(Icons.visibility_off_outlined), findsNWidgets(2),
          reason: 'positive control: two visible rows, each with one control — '
              'if this is 3 the fixture is not hidden and the test is vacuous');

      // ⚠️ NO CONFIRMATION ANY MORE — one tap hides. The dialog went with
      // Brief S, because the action it warned about became reversible.
      await tester.tap(find.byIcon(Icons.visibility_off_outlined).first);
      await settle(tester);

      final after = await tester.runAsync(idsInStorage);

      // ⛔ THE ASSERTION THIS FILE EXISTS FOR, AND IT IS DELIBERATELY FIRST.
      //
      // The positive controls below are the more natural opening — prove the
      // delete happened, then say what survived. But `expect` throws, so the
      // FIRST failing assertion is the only one that speaks, and under the
      // substitution this file guards against the length control fires first
      // and reports "expected 2, got 1" — true, attributable to the wrong
      // claim, and silent about the record that was destroyed.
      //
      // ⭐ `CLAUDE.md`'s rule: a control proves an apparatus is live only if the
      // failure it produces is ATTRIBUTABLE. Ordering is what buys that here.
      // Nothing is lost by the swap — a delete that never ran leaves HIDDEN
      // present and is still caught by the length control immediately below.
      expect(after, contains('HIDDEN'),
          reason: 'a hidden record was destroyed by an unrelated History '
              'delete. save() is a full delete-and-reinsert, so whatever list '
              'crosses onRecordsChanged is what survives — §13(cj) failure '
              'mode (a), and retention is FOREVER');

      // Positive control: the hide really happened. Without this the test
      // passes when nothing occurred at all.
      //
      // ⛔ ALL THREE, NOT TWO. Hiding does not remove a row — that is the
      // whole change — so storage is unchanged in LENGTH and changed in
      // FLAG. The flag is checked in the sibling file.
      expect(after, hasLength(3),
          reason: 'positive control: hiding removes nothing from storage');
      expect(after!.contains('visible-a'), isTrue,
          reason: 'the row the user hid is still there, hidden');
    });
  });

  group('the integrity sites still see hidden records', () {
    test('2. EXPORT ALL carries the hidden record', () {
      // ⛔ Home's "Export all events" passes `_records`, the complete list, and
      // R1 makes that absolute: there is one export named *all events* and it
      // means it.
      final csv = buildCsv(<EventRecord>[
        rec('visible-a', 1),
        rec('HIDDEN', 2, hidden: true),
      ]);

      expect(csv, contains('note visible-a'),
          reason: 'positive control: the builder emits notes at all');
      expect(csv, contains('note HIDDEN'),
          reason: 'export-all must be complete. A hidden record omitted here '
              'makes the one export named "all events" a false claim');
    });

    test('3. BACKUP carries the hidden record AND its flag', () {
      // ⛔ NON-NEGOTIABLE. Restore is merge-by-id and add-only, so on a fresh
      // install the backup is a full reconstruction — a hidden record absent
      // from the file is destroyed by an uninstall.
      final parsed = parseBackup(buildBackupJson(<EventRecord>[
        rec('visible-a', 1),
        rec('HIDDEN', 2, hidden: true),
      ]));

      expect(parsed.isValid, isTrue, reason: 'positive control: it parsed');
      expect(parsed.records.map((r) => r.id),
          containsAll(<String>['visible-a', 'HIDDEN']),
          reason: 'a hidden record absent from a backup is destroyed by an '
              'uninstall, and retention is FOREVER');
      expect(parsed.records.firstWhere((r) => r.id == 'HIDDEN').hidden, isTrue,
          reason: 'the flag travels too, or a restore unhides everything');
      expect(parsed.declaredCount, 2,
          reason: 'recordCount counts hidden rows — it describes the file, not '
              'the screen');
    });
  });
}
