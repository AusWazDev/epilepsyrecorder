import 'dart:convert';

import '../app_info.dart';
import '../constants.dart';
import 'event_record.dart';
import 'condition.dart';
import 'medication_note.dart';
import 'vocabulary.dart';

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
  List<Condition> conditions = const <Condition>[],
  Map<String, String> eventTypeConditions = const <String, String>{},
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
    // ADDED AT SCHEMA 3. Multi-condition attribution is DERIVED from a
    // record's event type, so nothing on the record carries it - which means
    // a restore onto a device with no conditions produced 72 records reading
    // `unknown` and no way for the user to know they had lost the mapping.
    //
    // Lost PREFERENCE rather than lost records, and restatable in one screen.
    // But SILENT is the property that matters: nobody would know to restate
    // it. That is the same argument that put medication notes in here.
    //
    // NO IDS. `condition.id` is AUTOINCREMENT and therefore LOCAL - it means
    // nothing on the target device, which will mint its own. So conditions
    // travel as NAMES and the mapping keys on the name. This is also what
    // makes merge natural: `addCondition` already matches case-insensitively
    // by name, so a condition the target already has is reused rather than
    // duplicated.
    'conditionCount': conditions.length,
    'conditions': conditions
        .map((c) => <String, Object?>{
              'name': c.name,
              'seededKey': c.seededKey,
              'isActive': c.isActive,
              'sortOrder': c.sortOrder,
            })
        .toList(),
    // event type VALUE -> condition NAME. The value is the stored string every
    // record already carries; the name is what survives the id being local.
    'eventTypeConditions': eventTypeConditions,
  });
}

/// The type-to-condition map, for a backup. Derived from the live vocabulary.
///
/// Only ASSIGNED types appear. An unassigned type has no condition, and writing
/// it as null would put "not said" in a file as though it were said.
Map<String, String> eventTypeConditionMap(
  List<VocabularyEntry> eventTypes,
  List<Condition> conditions,
) {
  final byId = <int, String>{for (final c in conditions) c.id: c.name};
  final out = <String, String>{};
  for (final t in eventTypes) {
    final name = t.conditionId == null ? null : byId[t.conditionId];
    if (name != null) out[t.value] = name;
  }
  return out;
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

  /// Condition NAMES in the file, in their stored order. **Empty for every
  /// schema 1 and 2 backup**, which is every backup taken before this change.
  final List<String> conditionNames;

  /// Event type VALUE to condition NAME. Empty for schema 1 and 2.
  final Map<String, String> eventTypeConditions;

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
    this.conditionNames = const <String>[],
    this.eventTypeConditions = const <String, String>{},
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

  // ABSENCE IS ABSENCE, exactly as `medicationNotes` does it. Every backup
  // taken before schema 3 lacks both keys, so a missing or malformed one
  // yields empty and NEVER a refusal. A gate here would refuse every file the
  // user already holds.
  //
  // The protection against the reverse - an OLD build reading a NEW file - is
  // the schema gate above, which is why the version was bumped to 3.
  final rawConditions = map['conditions'];
  final conditionNames = <String>[];
  if (rawConditions is List) {
    for (final entry in rawConditions) {
      if (entry is! Map) continue;
      final name = entry['name'];
      // A condition with no usable name cannot be merged by name, and name is
      // the only thing that survives the id being local. Skipped, not invented.
      if (name is String && name.trim().isNotEmpty) conditionNames.add(name);
    }
  }

  final rawMap = map['eventTypeConditions'];
  final eventTypeConditions = <String, String>{};
  if (rawMap is Map) {
    rawMap.forEach((k, v) {
      if (k is String && v is String && k.isNotEmpty && v.trim().isNotEmpty) {
        eventTypeConditions[k] = v;
      }
    });
  }

  final declared = map['recordCount'];
  final exported = map['exportedAt'];

  return ParsedBackup._(
    records: parsed,
    notes: parsedNotes,
    unreadableNotes: unreadableNotes,
    conditionNames: conditionNames,
    eventTypeConditions: eventTypeConditions,
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

  /// Condition names in the backup that the target does NOT already have.
  ///
  /// ⚠️ ADDITIONS, like [notesToAdd] and unlike [merged]. A condition the
  /// target already has is REUSED, not duplicated - `addCondition` matches
  /// case-insensitively by name, so "Migraine" does not become a second entry
  /// beside "migraine".
  final List<String> conditionsToAdd;

  final int conditionsInBackup;
  final int conditionsAlreadyPresent;

  /// Type-to-condition assignments the target does not already have.
  ///
  /// ⛔ **EXISTING ALWAYS WINS, the same rule as records and notes.** A type
  /// already assigned to a DIFFERENT condition on this device keeps its
  /// assignment: a restore only ever adds, and silently re-attributing every
  /// record carrying that type would be the migration this whole design
  /// avoids, arriving through the restore path.
  final Map<String, String> typeAssignmentsToAdd;

  final int typeAssignmentsInBackup;
  final int typeAssignmentsAlreadySet;

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
    this.conditionsToAdd = const <String>[],
    this.conditionsInBackup = 0,
    this.conditionsAlreadyPresent = 0,
    this.typeAssignmentsToAdd = const <String, String>{},
    this.typeAssignmentsInBackup = 0,
    this.typeAssignmentsAlreadySet = 0,
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
  /// True only when NEITHER RECORD STREAM has anything new.
  ///
  /// ⛔ **CONDITIONS ARE DELIBERATELY NOT A THIRD TERM, and that is a
  /// decision rather than an oversight.** A backup carrying conditions but no
  /// records is a degenerate case: conditions travel WITH records in every
  /// backup a user would actually take, and a conditions-only file could only
  /// come from naming a condition and backing up before recording anything.
  ///
  /// Restoring it would offer "Restore 0 events" on a button that does
  /// something, and the completion snackbar has no noun for it. The refusal
  /// a user gets instead is EXPLICIT - "this backup contains no events or
  /// medication notes" - which is the property that matters. The silent loss
  /// this pass fixes was silent; this is not.
  ///
  /// ⚠️ Conditions in a backup that DOES carry records restore normally. Only
  /// the degenerate case is refused.
  bool get addsNothing => toAdd == 0 && notesToAdd.isEmpty;
}

/// Merges by record id. Ids are uuid v4, so equality is exact and a record
/// already on the device is never duplicated. Existing records always win:
/// a restore cannot overwrite something already here.
RestorePlan planRestore(
  List<EventRecord> existing,
  ParsedBackup backup, {
  List<MedicationNote> existingNotes = const <MedicationNote>[],
  List<Condition> existingConditions = const <Condition>[],
  Map<String, String> existingTypeConditions = const <String, String>{},
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

  // Conditions merge BY NAME, case-insensitively - the same comparison
  // `addCondition` uses, so a name the target already has is reused rather
  // than duplicated. The id in the backup is meaningless here and is not
  // carried at all.
  final haveNames =
      existingConditions.map((c) => c.name.toLowerCase()).toSet();
  final conditionsToAdd = <String>[];
  var conditionsAlreadyPresent = 0;
  for (final name in backup.conditionNames) {
    if (haveNames.contains(name.toLowerCase())) {
      conditionsAlreadyPresent++;
    } else if (!conditionsToAdd
        .any((n) => n.toLowerCase() == name.toLowerCase())) {
      conditionsToAdd.add(name);
    }
  }

  // ⛔ EXISTING ALWAYS WINS. A type already assigned on this device keeps its
  // assignment, even if the backup disagrees. Restore only ever adds -
  // re-attributing a type would silently move every record carrying it to a
  // different condition, which is the migration this design exists to avoid
  // arriving through the restore path.
  final typeAssignmentsToAdd = <String, String>{};
  var typeAssignmentsAlreadySet = 0;
  backup.eventTypeConditions.forEach((type, name) {
    if (existingTypeConditions.containsKey(type)) {
      typeAssignmentsAlreadySet++;
    } else {
      typeAssignmentsToAdd[type] = name;
    }
  });

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
    conditionsToAdd: conditionsToAdd,
    conditionsInBackup: backup.conditionNames.length,
    conditionsAlreadyPresent: conditionsAlreadyPresent,
    typeAssignmentsToAdd: typeAssignmentsToAdd,
    typeAssignmentsInBackup: backup.eventTypeConditions.length,
    typeAssignmentsAlreadySet: typeAssignmentsAlreadySet,
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
