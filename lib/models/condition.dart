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
  /// It is what tells the app whether extra typed fields apply, and it is the
  /// key `kSeededRelevance` is looked up by.
  ///
  /// ⚠️ **CORRECTED 7 SEP 2026. This read "Nothing reads it yet", which
  /// has been false since `ce76d5a`** — `Vocabularies.load` reads it to build
  /// `_adoptedKeys`, which drives relevance ordering.
  ///
  /// ⛔ **STILL NULL ON EVERY DEVICE, checked 7 Sep 2026.** The only writers
  /// are [addCondition] and the restore path, and nothing has ever passed a
  /// non-null value — no catalogue exists for a user to choose from. So the
  /// reader exists, the writer exists, and the value does not.
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

/// ✅ **`condition_trigger` IS NOW BUILDABLE — and still is not built.**
///
/// It was blocked because the beforehand field was a `const List<String>` with
/// no rows and no ids to map to. Schema v9 made it a vocabulary table, so the
/// prerequisite is met.
///
/// ⛔ **BUILDABLE IS NOT USEFUL.** Relevance mapping is a no-op at one
/// condition — established last pass and unchanged by this one — so
/// `condition_trigger` would be a second table nothing reads, mapping a
/// vocabulary nothing orders. It waits for a second condition, which is a user
/// event rather than a build decision.
const String kConditionTriggerStatus =
    'condition_trigger is buildable since v9 made triggers a vocabulary. '
    'Not built: relevance mapping is a no-op at one condition.';

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
///
/// ## ⛔ ADOPTION STATE IS APPLIED ONLY ON CREATE, AND THAT IS EXISTING-WINS
///
/// `seededKey` and `isActive` are written **only when a row is inserted.** A
/// name already present returns the EXISTING condition untouched — its
/// adoption state is not overwritten, because a restore that reassigned it
/// would re-decide something the person on this device already decided.
///
/// ⚠️ **The cost, recorded rather than fixed:** adopt a condition on device
/// A while device B already holds that name unadopted, and no restore will
/// carry the adoption across. See `RestorePlan.conditionsToAdd`.
Future<Condition?> addCondition(
  DatabaseExecutor db,
  String typed, {
  String? seededKey,
  bool isActive = true,
}) async {
  final text = typed.trim();
  if (text.isEmpty) return null;

  for (final c in await loadConditions(db)) {
    if (c.name.toLowerCase() == text.toLowerCase()) return c;
  }
  final existing = await loadConditions(db);
  final order = existing.isEmpty ? 0 : existing.last.sortOrder + 1;
  final id = await db.insert(kConditionTable, <String, Object?>{
    'name': text,
    'seeded_key': seededKey,
    'is_active': isActive ? 1 : 0,
    'sort_order': order,
  });
  // ⛔ THE RETURNED OBJECT MUST AGREE WITH THE ROW JUST WRITTEN.
  //
  // Until 7 Sep 2026 this returned `Condition(id:, name:, sortOrder:)` while
  // writing `'seeded_key': null` unconditionally, so the two agreed only BY
  // COINCIDENCE — the object's defaults happened to match the literals. The
  // moment a caller could pass adoption state, that coincidence would have
  // become a caller holding an object that disagreed with its own row.
  return Condition(
    id: id,
    name: text,
    seededKey: seededKey,
    isActive: isActive,
    sortOrder: order,
  );
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
