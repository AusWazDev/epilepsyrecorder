import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/models/backup.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/models/vocabulary.dart';

/// What a restore onto a FRESH INSTALL does to the user's own lists.
///
/// ## THE QUESTION
///
/// A backup carries records, medication notes, conditions and the
/// type-to-condition mapping. It carries NO vocabulary state. So what happens
/// to (a) entries the user added themselves, and (b) seeded entries the user
/// hid, when the backup is restored onto a device that has never seen them?
///
/// ## ⛔ PREDICTION, WRITTEN BEFORE THE FIRST RUN (24 September 2026)
///
/// Read from the code, not yet run: `observationRowFor` and `triggerRowFor`
/// are called only by the schema MIGRATIONS, `SqliteEventStore.save` inserts
/// `event` rows and nothing else, and HomeScreen's restore loop says outright
/// *"Restore does not create vocabulary rows"*. So the prediction is:
///
///   custom observation, trigger, event type   NO ROW AT ALL on the new device
///                                             (not even `is_active: 0`)
///   a seeded entry hidden on the old device   ACTIVE again on the new one
///   the records themselves                    intact, values verbatim
///
/// If any of these is wrong, the test goes red and the prediction was wrong.
///
/// ## ⛔ WHY "ABSENT" AND "INACTIVE" ARE ASSERTED SEPARATELY
///
/// A restore that recreated NOTHING would pass a naive "the custom values are
/// not active" check, and so would a restore that recreated them hidden. Those
/// are different outcomes for a user. So:
///   * control 1 proves the restore did something: the records arrive intact;
///   * control 2 proves the query can see each state, on the OLD device, where
///     the custom entries exist and are active and the hidden one is inactive;
///   * control 3 proves the "absent" check can fail: add the same custom value
///     on the new device and the same lookup must then find a row.
///
/// ## ⚠️ WHAT THIS DRIVES, AND WHAT IT DOES NOT
///
/// It drives the calls that persist a restore — `parseBackup`, `planRestore`,
/// `SqliteEventStore.save` — against the REAL schema. It does NOT drive
/// HomeScreen's `onRestore`, whose remaining loop touches only conditions and
/// assignments to event types the device ALREADY has. That the loop writes no
/// vocabulary row rests on reading it, not on this test.
///
/// ## ISOLATION
///
/// Two temp-FILE databases, one per device. NOT `inMemoryDatabasePath`, which
/// is one database per test process and would silently make the two devices
/// the same device.

const _customObservation = 'Metallic taste before it starts';
const _customTrigger = 'Strobe lights at the gym';
const _customEventType = 'Staring spell (my own word for it)';

Future<Database> _openDevice(Directory dir, String name) async {
  return databaseFactoryFfi.openDatabase(
    '${dir.path}${Platform.pathSeparator}$name.db',
    options: OpenDatabaseOptions(
      version: kSqliteSchemaVersion,
      onCreate: (d, _) => createSchema(d),
      onUpgrade: upgradeSchema,
    ),
  );
}

/// Null when the table has no row with this value; otherwise its active flag.
Future<bool?> _activeFlag(Database db, String table, String value) async {
  final hits = (await loadVocabulary(db, table)).where((e) => e.value == value);
  return hits.isEmpty ? null : hits.first.isActive;
}

void main() {
  sqfliteFfiInit();

  late Directory dir;
  late Database oldDevice;
  late Database newDevice;
  late String hiddenSeeded;
  late EventRecord record;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mer_restore_vocab_');
    oldDevice = await _openDevice(dir, 'old');
    newDevice = await _openDevice(dir, 'new');

    // THE OLD DEVICE: the user adds three entries of their own and hides one
    // seeded observation.
    await addUserEntry(oldDevice, kObservationTable, _customObservation);
    await addUserEntry(oldDevice, kTriggerTable, _customTrigger);
    await addUserEntry(oldDevice, kEventTypeTable, _customEventType);
    final seeded = (await loadVocabulary(oldDevice, kObservationTable))
        .firstWhere((e) => e.isSeeded && e.isActive);
    hiddenSeeded = seeded.value;
    await setActive(oldDevice, kObservationTable, seeded, false);

    record = EventRecord(
      id: 'restore-vocab-1',
      timestamp: DateTime(2026, 9, 20, 9),
      duration: null,
      feelings: const <String>[_customObservation],
      triggers: const <String>[_customTrigger],
      referralRequired: false,
      notes: '',
      eventType: _customEventType,
    );
    await SqliteEventStore(oldDevice).save(<EventRecord>[record]);
  });

  tearDown(() async {
    await oldDevice.close();
    await newDevice.close();
    try {
      await dir.delete(recursive: true);
    } catch (_) {/* Windows can hold the file briefly; the OS cleans temp */}
  });

  Future<void> restoreOntoNewDevice() async {
    final json = buildBackupJson(await SqliteEventStore(oldDevice).load());
    final plan = planRestore(const <EventRecord>[], parseBackup(json));
    await SqliteEventStore(newDevice).save(plan.merged);
  }

  test('control 2: on the OLD device the query sees every state', () async {
    expect(await _activeFlag(oldDevice, kObservationTable, _customObservation),
        isTrue, reason: 'custom observation should exist and be offered');
    expect(await _activeFlag(oldDevice, kTriggerTable, _customTrigger),
        isTrue, reason: 'custom trigger should exist and be offered');
    expect(await _activeFlag(oldDevice, kEventTypeTable, _customEventType),
        isTrue, reason: 'custom event type should exist and be offered');
    expect(await _activeFlag(oldDevice, kObservationTable, hiddenSeeded),
        isFalse, reason: 'the hidden seeded entry should read as hidden');
  }, timeout: const Timeout(Duration(seconds: 45)));

  test('control 1: the restore itself works — the record arrives verbatim',
      () async {
    await restoreOntoNewDevice();
    final restored = await SqliteEventStore(newDevice).load();
    expect(restored.map((r) => r.id), <String>['restore-vocab-1'],
        reason: 'a restore that wrote nothing must fail here');
    expect(restored.single.feelings, <String>[_customObservation]);
    expect(restored.single.triggers, <String>[_customTrigger]);
    expect(restored.single.eventType, _customEventType);
  }, timeout: const Timeout(Duration(seconds: 45)));

  test('FINDING: custom entries have NO ROW on the new device', () async {
    await restoreOntoNewDevice();
    expect(await _activeFlag(newDevice, kObservationTable, _customObservation),
        isNull, reason: 'predicted absent; non-null means a row was created');
    expect(await _activeFlag(newDevice, kTriggerTable, _customTrigger),
        isNull, reason: 'predicted absent; non-null means a row was created');
    expect(await _activeFlag(newDevice, kEventTypeTable, _customEventType),
        isNull, reason: 'predicted absent; non-null means a row was created');
  }, timeout: const Timeout(Duration(seconds: 45)));

  test('FINDING: a seeded entry hidden on the old device is offered again',
      () async {
    await restoreOntoNewDevice();
    expect(await _activeFlag(newDevice, kObservationTable, hiddenSeeded),
        isTrue, reason: 'predicted reset to the seeded default (offered)');
  }, timeout: const Timeout(Duration(seconds: 45)));

  // ── RE-ADDING AFTER A RESTORE ── added 24 September 2026.
  //
  // Records hold vocabulary as TEXT (`feelings_json`, `triggers_json`), not as
  // ids, and as at 24 September 2026 nothing in lib/ reads the id join tables
  // at runtime. So the question is not "same id or a second id" but "does the
  // re-added entry's text match the text the records hold". `addUserEntry`
  // dedupes against vocabulary ROWS only, and after a restore there are none,
  // so what it stores is whatever the user types.

  Future<List<String>> valuesLike(Database db, String table, String v) async =>
      (await loadVocabulary(db, table))
          .where((e) => e.value.toLowerCase() == v.toLowerCase())
          .map((e) => e.value)
          .toList();

  test('RE-ADD, exact text: ONE entry, and it matches the records', () async {
    await restoreOntoNewDevice();
    await addUserEntry(newDevice, kObservationTable, _customObservation);
    await addUserEntry(newDevice, kObservationTable, _customObservation);
    expect(await valuesLike(newDevice, kObservationTable, _customObservation),
        <String>[_customObservation],
        reason: 'one row, whose value is the string the record already holds');
    final record = (await SqliteEventStore(newDevice).load()).single;
    expect(record.feelings, <String>[_customObservation]);
  }, timeout: const Timeout(Duration(seconds: 45)));

  test('RE-ADD, different case: ONE entry, and it does NOT match the records',
      () async {
    await restoreOntoNewDevice();
    final typed = _customObservation.toLowerCase();
    expect(typed, isNot(_customObservation), reason: 'the variant must differ');
    await addUserEntry(newDevice, kObservationTable, typed);
    expect(await valuesLike(newDevice, kObservationTable, _customObservation),
        <String>[typed],
        reason: 'no duplicate row, but its value is the new spelling');
    final record = (await SqliteEventStore(newDevice).load()).single;
    expect(record.feelings, <String>[_customObservation],
        reason: 'the record keeps the OLD spelling; nothing rewrites it');
  }, timeout: const Timeout(Duration(seconds: 45)));

  test('control 3: the absence check can fail — add the value and it is found',
      () async {
    await restoreOntoNewDevice();
    await addUserEntry(newDevice, kObservationTable, _customObservation);
    expect(await _activeFlag(newDevice, kObservationTable, _customObservation),
        isNotNull, reason: 'the same lookup must see a row once one exists');
  }, timeout: const Timeout(Duration(seconds: 45)));
}
