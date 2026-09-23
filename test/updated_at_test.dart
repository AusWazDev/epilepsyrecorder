import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/backup.dart';
import 'package:medical_event_recorder/models/capture_instruction.dart';
import 'package:medical_event_recorder/models/capture_inbox.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/services/ios_capture_bridge.dart';

/// `updatedAt` — schema v11, and the one rule that makes it mean anything.
///
/// ⛔ **IT RECORDS WHEN THE USER ACTED, NOT WHEN THE APP WROTE**, and the
/// difference is not cosmetic. A drain runs whenever the app next comes to the
/// foreground; the user acted when they tapped. Stamping `DateTime.now()` in a
/// drain would let **a device that merely launched outrank a device where
/// somebody actually edited something.**
///
/// ## ⚠️ WHY "NOT SET BY A DRAIN" WOULD HAVE BEEN THE WRONG RULE
///
/// `_endActiveEvent` is a button tapped INSIDE the app, and it routes through
/// the inbox deliberately — to keep Dart's main isolate the single writer of
/// the record list. **Three end surfaces on two platforms all reach storage
/// through the drain.** Drain does not mean no user; it means the write is
/// deferred. What distinguishes the cases is whether a user action is
/// ATTRIBUTABLE, and an inbox instruction is itself the evidence of one — it
/// even carries the time.
///
/// ## The three "when"s
///
///     timestamp   when it was LOGGED
///     occurredAt  when it HAPPENED
///     updatedAt   when it was last CHANGED
///
/// ⛔ **None of them means "when the row was written."**
///
/// ⭐ INERT. Nothing reads it — no restore change, no conflict screen, no
/// existing-wins change. Exactly `hidden` at v10.

const _channelName = 'au.com.notiva.mer/navigation';

EventRecord full(String id, DateTime ts, {DateTime? updatedAt}) => EventRecord(
      id: id,
      timestamp: ts,
      occurredAt: DateTime(2026, 8, 20, 9, 15),
      duration: DurationCategory.lt1,
      durationSeconds: null,
      detailsCompleted: true,
      feelings: const <String>['Tired'],
      triggers: const <String>['Stress'],
      referralRequired: true,
      notes: 'a note',
      eventType: 'seizure',
      severity: EventSeverity.moderate,
      rescueMedGiven: true,
      rescueMedHelped: RescueResponse.helped,
      rescueMedSecondDose: false,
      updatedAt: updatedAt,
    );

class _FakeIosHost {
  String? legacyRecords;
  bool legacyCleared = false;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(_channelName),
            (MethodCall call) async {
      switch (call.method) {
        case 'readLegacySharedRecords':
          return legacyRecords;
        case 'clearLegacySharedRecords':
          legacyCleared = true;
          return null;
      }
      return null;
    });
  }

  void remove() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(_channelName), null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. THE SCHEMA', () {
    late Directory tmp;
    var seq = 0;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });
    setUp(() async {
      tmp = await Directory.systemTemp.createTemp('mer_ua_');
    });
    tearDown(() async {
      if (tmp.existsSync()) await tmp.delete(recursive: true);
    });

    /// The phase-one table, frozen. A fixture built at the current version
    /// cannot fail, which is the whole reason this constant is copied rather
    /// than imported.
    const createEventSqlV1 = 'CREATE TABLE event ('
        'ordinal INTEGER NOT NULL, '
        'id TEXT NOT NULL, '
        'logged_at TEXT NOT NULL, '
        'occurred_at TEXT, '
        'duration_bucket TEXT, '
        'duration_seconds INTEGER, '
        'event_type TEXT, '
        'severity INTEGER, '
        'feelings_json TEXT, '
        'triggers_json TEXT, '
        'notes TEXT, '
        'referral_required INTEGER)';

    Future<Database> v1ThenUpgrade() async {
      final path = '${tmp.path}/mer_${seq++}.db';
      final v1 = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute(createSchemaMetaSql);
            await db.execute(createEventSqlV1);
            await putMeta(db, kMetaSchemaVersion, '1');
            await putMeta(db, kMetaMigrationState, 'migrated');
          },
        ),
      );
      await v1.insert('event', <String, Object?>{
        'ordinal': 0,
        'id': 'old',
        'logged_at': DateTime(2026, 8, 1, 9).toIso8601String(),
        'notes': 'predates the column',
        'referral_required': 0,
      });
      await v1.close();
      return databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: kSqliteSchemaVersion,
          onCreate: (db, _) => createSchema(db),
          onUpgrade: upgradeSchema,
        ),
      );
    }

    test('1a. v11 adds the column and a pre-existing row reads NULL', () async {
      final db = await v1ThenUpgrade();
      final cols = (await db.rawQuery('PRAGMA table_info(event)'))
          .map((r) => r['name'] as String)
          .toList();
      expect(cols, contains('updated_at'));
      expect(await getMeta(db, kMetaSchemaVersion), '11',
          reason: 'positive control: the upgrade ran to completion');

      final rows = await db.query('event');
      expect(rows, hasLength(1), reason: 'no row lost by the ALTER');
      // ⛔ NULL, NOT the logged time. Absent means UNKNOWN: this record
      // genuinely has no modification history and must read that way. A
      // migration that copied `logged_at` in here would be inventing one.
      expect(rows.single['updated_at'], isNull,
          reason: 'a record predating the column has no modification history, '
              'and `timestamp` is a different fact');
      await db.close();
    });

    test('1b. NEGATIVE CONTROL: the v1 fixture genuinely lacks the column',
        () async {
      final db = await databaseFactoryFfi.openDatabase(
        '${tmp.path}/mer_${seq++}.db',
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute(createSchemaMetaSql);
            await db.execute(createEventSqlV1);
          },
        ),
      );
      final cols = (await db.rawQuery('PRAGMA table_info(event)'))
          .map((r) => r['name'] as String)
          .toList();
      expect(cols, isNot(contains('updated_at')),
          reason: 'if the fixture already had it, 1a measures nothing');
      await db.close();
    });

    test('1c. it round-trips through the store, and NULL survives', () async {
      final db = await v1ThenUpgrade();
      final store = SqliteEventStore(db);
      final changed = DateTime(2026, 9, 1, 14, 30);
      await store.save(<EventRecord>[
        full('stamped', DateTime(2026, 8, 22, 18, 30), updatedAt: changed),
        full('unknown', DateTime(2026, 8, 23, 18, 30)),
      ]);
      final back = await store.load();
      // ⚠️ REBUILT 23 September 2026 · Brief 135R-2. This read
      // `expect(back, hasLength(2), reason: 'positive control')` and went red
      // when `save` became add-or-update. ⛔ IT WAS NOT TESTING WHAT THE
      // LENGTH SUGGESTED. `v1ThenUpgrade` seeds a row `'old'` to exercise the
      // v1 -> v11 upgrade, and the 2 was only reachable because a save used to
      // destroy every row its list did not name. ⭐ So the old assertion was
      // silently depending on the clobber, in a test about NULL survival.
      expect(back.map((r) => r.id), containsAll(['stamped', 'unknown']),
          reason: 'positive control: both written records must come back, or '
                  'the field assertions below are vacuous.');
      expect(back.map((r) => r.id), contains('old'),
          reason: '⭐ AND THE SEEDED ROW SURVIVES A SAVE THAT NEVER MENTIONED '
                  'IT — add-or-update, demonstrated incidentally by a fixture '
                  'that was not built to test it.');
      expect(back.firstWhere((r) => r.id == 'stamped').updatedAt, changed);
      expect(back.firstWhere((r) => r.id == 'unknown').updatedAt, isNull,
          reason: 'unknown must not become a value on the way through');
      await db.close();
    });
  });

  group('2. AN EDIT SETS IT, AND timestamp DOES NOT MOVE', () {
    test('2a. the two are independent facts', () {
      // The form and the wizard both preserve `timestamp` from the original —
      // `widget.existing?.timestamp ?? DateTime.now()` — which is correct for a
      // clinical record and is exactly why this field is needed.
      final logged = DateTime(2026, 8, 1, 9);
      final before = full('x', logged, updatedAt: logged);

      final edited = EventRecord(
        id: before.id,
        timestamp: before.timestamp, // preserved, as the screens preserve it
        occurredAt: before.occurredAt,
        duration: before.duration,
        durationSeconds: 187, // the edit
        detailsCompleted: before.detailsCompleted,
        feelings: before.feelings,
        triggers: before.triggers,
        referralRequired: before.referralRequired,
        notes: before.notes,
        eventType: before.eventType,
        severity: before.severity,
        rescueMedGiven: before.rescueMedGiven,
        rescueMedHelped: before.rescueMedHelped,
        rescueMedSecondDose: before.rescueMedSecondDose,
        hidden: before.hidden,
        updatedAt: DateTime(2026, 9, 5, 11),
      );

      expect(edited.timestamp, logged,
          reason: 'the log time must not drift on an edit');
      expect(edited.updatedAt, isNot(logged));
      expect(edited.updatedAt!.isAfter(edited.timestamp), isTrue,
          reason: 'positive control: the two really are different values');
    });

    test('2b. hiding stamps it, and the clock comes from the call site', () {
      final at = DateTime(2026, 9, 6, 8, 15);
      final before = full('h', DateTime(2026, 8, 1, 9));
      final after = before.withHidden(true, at: at);

      expect(after.hidden, isTrue);
      expect(after.updatedAt, at,
          reason: 'hiding is a change the user made; their most recent intent '
              'is what the field records');
      expect(after.timestamp, before.timestamp,
          reason: 'and the log time still does not drift');

      // Everything else, as a whole map minus the two keys this path exists to
      // change. Same shape as `rebuild_preserves_fields_test`.
      final b = before.toMap()
        ..remove('hidden')
        ..remove('updatedAt');
      final a = after.toMap()
        ..remove('hidden')
        ..remove('updatedAt');
      expect(a, b, reason: 'withHidden destroyed a field it was not meant to '
          'touch');
    });
  });

  group('5. THE BACKUP', () {
    test('5a. it travels, and an absent key restores to NULL', () {
      final changed = DateTime(2026, 9, 1, 14, 30);
      final parsed = parseBackup(buildBackupJson(<EventRecord>[
        full('stamped', DateTime(2026, 8, 22, 18, 30), updatedAt: changed),
        full('unknown', DateTime(2026, 8, 23, 18, 30)),
      ]));
      expect(parsed.isValid, isTrue, reason: 'positive control: it parsed');
      expect(parsed.records.firstWhere((r) => r.id == 'stamped').updatedAt,
          changed,
          reason: 'restore is merge-by-id and add-only, so on a fresh install '
              'the file is a full reconstruction');
      expect(parsed.records.firstWhere((r) => r.id == 'unknown').updatedAt,
          isNull);
    });

    test('5b. an OLD backup with the key absent restores to null', () {
      // Hand-built, because `buildBackupJson` now always writes the key and so
      // could never reproduce a pre-v11 file.
      final legacy = full('old', DateTime(2026, 8, 1, 9)).toMap()
        ..remove('updatedAt');
      expect(legacy.containsKey('updatedAt'), isFalse,
          reason: 'positive control: the fixture really is missing the key');

      final parsed = parseBackup(jsonEncode(<String, Object?>{
        'format': kBackupFormatId,
        'schemaVersion': kBackupSchemaVersion,
        'exportedAt': DateTime(2026, 8, 1).toIso8601String(),
        'recordCount': 1,
        'records': <Object?>[legacy],
      }));

      expect(parsed.isValid, isTrue,
          reason: 'positive control: treating the absent key as a fault would '
              'break every backup ever taken');
      expect(parsed.records.single.updatedAt, isNull,
          reason: 'absent means UNKNOWN, and it must equal the constructor '
              'default — see rebuild_preserves_fields_test test 3');
    });
  });
}
