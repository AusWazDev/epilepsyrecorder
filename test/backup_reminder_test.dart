import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/services/backup_service.dart';

EventRecord rec(String id, String iso) => EventRecord(
      id: id,
      timestamp: DateTime.parse(iso),
      duration: DurationCategory.lt1,
      feelings: const [],
      referralRequired: false,
      notes: '',
    );

/// Mirrors the decision backupShare makes, without the plugin: the share sheet
/// only counts as a backup when the platform reports it completed.
Future<void> simulateShare(ShareResultStatus status) async {
  if (backupCountsAsTaken(status)) await markBackupTaken();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final events = [
    rec('a', '2026-08-01T09:00:00.000'),
    rec('b', '2026-08-02T09:00:00.000'),
    rec('c', '2026-08-03T09:00:00.000'),
  ];

  group('only a completed share counts as a backup', () {
    test('success counts, dismissed and unavailable do not', () {
      expect(backupCountsAsTaken(ShareResultStatus.success), isTrue);
      expect(backupCountsAsTaken(ShareResultStatus.dismissed), isFalse);
      expect(backupCountsAsTaken(ShareResultStatus.unavailable), isFalse);
    });

    test('a CANCELLED share does not reset the reminder counter', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await eventsSinceLastBackup(events), 3);

      await simulateShare(ShareResultStatus.dismissed);

      expect(await eventsSinceLastBackup(events), 3,
          reason: 'cancelling the sheet must not clear the reminder');
      expect((await SharedPreferences.getInstance()).getString(kLastBackupKey),
          isNull,
          reason: 'no backup marker may be written for a cancelled share');
    });

    test('a share the platform cannot report on does not reset it either',
        () async {
      SharedPreferences.setMockInitialValues({});
      await simulateShare(ShareResultStatus.unavailable);
      expect(await eventsSinceLastBackup(events), 3,
          reason: 'desktop reports unavailable; fail in the safe direction');
    });

    test('a completed share does reset it', () async {
      SharedPreferences.setMockInitialValues({});
      await simulateShare(ShareResultStatus.success);

      expect(await eventsSinceLastBackup(events), 0,
          reason: 'all three events predate the backup');
      expect((await SharedPreferences.getInstance()).getString(kLastBackupKey),
          isNotNull);
    });
  });

  group('reminder counting', () {
    test('with no backup ever taken, every event counts', () async {
      SharedPreferences.setMockInitialValues({});
      expect(await eventsSinceLastBackup(events), 3);
      expect(await eventsSinceLastBackup(const []), 0);
    });

    test('only events logged after the backup count', () async {
      SharedPreferences.setMockInitialValues({
        kLastBackupKey: '2026-08-02T12:00:00.000',
      });
      expect(await eventsSinceLastBackup(events), 1);
    });

    test('restoring older events does not inflate the count', () async {
      SharedPreferences.setMockInitialValues({
        kLastBackupKey: '2026-08-03T12:00:00.000',
      });
      final withRestoredHistory = [
        ...events,
        rec('old-1', '2025-01-01T09:00:00.000'),
        rec('old-2', '2025-02-01T09:00:00.000'),
      ];
      expect(await eventsSinceLastBackup(withRestoredHistory), 0);
    });

    test('an unparseable marker is treated as never backed up', () async {
      SharedPreferences.setMockInitialValues({kLastBackupKey: 'not-a-date'});
      expect(await eventsSinceLastBackup(events), 3);
    });
  });
}
