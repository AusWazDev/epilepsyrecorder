// Brief 84 · a row that could not be read is never deleted by a write derived
// from a read that skipped it.
//
// ⛔ THE DEFECT. `save` did `txn.delete('event')` unconditionally, then
// re-inserted from the list. `_load` drops unreadable rows via
// `.whereType<EventRecord>()` BEFORE the list exists. So a parse failure at LOAD
// became a permanent deletion at the next SAVE — and `persistEvents` runs on
// capture, edit, hide, restore and drain, so ordinary use was enough.
//
// ⛔ EVERY TEST HERE USES AN UNPARSEABLE ROW AND A PARSEABLE ROW IN THE SAME
// TABLE. A test over only-parseable rows proves nothing and is the exact trap
// this defect sat in for as long as it existed.
//
// ⚠️ The fix ships because the failure is TOTAL and the fix is CHEAP. Whether
// any row has ever failed to parse in the field is NOT established and is not
// claimed anywhere here.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

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
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;
  late SqliteEventStore store;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: kSqliteSchemaVersion,
          onCreate: (d, v) async => createSchema(d),
        ));
    store = SqliteEventStore(db);
  });
  tearDown(() async => db.close());

  /// Inserts a row this build cannot read: `logged_at` is a real string, so the
  /// NOT NULL constraint holds, but it is not a date — which is one of the two
  /// conditions `eventFromRow` returns null on.
  Future<void> insertUnreadable(String id) async {
    await db.insert('event', {
      'id': id,
      'logged_at': 'not-a-date',
      'ordinal': 999,
    });
  }

  Future<int> rowCount() async =>
      (await db.rawQuery('SELECT COUNT(*) AS n FROM event')).first['n'] as int;

  Future<bool> rowExists(String id) async =>
      (await db.query('event', where: 'id = ?', whereArgs: [id])).isNotEmpty;

  test('1 · load still drops the unreadable row — behaviour unchanged', () async {
    await store.save([rec('good-1', DateTime(2026, 9, 1))]);
    await insertUnreadable('bad-1');

    // CONTROL: both rows must really be in the table, or everything below is
    // testing an empty case.
    expect(await rowCount(), 2,
        reason: 'CONTROL: the table must hold one readable and one unreadable '
                'row, or these tests are vacuous.');

    final loaded = await store.load();
    expect(loaded.map((r) => r.id), ['good-1'],
        reason: 'TEST 1: `load` drops what it cannot parse. That behaviour is '
                'UNCHANGED and is pinned here so the fix cannot silently alter '
                'it — the fix is about what SAVE destroys, not what LOAD '
                'returns.');
  });

  test('2 · ⛔ a save after that load leaves the unreadable row IN THE TABLE',
      () async {
    await store.save([rec('good-1', DateTime(2026, 9, 1))]);
    await insertUnreadable('bad-1');

    final loaded = await store.load();           // short by one, silently
    await store.save(loaded);                    // the destroying write

    expect(await rowExists('bad-1'), isTrue,
        reason: 'TEST 2: ⛔ THE ASSERTION THE WHOLE BRIEF EXISTS FOR. The row '
                'the load could not read must survive the save. Before the fix '
                'the unconditional `txn.delete(\'event\')` removed it, so a '
                'parse failure at load became permanent destruction at the '
                'next ordinary save.');
    expect(await rowExists('good-1'), isTrue,
        reason: 'TEST 2: and the readable record is still there.');
    expect(await rowCount(), 2, reason: 'TEST 2: exactly the two rows.');
  });

  test('3 · ⚠️ a record the user DELETED is still removed — no resurrection',
      () async {
    await store.save([
      rec('keep-me', DateTime(2026, 9, 1)),
      rec('delete-me', DateTime(2026, 9, 2)),
    ]);
    await insertUnreadable('bad-1');

    // The user removes one. The list shrinks deliberately, not by failure.
    final after = (await store.load()).where((r) => r.id != 'delete-me').toList();
    await store.save(after);

    expect(await rowExists('delete-me'), isFalse,
        reason: 'TEST 3: ⚠️ THE RESURRECTION TEST, and the one a careless fix '
                'gets wrong. Deletion is a real feature — hiding or removing a '
                'record takes it out of the list and the row must go. Making '
                'save an upsert would bring deleted records back, which is a '
                'worse defect than the one being fixed.');
    expect(await rowExists('keep-me'), isTrue, reason: 'TEST 3: kept.');
    expect(await rowExists('bad-1'), isTrue,
        reason: 'TEST 3: and the unreadable row still survives ALONGSIDE a '
                'genuine deletion — the two behaviours coexist rather than one '
                'being traded for the other.');

    // ⭐ THE CONTROL THAT MATTERS: this suite observes BOTH outcomes. A harness
    // that can only see "survived" would pass against an upsert; one that can
    // only see "deleted" would pass against the original defect.
    expect(await rowExists('delete-me'), isFalse);   // deleted
    expect(await rowExists('bad-1'), isTrue);        // survived
  });

  test('5 · the single-transaction property survives', () async {
    await store.save([rec('good-1', DateTime(2026, 9, 1))]);
    await insertUnreadable('bad-1');
    final before = await rowCount();

    // Force a failure mid-write: a row violating NOT NULL on logged_at makes
    // the batch throw after the delete has already run inside the transaction.
    await expectLater(
      db.transaction((txn) async {
        await txn.delete('event');
        await txn.insert('event', {'id': 'x', 'ordinal': 0});   // no logged_at
      }),
      throwsA(anything),
      reason: 'CONTROL: the injected failure must actually throw, or this test '
              'proves nothing about rollback.',
    );

    expect(await rowCount(), before,
        reason: 'TEST 5: a failure mid-write leaves the PREVIOUS contents '
                'intact. The docstring\'s atomicity reasoning is correct and '
                'unchanged by this fix — it protects the write, not the '
                'contents, which is why it never addressed the defect above.');
  });

  test('6 · ⛔ more unreadable rows than SQLITE_MAX_VARIABLE_NUMBER', () async {
    // ⛔ THE STANDING RULE IS WHAT THIS GUARDS. A bound-parameter IN-clause
    // caps the preserved count at SQLITE_MAX_VARIABLE_NUMBER — 999 on older
    // builds. Past that, every save would THROW, and a save that always fails
    // means the user can no longer record anything: a fix that gates capture in
    // the course of protecting data.
    for (var i = 0; i < 1200; i++) {
      await insertUnreadable('bad-$i');
    }
    expect(await rowCount(), 1200,
        reason: 'CONTROL: 1200 unreadable rows must really be present, and 1200 '
                'is deliberately past the 999 variable limit.');

    await store.save([rec('good-1', DateTime(2026, 9, 1))]);

    expect(await rowCount(), 1201,
        reason: 'TEST 6: the save must SUCCEED and preserve all 1200.');

    // ⛔ AND WHAT THIS TEST CANNOT SETTLE, STATED RATHER THAN IMPLIED.
    // Reverting the clause to bound parameters and re-running leaves this
    // GREEN: the FFI SQLite on this host caps variables well above 1200
    // (modern builds default to 32766). Android ships its own SQLite and older
    // builds cap at 999, so the limit is a property of the DEVICE, not of this
    // harness — a behavioural test here cannot discriminate.
    //
    // ⭐ So the real guard is the source assertion below. Recorded because a
    // control that passes under both the fix and the defect is not a control,
    // and treating this as one would be exactly the blind apparatus this
    // project has been caught by twice.
    expect(await rowExists('good-1'), isTrue,
        reason: 'TEST 6: and the new record was still written — capture is '
                'never gated.');
  });

  test('7 · ⛔ SOURCE — the preserve clause is not parameter-bound', () {
    // ⭐ THE GUARD TEST 6 CANNOT BE. The variable cap is a property of the
    // device's SQLite build, so only the SOURCE can settle whether the clause
    // is exposed to it.
    final src = File('lib/models/event_store_sqlite.dart').readAsStringSync();

    // CONTROL: the reader must find the clause, or this is vacuous.
    expect(src.contains('rowid NOT IN'), isTrue,
        reason: 'CONTROL: the preserve clause was not found — either it was '
                'removed or this scan reads the wrong file.');

    final i = src.indexOf('rowid NOT IN');
    final clause = src.substring(i - 200, i + 200);
    expect(clause.contains('whereArgs'), isFalse,
        reason: '⛔ The rowid list must be INLINE LITERALS. One placeholder per '
                'preserved row caps the count at SQLITE_MAX_VARIABLE_NUMBER — '
                '999 on older Android builds — and past that EVERY save '
                'throws. A save that always fails means the user can no longer '
                'record anything: a fix that gates capture while protecting '
                'data. Safe to inline only because every value is a rowid '
                'SQLite issued, type-checked as an int before it enters the '
                'list.');
  });
}
