import 'dart:convert';
import 'dart:io';

import 'package:sqflite_common/sqlite_api.dart';

import '../constants.dart';
import 'event_record.dart';
import 'event_store_sqlite.dart';

/// The one-shot conversion of the JSON record list into SQLite, and the
/// verification that decides which store the app runs on for this launch.
///
/// The whole build exists to answer ONE question — did every record survive? —
/// so everything here is arranged so that a failure is loud, attributable, and
/// recoverable: nothing is deleted, a backup is written before anything is
/// touched, and a count that does not reconcile falls back rather than
/// proceeding.

enum MigrationState {
  /// SQLite already carries the migration marker. Nothing was read or written.
  alreadyMigrated,

  /// Converted and verified. SQLite is the store.
  migrated,

  /// Converted, but the row count did not reconcile. Falls back.
  failedVerification,

  /// Threw. Falls back.
  error,
}

class MigrationOutcome {
  const MigrationOutcome({
    required this.state,
    required this.sourceEntries,
    required this.loadableCount,
    required this.insertedCount,
    required this.distinctIds,
    required this.absentCounts,
    this.backupPath,
    this.error,
  });

  final MigrationState state;

  /// Every entry in the JSON array, including ones the old store would skip.
  final int sourceEntries;

  /// Entries the OLD store would have produced a record for. This is the number
  /// verification reconciles against, because it is what the user could see.
  final int loadableCount;

  final int insertedCount;

  /// Distinct ids among inserted rows. Below [insertedCount] means the device
  /// carries duplicate ids — recorded rather than rejected, see [createEventSql].
  final int distinctIds;

  /// Per-field count of keys ABSENT from the source JSON.
  final Map<String, int> absentCounts;

  final String? backupPath;
  final Object? error;

  bool get succeeded =>
      state == MigrationState.migrated || state == MigrationState.alreadyMigrated;

  /// Entries the old store would silently drop. Named rather than left as a
  /// difference between two other numbers, so a skip is visible.
  int get skipped => sourceEntries - loadableCount;
}

/// The source columns whose absence is counted. `timestamp` is not here: an
/// absent timestamp makes the whole record unloadable, which is counted as a
/// skip instead.
const List<String> kMigratedOptionalKeys = <String>[
  'id',
  'duration',
  'eventType',
  'severity',
  'feelings',
  'triggers',
  'notes',
  'referralRequired',
];

/// Converts one raw JSON map to a row, writing NULL for every ABSENT key.
///
/// This is the reason the migration reads raw maps rather than [EventRecord]s.
/// `EventRecord.fromMap` coerces an absent `eventType` to `seizure`, an absent
/// `severity` to `mild` and an unparseable `duration` to `lt1` — its own comment
/// calls them "safe fallbacks for old records". Reading through it would convert
/// UNKNOWN into a confident wrong value, permanently, in the schema whose entire
/// premise is that NULL means unknown.
///
/// Returns null when the record is one the old store would itself have skipped.
Map<String, Object?>? rawMapToRow(
  Map<String, dynamic> map,
  int ordinal,
  Map<String, int> absentCounts,
) {
  // Identical to EventRecord._parseTimestamp, deliberately.
  final rawTs = map['timestamp'];
  final ts = (rawTs is String) ? DateTime.tryParse(rawTs)?.toLocal() : null;
  if (ts == null) return null;

  void countAbsent(String key, bool present) {
    if (!present) absentCounts[key] = (absentCounts[key] ?? 0) + 1;
  }

  final rawId = map['id'];
  countAbsent('id', rawId is String);

  final rawDuration = map['duration'];
  final durationName = DurationCategory.values
      .where((e) => e.name == rawDuration)
      .map((e) => e.name)
      .firstOrNull;
  countAbsent('duration', durationName != null);

  final rawType = map['eventType'];
  final typeName = EventType.values
      .where((e) => e.name == rawType)
      .map((e) => e.name)
      .firstOrNull;
  countAbsent('eventType', typeName != null);

  final rawSeverity = map['severity'];
  final severity = EventSeverity.values
      .where((e) => e.name == rawSeverity)
      .map(severityToInt)
      .firstOrNull;
  countAbsent('severity', severity != null);

  final rawFeelings = map['feelings'];
  countAbsent('feelings', rawFeelings is List);

  final rawTriggers = map['triggers'];
  countAbsent('triggers', rawTriggers is List);

  final rawNotes = map['notes'];
  countAbsent('notes', rawNotes is String);

  final rawReferral = map['referralRequired'];
  countAbsent('referralRequired', rawReferral is bool);

  return <String, Object?>{
    'ordinal': ordinal,
    // Preserved verbatim. NEVER case-folded: Swift generates uppercase ids and
    // Dart lowercase, both exist in stored records, and restore matches on id.
    'id': rawId is String ? rawId : '',
    'logged_at': ts.toIso8601String(),
    // The source is log time. Pretending it is event time fabricates data.
    'occurred_at': null,
    'duration_bucket': durationName,
    // Never invented from a bucket.
    'duration_seconds': null,
    'event_type': typeName,
    'severity': severity,
    'feelings_json':
        rawFeelings is List ? jsonEncode(rawFeelings.map((e) => e.toString()).toList()) : null,
    'triggers_json':
        rawTriggers is List ? jsonEncode(rawTriggers.map((e) => e.toString()).toList()) : null,
    'notes': rawNotes is String ? rawNotes : null,
    'referral_required': rawReferral is bool ? (rawReferral ? 1 : 0) : null,
  };
}

/// Runs the conversion against an OPEN, freshly created database.
///
/// [rawJson] is the verbatim string under [kEventStorageKey]. Nothing here
/// touches shared_preferences — the caller owns that, so this stays testable
/// without a binding.
///
/// [dropForNegativeControl] exists so a test can prove verification FAILS when
/// a record is lost. Without it, a passing verification is unfalsifiable.
Future<MigrationOutcome> migrateJsonToSqlite({
  required Database db,
  required String? rawJson,
  String? backupPath,
  int dropForNegativeControl = 0,
}) async {
  final absentCounts = <String, int>{};

  try {
    final existing = await getMeta(db, kMetaMigrationState);
    if (existing == 'migrated') {
      return MigrationOutcome(
        state: MigrationState.alreadyMigrated,
        sourceEntries: 0,
        loadableCount: 0,
        insertedCount: 0,
        distinctIds: 0,
        absentCounts: const <String, int>{},
        backupPath: await getMeta(db, kMetaBackupPath),
      );
    }

    final decoded = (rawJson == null || rawJson.isEmpty)
        ? const <dynamic>[]
        : jsonDecode(rawJson) as List<dynamic>;

    final maps = decoded.whereType<Map>().toList();
    final rows = <Map<String, Object?>>[];
    var ordinal = 0;
    for (final m in maps) {
      final row =
          rawMapToRow(Map<String, dynamic>.from(m), ordinal, absentCounts);
      if (row == null) continue;
      rows.add(row);
      ordinal++;
    }

    final loadableCount = rows.length;
    final toInsert = rows.length - dropForNegativeControl;

    await db.transaction((txn) async {
      final batch = txn.batch();
      for (var i = 0; i < toInsert; i++) {
        batch.insert('event', rows[i]);
      }
      await batch.commit(noResult: true);
    });

    final countRow =
        await db.rawQuery('SELECT COUNT(*) AS c FROM event');
    final inserted = (countRow.first['c'] as int?) ?? -1;

    final distinctRow =
        await db.rawQuery('SELECT COUNT(DISTINCT id) AS c FROM event');
    final distinct = (distinctRow.first['c'] as int?) ?? -1;

    // Verify BEFORE marking complete. A count that does not reconcile means
    // records were lost, and proceeding would bake that loss in.
    final verified = inserted == loadableCount;

    await putMeta(db, kMetaSourceCount, '${decoded.length}');
    await putMeta(db, kMetaInsertedCount, '$inserted');
    await putMeta(db, kMetaDistinctIds, '$distinct');
    for (final key in kMigratedOptionalKeys) {
      await putMeta(db, '$kMetaAbsentPrefix$key', '${absentCounts[key] ?? 0}');
    }
    if (backupPath != null) await putMeta(db, kMetaBackupPath, backupPath);

    if (verified) {
      await putMeta(db, kMetaMigrationState, 'migrated');
      await putMeta(db, kMetaMigratedAt, DateTime.now().toIso8601String());
    } else {
      await putMeta(db, kMetaMigrationState, 'failed_verification');
    }

    return MigrationOutcome(
      state:
          verified ? MigrationState.migrated : MigrationState.failedVerification,
      sourceEntries: decoded.length,
      loadableCount: loadableCount,
      insertedCount: inserted,
      distinctIds: distinct,
      absentCounts: absentCounts,
      backupPath: backupPath,
    );
  } catch (e) {
    return MigrationOutcome(
      state: MigrationState.error,
      sourceEntries: 0,
      loadableCount: 0,
      insertedCount: 0,
      distinctIds: 0,
      absentCounts: absentCounts,
      backupPath: backupPath,
      error: e,
    );
  }
}

/// Writes the pre-migration payload to [dir] and returns its path.
///
/// Written BEFORE anything is touched, silently, and never deleted. A few
/// hundred kilobytes buys a rollback usable by hand on the one device that
/// matters.
Future<String?> writeMigrationBackup(Directory dir, String? rawJson) async {
  if (rawJson == null || rawJson.isEmpty) return null;
  final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
  final file = File('${dir.path}/mer_pre_sqlite_backup_$stamp.json');
  await file.writeAsString(rawJson, flush: true);
  return file.path;
}
