import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common/sqlite_api.dart';

import 'event_record.dart';
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
///
/// Every bump so far is ADDITIVE ONLY — new tables, and ADD COLUMN on a
/// populated table. Non-destructive, every existing value untouched, and the
/// new columns NULL on every existing row, which is exactly right: those
/// records predate the concept.
const int kSqliteSchemaVersion = 3;

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
    'condition_id INTEGER)';

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
  await putMeta(db, kMetaSchemaVersion, '$kSqliteSchemaVersion');
}

Future<void> createSchema(Database db) async {
  await db.execute(createSchemaMetaSql);
  await db.execute(createEventSql);
  await db.execute(createEventIdIndexSql);
  await db.execute(createEventLoggedAtIndexSql);
  await createAndSeedVocabularies(db);
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
      'severity': severityToInt(r.severity),
      'feelings_json': jsonEncode(r.feelings),
      'triggers_json': jsonEncode(r.triggers),
      'notes': r.notes,
      'referral_required': r.referralRequired ? 1 : 0,
      'details_completed': r.detailsCompleted == null
          ? null
          : (r.detailsCompleted! ? 1 : 0),
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
        : kTypeSeizure,
    severity: severityFromInt(row['severity']) ?? EventSeverity.mild,
    triggers: decodeStringList(row['triggers_json']),
    // NULL stays null. `== 1` alone would turn NULL into false and
    // route 71 records into a wizard that does not describe them.
    detailsCompleted: row['details_completed'] == null
        ? null
        : row['details_completed'] == 1,
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
