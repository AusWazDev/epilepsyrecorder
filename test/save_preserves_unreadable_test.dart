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

EventRecord rec(String id, DateTime ts, {String notes = ''}) => EventRecord(
      id: id,
      timestamp: ts,
      duration: DurationCategory.lt1,
      durationSeconds: 40,
      eventType: 'seizure',
      severity: EventSeverity.mild,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: false,
      notes: notes,
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

  /// How many rows carry this id. ⭐ NOT `rowExists`: the discriminator for
  /// add-or-update is whether an update REPLACED a row or ADDED a second one,
  /// and `isNotEmpty` cannot tell those apart.
  Future<int> rowsWithId(String id) async =>
      (await db.query('event', where: 'id = ?', whereArgs: [id])).length;

  /// The `notes` cell, as the single field an update is watched through.
  Future<String?> notesOf(String id) async =>
      (await db.query('event', where: 'id = ?', whereArgs: [id]))
          .first['notes'] as String?;

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

  // ── REBUILT 23 September 2026 · Brief 135R-2 ─────────────────────────────
  // ⛔ THIS TEST PREVIOUSLY ASSERTED THE OPPOSITE, and it is preserved here as
  // a record rather than silently replaced. It read:
  //
  //     '3 · ⚠️ a record the user DELETED is still removed — no resurrection'
  //     expect(await rowExists('delete-me'), isFalse, reason: 'TEST 3: ⚠️ THE
  //     RESURRECTION TEST … Deletion is a real feature — hiding or removing a
  //     record takes it out of the list and the row must go.'
  //
  // ⚠️ IT PINNED A PREMISE THAT WAS ALREADY FALSE WHEN IT WAS WRITTEN. Nothing
  // in the app removes a record: hiding sets `event.hidden` (v10, 17 Sep) and
  // History's `onDelete:` calls `_toggleHiddenAndPersist`. The only removal is
  // `clearAll()`, the user's own Reset, which is tested separately and
  // unchanged. See the annotation on `SqliteEventStore.save`.
  //
  // ⭐ SO THE DISCRIMINATOR MOVES FROM DELETION TO UPDATE. That is not a
  // weaker test — it is a strictly sharper one, because it separates THREE
  // outcomes where the old one separated two:
  //     · the clobber        an absent record is destroyed        -> caught
  //     · a naive fix        the delete is simply removed, so a   -> caught
  //                          save DUPLICATES every record it holds
  //     · add-or-update      updated in place, absent untouched   -> passes
  // The old test could not see the middle one at all.
  test('3 · ⭐ an UPDATE replaces the row it names and touches nothing else',
      () async {
    await store.save([
      rec('keep-me', DateTime(2026, 9, 1)),
      rec('edit-me', DateTime(2026, 9, 2)),
    ]);
    await insertUnreadable('bad-1');

    expect(await notesOf('edit-me'), '',
        reason: 'CONTROL: the field this test watches must start empty, or '
                '"it changed" cannot be distinguished from "it was always so".');
    expect(await rowsWithId('edit-me'), 1,
        reason: 'CONTROL: exactly one row to start, or the duplication '
                'assertion below has nothing to measure.');

    // The user edits one record. Every other record is still in the list.
    final loaded = await store.load();
    await store.save([
      for (final r in loaded)
        if (r.id == 'edit-me')
          rec('edit-me', DateTime(2026, 9, 2), notes: 'edited')
        else
          r,
    ]);

    // ⛔ ORDER MATTERS HERE AND IT IS NOT COSMETIC. The structural assertion
    // comes FIRST because `notesOf` reads the first matching row: against a
    // save that appends instead of replacing, it returns the STALE row and
    // fails with "expected 'edited', got ''" — which reads as "the write did
    // not land" when the write landed twice. ⭐ Caught by running the control,
    // where it masked the duplication assertion exactly as CLAUDE.md's
    // attribution rule predicts.
    expect(await rowsWithId('edit-me'), 1,
        reason: '⛔ IT MUST REPLACE, NOT ACCUMULATE. Two rows here means the '
                'delete was removed without being re-scoped, so every save '
                'would duplicate its own records and the history would grow '
                'without bound. This is the assertion that makes '
                'add-or-update different from add-only.');
    expect(await notesOf('edit-me'), 'edited',
        reason: '⛔ AND THE UPDATE MUST LAND. A save that preserved everything '
                'and wrote nothing would leave this empty — the failure mode '
                'at the opposite extreme from the clobber, and the reason this '
                'fix cannot be "stop deleting" on its own.');

    expect(await rowExists('keep-me'), isTrue,
        reason: 'TEST 3: the untouched record is still there.');
    expect(await rowExists('bad-1'), isTrue,
        reason: 'TEST 3: and the unreadable row still survives ALONGSIDE a '
                'real update — the two behaviours coexist rather than one '
                'being traded for the other.');
  });

  // ⭐ THE OTHER HALF OF THE SAME CONTRACT, AND THE ONE THE OLD TEST 3 HAD
  // BACKWARDS. A record the list does not mention is NOT the list's to remove.
  test('3b · ⛔ a record absent from the snapshot SURVIVES the save', () async {
    await store.save([
      rec('keep-me', DateTime(2026, 9, 1)),
      rec('not-in-the-list', DateTime(2026, 9, 2)),
    ]);
    expect(await rowExists('not-in-the-list'), isTrue,
        reason: 'CONTROL: it must be there before a save can fail to keep it.');

    // A caller writes a list that never mentions it — the shape History takes
    // when a record was drained into storage after its snapshot was taken.
    await store.save([rec('keep-me', DateTime(2026, 9, 1))]);

    expect(await rowExists('not-in-the-list'), isTrue,
        reason: '⛔ THE CLOBBER, AT STORE LEVEL. Absence from a snapshot means '
                'the caller never knew about the record, NOT that the user '
                'deleted it — nothing in the app deletes one. Removal is an '
                'operation (`clearAll`), never a side effect of a save.');
    expect(await rowExists('keep-me'), isTrue, reason: 'TEST 3b: and the '
        'record that WAS named is still there.');
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

    // ⭐ UPDATED 23 September 2026 · Brief 135R-2. The clause was
    // `rowid NOT IN (…)` — keep everything absent — and is now `rowid IN (…)`,
    // replace only what the snapshot names. ⛔ THIS CONTROL DID ITS JOB: it
    // reported the old token missing rather than passing over a changed file,
    // which is the whole reason a source pin carries one.
    const clauseToken = 'rowid IN (';

    // CONTROL: the reader must find the clause, or this is vacuous.
    expect(src.contains(clauseToken), isTrue,
        reason: 'CONTROL: the preserve clause was not found — either it was '
                'removed or this scan reads the wrong file.');

    final i = src.indexOf(clauseToken);
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
