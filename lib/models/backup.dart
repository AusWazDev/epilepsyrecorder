import 'dart:convert';

import '../app_info.dart';
import '../constants.dart';
import 'event_record.dart';
import 'medication_note.dart';

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
String buildBackupJson(
  List<EventRecord> records, {
  List<MedicationNote> notes = const <MedicationNote>[],
  DateTime? exportedAt,
}) {
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
    // ⛔ ADDED AT SCHEMA 2. Medication notes reached the CSV and NOTHING ELSE,
    // so a restore onto a new device silently lost every one of them — in the
    // single feature whose stated purpose is that this file is the only copy
    // that survives losing the phone.
    //
    // The row shape is reused verbatim rather than given a second
    // backup-specific serialisation. `medicationNoteToRow` already emits
    // JSON-safe primitives (ISO strings and `kind.name`, never an ordinal),
    // and a parallel encoder is a second thing to keep in step — which is
    // exactly how `feelings_json` and the observation table are kept honest by
    // having ONE authority rather than two agreeing ones.
    'medicationNoteCount': notes.length,
    'medicationNotes': notes.map(medicationNoteToRow).toList(),
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

  /// Medication notes in the file. **Empty for every schema 1 backup**, which
  /// is every backup taken before this change — absence is absence, not a
  /// fault. See [parseBackup].
  final List<MedicationNote> notes;

  /// Notes present in the file that could not be rebuilt. Counted the same way
  /// as [unreadableRecords] so a partial file reports rather than hides.
  final int unreadableNotes;

  final int unreadableRecords;
  final int declaredCount;
  final int schemaVersion;
  final String appVersion;
  final DateTime? exportedAt;
  final BackupProblem? problem;
  final String message;

  const ParsedBackup._({
    this.records = const [],
    this.notes = const <MedicationNote>[],
    this.unreadableNotes = 0,
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

  // ⛔ ABSENCE IS ABSENCE. A schema 1 backup has no `medicationNotes` key at
  // all, and EVERY backup taken before this change is schema 1 — so a missing
  // or malformed key yields an empty list and NEVER a refusal. Adding a
  // thirteenth gate here would refuse every file the user already holds,
  // turning a fix for silent loss into total loss.
  //
  // The protection against the reverse direction — an OLD build reading a NEW
  // file — is the schema gate above, which is why the version was bumped.
  final rawNotes = map['medicationNotes'];
  final parsedNotes = <MedicationNote>[];
  var unreadableNotes = 0;
  if (rawNotes is List) {
    for (final entry in rawNotes) {
      if (entry is! Map) {
        unreadableNotes++;
        continue;
      }
      final note = medicationNoteFromRow(Map<String, Object?>.from(entry));
      // An id is what merge-by-id needs; a note without one cannot be
      // deduplicated and would re-add itself on every future restore.
      if (note == null || note.id.isEmpty) {
        unreadableNotes++;
        continue;
      }
      parsedNotes.add(note);
    }
  }

  final declared = map['recordCount'];
  final exported = map['exportedAt'];

  return ParsedBackup._(
    records: parsed,
    notes: parsedNotes,
    unreadableNotes: unreadableNotes,
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

  /// Notes in the backup that are NOT already on this device.
  ///
  /// ⚠️ Deliberately the ADDITIONS, not a merged list — unlike [merged].
  /// Events live in one list the caller rewrites wholesale; notes live in a
  /// SQLite table the caller INSERTS into, so handing it the union would make
  /// it re-insert every note already there. The shape of each field matches
  /// what its writer actually needs.
  final List<MedicationNote> notesToAdd;

  final int notesInBackup;
  final int notesAlreadyPresent;
  final int notesUnreadable;

  final int inBackup;
  final int alreadyPresent;
  final int toAdd;
  final int unreadable;
  final DateTime? earliest;
  final DateTime? latest;

  /// When the backup was WRITTEN, straight from the envelope's `exportedAt`.
  ///
  /// Distinct from [latest], which is the newest event INSIDE it. Two files can
  /// hold overlapping events and differ only by when they were taken, which is
  /// exactly the case the picker cannot show.
  final DateTime? exportedAt;

  // DEFERRED: a staleness caution — "this backup is older than your most
  // recent event" — was built here and removed. The comparison needs when
  // EVENTS happened, and `timestamp` is logged_at: when the row was WRITTEN.
  // Across two devices that compares which one last logged something, not
  // which holds newer events, so it would caution on legitimate restores. The
  // weaker variant, comparing export timestamps, is a much thinner signal for
  // the same dialog space. Revisit when occurred_at is populated by the
  // expansion — see docs/DATA-MODEL.md - and build it once.

  const RestorePlan({
    required this.merged,
    this.notesToAdd = const <MedicationNote>[],
    this.notesInBackup = 0,
    this.notesAlreadyPresent = 0,
    this.notesUnreadable = 0,
    required this.inBackup,
    required this.alreadyPresent,
    required this.toAdd,
    required this.unreadable,
    this.earliest,
    this.latest,
    this.exportedAt,
  });

  /// True only when NEITHER stream has anything new.
  ///
  /// ⚠️ This gates the Restore button. Reading it off events alone would
  /// refuse a backup whose only new content is medication notes.
  bool get addsNothing => toAdd == 0 && notesToAdd.isEmpty;
}

/// Merges by record id. Ids are uuid v4, so equality is exact and a record
/// already on the device is never duplicated. Existing records always win:
/// a restore cannot overwrite something already here.
RestorePlan planRestore(
  List<EventRecord> existing,
  ParsedBackup backup, {
  List<MedicationNote> existingNotes = const <MedicationNote>[],
}) {
  final existingIds = existing.map((e) => e.id).toSet();

  // Same rule as records, and for the same reason: ids are uuid v4 so equality
  // is exact, and anything already on the device WINS. A restore adds; it never
  // rewrites. `notes` defaults to empty so every existing caller and test keeps
  // its current meaning rather than silently acquiring a second stream.
  final existingNoteIds = existingNotes.map((n) => n.id).toSet();
  final noteAdditions = <MedicationNote>[];
  var notesAlreadyPresent = 0;
  for (final note in backup.notes) {
    if (existingNoteIds.contains(note.id)) {
      notesAlreadyPresent++;
    } else {
      noteAdditions.add(note);
    }
  }

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
    notesToAdd: noteAdditions,
    notesInBackup: backup.notes.length,
    notesAlreadyPresent: notesAlreadyPresent,
    notesUnreadable: backup.unreadableNotes,
    inBackup: backup.records.length,
    alreadyPresent: alreadyPresent,
    toAdd: additions.length,
    unreadable: backup.unreadableRecords,
    earliest: earliest,
    latest: latest,
    exportedAt: backup.exportedAt,
  );
}
