import 'package:sqflite_common/sqlite_api.dart';

/// A condition a person tracks. Epilepsy, migraine, something MER has never
/// heard of.
///
/// ## ⚠️ NOTHING IS SEEDED, AND NOTHING IS ASSIGNED
///
/// The table is created **empty**, and the 72 records on the device keep
/// `condition_id` NULL. Naming a condition on someone's behalf and applying it
/// retroactively is an assertion about their health invented by a migration —
/// which was the blocker in all three design reads, and nullable is what
/// resolves it.
///
/// NULL means **NOT YET SAID**, the same rule as `occurredAt`,
/// `detailsCompleted`, duration at creation, the legacy buckets, and event
/// type.
class Condition {
  const Condition({
    required this.id,
    required this.name,
    this.seededKey,
    this.isActive = true,
    this.sortOrder = 0,
  });

  final int id;
  final String name;

  /// Non-null only for a condition MER itself defines.
  ///
  /// It is what tells the app whether extra typed fields apply — a seeded
  /// `epilepsy` may later carry fields MER has researched, where a user-named
  /// one gets the standard shape. **Nothing reads it yet**, and nothing seeds
  /// one, so it is null on everything that exists.
  final String? seededKey;

  final bool isActive;
  final int sortOrder;
}

const String kConditionTable = 'condition';

const String createConditionSql = 'CREATE TABLE $kConditionTable ('
    'id INTEGER PRIMARY KEY AUTOINCREMENT, '
    'name TEXT NOT NULL, '
    'seeded_key TEXT, '
    'is_active INTEGER NOT NULL, '
    'sort_order INTEGER NOT NULL)';

/// Relevance mapping: which observations matter for which condition.
///
/// ## ⛔ ORDERING, NOT MEMBERSHIP. ABSENCE SORTS LOWER; IT NEVER HIDES.
///
/// DATA-MODEL.md §1 principle 4: **one shared vocabulary with per-condition
/// ordering, not per-condition lists.** Someone tracking epilepsy and migraine
/// must not configure "Poor sleep" twice, and a migraine user must still be
/// able to reach every entry — they just see their relevant ones first.
///
/// A row here means "this observation is relevant to this condition". No row
/// means it sorts after the ones that have one. Nothing is ever removed from a
/// picker by this table.
///
/// ## ⚠️ AND WITH ONE CONDITION IT CHANGES NOTHING OBSERVABLE
///
/// Stated here rather than discovered later: per-condition ordering needs at
/// least TWO conditions to differ from a single global ordering. With one, a
/// mapping is indistinguishable from reordering the picker — the condition is
/// an indirection with a single value.
///
/// The table is built because it is the schema half and it is free; the
/// ordering is **not wired into any picker**, because with the device's actual
/// data it would reorder nothing and the code would be a consumer that cannot
/// be observed to work.
const String kConditionObservationTable = 'condition_observation';

const String createConditionObservationSql =
    'CREATE TABLE $kConditionObservationTable ('
    'condition_id INTEGER NOT NULL, '
    'observation_id INTEGER NOT NULL, '
    'sort_order INTEGER NOT NULL)';

/// ⛔ **`condition_trigger` IS NOT BUILT, AND IT CANNOT BE.**
///
/// DATA-MODEL.md names it beside `condition_observation` as though the two were
/// symmetrical. They are not: observations became a table, but the beforehand
/// field is still `kTriggerOptions` — a `const List<String>` in
/// `constants.dart` with no rows and no ids to map to.
///
/// **Triggers-as-a-vocabulary is an undocumented prerequisite** for that half
/// of the model. Recorded here rather than left as an absence someone
/// rediscovers.
const String kConditionTriggerNotBuilt =
    'condition_trigger requires triggers to be a vocabulary table. '
    'They are still a const list.';

Condition? conditionFromRow(Map<String, Object?> row) {
  final id = row['id'];
  final name = row['name'];
  if (id is! int || name is! String) return null;
  return Condition(
    id: id,
    name: name,
    seededKey: row['seeded_key'] is String ? row['seeded_key'] as String : null,
    isActive: row['is_active'] == 1,
    sortOrder: row['sort_order'] is int ? row['sort_order'] as int : 0,
  );
}

Future<List<Condition>> loadConditions(DatabaseExecutor db) async {
  final rows = await db.query(kConditionTable, orderBy: 'sort_order, id');
  return rows.map(conditionFromRow).whereType<Condition>().toList();
}

/// Adds a condition, or returns the existing one if the name is already used.
///
/// Case-insensitive and trimmed, exactly like `addUserEntry` — so "Migraine"
/// does not create a second entry beside "migraine". Returns null for empty
/// input rather than creating a blank row.
Future<Condition?> addCondition(DatabaseExecutor db, String typed) async {
  final text = typed.trim();
  if (text.isEmpty) return null;

  for (final c in await loadConditions(db)) {
    if (c.name.toLowerCase() == text.toLowerCase()) return c;
  }
  final existing = await loadConditions(db);
  final order = existing.isEmpty ? 0 : existing.last.sortOrder + 1;
  final id = await db.insert(kConditionTable, <String, Object?>{
    'name': text,
    'seeded_key': null,
    'is_active': 1,
    'sort_order': order,
  });
  return Condition(id: id, name: text, sortOrder: order);
}

/// The store a screen is given. **Never a `Database`.**
///
/// Same rule `MedicationStore` follows, and for the same reason:
/// `sqlite_single_writer_test` forbids a screen holding one, because that is
/// what stops a screen writing rows behind a store's back.
class ConditionStore {
  const ConditionStore(this._db);

  final DatabaseExecutor? _db;

  bool get canPersist => _db != null;

  Future<List<Condition>> load() async {
    final db = _db;
    if (db == null) return const <Condition>[];
    return loadConditions(db);
  }

  Future<Condition?> add(String typed) async {
    final db = _db;
    if (db == null) return null;
    return addCondition(db, typed);
  }
}
