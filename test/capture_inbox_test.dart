import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/capture_inbox.dart';
import 'package:medical_event_recorder/models/capture_instruction.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The capture inbox: single-writer for `epilepsy_event_records_v1`.
///
/// THE PROPERTY: Dart's main isolate is the only writer of the record list.
/// Every other capture path posts a fact.
///
/// Test 1 is the negative control and the reason the rest can be believed.
/// `_LegacyQuickLog` reproduces the shipped background-isolate write in shape,
/// and is asserted to LOSE a record that the inbox keeps. Without it, every
/// other test here could pass against a store that simply never raced.

/// The shipped `_handleStart` write, verbatim in shape: read the whole stored
/// list, insert, re-encode, and write it straight through `writeEventPayload`,
/// bypassing `EventStore`'s serialising queue entirely.
///
/// The read and the write are separate methods so the interleaving can be made
/// deliberate rather than left to chance — a probabilistic race would make this
/// control flaky, and a flaky control is worse than none.
class _LegacyQuickLog {
  Future<List<dynamic>> readList() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(kEventStorageKey);
    return raw == null || raw.isEmpty
        ? <dynamic>[]
        : jsonDecode(raw) as List<dynamic>;
  }

  Future<void> writeInserting(List<dynamic> staleList, EventRecord added) async {
    final prefs = await SharedPreferences.getInstance();
    staleList.insert(0, added.toMap());
    await writeEventPayload(prefs, jsonEncode(staleList));
  }
}

/// A store whose writes always fail, so the drain's verify-then-delete order
/// can be tested rather than asserted.
class _FailingStore extends EventStore {
  @override
  Future<void> save(List<EventRecord> records) async =>
      throw StateError('storage unavailable');
}

/// The shipped `_durationFromDiff`, transcribed verbatim from
/// `notification_service.dart` as it stood before the inbox removed it.
///
/// It is the ORACLE for test 9. Transcribed rather than imported because the
/// function no longer exists — the writer stopped computing buckets, which is
/// the point of the change. Keeping the original expressed the original way,
/// over `DateTime`s rather than an int, is what makes test 9 an equivalence
/// check rather than a restatement of the new implementation.
DurationCategory legacyDurationFromDiff(DateTime start, DateTime end) {
  final secs = end.difference(start).inSeconds;
  if (secs < 60) return DurationCategory.lt1;
  if (secs < 300) return DurationCategory.oneToFive;
  return DurationCategory.gt5;
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

Future<List<String>> inboxKeys() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  return prefs.getKeys().where((k) => k.startsWith(kInboxKeyPrefix)).toList()
    ..sort();
}

String startPayload(String id, DateTime at) => jsonEncode({
      'v': kInboxSchemaVersion,
      'kind': kInboxKindStart,
      'id': id,
      'at': at.toIso8601String(),
    });

String endPayload(String id, DateTime at, int seconds) => jsonEncode({
      'v': kInboxSchemaVersion,
      'kind': kInboxKindEnd,
      'id': id,
      'at': at.toIso8601String(),
      'seconds': seconds,
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final t0 = DateTime(2026, 8, 22, 18, 0, 0);

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // ── 1 ──────────────────────────────────────────────────────────────────────
  group('1. the loss this exists to close', () {
    test('NEGATIVE CONTROL: the shipped quick-log write loses a record '
        '(backlog item 13)', () async {
      final store = EventStore();
      await store.save(<EventRecord>[record('a', 1)]);

      final legacy = _LegacyQuickLog();

      // The background isolate reads the whole list...
      final stale = await legacy.readList();
      expect(stale, hasLength(1));

      // ...the main isolate saves through the queue in the meantime...
      await store.save(<EventRecord>[record('a', 1), record('b', 2)]);
      expect(await storedIds(), containsAll(<String>['a', 'b']));

      // ...and the background isolate then writes its stale-derived list.
      await legacy.writeInserting(stale, record('c', 3));

      final ids = await storedIds();
      expect(ids, isNot(contains('b')),
          reason: 'b is gone. The background isolate re-encoded a list it had '
              'read before the main isolate wrote, so its write silently '
              'reverted one. This is backlog item 13, reachable through '
              'ordinary use.');
      expect(ids, containsAll(<String>['a', 'c']));
    });

    test('the inbox survives the identical interleaving', () async {
      final store = EventStore();
      await store.save(<EventRecord>[record('a', 1)]);
      final prefs = await SharedPreferences.getInstance();

      // The background isolate posts a fact. It reads no record, so there is
      // no stale snapshot to write back.
      await writeStartInstruction(prefs, id: 'c', at: t0.add(const Duration(minutes: 3)));

      await store.save(<EventRecord>[record('a', 1), record('b', 2)]);

      final outcome = await drainInbox(
        prefs: prefs,
        store: store,
        loaded: await store.load(),
      );

      expect(outcome.wrote, isTrue);
      expect(await storedIds(), containsAll(<String>['a', 'b', 'c']),
          reason: 'nothing is lost: the only writer of the list is the main '
              'isolate, and it applied c on top of what it had');
    });
  });

  // ── 2, 3 ───────────────────────────────────────────────────────────────────
  group('2-3. the write path posts facts and touches no record', () {
    test('2. a start writes exactly one key and no record list', () async {
      final prefs = await SharedPreferences.getInstance();

      await writeStartInstruction(prefs, id: 'x', at: t0);

      final keys = await inboxKeys();
      expect(keys, hasLength(1));
      expect(keys.single, startsWith(kInboxKeyPrefix));
      expect(keys.single, isNot(contains('2026')),
          reason: 'no timestamp in the key: ordering comes from the payload, '
              'so a future non-Dart writer need not match a key format');

      final body = jsonDecode(prefs.getString(keys.single)!) as Map;
      expect(body['v'], kInboxSchemaVersion);
      expect(body['kind'], kInboxKindStart);
      expect(body['id'], 'x');
      expect(body.containsKey('seconds'), isFalse,
          reason: 'a start is a fact; duration is not one of its fields');

      expect(prefs.getString(kEventStorageKey), isNull,
          reason: 'the record list must be untouched by a writer');
    });

    test('3. an end writes one key carrying SECONDS, not a bucket', () async {
      final prefs = await SharedPreferences.getInstance();

      await writeEndInstruction(prefs, id: 'x', at: t0, seconds: 187);

      final keys = await inboxKeys();
      expect(keys, hasLength(1));

      final body = jsonDecode(prefs.getString(keys.single)!) as Map;
      expect(body['kind'], kInboxKindEnd);
      expect(body['seconds'], 187);
      for (final bucket in DurationCategory.values) {
        expect(body.values, isNot(contains(bucket.name)),
            reason: 'the bucket is a storage decision and belongs to the '
                'drain, so no bucket name may appear in an instruction');
      }

      expect(prefs.getString(kEventStorageKey), isNull);
    });
  });

  // ── 4, 5 ───────────────────────────────────────────────────────────────────
  group('4-5. apply, and replay without duplication', () {
    test('4. a start merges by id and applies the defaults', () {
      final entries = <InboxEntry>[
        parseInboxEntry('mer_inbox_1', startPayload('x', t0)),
      ];

      final first = applyInbox(const <EventRecord>[], entries);
      expect(first.changed, isTrue);
      expect(first.merged, hasLength(1));

      final made = first.merged.single;
      expect(made.id, 'x');
      expect(made.timestamp, t0);
      // Facts in, defaults here — exactly what _handleStart used to write.
      expect(made.duration, DurationCategory.lt1);
      expect(made.eventType, EventType.seizure);
      expect(made.severity, EventSeverity.mild);
      expect(made.feelings, isEmpty);
      expect(made.triggers, isEmpty);
      expect(made.notes, '');
      expect(made.referralRequired, isFalse);

      // Replay: a crash between the write and the delete must not duplicate.
      final second = applyInbox(first.merged, entries);
      expect(second.changed, isFalse);
      expect(second.merged, hasLength(1));
      expect(second.drainableKeys, hasLength(1),
          reason: 'a replayed key is still consumed, or it would never clear');
    });

    test('5. an end sets the duration, and replaying it is a no-op', () {
      final start = applyInbox(const <EventRecord>[], <InboxEntry>[
        parseInboxEntry('mer_inbox_1', startPayload('x', t0)),
      ]);

      final endEntries = <InboxEntry>[
        parseInboxEntry('mer_inbox_2',
            endPayload('x', t0.add(const Duration(seconds: 200)), 200)),
      ];

      final first = applyInbox(start.merged, endEntries);
      expect(first.changed, isTrue);
      expect(first.merged.single.duration, DurationCategory.oneToFive);
      expect(first.merged.single.timestamp, t0,
          reason: 'an end sets the duration and nothing else; the start time '
              'is the record\'s own');

      final second = applyInbox(first.merged, endEntries);
      expect(second.changed, isFalse);
      expect(second.merged.single.duration, DurationCategory.oneToFive);
    });
  });

  // ── 6 ──────────────────────────────────────────────────────────────────────
  test('6. a start applies before its end regardless of `at`', () {
    // The end carries an EARLIER `at` than the start, which is what a device
    // whose clock moved between the two captures produces. Sorting by `at`
    // alone would apply the end first and orphan it.
    final entries = <InboxEntry>[
      parseInboxEntry('mer_inbox_end',
          endPayload('x', t0.subtract(const Duration(hours: 2)), 400)),
      parseInboxEntry('mer_inbox_start', startPayload('x', t0)),
    ];

    final result = applyInbox(const <EventRecord>[], entries);

    expect(result.orphanEndIds, isEmpty,
        reason: 'the start must apply first even though its `at` is later, or '
            'a clock change turns a real capture into an orphan');
    expect(result.merged, hasLength(1));
    expect(result.merged.single.duration, DurationCategory.gt5);
  });

  // ── 7 ──────────────────────────────────────────────────────────────────────
  test('7. an orphan end is dropped and reported, never fabricated into a '
      'record', () {
    final entries = <InboxEntry>[
      parseInboxEntry('mer_inbox_1', endPayload('ghost', t0, 120)),
    ];

    final result = applyInbox(<EventRecord>[record('a', 1)], entries);

    expect(result.orphanEndIds, <String>['ghost']);
    expect(result.merged.map((r) => r.id), <String>['a'],
        reason: 'no record is invented: that would need a start time, and a '
            'wrong timestamp in a medical record is worse than a missing '
            'duration');
    expect(result.changed, isFalse);
    expect(result.drainableKeys, hasLength(1),
        reason: 'dropped deliberately, so the key is consumed rather than '
            'retried forever');
  });

  // ── 12 ─────────────────────────────────────────────────────────────────────
  group('12. an end whose start is deferred is held back, not dropped', () {
    // A start this build cannot read, and its end, which this build CAN read.
    // Dropping the end would lose a duration sitting three keys away.
    List<InboxEntry> pair() => <InboxEntry>[
          parseInboxEntry(
              '${kInboxKeyPrefix}deferred_start',
              jsonEncode({
                'v': kInboxSchemaVersion + 1,
                'kind': kInboxKindStart,
                'id': 'x',
                'at': t0.toIso8601String(),
              })),
          parseInboxEntry('${kInboxKeyPrefix}readable_end',
              endPayload('x', t0.add(const Duration(seconds: 400)), 400)),
        ];

    test('the end is deferred alongside its start, not orphaned', () {
      final result = applyInbox(const <EventRecord>[], pair());

      expect(result.orphanEndIds, isEmpty,
          reason: 'its start is present and readable, just not yet legible to '
              'this build — that is not an orphan');
      expect(result.deferredKeys,
          containsAll(<String>['${kInboxKeyPrefix}deferred_start',
              '${kInboxKeyPrefix}readable_end']));
      expect(result.deferReasons, contains(InboxDefer.awaitingDeferredStart),
          reason: 'reported as a deferral, distinctly from a drop, so the two '
              'stay separable in telemetry');
      expect(result.drainableKeys, isEmpty,
          reason: 'nothing may be deleted while either half is held back');
      expect(result.merged, isEmpty);
      expect(result.changed, isFalse);
    });

    test('both keys survive a drain, and neither is applied', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          '${kInboxKeyPrefix}deferred_start',
          jsonEncode({
            'v': kInboxSchemaVersion + 1,
            'kind': kInboxKindStart,
            'id': 'x',
            'at': t0.toIso8601String(),
          }));
      await prefs.setString('${kInboxKeyPrefix}readable_end',
          endPayload('x', t0.add(const Duration(seconds: 400)), 400));

      final outcome = await drainInbox(
        prefs: prefs,
        store: EventStore(),
        loaded: const <EventRecord>[],
      );

      expect(outcome.attempted, isFalse);
      expect(outcome.deferredCount, 2);
      expect(outcome.orphanEndIds, isEmpty);
      expect(await inboxKeys(), hasLength(2));
      expect(await storedIds(), isEmpty);
    });

    test('a later build that understands the kind applies both and gets the '
        'right duration', () {
      // The same two instructions, now both legible — which is what the newer
      // build sees. The end must land on the record its start creates.
      final understood = <InboxEntry>[
        parseInboxEntry('${kInboxKeyPrefix}deferred_start',
            startPayload('x', t0)),
        parseInboxEntry('${kInboxKeyPrefix}readable_end',
            endPayload('x', t0.add(const Duration(seconds: 400)), 400)),
      ];

      final result = applyInbox(const <EventRecord>[], understood);

      expect(result.orphanEndIds, isEmpty);
      expect(result.deferredKeys, isEmpty);
      expect(result.drainableKeys, hasLength(2));
      expect(result.merged, hasLength(1));
      expect(result.merged.single.id, 'x');
      expect(result.merged.single.timestamp, t0);
      expect(result.merged.single.duration, DurationCategory.gt5,
          reason: '400 seconds, so the duration the deferral preserved is the '
              'one that finally gets stored');
    });

    test('UNCHANGED PATH: an end matching nothing at all is still dropped and '
        'reported', () {
      // No record, and no deferred entry either. This is the deletion case the
      // orphan rule was written for, and it must behave exactly as before.
      final result = applyInbox(<EventRecord>[record('a', 1)], <InboxEntry>[
        parseInboxEntry('${kInboxKeyPrefix}1', endPayload('ghost', t0, 120)),
      ]);

      expect(result.orphanEndIds, <String>['ghost']);
      expect(result.deferReasons, isNot(contains(InboxDefer.awaitingDeferredStart)));
      expect(result.deferredKeys, isEmpty);
      expect(result.drainableKeys, hasLength(1),
          reason: 'a genuine orphan is consumed, not retried forever');
      expect(result.merged.map((r) => r.id), <String>['a']);
    });

    test('a malformed entry with an unreadable id cannot hold an end back', () {
      // The id is what makes the match possible. Without one, the end has
      // nothing to be held against and the orphan rule correctly applies.
      final result = applyInbox(const <EventRecord>[], <InboxEntry>[
        parseInboxEntry('${kInboxKeyPrefix}junk', 'not json at all'),
        parseInboxEntry('${kInboxKeyPrefix}end', endPayload('x', t0, 400)),
      ]);

      expect(result.deferReasons, contains(InboxDefer.malformed));
      expect(result.orphanEndIds, <String>['x'],
          reason: 'an unmatched end is an orphan; a deferred entry only rescues '
              'one when it carries the same id');
    });
  });

  // ── 8 ──────────────────────────────────────────────────────────────────────
  test('8. keys are deleted only after the write is confirmed', () async {
    final prefs = await SharedPreferences.getInstance();
    await writeStartInstruction(prefs, id: 'x', at: t0);
    expect(await inboxKeys(), hasLength(1));

    final failed = await drainInbox(
      prefs: prefs,
      store: _FailingStore(),
      loaded: const <EventRecord>[],
    );

    expect(failed.attempted, isTrue);
    expect(failed.wrote, isFalse);
    expect(failed.records.map((r) => r.id), <String>['x'],
        reason: 'the user still sees the capture; the list on screen is ahead '
            'of storage, which is what the unsaved-events banner means');
    expect(await inboxKeys(), hasLength(1),
        reason: 'THE ORDER IS THE POINT: clearing before the write is '
            'confirmed would lose the capture outright. The key survives so '
            'the next foreground retries.');

    final ok = await drainInbox(
      prefs: prefs,
      store: EventStore(),
      loaded: const <EventRecord>[],
    );

    expect(ok.wrote, isTrue);
    expect(await inboxKeys(), isEmpty);
    expect(await storedIds(), <String>['x']);
  });

  // ── 9 ──────────────────────────────────────────────────────────────────────
  test('9. seconds->bucket equals the shipped _durationFromDiff at every '
      'boundary', () {
    for (final seconds in <int>[0, 59, 60, 299, 300, 301]) {
      expect(
        bucketFromSeconds(seconds),
        legacyDurationFromDiff(t0, t0.add(Duration(seconds: seconds))),
        reason: 'the mapping must be preserved exactly at $seconds seconds; a '
            'silent shift here would rewrite the meaning of every stored '
            'duration',
      );
    }
    // Pinned explicitly as well, so a matching pair of wrong implementations
    // still fails.
    expect(bucketFromSeconds(59), DurationCategory.lt1);
    expect(bucketFromSeconds(60), DurationCategory.oneToFive);
    expect(bucketFromSeconds(299), DurationCategory.oneToFive);
    expect(bucketFromSeconds(300), DurationCategory.gt5);
  });

  // ── 10 ─────────────────────────────────────────────────────────────────────
  test('10. an unreadable version or kind is left in place, not applied',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('${kInboxKeyPrefix}newer',
        jsonEncode({'v': 2, 'kind': 'start', 'id': 'x', 'at': t0.toIso8601String()}));
    await prefs.setString('${kInboxKeyPrefix}sideways',
        jsonEncode({'v': 1, 'kind': 'sideways', 'id': 'y', 'at': t0.toIso8601String()}));

    final result = applyInbox(const <EventRecord>[], readInboxEntries(prefs));

    expect(result.deferredKeys, hasLength(2));
    expect(
        result.deferReasons,
        containsAll(<InboxDefer>[
          InboxDefer.unsupportedVersion,
          InboxDefer.unknownKind,
        ]));
    expect(result.drainableKeys, isEmpty);
    expect(result.merged, isEmpty);
    expect(result.changed, isFalse);

    final outcome = await drainInbox(
      prefs: prefs,
      store: EventStore(),
      loaded: const <EventRecord>[],
    );

    expect(outcome.attempted, isFalse);
    expect(outcome.deferredCount, 2);
    expect(await inboxKeys(), hasLength(2),
        reason: 'an instruction a newer build wrote is data this build does '
            'not understand, not garbage. Never deleted, never guessed at.');
  });

  // ── 11 ─────────────────────────────────────────────────────────────────────
  test('11. a Z-suffixed and a naive-local `at` for the same instant agree',
      () {
    final local = DateTime(2026, 8, 22, 18, 18, 35);
    final naiveIso = local.toIso8601String();
    final utcIso = local.toUtc().toIso8601String();

    expect(utcIso.endsWith('Z'), isTrue, reason: 'the Swift shape');
    expect(naiveIso.endsWith('Z'), isFalse, reason: 'the Dart shape');

    // NEGATIVE CONTROL for the trap itself: under a bare DateTime.parse the two
    // shapes carry different wall clocks, which is what DateFormat renders and
    // what the ten-hour display bug fixed in e48d91b actually was. Vacuous on a
    // machine at UTC+0, hence the guard rather than an unconditional assert.
    if (DateTime.now().timeZoneOffset != Duration.zero) {
      expect(DateTime.parse(utcIso).hour,
          isNot(equals(DateTime.parse(naiveIso).hour)),
          reason: 'if this ever stops differing the trap is gone, and so is '
              'the reason for this test');
    }

    final result = applyInbox(const <EventRecord>[], <InboxEntry>[
      parseInboxEntry('mer_inbox_naive', startPayload('naive', local)),
      parseInboxEntry(
          '${kInboxKeyPrefix}utc',
          jsonEncode({
            'v': kInboxSchemaVersion,
            'kind': kInboxKindStart,
            'id': 'utc',
            'at': utcIso,
          })),
    ]);

    final byId = {for (final r in result.merged) r.id: r};
    expect(byId, hasLength(2));
    expect(byId['utc']!.timestamp, equals(byId['naive']!.timestamp),
        reason: 'both shapes describe one instant and must normalise to one '
            'local DateTime — parseInstructionAt does toLocal(), exactly as '
            'EventRecord._parseTimestamp does');
    expect(byId['utc']!.timestamp.isUtc, isFalse,
        reason: 'a UTC DateTime would display ten hours early in AEST');
  });

  // ── §7 verification, not one of the eleven ─────────────────────────────────
  test('VERIFICATION: epilepsy_event_records_v1 has exactly one writer',
      () async {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();

    expect(files, isNotEmpty, reason: 'positive control: files were scanned');

    for (final file in files) {
      final path = file.path.replaceAll(r'\', '/');
      // event_record.dart owns the store: it defines writeEventPayload and
      // EventStore._write is the one caller, behind the serialising queue.
      if (path.endsWith('lib/models/event_record.dart')) continue;
      final src = file.readAsStringSync();
      if (src.contains('writeEventPayload(') ||
          src.contains('setString(kEventStorageKey')) {
        offenders.add(path);
      }
    }

    expect(offenders, isEmpty,
        reason: 'a second writer of the record list defeats the whole change. '
            'Scanned ${files.length} files under lib/.');
  });
}
