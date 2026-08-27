import 'package:sqflite_common/sqlite_api.dart';

/// A medication DEVIATION. Not a dose, and not an event.
///
/// ## ⛔ EXCEPTIONS ONLY. DO NOT ASK THE USER TO LOG EVERY DOSE.
///
/// Daily logging is the most abandoned feature in health apps, and the data it
/// produces is mostly noise: a specialist does not need 340 confirmations of
/// adherence, they need the 25 deviations. So this records **missed, late or
/// changed** and nothing else.
///
/// ## Why it is a separate record kind rather than an event type
///
/// `medication` WAS an event type, and that was a live data-quality defect: a
/// dose and a seizure shared a row, a duration and a severity, and counted
/// identically — so the home screen's "N events this month" inflated the
/// seizure count for anyone tracking adherence. Every published source treats
/// medication as its own stream graphed AGAINST seizure activity, not as a kind
/// of seizure.
///
/// ## ⛔ CORRELATION IS FOR THE SPECIALIST, NOT THE APP
///
/// Both streams go in the export on one timeline and the specialist reads it.
/// **MER must not chart the connection, rank it, or surface it** — that is
/// interpretation, and it is the boundary the analysis tier was rejected over.
/// A missed dose three days before a cluster is a fact; "this caused that" is a
/// clinical judgement MER is not qualified to offer.
class MedicationNote {
  const MedicationNote({
    required this.id,
    required this.occurredAt,
    required this.loggedAt,
    required this.kind,
    this.notes = '',
  });

  final String id;

  /// When the deviation happened — the dose that was missed, late or changed.
  ///
  /// Separate from [loggedAt] deliberately: a missed dose is usually recorded
  /// hours later, which is the whole reason the stream is exceptions-only. The
  /// event side has the same pair (`occurred_at` / `logged_at`), and there
  /// `occurred_at` is still unpopulated — here it is the field that matters.
  final DateTime occurredAt;

  /// When it was written down. Never editable, always now.
  final DateTime loggedAt;

  final MedicationDeviation kind;

  /// Free text. **There is no drug-name field**, decided on burden grounds —
  /// notes covers it, and asking for a name every time is a reason not to log.
  final String notes;
}

/// ⛔ **STORED DATA. `.name` is persisted, so these three words are permanent
/// the moment one is written.** Same rule as [DurationCategory]: renaming one
/// is not a rename, it silently reclassifies every historical row.
enum MedicationDeviation { missed, late, changed }

String medicationDeviationLabel(MedicationDeviation k) {
  switch (k) {
    case MedicationDeviation.missed:
      return 'Missed';
    case MedicationDeviation.late:
      return 'Late';
    case MedicationDeviation.changed:
      return 'Changed';
  }
}

/// Resolves a stored name, or NULL when absent or unrecognised.
///
/// Never falls back to the first value. The `orElse` that produced `seizure`
/// and `mild` is the defect this project spent a week undoing.
MedicationDeviation? medicationDeviationFromName(Object? raw) {
  for (final k in MedicationDeviation.values) {
    if (k.name == raw) return k;
  }
  return null;
}

const String kMedicationNoteTable = 'medication_note';

/// ⚠️ **NO `condition_id`, deliberately, and this is a departure from
/// DATA-MODEL.md §2 worth stating rather than leaving to be noticed.**
///
/// The model lists a nullable `condition_id` here, and `event` carries one for
/// exactly that reason — built ahead of a purpose so the expansion stays
/// additive. The difference is that `event` was already a populated table when
/// that decision was made, so adding the column later would have meant altering
/// live rows.
///
/// This table is **empty and brand new**. Adding a column to it during the
/// conditions pass is `ALTER TABLE ADD COLUMN` on zero rows, which is free.
/// There is no cost to defer and no risk in deferring, so the column waits for
/// the pass that gives it meaning.
const String createMedicationNoteSql = 'CREATE TABLE $kMedicationNoteTable ('
    'id TEXT NOT NULL, '
    'occurred_at TEXT NOT NULL, '
    'logged_at TEXT NOT NULL, '
    // TEXT holding MedicationDeviation.name, not an integer ordinal. Readable
    // in a raw dump and immune to the enum being reordered.
    'kind TEXT NOT NULL, '
    'notes TEXT)';

const String createMedicationNoteIndexSql =
    'CREATE INDEX idx_medication_note_occurred '
    'ON $kMedicationNoteTable(occurred_at)';

Map<String, Object?> medicationNoteToRow(MedicationNote n) => <String, Object?>{
      'id': n.id,
      'occurred_at': n.occurredAt.toIso8601String(),
      'logged_at': n.loggedAt.toIso8601String(),
      'kind': n.kind.name,
      'notes': n.notes,
    };

/// Rebuilds a note from a row, or NULL if it cannot be trusted.
///
/// Same discipline as `EventRecord.fromMap`: an unparseable timestamp yields
/// null and the caller skips the row, rather than defaulting to now. A silently
/// wrong date in a medical record is worse than an omission.
MedicationNote? medicationNoteFromRow(Map<String, Object?> row) {
  final occurred = DateTime.tryParse('${row['occurred_at']}');
  final logged = DateTime.tryParse('${row['logged_at']}');
  final kind = medicationDeviationFromName(row['kind']);
  if (occurred == null || logged == null || kind == null) return null;
  return MedicationNote(
    id: row['id'] is String ? row['id'] as String : '',
    occurredAt: occurred.toLocal(),
    loggedAt: logged.toLocal(),
    kind: kind,
    notes: row['notes'] is String ? row['notes'] as String : '',
  );
}

/// Reads every note, newest deviation first.
Future<List<MedicationNote>> loadMedicationNotes(DatabaseExecutor db) async {
  final rows = await db.query(kMedicationNoteTable, orderBy: 'occurred_at DESC');
  return rows
      .map(medicationNoteFromRow)
      .whereType<MedicationNote>()
      .toList();
}

Future<void> insertMedicationNote(DatabaseExecutor db, MedicationNote n) =>
    db.insert(kMedicationNoteTable, medicationNoteToRow(n));

Future<void> deleteMedicationNote(DatabaseExecutor db, String id) =>
    db.delete(kMedicationNoteTable, where: 'id = ?', whereArgs: <Object?>[id]);

/// The medication stream's store. **The only thing a screen is given.**
///
/// ⛔ **A SCREEN MAY NOT HOLD A `Database`.** `sqlite_single_writer_test`
/// enforces it, and the first draft of `MedicationScreen` broke it by taking
/// one directly. The guard caught it, and the right response was this class
/// rather than adding a screen to the permitted list — the rule exists to stop
/// a screen writing rows behind a store's back, and a medication screen writing
/// medication rows is precisely the shape it forbids.
///
/// Deliberately NOT part of `EventStore`. That interface is the event list, and
/// widening it to carry a second record kind is how two streams start sharing
/// assumptions again — which is the defect the split exists to remove.
class MedicationStore {
  const MedicationStore(this._db);

  final DatabaseExecutor? _db;

  /// False on a fallback launch, where SQLite could not be opened.
  ///
  /// The screen renders and says so rather than offering an action that would
  /// silently not persist — the same rule `Vocabularies.canPersist` uses.
  bool get canPersist => _db != null;

  Future<List<MedicationNote>> load() async {
    final db = _db;
    if (db == null) return const <MedicationNote>[];
    return loadMedicationNotes(db);
  }

  Future<void> add(MedicationNote n) async {
    final db = _db;
    if (db == null) return;
    await insertMedicationNote(db, n);
  }

  Future<void> remove(String id) async {
    final db = _db;
    if (db == null) return;
    await deleteMedicationNote(db, id);
  }
}
