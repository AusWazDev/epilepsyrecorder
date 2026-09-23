// Brief 84 · test 4 — the PREFS FALLBACK store, same invariant.
//
// ⛔ BOTH BOOT PATHS OR NEITHER. This implementation is chosen at boot when
// SQLite cannot open (`StorageBoot` :139, :154, :167). A divergence here would
// be a defect that appears on one boot path and never on the other — worse than
// either uniform behaviour, because nothing on the working path would show it.
//
// ⚠️ Separate file because this one is prefs-dependent and the SQLite file is
// not; the harness rule in CLAUDE.md is about prefs-dependent tests per process.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_record.dart';

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

/// An entry this build cannot read: a real map, but the timestamp is not a
/// date — the condition `EventRecord.fromMap` returns null on.
const unreadableEntry = {'id': 'bad-1', 'timestamp': 'not-a-date'};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('the fallback store preserves, deletes, and quarantines identically',
      () async {
    final store = EventStore();

    // ── a readable record and an unreadable entry, in the same payload ────
    await prefs.clear();
    await prefs.setString(
      kEventStorageKey,
      jsonEncode([rec('good-1', DateTime(2026, 9, 1)).toMap(), unreadableEntry]),
    );

    // CONTROL: the load must really drop one, or the rest is vacuous.
    final loaded = await store.load();
    expect(loaded.map((r) => r.id), ['good-1'],
        reason: 'CONTROL: the fallback load drops the unreadable entry, the '
                'same way the SQLite load does.');

    await store.save(loaded);

    final after = jsonDecode(prefs.getString(kEventStorageKey)!) as List;
    expect(after.whereType<Map>().map((e) => e['id']), contains('bad-1'),
        reason: 'TEST 4: ⛔ the unreadable ENTRY must survive the save, exactly '
                'as the unreadable ROW does on SQLite. Different handle — '
                'there is no rowid here, so the raw map is carried through — '
                'but the same invariant.');
    expect(after.whereType<Map>().map((e) => e['id']), contains('good-1'),
        reason: 'TEST 4: and the readable record is still there.');
    expect(after, hasLength(2), reason: 'TEST 4: exactly two entries.');

    // ── REBUILT 23 September 2026 · Brief 135R-2 ─────────────────────────
    // ⛔ THIS SECTION PREVIOUSLY ASSERTED THE OPPOSITE, preserved here as a
    // record rather than silently replaced. It read:
    //
    //     expect(ids2, isNot(contains('delete-me')), reason: 'TEST 4: ⚠️ no
    //     resurrection here either. Deletion is a real feature on both boot
    //     paths.'
    //
    // ⚠️ Nothing in the app removes a record — hiding is a flag and History's
    // `onDelete:` is the hide. So the discriminator moves from DELETION to
    // UPDATE, exactly as it does on the SQLite side. ⭐ The two stores reach
    // this contract by different mechanisms — rowid there, an id set here —
    // which is precisely why both are pinned rather than one.
    await prefs.clear();
    await prefs.setString(
      kEventStorageKey,
      jsonEncode([
        rec('keep-me', DateTime(2026, 9, 1)).toMap(),
        rec('edit-me', DateTime(2026, 9, 2)).toMap(),
        unreadableEntry,
      ]),
    );

    // The caller edits ONE record and hands back the whole list.
    final loaded2 = await store.load();
    expect(loaded2.map((r) => r.id), containsAll(['keep-me', 'edit-me']),
        reason: 'CONTROL: both readable records must load, or the edit below '
                'is not editing anything.');
    await store.save([
      for (final r in loaded2)
        if (r.id == 'edit-me')
          rec('edit-me', DateTime(2026, 9, 2), notes: 'edited')
        else
          r,
    ]);

    final after2 = jsonDecode(prefs.getString(kEventStorageKey)!) as List;
    final ids2 = after2.whereType<Map>().map((e) => e['id']).toList();
    expect(ids2.where((id) => id == 'edit-me'), hasLength(1),
        reason: '⛔ THE UPDATE REPLACES, IT DOES NOT ACCUMULATE. Two entries '
                'here means the rebuild stopped dropping the old copy without '
                'scoping what it keeps — every save would then duplicate its '
                'own records.');
    expect(
        after2
            .whereType<Map>()
            .firstWhere((e) => e['id'] == 'edit-me')['notes'],
        'edited',
        reason: '⛔ AND THE NEW VALUE MUST WIN. A merge that preferred the '
                'stored copy would silently discard every edit the user makes '
                '— the failure at the opposite extreme from the clobber.');
    expect(ids2, contains('bad-1'),
        reason: 'TEST 4: and the unreadable entry survives a real update — '
                'both behaviours coexist.');

    // ⭐ THE OTHER HALF: an entry the snapshot never mentions is not the
    // snapshot's to remove. This is the clobber, at store level.
    await store.save([rec('keep-me', DateTime(2026, 9, 1))]);
    final afterAbsent = jsonDecode(prefs.getString(kEventStorageKey)!) as List;
    final idsAbsent = afterAbsent.whereType<Map>().map((e) => e['id']).toList();
    expect(idsAbsent, contains('edit-me'),
        reason: '⛔ THE CLOBBER, on the fallback store. Absence from a '
                'snapshot means the caller never knew about the record, NOT '
                'that the user deleted it. Removal is an operation '
                '(`clearAll`), never a side effect of a save.');
    expect(idsAbsent, contains('bad-1'),
        reason: 'TEST 4: the unreadable entry is still carried through.');

    // ── a WHOLLY unreadable payload is quarantined, not overwritten ──────
    await prefs.clear();
    await prefs.setString(kEventStorageKey, 'this is not json at all');
    await store.save([rec('new-1', DateTime(2026, 9, 3))]);

    expect(prefs.getString(kEventPayloadQuarantineKey), 'this is not json at all',
        reason: 'TEST 4: ⛔ no per-entry pass can rescue a payload that will '
                'not decode at all. Preserved wholesale before the overwrite, '
                'in the same shape and for the same reason as the '
                'active-marker quarantine — the bytes are cheap and the loss '
                'is irreversible.');
    final after3 = jsonDecode(prefs.getString(kEventStorageKey)!) as List;
    expect(after3.whereType<Map>().map((e) => e['id']), ['new-1'],
        reason: 'TEST 4: and the new record is still written — a quarantine '
                'must not gate capture.');
  });
}
