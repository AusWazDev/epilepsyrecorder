import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/backup.dart';
import 'package:medical_event_recorder/models/event_record.dart';

EventRecord rec(String id, String iso) => EventRecord(
      id: id,
      timestamp: DateTime.parse(iso),
      duration: DurationCategory.oneToFive,
      feelings: const ['Just tired'],
      referralRequired: true,
      notes: 'note $id',
      eventType: EventType.absence,
      severity: EventSeverity.moderate,
      triggers: const ['Stress'],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('envelope', () {
    test('round-trips every field', () {
      final records = [
        rec('a', '2026-01-03T08:00:00.000'),
        rec('b', '2026-08-18T19:30:00.000'),
      ];
      final parsed = parseBackup(buildBackupJson(records));

      expect(parsed.isValid, isTrue);
      expect(parsed.problem, isNull);
      expect(parsed.schemaVersion, kBackupSchemaVersion);
      expect(parsed.declaredCount, 2);
      expect(parsed.records.length, 2);
      expect(parsed.exportedAt, isNotNull);

      final a = parsed.records.firstWhere((r) => r.id == 'a');
      expect(a.timestamp, DateTime.parse('2026-01-03T08:00:00.000'));
      expect(a.duration, DurationCategory.oneToFive);
      expect(a.eventType, EventType.absence);
      expect(a.severity, EventSeverity.moderate);
      expect(a.feelings, ['Just tired']);
      expect(a.triggers, ['Stress']);
      expect(a.referralRequired, isTrue);
      expect(a.notes, 'note a');
    });

    test('is an envelope, not a bare array', () {
      final decoded =
          jsonDecode(buildBackupJson([rec('a', '2026-01-03T08:00:00.000')]));
      expect(decoded, isA<Map>());
      expect(decoded['format'], kBackupFormatId);
      expect(decoded['schemaVersion'], isA<int>());
      expect(decoded['recordCount'], 1);
      expect(decoded['records'], isA<List>());
    });
  });

  group('merge', () {
    test('dedups by id and never overwrites what is already here', () {
      final existing = [
        rec('keep-1', '2026-02-01T10:00:00.000'),
        rec('keep-2', '2026-02-02T10:00:00.000'),
      ];
      final backup = parseBackup(buildBackupJson([
        rec('keep-1', '2026-02-01T10:00:00.000'),
        rec('new-1', '2026-03-01T10:00:00.000'),
        rec('new-2', '2026-03-02T10:00:00.000'),
      ]));

      final plan = planRestore(existing, backup);

      expect(plan.inBackup, 3);
      expect(plan.alreadyPresent, 1);
      expect(plan.toAdd, 2);
      expect(plan.merged.length, 4);
      expect(plan.merged.map((r) => r.id).toSet(),
          {'keep-1', 'keep-2', 'new-1', 'new-2'});
      expect(plan.merged.where((r) => r.id == 'keep-1').length, 1);
      expect(plan.merged.first.id, 'new-2');
    });

    test('clean install merges against nothing', () {
      final backup = parseBackup(buildBackupJson([
        rec('a', '2026-01-03T08:00:00.000'),
        rec('b', '2026-08-18T19:30:00.000'),
      ]));
      final plan = planRestore(const [], backup);
      expect(plan.alreadyPresent, 0);
      expect(plan.toAdd, 2);
      expect(plan.earliest, DateTime.parse('2026-01-03T08:00:00.000'));
      expect(plan.latest, DateTime.parse('2026-08-18T19:30:00.000'));
    });

    test('a backup with nothing new to add is detected', () {
      final existing = [rec('a', '2026-01-03T08:00:00.000')];
      final plan = planRestore(existing, parseBackup(buildBackupJson(existing)));
      expect(plan.addsNothing, isTrue);
      expect(plan.toAdd, 0);
    });
  });

  group('refuses bad input and leaves stored data untouched', () {
    const untouched = '[{"id":"live","timestamp":"2026-05-05T05:05:00.000",'
        '"duration":"lt1","feelings":[],"referralRequired":false,"notes":"live",'
        '"eventType":"seizure","severity":"mild","triggers":[]}]';

    Future<void> expectRefused(String raw, BackupProblem problem) async {
      SharedPreferences.setMockInitialValues({kEventStorageKey: untouched});
      final before =
          (await SharedPreferences.getInstance()).getString(kEventStorageKey);

      final parsed = parseBackup(raw);
      expect(parsed.isValid, isFalse);
      expect(parsed.problem, problem);
      expect(parsed.records, isEmpty);
      expect(parsed.message, isNotEmpty);

      final after =
          (await SharedPreferences.getInstance()).getString(kEventStorageKey);
      expect(after, before, reason: 'stored payload must be untouched');
      expect((await EventStore().load()).single.id, 'live');
    }

    test('corrupt or truncated JSON', () async {
      await expectRefused('{"format":"medical-event-recorder-backup", "rec',
          BackupProblem.unreadable);
      await expectRefused('not json at all', BackupProblem.unreadable);
    });

    test('valid JSON from another app', () async {
      await expectRefused(jsonEncode({'app': 'something-else', 'items': []}),
          BackupProblem.notABackup);
      await expectRefused('[{"id":"x"}]', BackupProblem.notABackup);
    });

    test('schema newer than this build understands', () async {
      await expectRefused(
        jsonEncode({
          'format': kBackupFormatId,
          'schemaVersion': kBackupSchemaVersion + 1,
          'records': [],
        }),
        BackupProblem.unsupportedSchema,
      );
    });
  });

  test('unreadable records inside a valid backup are counted, not dropped',
      () {
    final good = rec('good', '2026-04-04T04:00:00.000').toMap();
    final bad2 = Map<String, dynamic>.from(good);
    bad2['id'] = 'bad-2';
    bad2.remove('timestamp');

    final parsed = parseBackup(jsonEncode({
      'format': kBackupFormatId,
      'schemaVersion': kBackupSchemaVersion,
      'recordCount': 4,
      'records': [
        good,
        {...good, 'id': 'bad-1', 'timestamp': 'not-a-date'},
        bad2,
        'not even a map',
      ],
    }));

    expect(parsed.isValid, isTrue);
    expect(parsed.records.length, 1);
    expect(parsed.unreadableRecords, 3);
    expect(planRestore(const [], parsed).unreadable, 3);
  });

  group('rollback key', () {
    // These assert the non-iOS branch of writeEventPayload, which is what the
    // Windows/macOS test host exercises. On iOS the rollback copy is
    // deliberately never written, because the native Swift capture path writes
    // the primary key without going through writeEventPayload — see the guard
    // and its comment in event_record.dart.
    test('absent on first save, holds previous payload after the second',
        () async {
      SharedPreferences.setMockInitialValues({});
      final store = EventStore();
      final prefs = await SharedPreferences.getInstance();

      await store.save([rec('first', '2026-01-01T01:00:00.000')]);
      expect(prefs.getString(kEventRollbackKey), isNull,
          reason: 'nothing to roll back to on first run');

      await store.save([
        rec('first', '2026-01-01T01:00:00.000'),
        rec('second', '2026-01-02T01:00:00.000'),
      ]);

      final rollback = prefs.getString(kEventRollbackKey);
      expect(rollback, isNotNull);
      expect(jsonDecode(rollback!), hasLength(1));
      expect(jsonDecode(rollback)[0]['id'], 'first');
      expect((await store.load()).length, 2);
    });
  });
}
