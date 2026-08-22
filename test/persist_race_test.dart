import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/backup.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The capture-path write race, and the optimistic-write warning.
///
/// Every record lives in one JSON string under one key, so a save is
/// read-modify-write over the whole history and two overlapping saves are a lost
/// update. The quick-record button was re-entrant — it awaited a 200 ms flash
/// with the button still live — so taps 150 ms apart each started their own
/// save. Live device data showed 27 Dart-written records from about 29 taps.
///
/// The negative controls are the point. `_LegacyStore` below reproduces the
/// shipped code exactly, and each is asserted to LOSE the record that the real
/// store keeps. Without them, these tests would pass against a store that
/// simply never raced.

/// The shipped save path, verbatim in shape: no queue, and the payload encoded
/// AFTER an await, from the caller's live list.
class _LegacyStore {
  Future<void> save(List<EventRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    // The await above is why this is wrong: by the time it resumes, `records`
    // is whatever the caller has since mutated it into.
    await prefs.setString(
      kEventStorageKey,
      jsonEncode(records.map((e) => e.toMap()).toList()),
    );
  }
}

/// A store that snapshots correctly but has no queue, with injectable write
/// latency so the landing order can be inverted deliberately.
///
/// Isolates the queue as the single variable: any loss it shows is caused by
/// unordered writes, not by the snapshot hazard `_LegacyStore` demonstrates.
class _UnqueuedStore {
  _UnqueuedStore(this.delay);

  final Duration delay;

  Future<void> save(List<EventRecord> records) async {
    final payload = jsonEncode(records.map((e) => e.toMap()).toList());
    await Future<void>.delayed(delay);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kEventStorageKey, payload);
  }
}

EventRecord record(String id, int minute) => EventRecord(
      id: id,
      timestamp: DateTime(2026, 8, 22, 18, minute),
      duration: DurationCategory.lt1,
      feelings: const <String>[],
      referralRequired: false,
      notes: '',
    );

Future<List<String>> storedIds() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  final raw = prefs.getString(kEventStorageKey);
  if (raw == null || raw.isEmpty) return <String>[];
  return (jsonDecode(raw) as List<dynamic>)
      .map((e) => (e as Map)['id'] as String)
      .toList();
}

/// A store whose writes always fail, for the warning tests.
class _FailingStore extends EventStore {
  @override
  Future<void> save(List<EventRecord> records) async =>
      throw StateError('storage unavailable');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('save takes a snapshot at the moment of the call', () {
    // This is the property that closes all three reported hazards at once: the
    // list being mutated in place by insert, the list being replaced wholesale
    // by _loadRecords, and an earlier save landing after a later one. If a save
    // cannot see later mutations, it cannot write the wrong generation.

    test('LEGACY (negative control) encodes the live list and loses the '
        'snapshot', () async {
      final records = <EventRecord>[record('first', 1)];

      final pending = _LegacyStore().save(records);
      // Simulates the next tap arriving while the save is in flight.
      records.insert(0, record('second', 2));
      await pending;

      expect(await storedIds(), <String>['second', 'first'],
          reason: 'the shipped code encodes after an await, so it serialises '
              'records the caller never handed it — this is the hazard');
    });

    test('a save writes what it was given, not what the list became', () async {
      final records = <EventRecord>[record('first', 1)];

      final pending = EventStore().save(records);
      records.insert(0, record('second', 2));
      await pending;

      expect(await storedIds(), <String>['first'],
          reason: 'the payload is encoded synchronously at the call, so a '
              'later mutation cannot reach into a write already started');
    });
  });

  group('concurrent saves are serialised and the last call wins', () {
    test('UNQUEUED (negative control) loses the newer event when an earlier '
        'write is slower', () async {
      // The exact reported mechanism. Snapshotting is held constant here so the
      // only variable is the queue: without one, nothing orders the setString
      // calls, so a save launched first but slower lands LAST and overwrites a
      // newer generation. This is what cost two of about 29 taps on the device.
      final first = _UnqueuedStore(const Duration(milliseconds: 40))
          .save(<EventRecord>[record('a', 1)]);
      final second = _UnqueuedStore(const Duration(milliseconds: 1))
          .save(<EventRecord>[record('b', 2), record('a', 1)]);
      await Future.wait([first, second]);

      expect(await storedIds(), <String>['a'],
          reason: 'the slower earlier write landed last and erased record b — '
              'the lost update this fix exists to prevent');
    });

    test('the real store is immune to that ordering regardless of latency',
        () async {
      // Same launch pattern against the real store. The queue means the second
      // call cannot start until the first has finished, so latency cannot
      // reorder them.
      final store = EventStore();
      final first  = store.save(<EventRecord>[record('a', 1)]);
      final second = store.save(<EventRecord>[record('b', 2), record('a', 1)]);
      await Future.wait([first, second]);

      expect(await storedIds(), <String>['b', 'a']);
    });

    test('the real store applies saves in call order', () async {
      final one   = <EventRecord>[record('a', 1)];
      final two   = <EventRecord>[record('b', 2), record('a', 1)];
      final three = <EventRecord>[record('c', 3), record('b', 2), record('a', 1)];

      final store = EventStore();
      // Launched together, deliberately not awaited in turn.
      final futures = <Future<void>>[
        store.save(one),
        store.save(two),
        store.save(three),
      ];
      await Future.wait(futures);

      expect(await storedIds(), <String>['c', 'b', 'a'],
          reason: 'the newest call must be the one left in storage');
    });

    test('completion order matches call order', () async {
      final store = EventStore();
      final completed = <int>[];

      await Future.wait(<Future<void>>[
        store.save([record('a', 1)]).then((_) => completed.add(1)),
        store.save([record('b', 2)]).then((_) => completed.add(2)),
        store.save([record('c', 3)]).then((_) => completed.add(3)),
      ]);

      expect(completed, <int>[1, 2, 3],
          reason: 'two writes must never be in flight at once');
    });

    test('a load cannot jump ahead of a queued write', () async {
      // The resume hazard: _handleResume calls _loadRecords, which assigns the
      // result straight over the in-memory list. A read that overtook a pending
      // write would return pre-write state and drop a just-logged event.
      final store = EventStore();
      final pendingWrite = store.save([record('b', 2), record('a', 1)]);
      final read = store.load();

      final loaded = await read;
      await pendingWrite;

      expect(loaded.map((r) => r.id), <String>['b', 'a'],
          reason: 'the load must observe the write queued before it');
    });
  });

  group('a failed write surfaces a warning and keeps the record', () {
    test('persistEvents reports failure and raises the warning', () async {
      final records = <EventRecord>[record('a', 1), record('b', 2)];

      final ok = await persistEvents(_FailingStore(), records);

      expect(ok, isFalse);
      expect(await hasUnsavedEvents(), isTrue);
    });

    test('the record is NOT removed from the list on failure', () async {
      final records = <EventRecord>[record('a', 1), record('b', 2)];

      await persistEvents(_FailingStore(), records);

      expect(records, hasLength(2),
          reason: 'an event vanishing in front of the person who just logged '
              'it is the worst outcome available, even when truthful');
      expect(records.map((r) => r.id), <String>['a', 'b']);
    });

    test('persistEvents never throws, so it cannot escape into a discarded '
        'Future', () async {
      await expectLater(
          persistEvents(_FailingStore(), <EventRecord>[record('a', 1)]),
          completion(isFalse));
    });

    test('the warning survives into a later session', () async {
      await persistEvents(_FailingStore(), <EventRecord>[record('a', 1)]);

      // hasUnsavedEvents reloads from storage rather than trusting a cached
      // instance, which is what makes it survive a restart.
      expect(await hasUnsavedEvents(), isTrue);
    });
  });

  group('a successful write clears the warning', () {
    test('a good save after a failed one clears it', () async {
      final records = <EventRecord>[record('a', 1)];

      await persistEvents(_FailingStore(), records);
      expect(await hasUnsavedEvents(), isTrue);

      final ok = await persistEvents(EventStore(), records);

      expect(ok, isTrue);
      expect(await hasUnsavedEvents(), isFalse);
      expect(await storedIds(), <String>['a'],
          reason: 'the retry must actually write the records, not just clear '
              'the flag');
    });

    test('a successful save leaves no warning behind', () async {
      final ok = await persistEvents(EventStore(), <EventRecord>[record('a', 1)]);

      expect(ok, isTrue);
      expect(await hasUnsavedEvents(), isFalse);
    });
  });

  group('the warning banner\'s advice is actually true', () {
    // The banner tells the user to use Back up now if the retry keeps failing.
    // That is only sound if the backup serialises the in-memory list. If it
    // ever read from storage instead, it would write a file missing exactly the
    // events the banner is about — sending someone to a rescue that quietly
    // fails. This pins it.
    test('a backup taken while a write is failing still contains the unsaved '
        'events', () async {
      final records = <EventRecord>[record('a', 1)];

      // 'a' reaches storage; 'b' does not.
      await persistEvents(EventStore(), records);
      records.insert(0, record('b', 2));
      final ok = await persistEvents(_FailingStore(), records);

      expect(ok, isFalse);
      expect(await hasUnsavedEvents(), isTrue);
      expect(await storedIds(), <String>['a'],
          reason: 'storage is behind the list on screen — the condition the '
              'banner reports');

      // What Back up now would produce, from the same list the home screen
      // hands it.
      final parsed = parseBackup(buildBackupJson(records));

      expect(parsed.isValid, isTrue, reason: parsed.message);
      expect(parsed.records.map((r) => r.id), <String>['b', 'a'],
          reason: 'the backup must include the event that failed to save, or '
              'the banner is advising a rescue that loses it');
    });
  });

  group('nothing about the stored payload changed', () {
    test('the key and the payload shape are as before', () async {
      final records = <EventRecord>[record('a', 1)];
      await persistEvents(EventStore(), records);

      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final raw = prefs.getString(kEventStorageKey);

      // Still a bare JSON array under the same key, each entry the same map.
      expect(raw, isNotNull);
      final decoded = jsonDecode(raw!);
      expect(decoded, isA<List<dynamic>>());
      expect((decoded as List).single, records.single.toMap());
    });

    test('a round trip through the store preserves the record exactly',
        () async {
      final original = record('a', 1);
      await persistEvents(EventStore(), <EventRecord>[original]);

      final loaded = await EventStore().load();

      expect(loaded.single.toMap(), original.toMap());
    });
  });
}
