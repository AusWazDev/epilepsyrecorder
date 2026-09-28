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
  'durationSeconds',
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
  //
  // ⚠️ VERIFIED 27 Sep 2026: the toLocal() below normalises the STORED FORM
  // to naive local. It is NOT what preserves the instant — the SQLite reader
  // (eventFromRow) parses and calls toLocal() too, so a Z-suffixed timestamp
  // keeps its instant without this call. Removing it would keep the Z for
  // UTC-stored rows and leave logged_at holding two formats. Measured with
  // test/migration_instant_test.dart: with this call removed the instants
  // were unchanged and logged_at held "...06:45:09.000Z".
  final rawTs = map['timestamp'];
  final ts = (rawTs is String) ? DateTime.tryParse(rawTs)?.toLocal() : null;
  if (ts == null) return null;

  void countAbsent(String key, bool present) {
    if (!present) absentCounts[key] = (absentCounts[key] ?? 0) + 1;
  }

  final rawId = map['id'];
  countAbsent('id', rawId is String);

  final rawSeconds = map['durationSeconds'];
  countAbsent('durationSeconds', rawSeconds is int);

  final rawDuration = map['duration'];
  final durationName = DurationCategory.values
      .where((e) => e.name == rawDuration)
      .map((e) => e.name)
      .firstOrNull;
  countAbsent('duration', durationName != null);

  // ANY non-empty string is a type now, not just the four MER shipped. The
  // old code counted an unrecognised value as ABSENT and wrote NULL, which
  // for a user-defined type would have been silent data loss at migration.
  final rawType = map['eventType'];
  final typeName = (rawType is String && rawType.isNotEmpty) ? rawType : null;
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
    // NEVER invented from a bucket. A legacy payload carries no
    // durationSeconds key at all, so this stays null and that record keeps its
    // range forever — the same rule occurred_at is held to.
    'duration_seconds': rawSeconds is int ? rawSeconds : null,
    'event_type': typeName,
    'severity': severity,
    'feelings_json':
        rawFeelings is List ? jsonEncode(rawFeelings.map((e) => e.toString()).toList()) : null,
    'triggers_json':
        rawTriggers is List ? jsonEncode(rawTriggers.map((e) => e.toString()).toList()) : null,
    'notes': rawNotes is String ? rawNotes : null,
    'referral_required': rawReferral is bool ? (rawReferral ? 1 : 0) : null,
    // NULL, always, for a legacy payload: these records predate the wizard
    // and are neither complete nor incomplete. Nothing back-fills it.
    'details_completed': null,
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
///
/// [writeMarker], when given, is called with [migrationMarkerJson] in the
/// verified branch, immediately BEFORE `migration_state` is set to
/// `migrated` — Brief 205. The caller owns where it goes, which is
/// [kLegacyMigrationMarkerKey] in shared_preferences, so this function still
/// touches no preferences itself.
///
/// ⚠️ THE TWO WRITES CANNOT BE ATOMIC: one is SQLite, the other is the
/// preferences store. The order is chosen so the marker's claim is never
/// false. It is written only once the rows are verified, so "this payload was
/// migrated" is already true. A crash after it and before `migrated` leaves
/// `migration_in_progress` set, so the next boot clears the partial rows,
/// migrates the same untouched payload again, and writes the same marker.
/// The reverse order would let a crash leave a migrated database with no
/// marker, which is permanent: that device never migrates again.
///
/// A failing marker write is swallowed. It must not change which store this
/// launch runs on; the marker is a record for a later decision, not a gate.
Future<MigrationOutcome> migrateJsonToSqlite({
  required Database db,
  required String? rawJson,
  String? backupPath,
  int dropForNegativeControl = 0,
  Future<void> Function(String marker)? writeMarker,
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

    // ⛔ SET BEFORE THE INSERTS, so a kill between the commit below and the
    // state write at the end of this function is recoverable. See
    // [kMetaMigrationInProgress] for why it is cleared where it is and not
    // anywhere else.
    await putMeta(db, kMetaMigrationInProgress, '1');

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
      if (writeMarker != null) {
        try {
          await writeMarker(migrationMarkerJson(rawJson, DateTime.now()));
        } catch (_) {
          // See [writeMarker]: never allowed to change this launch's outcome.
        }
      }
      await putMeta(db, kMetaMigrationState, 'migrated');
      await putMeta(db, kMetaMigratedAt, DateTime.now().toIso8601String());
      // The ONLY place this is cleared. Deliberately not on the else branch
      // and not in the catch — [kMetaMigrationInProgress] says why, once.
      await putMeta(db, kMetaMigrationInProgress, '0');
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

/// The fingerprint of the legacy payload, over its exact UTF-8 bytes: the
/// byte length and a 32-bit FNV-1a hash. Brief 205.
///
/// ⭐ WHAT IT IS FOR, AND WHY THIS HASH IS ENOUGH. It answers one question:
/// is the list under [kEventStorageKey] the one that was migrated, or has it
/// changed since? An APPEND, which is what a fallback launch does to that
/// list, always changes the byte length, so the length alone catches it. The
/// hash is for the rarer same-length rewrite, where 32 bits leaves a
/// one-in-four-billion chance of a false "unchanged". ⛔ This is not a
/// security boundary. Nothing adversarial writes this list; a cryptographic
/// hash would buy nothing here and would add a dependency.
///
/// A null or empty payload fingerprints as 0 bytes: a device that started on
/// SQLite migrated nothing, and the marker says exactly that.
({int bytes, String fnv1a32}) legacyPayloadFingerprint(String? raw) {
  final data = utf8.encode(raw ?? '');
  // FNV-1a, 32-bit. The prime 0x01000193 is split as (1 << 24) + 0x193 so no
  // intermediate exceeds ~2^42: a plain `hash * 0x01000193` reaches 2^56,
  // which is exact on the Dart VM and NOT on JavaScript's 53-bit integers.
  var hash = 0x811c9dc5;
  for (final b in data) {
    hash ^= b;
    hash = ((hash * 0x193) + ((hash << 24) & 0xffffffff)) & 0xffffffff;
  }
  return (bytes: data.length, fnv1a32: hash.toRadixString(16).padLeft(8, '0'));
}

/// The value written under [kLegacyMigrationMarkerKey]. A JSON object:
/// `v` (the marker's own format version), `payloadBytes` and `fnv1a32` from
/// [legacyPayloadFingerprint], and `migratedAt`.
String migrationMarkerJson(String? rawJson, DateTime at) {
  final fp = legacyPayloadFingerprint(rawJson);
  return jsonEncode(<String, Object>{
    'v': 1,
    'payloadBytes': fp.bytes,
    'fnv1a32': fp.fnv1a32,
    'migratedAt': at.toIso8601String(),
  });
}

/// What this database was built FROM. Brief 217, 28 September 2026.
enum RebuildVerdict {
  /// A marker was present and matched the payload: this database was rebuilt
  /// from a snapshot frozen at an earlier migration (a transfer, or local loss).
  rebuild,

  /// A marker was present and did NOT match: the payload changed after an
  /// earlier migration (fallback writes landed), then this database was built.
  diverged,

  /// No marker: the first migration this payload has ever had.
  ordinary,
}

/// Where the verdict is kept: `schema_meta` of the database it describes.
const String kMetaRebuildVerdict = 'legacy_rebuild_verdict';

/// The verdict for a marker read from prefs and the payload about to migrate.
///
/// ⚠️ A marker that is present but unreadable counts as DIVERGED: it says a
/// migration happened somewhere, and it cannot say the payload is unchanged.
RebuildVerdict rebuildVerdictFor(String? markerJson, String? rawJson) {
  if (markerJson == null) return RebuildVerdict.ordinary;
  try {
    final m = jsonDecode(markerJson) as Map<String, Object?>;
    final fp = legacyPayloadFingerprint(rawJson);
    return (m['payloadBytes'] == fp.bytes && m['fnv1a32'] == fp.fnv1a32)
        ? RebuildVerdict.rebuild
        : RebuildVerdict.diverged;
  } catch (_) {
    return RebuildVerdict.diverged;
  }
}

/// Records the verdict ONCE per database, before its first migration attempt.
///
/// ⛔ **WHY BEFORE, AND WHY ONCE.** The migration writes a fresh marker with the
/// same fingerprint (Brief 215 §2.1), so a verdict taken afterwards always reads
/// REBUILD. And an interrupted first attempt can leave THIS database's own marker
/// behind (the marker is written before `migrated`, Brief 205), so a verdict
/// recomputed on the re-run would read this device's own write as a travelled
/// one. The first attempt runs before this database has written anything, so its
/// reading is the only one that describes where the payload came from.
///
/// ⭐ **WHY `schema_meta` AND NOT PREFS.** The verdict is a fact about how THIS
/// database came to exist. Prefs travel in an iOS backup and the database does
/// not (`10c2f7c`), so a verdict in prefs would arrive on the next device
/// describing the last one. In `schema_meta` it is lost exactly when the
/// database is, which is exactly when a new one must be taken. Reset keeps
/// `schema_meta`, and the verdict stays true after a Reset: it describes the
/// database's origin, not its current rows.
///
/// Best-effort: a failed read or write leaves no verdict, which reads as today.
/// Nothing reads it yet.
Future<void> captureRebuildVerdict(
    DatabaseExecutor db, String? markerJson, String? rawJson) async {
  try {
    if (await getMeta(db, kMetaRebuildVerdict) != null) return;
    await putMeta(db, kMetaRebuildVerdict, jsonEncode(<String, Object>{
      'verdict': rebuildVerdictFor(markerJson, rawJson).name,
      'at': DateTime.now().toIso8601String(),
    }));
  } catch (_) {}
}
