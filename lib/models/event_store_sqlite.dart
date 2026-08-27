import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common/sqlite_api.dart';

import 'event_record.dart';
import 'medication_note.dart';
import 'vocabulary.dart';

/// The SQLite backing for [EventStore].
///
/// Phase one holds TODAY'S nine fields, relationally. It deliberately does not
/// create `condition`, `event_type`, `medication_note` or `condition_field`:
/// they would sit empty, and a NOT NULL `condition_id` would force a seed row
/// whose name and identity the expansion has not decided. A guessed default in
/// a medical app becomes permanent.
///
/// What it DOES do is refuse to foreclose the target — every optional column is
/// nullable and NULL means UNKNOWN, so the expansion adds tables rather than
/// altering populated columns.

/// Bumped only when the shape changes. The old store had no version field at
/// all, and that gap has cost repeatedly.
/// 2 since the wizard: `event.details_completed` was added.
/// 3 since user-defined vocabularies: `event_type` and `observation` tables,
///   seeded, plus a NULLABLE `event.condition_id` that stays unpopulated.
/// 4 since the observation revision: `emoji` on both vocabulary tables —
///   PRESENTATION ONLY, so a glyph is never inside a stored value again.
/// 5 since rescue medication: three nullable columns on `event`. A FIELD on an
///   event, not a record kind — regular medication is a separate stream and is
///   NOT part of this bump.
/// 6 since regular medication: the `medication_note` table, and `medication`
///   retired as an event type. A SEPARATE RECORD KIND — the stream the bump
///   above deliberately excluded.
///
/// Every bump so far is ADDITIVE ONLY — new tables, and ADD COLUMN on a
/// populated table. Non-destructive, every existing value untouched, and the
/// new columns NULL on every existing row, which is exactly right: those
/// records predate the concept.
const int kSqliteSchemaVersion = 6;

const String kSqliteDbFileName = 'mer_events.db';

/// `schema_meta` keys. Values are TEXT; numbers are stored as their decimal
/// string so the table stays one shape.
const String kMetaSchemaVersion  = 'schema_version';
const String kMetaMigrationState = 'migration_state';
const String kMetaMigratedAt     = 'migrated_at';
const String kMetaSourceCount    = 'migration_source_count';
const String kMetaInsertedCount  = 'migration_inserted_count';
const String kMetaDistinctIds    = 'migration_distinct_ids';
const String kMetaBackupPath     = 'migration_backup_path';

/// Per-field counts of keys that were ABSENT in the source JSON.
///
/// Recorded because the NULLs themselves are not durable: [EventRecord] has no
/// concept of unknown, and `save(List)` rewrites every row, so the first write
/// after migration replaces each NULL with the fallback the model has always
/// applied. These counts survive that, and are what the expansion needs.
const String kMetaAbsentPrefix = 'migration_absent_';

const String createSchemaMetaSql =
    'CREATE TABLE schema_meta (key TEXT PRIMARY KEY, value TEXT)';

/// `id` is NOT a PRIMARY KEY, and that is deliberate.
///
/// The old store is a JSON array, which permits duplicate ids. Making id unique
/// here would make a duplicate an INSERT failure — turning "this device has two
/// records sharing an id" into "the migration lost records", which is the exact
/// outcome this build exists to rule out. Duplicates are carried across and
/// counted into `migration_distinct_ids` instead, so the question is answered
/// on the device rather than decided here.
///
/// `ordinal` preserves the source array order. SQLite row order is otherwise
/// unspecified, and `load()` re-applies the same newest-first sort the old
/// store applied — which needs a deterministic input to be equivalent.
const String createEventSql = 'CREATE TABLE event ('
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
    'referral_required INTEGER, '
    // Nullable THREE ways: 1 complete, 0 partial, NULL predates the wizard.
    'details_completed INTEGER, '
    // NULLABLE and NEVER POPULATED this stage. There is no `condition` table
    // and no screen on which someone could say what they track, so any value
    // written here would be an assertion about their health invented by a
    // migration. NULL means NOT YET SAID.
    //
    // DATA-MODEL.md leaves this cell blank rather than requiring NOT NULL —
    // verified, `grep -c "NOT NULL" docs/DATA-MODEL.md` returns 0. The doc now
    // says nullable explicitly instead of saying nothing.
    'condition_id INTEGER, '
    // RESCUE MEDICATION. All three nullable, all NULL meaning NOT ASKED, and
    // NULL on every row that exists today because they predate the question.
    //
    // `rescue_med_helped` is TEXT, holding `RescueResponse.name`, not an INTEGER
    // ordinal like `severity`. Deliberate divergence: severity's integer mapping
    // is load-bearing legacy, and a new column has no reason to inherit an
    // encoding whose only virtue is that it already exists. A name is readable
    // in a raw dump and cannot be silently shifted by reordering the enum.
    'rescue_med_given INTEGER, '
    'rescue_med_helped TEXT, '
    'rescue_med_second_dose INTEGER)';

const String createEventIdIndexSql = 'CREATE INDEX idx_event_id ON event(id)';
const String createEventLoggedAtIndexSql =
    'CREATE INDEX idx_event_logged_at ON event(logged_at)';

/// Walks a database forward one version at a time.
///
/// Each step is additive and non-destructive: no row is rewritten and no value
/// is derived. Every existing row gets NULL in every new column, which is the
/// honest answer for a record captured before the concept existed.
///
/// Steps are `if`, not `else if`, and each guards on its own version — so a
/// v1 database installed after a long gap walks 1 -> 2 -> 3 in one open, and a
/// v2 database runs only the second step.
Future<void> upgradeSchema(Database db, int from, int to) async {
  if (from < 2 && to >= 2) {
    await db.execute('ALTER TABLE event ADD COLUMN details_completed INTEGER');
  }
  if (from < 3 && to >= 3) {
    await db.execute('ALTER TABLE event ADD COLUMN condition_id INTEGER');
    // Creates AND seeds. The seed is idempotent on `value`, so it is safe here
    // and in onCreate, and safe to re-run when a later version adds a seed.
    await createAndSeedVocabularies(db);
  }
  // ⚠️ TWO-SIDED BOUND, and the lower half is the load-bearing one.
  //
  // `createVocabularySql` always emits the CURRENT column list, so the v3 step
  // above creates these tables ALREADY CARRYING `emoji`. A one-sided
  // `from < 4` therefore threw `duplicate column name: emoji` for any database
  // walking 1 -> 4 or 2 -> 4 in a single open — which is every device upgrading
  // from a release before v3, i.e. every real user rather than this one tablet.
  //
  // Found by the v1 -> current fixture in `sqlite_upgrade_v2_test`, which
  // exists precisely because a fixture built at the current version cannot
  // fail. The same class as the seed that never reached the device: a step
  // written for one starting point, reached from another.
  if (from >= 3 && from < 4 && to >= 4) {
    // Presentation only. The glyph moves OUT of the stored value and into its
    // own column — see [VocabularyEntry.emoji] for the three defects that
    // caused. `ensureSeeded` backfills the values on the next open, and runs
    // from `storage_boot` on every open precisely so it can.
    for (final t in kVocabularyTables) {
      await db.execute('ALTER TABLE $t ADD COLUMN emoji TEXT');
    }
  }
  // ONE-SIDED BOUND, unlike the v4 step above, and the difference is worth
  // stating because the v4 comment warns about exactly this.
  //
  // v4 needed a two-sided bound because `createVocabularySql` emits the CURRENT
  // column list, so the v3 step CREATED those tables already carrying `emoji`.
  // The `event` table has no such problem: it is created only in `onCreate` and
  // by no upgrade step, so a database being upgraded reaches here with the
  // column list it was born with and can never already have these three.
  if (from < 5 && to >= 5) {
    await db.execute('ALTER TABLE event ADD COLUMN rescue_med_given INTEGER');
    await db.execute('ALTER TABLE event ADD COLUMN rescue_med_helped TEXT');
    await db
        .execute('ALTER TABLE event ADD COLUMN rescue_med_second_dose INTEGER');
  }
  if (from < 6 && to >= 6) {
    await db.execute(createMedicationNoteSql);
    await db.execute(createMedicationNoteIndexSql);
    await retireMedicationEventType(db);
  }
  await putMeta(db, kMetaSchemaVersion, '$kSqliteSchemaVersion');
}

Future<void> createSchema(Database db) async {
  await db.execute(createSchemaMetaSql);
  await db.execute(createEventSql);
  await db.execute(createEventIdIndexSql);
  await db.execute(createEventLoggedAtIndexSql);
  await createAndSeedVocabularies(db);
  await db.execute(createMedicationNoteSql);
  await db.execute(createMedicationNoteIndexSql);
  await retireMedicationEventType(db);
  await db.insert('schema_meta', {
    'key': kMetaSchemaVersion,
    'value': '$kSqliteSchemaVersion',
  });
}

Future<void> putMeta(DatabaseExecutor db, String key, String value) =>
    db.insert('schema_meta', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);

Future<String?> getMeta(DatabaseExecutor db, String key) async {
  final rows = await db.query('schema_meta',
      columns: ['value'], where: 'key = ?', whereArgs: [key], limit: 1);
  if (rows.isEmpty) return null;
  final v = rows.first['value'];
  return v is String ? v : null;
}

/// Severity as an INTEGER rather than a three-value enum column.
///
/// mild/moderate/severe map to 1/2/3, which is lossless today and leaves the
/// column forward-compatible with a wider scale without an ALTER on populated
/// data. DATA-MODEL.md §10 records that the value type may become
/// condition-defined; an INTEGER column does not have to change if it does.
int severityToInt(EventSeverity s) {
  switch (s) {
    case EventSeverity.mild:
      return 1;
    case EventSeverity.moderate:
      return 2;
    case EventSeverity.severe:
      return 3;
  }
}

EventSeverity? severityFromInt(Object? v) {
  if (v is! int) return null;
  switch (v) {
    case 1:
      return EventSeverity.mild;
    case 2:
      return EventSeverity.moderate;
    case 3:
      return EventSeverity.severe;
  }
  return null;
}

/// Row shape for one [EventRecord] at [ordinal].
///
/// Writes CONCRETE values for every field, because an [EventRecord] cannot
/// express unknown. NULLs are written only by the migration, which reads the
/// raw JSON and can tell an absent key from a present one.
Map<String, Object?> eventToRow(EventRecord r, int ordinal) => {
      'ordinal': ordinal,
      'id': r.id,
      'logged_at': r.timestamp.toIso8601String(),
      'occurred_at': null,
      'duration_bucket': r.duration?.name,
      'duration_seconds': r.durationSeconds,
      'event_type': r.eventType,
      // NULL stays NULL through the column, which has always been nullable —
      // the schema was written for this and only the model was coercing.
      'severity': r.severity == null ? null : severityToInt(r.severity!),
      'feelings_json': jsonEncode(r.feelings),
      'triggers_json': jsonEncode(r.triggers),
      'notes': r.notes,
      'referral_required': r.referralRequired ? 1 : 0,
      'details_completed': r.detailsCompleted == null
          ? null
          : (r.detailsCompleted! ? 1 : 0),
      // Written INDEPENDENTLY of each other. The store does not re-apply the
      // UI's gate: if a record carries a child without its parent, that is what
      // is persisted. See [EventRecord.rescueMedGiven].
      'rescue_med_given': r.rescueMedGiven == null
          ? null
          : (r.rescueMedGiven! ? 1 : 0),
      'rescue_med_helped': r.rescueMedHelped?.name,
      'rescue_med_second_dose': r.rescueMedSecondDose == null
          ? null
          : (r.rescueMedSecondDose! ? 1 : 0),
    };

List<String> decodeStringList(Object? raw) {
  if (raw is! String || raw.isEmpty) return <String>[];
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <String>[];
    return decoded.map((e) => e.toString()).toList();
  } catch (_) {
    return <String>[];
  }
}

/// Rebuilds an [EventRecord] from a row.
///
/// Applies EXACTLY the fallbacks `EventRecord.fromMap` applies, so a NULL
/// column produces the same in-memory record the JSON store produced for an
/// absent key. The database is more honest than the model; the app behaves
/// identically either way.
EventRecord? eventFromRow(Map<String, Object?> row) {
  final rawLoggedAt = row['logged_at'];
  if (rawLoggedAt is! String) return null;
  final ts = DateTime.tryParse(rawLoggedAt);
  if (ts == null) return null;

  return EventRecord(
    id: row['id'] is String ? row['id'] as String : '',
    timestamp: ts.toLocal(),
    duration: durationFromName(row['duration_bucket']),
    durationSeconds:
        (row['duration_seconds'] is int) ? row['duration_seconds'] as int : null,
    feelings: decodeStringList(row['feelings_json']),
    referralRequired: row['referral_required'] == 1,
    notes: row['notes'] is String ? row['notes'] as String : '',
    // Verbatim, like fromMap. A user-defined type is a string this code has
    // never seen, and narrowing it to a known one would rewrite the record.
    eventType: (row['event_type'] is String &&
            (row['event_type'] as String).isNotEmpty)
        ? row['event_type'] as String
        : null,
    // The `?? mild` that was here is the same defect as fromMap's orElse: it
    // turned a NULL column — which the schema has always allowed — into a
    // confident clinical claim on the way out.
    severity: severityFromInt(row['severity']),
    triggers: decodeStringList(row['triggers_json']),
    // NULL stays null. `== 1` alone would turn NULL into false and
    // route 71 records into a wizard that does not describe them.
    detailsCompleted: row['details_completed'] == null
        ? null
        : row['details_completed'] == 1,
    // Same NULL discipline. A column that predates the ALTER reads NULL on
    // every existing row, which is exactly right - those records were never
    // asked.
    rescueMedGiven: row['rescue_med_given'] == null
        ? null
        : row['rescue_med_given'] == 1,
    rescueMedHelped: RescueResponse.values
        .where((e) => e.name == row['rescue_med_helped'])
        .firstOrNull,
    rescueMedSecondDose: row['rescue_med_second_dose'] == null
        ? null
        : row['rescue_med_second_dose'] == 1,
  );
}

class SqliteEventStore implements EventStore {
  SqliteEventStore(this.db);

  final Database db;

  @override
  Future<List<EventRecord>> load() => EventStore.serialise(_load);

  Future<List<EventRecord>> _load() async {
    final rows = await db.query('event', orderBy: 'ordinal ASC');
    return rows.map(eventFromRow).whereType<EventRecord>().toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Rewrite-everything, preserved on purpose — see [EventStore].
  ///
  /// Inside ONE transaction, so a kill mid-write leaves the previous contents
  /// intact rather than a partial history. That is strictly stronger than the
  /// old store's rollback key, which bounded the loss rather than preventing it.
  @override
  Future<void> save(List<EventRecord> records) {
    final snapshot = List<EventRecord>.of(records);
    return EventStore.serialise(() => db.transaction((txn) async {
          await txn.delete('event');
          final batch = txn.batch();
          for (var i = 0; i < snapshot.length; i++) {
            batch.insert('event', eventToRow(snapshot[i], i));
          }
          await batch.commit(noResult: true);
        }));
  }

  /// Clears BOTH stores.
  ///
  /// Returns [SharedPreferences] because the interface does and the one caller
  /// (the reset path) uses it. The old key goes here because this is an
  /// explicit user-initiated reset — the one case where leaving it would
  /// resurrect deleted events on the next launch.
  @override
  Future<SharedPreferences> clearAll() async {
    await EventStore.serialise(() => db.delete('event'));
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    return prefs;
  }
}
