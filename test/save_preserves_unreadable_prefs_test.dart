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

    // ── deletion still works ─────────────────────────────────────────────
    await prefs.clear();
    await prefs.setString(
      kEventStorageKey,
      jsonEncode([
        rec('keep-me', DateTime(2026, 9, 1)).toMap(),
        rec('delete-me', DateTime(2026, 9, 2)).toMap(),
        unreadableEntry,
      ]),
    );
    final kept =
        (await store.load()).where((r) => r.id != 'delete-me').toList();
    await store.save(kept);

    final after2 = jsonDecode(prefs.getString(kEventStorageKey)!) as List;
    final ids2 = after2.whereType<Map>().map((e) => e['id']).toList();
    expect(ids2, isNot(contains('delete-me')),
        reason: 'TEST 4: ⚠️ no resurrection here either. Deletion is a real '
                'feature on both boot paths.');
    expect(ids2, contains('bad-1'),
        reason: 'TEST 4: and the unreadable entry survives a genuine deletion '
                '— both behaviours coexist.');

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
