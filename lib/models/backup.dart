import 'dart:convert';

import '../app_info.dart';
import '../constants.dart';
import 'event_record.dart';

/* ===========================
   BACKUP ENVELOPE
   =========================== */

/// Builds the JSON backup payload.
///
/// Deliberately an envelope, not a bare array. The shared_preferences payload
/// is a bare array with no version marker at all — the `_v1` in its key name is
/// a naming convention, not a mechanism — and that mistake is not repeated
/// here. A reader can identify this file, refuse a schema it does not
/// understand, and report what it contains before touching anything.
String buildBackupJson(List<EventRecord> records, {DateTime? exportedAt}) {
  final stamp = exportedAt ?? DateTime.now();
  return const JsonEncoder.withIndent('  ').convert({
    'format': kBackupFormatId,
    'schemaVersion': kBackupSchemaVersion,
    'appVersion': AppInfo.isLoaded
        ? '${AppInfo.version}+${AppInfo.buildNumber}'
        : 'unknown',
    'exportedAt': stamp.toIso8601String(),
    'recordCount': records.length,
    'records': records.map((e) => e.toMap()).toList(),
  });
}

/* ===========================
   PARSING
   =========================== */

enum BackupProblem {
  /// Not JSON at all, or truncated partway through.
  unreadable,

  /// Valid JSON, but not a Medical Event Recorder backup.
  notABackup,

  /// A backup, but written by a newer build than this one understands.
  unsupportedSchema,
}

/// Result of reading a candidate backup file. Either [records] is populated and
/// [problem] is null, or the reverse. Never both.
class ParsedBackup {
  final List<EventRecord> records;
  final int unreadableRecords;
  final int declaredCount;
  final int schemaVersion;
  final String appVersion;
  final DateTime? exportedAt;
  final BackupProblem? problem;
  final String message;

  const ParsedBackup._({
    this.records = const [],
    this.unreadableRecords = 0,
    this.declaredCount = 0,
    this.schemaVersion = 0,
    this.appVersion = '',
    this.exportedAt,
    this.problem,
    this.message = '',
  });

  bool get isValid => problem == null;

  static ParsedBackup _fail(BackupProblem p, String message) =>
      ParsedBackup._(problem: p, message: message);
}

/// Reads and fully validates a candidate backup. Nothing is written by this
/// function; a caller must validate before it touches stored data, so that a
/// restore is never partially applied.
ParsedBackup parseBackup(String raw) {
  dynamic decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return ParsedBackup._fail(
      BackupProblem.unreadable,
      'This file could not be read. It may be damaged or incomplete.',
    );
  }

  if (decoded is! Map) {
    return ParsedBackup._fail(
      BackupProblem.notABackup,
      'This is not a Medical Event Recorder backup file.',
    );
  }
  final map = Map<String, dynamic>.from(decoded);

  if (map['format'] != kBackupFormatId) {
    return ParsedBackup._fail(
      BackupProblem.notABackup,
      'This is not a Medical Event Recorder backup file.',
    );
  }

  final schema = map['schemaVersion'];
  if (schema is! int) {
    return ParsedBackup._fail(
      BackupProblem.notABackup,
      'This backup is missing its version information and cannot be read.',
    );
  }
  if (schema > kBackupSchemaVersion) {
    return ParsedBackup._fail(
      BackupProblem.unsupportedSchema,
      'This backup was made by a newer version of Medical Event Recorder. '
      'Update the app, then try again.',
    );
  }

  final rawRecords = map['records'];
  if (rawRecords is! List) {
    return ParsedBackup._fail(
      BackupProblem.notABackup,
      'This backup does not contain any event data.',
    );
  }

  final parsed = <EventRecord>[];
  var unreadable = 0;
  for (final entry in rawRecords) {
    if (entry is! Map) {
      unreadable++;
      continue;
    }
    final record = EventRecord.fromMap(Map<String, dynamic>.from(entry));
    if (record == null) {
      unreadable++;
      continue;
    }
    parsed.add(record);
  }

  final declared = map['recordCount'];
  final exported = map['exportedAt'];

  return ParsedBackup._(
    records: parsed,
    unreadableRecords: unreadable,
    declaredCount: declared is int ? declared : rawRecords.length,
    schemaVersion: schema,
    appVersion: map['appVersion'] is String ? map['appVersion'] as String : '',
    exportedAt: exported is String ? DateTime.tryParse(exported) : null,
  );
}

/* ===========================
   MERGE
   =========================== */

/// What a restore would do, computed before anything is written so the user can
/// be shown the consequences and confirm them.
///
/// There is no replace mode and no "start afresh" here by design. Restore only
/// ever adds. Clearing data is a separate, deliberate action.
class RestorePlan {
  final List<EventRecord> merged;
  final int inBackup;
  final int alreadyPresent;
  final int toAdd;
  final int unreadable;
  final DateTime? earliest;
  final DateTime? latest;

  const RestorePlan({
    required this.merged,
    required this.inBackup,
    required this.alreadyPresent,
    required this.toAdd,
    required this.unreadable,
    this.earliest,
    this.latest,
  });

  bool get addsNothing => toAdd == 0;
}

/// Merges by record id. Ids are uuid v4, so equality is exact and a record
/// already on the device is never duplicated. Existing records always win:
/// a restore cannot overwrite something already here.
RestorePlan planRestore(List<EventRecord> existing, ParsedBackup backup) {
  final existingIds = existing.map((e) => e.id).toSet();

  final additions = <EventRecord>[];
  var alreadyPresent = 0;
  for (final record in backup.records) {
    if (record.id.isNotEmpty && existingIds.contains(record.id)) {
      alreadyPresent++;
    } else {
      additions.add(record);
    }
  }

  final merged = [...existing, ...additions]
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  DateTime? earliest;
  DateTime? latest;
  for (final r in backup.records) {
    if (earliest == null || r.timestamp.isBefore(earliest)) earliest = r.timestamp;
    if (latest == null || r.timestamp.isAfter(latest)) latest = r.timestamp;
  }

  return RestorePlan(
    merged: merged,
    inBackup: backup.records.length,
    alreadyPresent: alreadyPresent,
    toAdd: additions.length,
    unreadable: backup.unreadableRecords,
    earliest: earliest,
    latest: latest,
  );
}
