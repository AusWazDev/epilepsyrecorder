// Brief 98 · the seventh door — a persist derived from a load that FAILED must
// not apply replace semantics, and the capture it carries must survive anyway.
//
// ⛔ THE DEFECT, MEASURED AT HEAD ON 23 SEPTEMBER 2026 (Brief 91 A3b):
//
//     12 readable rows + a capture into an EMPTY list -> 1 row(s) remain
//       history-0 -> DELETED   history-1 -> DELETED   history-2 -> DELETED
//
// `_records` starts empty and stays empty when a load throws. Every route to a
// persist then rewrote storage from that empty list, and because `save`'s keep
// list holds only UNREADABLE rows, `keep.isEmpty` took the branch with no
// `where` clause at all — `txn.delete('event')`. The narrowed scope from
// 3c3a6fd collapsed back to the unconditional delete on a HEALTHY device.
//
// ⚠️ 3c3a6fd IS NOT WRONG. Its invariant — a row that could not be READ is
// never deleted by a write derived from a read that skipped it — holds exactly
// as written. This failure is one level up: the read did not skip a row, it
// never happened.
//
// ⛔ HARNESS ISOLATION, STATED BEFORE ANY NUMBER IS REPORTED.
// `inMemoryDatabasePath` is SHARED ACROSS TESTS IN ONE PROCESS. Brief 91's
// first run reported 13 rows against an expected 12 because the previous
// test's rows carried in, and the control caught it. Every fixture here clears
// `event` on open and asserts its own starting count before acting.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/models/capture_inbox.dart';
import 'package:medical_event_recorder/models/capture_instruction.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';

EventRecord rec(String id, DateTime ts) => EventRecord(
      id: id,
      timestamp: ts,
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
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  // ⛔ ONE prefs-dependent test per PROCESS is the standing rule, so the inbox
  // half of this file lives in its own test and the mock is set once here.
  SharedPreferences.setMockInitialValues(<String, Object>{});

  Future<Database> freshDb() async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: kSqliteSchemaVersion,
        onCreate: (d, v) async => createSchema(d),
      ),
    );
    await db.delete('event'); // see the isolation note in the header
    return db;
  }

  Future<int> count(Database db) async =>
      (await db.rawQuery('SELECT COUNT(*) AS n FROM event')).first['n'] as int;

  test('1 · ⛔ THE REGRESSION — twelve readable rows survive a capture taken '
      'while the load has FAILED, and the capture survives too', () async {
    final db = await freshDb();
    final store = SqliteEventStore(db);

    await store.save([
      for (var i = 0; i < 12; i++) rec('history-$i', DateTime(2026, 8, i + 1)),
    ]);
    expect(await count(db), 12,
        reason: 'CONTROL: twelve readable rows must really be present before '
                'anything is asserted about what survives. Brief 91 reported '
                '13 here once, carried over from a previous test in the same '
                'process, and the control is what caught it.');

    // ── the capture, taken while the list is BEHIND storage ──────────────
    // ⛔ THIS IS THE SHAPE THAT FAILS IN THE FIELD: a load that THREW, so
    // `_records` is empty and one capture has been appended to it. NOT a slow
    // load — a slow load eventually assigns the list and is not this defect.
    final captured = rec('the-one-new-record', DateTime(2026, 9, 23));
    final ok = await persistEvents(store, [captured],
        from: LoadState.failed);

    expect(ok, isFalse,
        reason: 'The write is WITHHELD, so it reports false and the standing '
                'unsaved-write banner comes up. ⚠️ False here means "not '
                'written", not "lost" — the record is in the in-memory list '
                'and its instruction is in the inbox.');

    expect(await count(db), 12,
        reason: '⛔ THE ASSERTION THE WHOLE BRIEF EXISTS FOR. Before the fix '
                'this was 1: the rewrite deleted every readable row the short '
                'list did not contain. Nothing may be deleted by a write '
                'derived from a load that never happened.');

    // ── the refuge: the capture is durable even though it was not stored ──
    final prefs = await SharedPreferences.getInstance();
    await writeStartInstruction(prefs,
        id: captured.id, at: captured.timestamp);

    // ── and the next load that SUCCEEDS merges it ────────────────────────
    final loaded = await store.load();
    expect(loaded.length, 12, reason: 'CONTROL: the store still holds twelve.');

    final drain = await drainInbox(
      transport: PrefsInboxTransport(prefs),
      store:     store,
      loaded:    loaded,
    );

    expect(drain.records.length, 13,
        reason: '⭐ THIRTEEN. Twelve preserved in the store and the thirteenth '
                'recovered from the inbox — the end-to-end property is that '
                'NOTHING IS LOST, not merely that nothing is deleted.');
    expect(drain.records.map((r) => r.id), contains('the-one-new-record'),
        reason: 'and the recovered one is the capture that was taken while the '
                'store could not be trusted.');
    expect(await count(db), 13,
        reason: 'the drain persisted it, because by then the list came from a '
                'load that completed.');
    await db.close();
  });

  test('2 · ⚠️ THE DISCRIMINATING CONTROL — a COMPLETED load still deletes, so '
      'hide and delete keep working', () async {
    final db = await freshDb();
    final store = SqliteEventStore(db);

    await store.save([
      rec('keep-me',   DateTime(2026, 9, 1)),
      rec('delete-me', DateTime(2026, 9, 2)),
    ]);
    expect(await count(db), 2, reason: 'CONTROL: two rows to start.');

    // The user removed one. The list is SHORT ON PURPOSE, from a load that
    // completed.
    final ok = await persistEvents(store, [rec('keep-me', DateTime(2026, 9, 1))],
        from: LoadState.completed);

    expect(ok, isTrue, reason: 'a completed load still writes.');
    expect(await count(db), 1,
        reason: '⛔ THE TEST THAT STOPS THIS FIX BECOMING A BLANKET REFUSAL. '
                'Deletion is a real feature: hiding or removing a record takes '
                'it out of the list and the row must go. A guard that '
                'preserved rows here would resurrect deleted records, which is '
                'a worse defect than the one being fixed. ⭐ Tests 1 and 2 '
                'differ ONLY in `from`, so a harness that passed both by '
                'preserving everything is impossible.');
    await db.close();
  });

  test('3 · notAttempted is withheld too — a capture before the first load', ()
      async {
    final db = await freshDb();
    final store = SqliteEventStore(db);
    await store.save([rec('existing', DateTime(2026, 9, 1))]);
    expect(await count(db), 1, reason: 'CONTROL: one row to start.');

    final ok = await persistEvents(store, [rec('new', DateTime(2026, 9, 2))],
        from: LoadState.notAttempted);

    expect(ok, isFalse);
    expect(await count(db), 1,
        reason: '⭐ `notAttempted` is distinct from `failed` — nothing has gone '
                'wrong, we do not know yet — but it withholds for the same '
                'reason: the list is not known to be a superset of storage. '
                'The distinction exists so the REPORTING can tell them apart, '
                'not so one of them may overwrite.');
    await db.close();
  });

  test('4 · ⛔ THE PIN — the keyspace separation this fix rests on', () {
    // ⭐ WHAT THIS PIN ESTABLISHES, AND WHAT IT CANNOT (control 6).
    //
    // IT ESTABLISHES: that no source file in lib/ uses the shared_preferences
    // ASYNC API, and that nothing changes the key prefix.
    //
    // ⛔ IT DOES NOT ESTABLISH that the iOS keyspaces are actually disjoint at
    // runtime. That is a property of two storage containers on a device and no
    // test on this host can reach it. This is a SOURCE scan and it proves a
    // source property only.
    //
    // WHY IT IS STILL WORTH HAVING. The composite transport on iOS is correct
    // only while Swift's `mer_inbox_*` keys and Dart's cannot collide. Measured
    // 23 September 2026: Swift writes bare keys to
    // `UserDefaults(suiteName: group.au.com.notiva.medicaleventrecorder)`, and
    // Dart's LEGACY api writes `flutter.`-prefixed keys to
    // `UserDefaults.standard`. Either mechanism alone separates them.
    //
    // ⚠️ AND THE PART THAT MAKES THIS A PIN RATHER THAN A COMMENT: that is a
    // property of the API THIS APP CHOSE, not of the package.
    // `shared_preferences_foundation`'s newer `SharedPreferencesPlugin` DOES
    // address a suite — `getUserDefaults(options:)` calls
    // `UserDefaults(suiteName: options.suiteName)` and validates a `group.`
    // prefix on iOS. A migration to `SharedPreferencesAsync` or
    // `SharedPreferencesWithCache` could therefore relocate Dart's keys into
    // the App Group and make the two writers collide — silently, because
    // nothing else in the codebase knows this is load-bearing.
    const asyncApis = <String>[
      'SharedPreferencesAsync',
      'SharedPreferencesWithCache',
    ];

    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    // CONTROL: the scanner must actually be reading files, or the null below
    // is a scan that never ran.
    expect(files.length, greaterThan(20),
        reason: 'CONTROL: the scan found almost no files — it is looking in '
                'the wrong place and any zero it reports is meaningless.');

    final legacyUsers = <String>[];
    final offenders   = <String>[];
    for (final f in files) {
      final src = f.readAsStringSync();
      if (src.contains('SharedPreferences.getInstance')) {
        legacyUsers.add(f.path);
      }
      for (final api in asyncApis) {
        if (src.contains(api)) offenders.add('${f.path}: $api');
      }
      if (src.contains('setPrefix(')) {
        offenders.add('${f.path}: setPrefix');
      }
    }

    // ⭐ POSITIVE CONTROL ON THE NULL: the same reader, over the same corpus,
    // must FIND the legacy API. If this is empty the scanner is broken and the
    // empty `offenders` list means nothing.
    expect(legacyUsers, isNotEmpty,
        reason: 'CONTROL: the scanner found no use of '
                '`SharedPreferences.getInstance` anywhere in lib/. Either the '
                'app has been migrated — in which case this pin has fired for '
                'real — or the scanner is broken. Either way, stop.');

    expect(offenders, isEmpty,
        reason: '⛔ THE PIN FIRED. Something in lib/ now uses the '
                'shared_preferences ASYNC api, or changes the key prefix. '
                'The iOS capture inbox depends on Dart keys living in '
                '`UserDefaults.standard` under a `flutter.` prefix, DISJOINT '
                'from the App Group keys Swift writes. The async api can be '
                'given a suite name; the legacy one is hardcoded to standard. '
                'Before proceeding, re-establish that Swift `mer_inbox_*` keys '
                'and Dart `mer_inbox_*` keys still cannot collide, and update '
                '`CompositeInboxTransport`, whose delete routing assumes they '
                'cannot. Offenders: $offenders');
  });
}
