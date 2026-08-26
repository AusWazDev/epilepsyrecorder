import 'package:sqflite_common/sqlite_api.dart';

/// User-extensible vocabularies: event types and observations.
///
/// ## The one idea this file exists for
///
/// **A vocabulary entry has a `value` and a `label`, and they are not the same
/// thing.** `value` is what gets written into a record and is IMMUTABLE. `label`
/// is what a person reads and may change. Every safety property here follows
/// from that split:
///
///   * renaming an entry touches `label` only, so no record is ever orphaned;
///   * retiring an entry sets `isActive = 0`, so it vanishes from pickers while
///     records that reference it still render;
///   * nothing is ever deleted, so no record can point at a row that is gone.
///
/// Collapse "Just tired" into "Tired" by RETIRING the old entry and seeding the
/// new one. The three records carrying `😵 Confused` keep that exact string
/// forever, and it keeps rendering, because its row is still there.
///
/// ## Why two tables and not one with a `kind` column
///
/// They diverge in the target model and the divergence is already known:
/// `event_type` is per-condition and gains `condition_id`; observations are
/// SHARED across conditions by decision (DATA-MODEL.md §1, principle 4 — one
/// vocabulary, "someone tracking two conditions does not configure 'Poor sleep'
/// twice"). A `kind` column would have to carry a `condition_id` that is
/// meaningful for half its rows and meaningless for the other half.
///
/// The MECHANISM is shared instead: one [VocabularyEntry], one set of queries,
/// one seed routine, parameterised by table name.
///
/// ## condition_id
///
/// `event_type.condition_id` exists, is NULLABLE, and is NEVER populated this
/// stage. There is no `condition` table and no screen on which a person could
/// say what they track, so any value written here would be an assertion about
/// someone's health invented by a migration. NULL means NOT YET SAID — the same
/// rule as `occurredAt`, `detailsCompleted`, duration at creation, and the
/// legacy buckets.

/// Table names. Used as an identifier in SQL, so they are never interpolated
/// from anything a user can influence.
const String kEventTypeTable = 'event_type';
const String kObservationTable = 'observation';

const List<String> kVocabularyTables = <String>[
  kEventTypeTable,
  kObservationTable,
];

/// One entry in either vocabulary.
class VocabularyEntry {
  const VocabularyEntry({
    required this.id,
    required this.value,
    required this.label,
    required this.isSeeded,
    required this.isActive,
    required this.isProtected,
    required this.sortOrder,
    this.conditionId,
  });

  final int id;

  /// **The stored string. Never changes, for any reason.** This is what appears
  /// inside `EventRecord.feelings`, `EventRecord.eventType` and every backup
  /// file and CSV ever exported. Changing it orphans records.
  final String value;

  /// What a person reads. May be changed by a rename; seeded entries refuse.
  final String label;

  /// MER shipped it. Seeded entries refuse rename and delete.
  final bool isSeeded;

  /// Offered in pickers. A retired entry is `false` and still renders in
  /// history — that is the whole point of retiring rather than deleting.
  final bool isActive;

  /// May not be hidden. Exactly one entry carries this: "Medication taken".
  /// See [kMedicationValue].
  final bool isProtected;

  final int sortOrder;

  /// NULLABLE and unpopulated this stage. See the file header.
  final int? conditionId;

  VocabularyEntry copyWith({String? label, bool? isActive, int? sortOrder}) =>
      VocabularyEntry(
        id: id,
        value: value,
        label: label ?? this.label,
        isSeeded: isSeeded,
        isActive: isActive ?? this.isActive,
        isProtected: isProtected,
        sortOrder: sortOrder ?? this.sortOrder,
        conditionId: conditionId,
      );

  Map<String, Object?> toRow() => <String, Object?>{
        'id': id,
        'value': value,
        'label': label,
        'is_seeded': isSeeded ? 1 : 0,
        'is_active': isActive ? 1 : 0,
        'is_protected': isProtected ? 1 : 0,
        'sort_order': sortOrder,
        'condition_id': conditionId,
      };

  static VocabularyEntry fromRow(Map<String, Object?> row) => VocabularyEntry(
        id: row['id'] as int,
        value: row['value'] as String,
        label: row['label'] as String,
        isSeeded: row['is_seeded'] == 1,
        isActive: row['is_active'] == 1,
        isProtected: row['is_protected'] == 1,
        sortOrder: row['sort_order'] as int? ?? 0,
        conditionId: row['condition_id'] as int?,
      );
}

/// Raised when an operation would orphan a record or edit something MER owns.
///
/// A distinct type rather than an assert: these are reachable from the UI, and
/// the UI has to explain WHY rather than just refusing.
class VocabularyRuleError implements Exception {
  const VocabularyRuleError(this.message);
  final String message;
  @override
  String toString() => message;
}

// ── DDL ──────────────────────────────────────────────────────────────────────

/// Both tables have the same shape. `condition_id` is present on both so the
/// mechanism stays one thing; only `event_type` will ever populate it, and not
/// this stage.
///
/// `value` is UNIQUE: two rows with the same stored string would make rendering
/// a record ambiguous, which is the one thing this design must never allow.
String createVocabularySql(String table) => 'CREATE TABLE $table ('
    'id INTEGER PRIMARY KEY AUTOINCREMENT, '
    'condition_id INTEGER, '
    'value TEXT NOT NULL UNIQUE, '
    'label TEXT NOT NULL, '
    'is_seeded INTEGER NOT NULL, '
    'is_active INTEGER NOT NULL, '
    'is_protected INTEGER NOT NULL, '
    'sort_order INTEGER NOT NULL)';

// ── SEEDS ────────────────────────────────────────────────────────────────────

/// The value stored for medication events. Protected — see [seedEventTypes].
const String kMedicationValue = 'medication';

/// The value stored for the no-fit escape hatch, in BOTH vocabularies.
const String kOtherEventTypeValue = 'other';
const String kOtherObservationValue = 'Other';

/// A seed row, before it has an id.
class VocabularySeed {
  const VocabularySeed(
    this.value,
    this.label, {
    this.isActive = true,
    this.isProtected = false,
  });
  final String value;
  final String label;
  final bool isActive;
  final bool isProtected;
}

/// Event types, reproducing today's four EXACTLY.
///
/// The `value`s are the enum `.name` strings already persisted in every record
/// (`seizure`, `absence`, `medication`, `other`) and the labels are today's
/// labels character for character. Nothing about an existing record changes.
///
/// **"Other / custom" is LAST and permanent.** Not retired, not renamed. The
/// research reason is the load-bearing one: every section of a real diary keeps
/// an "Other" alongside its custom vocabulary, because it means *this does not
/// fit the ones I have made either*, and it is what stops someone abandoning a
/// log when no chip fits. In a medical diary the cost of no-fit is a MISSING
/// RECORD.
///
/// **"Medication taken" is PROTECTED and may not be hidden**, on top of the
/// seeded rules. Every published source treats medication as a separate stream;
/// it is an event type here by historical accident and a later stage splits it
/// out into `medication_note`. A hide between now and then produces records that
/// split cannot reliably identify.
const List<VocabularySeed> kSeedEventTypes = <VocabularySeed>[
  VocabularySeed('seizure', 'Seizure / fit'),
  VocabularySeed('absence', 'Absence episode'),
  VocabularySeed(kMedicationValue, 'Medication taken', isProtected: true),
  VocabularySeed(kOtherEventTypeValue, 'Other / custom'),
];

/// The observation values shipped before the revision, WITH their emoji.
///
/// Retired, never deleted: `isActive: false`. They are here so that a record
/// carrying `😵 Confused` still renders, and so that the revision is a change to
/// what is OFFERED rather than a rewrite of what was RECORDED.
///
/// The emoji are part of the stored string, not decoration — that is why they
/// cannot simply be dropped.
const List<VocabularySeed> kLegacyObservations = <VocabularySeed>[
  VocabularySeed('😴 Tired and weary', 'Tired and weary', isActive: false),
  VocabularySeed('😪 Just tired', 'Just tired', isActive: false),
  VocabularySeed('😩 Just weary', 'Just weary', isActive: false),
  VocabularySeed('🤕 Experiencing a headache', 'Experiencing a headache',
      isActive: false),
  VocabularySeed('😢 Sad', 'Sad', isActive: false),
  VocabularySeed('😵 Confused', 'Confused', isActive: false),
  VocabularySeed('😠 Annoyed', 'Annoyed', isActive: false),
  VocabularySeed('😡 Angry', 'Angry', isActive: false),
  VocabularySeed('😰 Anxious', 'Anxious', isActive: false),
  VocabularySeed('🤢 Nauseous', 'Nauseous', isActive: false),
  VocabularySeed('😣 In pain', 'In pain', isActive: false),
];

/// The revised observation set.
///
/// ⚠️ **A SOURCED DRAFT, NOT CLINICALLY VALIDATED.** Drawn from published
/// seizure diaries during the epilepsy research pass and recorded in the Change
/// Register. It needs a clinical eye before release. The three ADDITIONS —
/// Weak, Memory gap, Speech difficulty — are the most clinically meaningful and
/// therefore the ones most needing review.
///
/// The revision, and why each:
///   COLLAPSED  "Tired and weary" / "Just tired" / "Just weary" -> Tired
///              Three chips on one axis, never pressure-tested, and severity
///              already carries intensity.
///   COLLAPSED  "Annoyed" / "Angry" -> Angry and Irritable
///              Same axis, same problem.
///   REWORDED   "In pain" -> "Sore or aching"
///              Postictal muscle pain from convulsion is a distinct reported
///              thing; "in pain" means anything.
///   ADDED      Weak — postictal weakness, sometimes one-sided.
///   ADDED      Memory gap — not remembering the event or the period after is
///              among the most useful things a diary can capture, and there was
///              nowhere to record it.
///   ADDED      Speech difficulty — postictal aphasia.
///   KEPT       Confused, Headache, Nauseous, Sad, Anxious.
///
/// **No emoji.** DATA-MODEL.md §6 requires emoji stripped from values as well
/// as headers, and the legacy strings already render as mojibake in History
/// rows on the tablet. New values are plain text; the legacy ones keep theirs
/// because they are stored data.
///
/// "Other" is LAST here too, for the same reason as event types.
const List<VocabularySeed> kSeedObservations = <VocabularySeed>[
  VocabularySeed('Tired', 'Tired'),
  VocabularySeed('Weak', 'Weak'),
  VocabularySeed('Memory gap', 'Memory gap'),
  VocabularySeed('Speech difficulty', 'Speech difficulty'),
  VocabularySeed('Confused', 'Confused'),
  VocabularySeed('Headache', 'Headache'),
  VocabularySeed('Sore or aching', 'Sore or aching'),
  VocabularySeed('Nauseous', 'Nauseous'),
  VocabularySeed('Sad', 'Sad'),
  VocabularySeed('Anxious', 'Anxious'),
  VocabularySeed('Angry', 'Angry'),
  VocabularySeed('Irritable', 'Irritable'),
  VocabularySeed(kOtherObservationValue, 'Other'),
];

/// Inserts seeds that are not already present, matched on `value`.
///
/// Idempotent by `value`, so re-running it on an already-seeded database adds
/// nothing and changes nothing. That matters because the seed runs from BOTH
/// `onCreate` and `onUpgrade`, and a future seed addition must be able to run
/// over a database that already holds the earlier ones.
///
/// Ordering is the list order, offset so retired legacy entries sort behind the
/// live set rather than interleaving with it.
Future<void> seedVocabulary(
  DatabaseExecutor db,
  String table,
  List<VocabularySeed> seeds, {
  int sortBase = 0,
}) async {
  final existing = <String>{
    for (final r in await db.query(table, columns: <String>['value']))
      r['value'] as String,
  };

  var i = 0;
  for (final s in seeds) {
    final order = sortBase + i;
    i++;
    if (existing.contains(s.value)) continue;
    await db.insert(table, <String, Object?>{
      'condition_id': null,
      'value': s.value,
      'label': s.label,
      'is_seeded': 1,
      'is_active': s.isActive ? 1 : 0,
      'is_protected': s.isProtected ? 1 : 0,
      'sort_order': order,
    });
  }
}

/// The same string as it appears when its UTF-8 bytes were decoded as Latin-1.
///
/// ⚠️ **FOUND ON THE TABLET, 26-Aug-26, and NOT CAUSED BY THIS WORK.** Three
/// records store `Ã°ÂŸÂ˜Âµ Confused` rather than `😵 Confused` — the UTF-8 bytes
/// of the emoji (F0 9F 98 B5) read back as four Latin-1 characters. They have
/// rendered that way in History for as long as the records have existed; the
/// vocabulary work only made it visible, because an unmatched value now gets
/// its own chip instead of blending into a row.
///
/// **The cause is UNKNOWN and is deliberately not guessed at.** Nothing in the
/// current write path does this — `jsonEncode`/`jsonDecode` are UTF-16 safe and
/// `writeAsString` defaults to UTF-8. Whatever produced it is upstream and
/// historical. Recording it as unexplained is better than supplying the next
/// plausible cause.
///
/// **What this does about it, and what it deliberately does NOT do.** It seeds
/// the mangled twin of each legacy value as a further RETIRED entry, so those
/// records resolve to a readable label. It does not rewrite a single stored
/// value: that is the same rule the whole revision follows, and it applies with
/// more force here, not less — a repair that edits records is unreviewable
/// afterwards, whereas a vocabulary row can be read, counted and removed.
///
/// The transform is EXACT and reversible, not a guess: `s.codeUnits` re-read as
/// UTF-8. Applied only to the eleven strings MER itself shipped, so it cannot
/// touch anything a user typed.
String? latin1Mangled(String s) {
  try {
    final bytes = <int>[];
    for (final r in s.runes) {
      if (r > 0xFFFF) {
        // Non-BMP: encode manually, since String.codeUnits would give
        // surrogates rather than the UTF-8 bytes that were mis-decoded.
        bytes.addAll(<int>[
          0xF0 | (r >> 18),
          0x80 | ((r >> 12) & 0x3F),
          0x80 | ((r >> 6) & 0x3F),
          0x80 | (r & 0x3F),
        ]);
      } else if (r > 0x7FF) {
        bytes.addAll(<int>[
          0xE0 | (r >> 12),
          0x80 | ((r >> 6) & 0x3F),
          0x80 | (r & 0x3F),
        ]);
      } else if (r > 0x7F) {
        bytes.addAll(<int>[0xC0 | (r >> 6), 0x80 | (r & 0x3F)]);
      } else {
        bytes.add(r);
      }
    }
    final mangled = String.fromCharCodes(bytes);
    // Only interesting when it actually differs — an ASCII-only string maps to
    // itself and would collide with the real entry's UNIQUE value.
    return mangled == s ? null : mangled;
  } catch (_) {
    return null;
  }
}

/// The mangled twins, as seeds. Same labels as the originals.
List<VocabularySeed> mangledLegacyObservations() {
  final out = <VocabularySeed>[];
  for (final s in kLegacyObservations) {
    final m = latin1Mangled(s.value);
    if (m != null) out.add(VocabularySeed(m, s.label, isActive: false));
  }
  return out;
}

/// Creates and seeds both vocabularies.
///
/// Legacy observations are seeded at a HIGH sort base so that if one is ever
/// re-activated it appears after the revised set rather than in the middle of
/// it.
Future<void> createAndSeedVocabularies(DatabaseExecutor db) async {
  for (final t in kVocabularyTables) {
    await db.execute(createVocabularySql(t));
  }
  await seedVocabulary(db, kEventTypeTable, kSeedEventTypes);
  await seedVocabulary(db, kObservationTable, kSeedObservations);
  await seedVocabulary(db, kObservationTable, kLegacyObservations,
      sortBase: 1000);
  // The mis-decoded twins, so records carrying them read correctly. Retired,
  // like the originals — see [latin1Mangled].
  await seedVocabulary(db, kObservationTable, mangledLegacyObservations(),
      sortBase: 2000);
}

// ── QUERIES AND MUTATIONS ────────────────────────────────────────────────────

/// Every row, active and retired, in sort order.
///
/// History and the CSV need the retired ones to render records that reference
/// them, so "all" is the default and "active only" is the special case — the
/// opposite of the obvious arrangement, and deliberately so: a caller that
/// forgets which it wanted gets the one that cannot lose data.
Future<List<VocabularyEntry>> loadVocabulary(
    DatabaseExecutor db, String table) async {
  final rows = await db.query(table, orderBy: 'sort_order, id');
  return rows.map(VocabularyEntry.fromRow).toList();
}

/// What a picker offers: active entries, "Other" forced last.
List<VocabularyEntry> offerable(List<VocabularyEntry> all) {
  final active = all.where((e) => e.isActive).toList();
  final other = active
      .where((e) =>
          e.value == kOtherEventTypeValue || e.value == kOtherObservationValue)
      .toList();
  final rest = active
      .where((e) =>
          e.value != kOtherEventTypeValue && e.value != kOtherObservationValue)
      .toList();
  return <VocabularyEntry>[...rest, ...other];
}

/// The label to render for a stored [value].
///
/// Falls back to the value itself when nothing matches. That is not a defect to
/// be fixed later: a record may carry a string from a backup made on another
/// device whose vocabulary this one has never seen, and showing the raw string
/// is strictly better than showing nothing or "unknown".
String labelForValue(List<VocabularyEntry> all, String value) {
  for (final e in all) {
    if (e.value == value) return e.label;
  }
  return value;
}

/// Adds a user-defined entry, or returns the existing one if the value is
/// already present.
///
/// Matching is case-insensitive and whitespace-trimmed on the LABEL a person
/// typed, so "tired" does not create a second entry beside "Tired". The stored
/// `value` is the trimmed text as typed.
///
/// Returns null for empty input rather than creating a blank entry.
Future<VocabularyEntry?> addUserEntry(
  DatabaseExecutor db,
  String table,
  String typed,
) async {
  final text = typed.trim();
  if (text.isEmpty) return null;

  final all = await loadVocabulary(db, table);
  for (final e in all) {
    if (e.label.toLowerCase() == text.toLowerCase() ||
        e.value.toLowerCase() == text.toLowerCase()) {
      // Already exists — including as a RETIRED entry. Returning it rather than
      // reviving it keeps the retirement decision with whoever made it; the
      // caller decides whether to re-activate.
      return e;
    }
  }

  final maxOrder = all
      .where((e) => !e.isSeeded)
      .fold<int>(0, (m, e) => e.sortOrder > m ? e.sortOrder : m);
  // User entries sort after the seeded set but before the retired legacy block.
  final order = maxOrder == 0 ? 500 : maxOrder + 1;

  final id = await db.insert(table, <String, Object?>{
    'condition_id': null,
    'value': text,
    'label': text,
    'is_seeded': 0,
    'is_active': 1,
    'is_protected': 0,
    'sort_order': order,
  });

  return VocabularyEntry(
    id: id,
    value: text,
    label: text,
    isSeeded: false,
    isActive: true,
    isProtected: false,
    sortOrder: order,
  );
}

/// Renames an entry's LABEL. The stored `value` is untouched, always.
///
/// **This is the orphan guard, and it is structural rather than checked.** There
/// is no code path here that writes `value`, so no rename can detach a record
/// from its entry. A test asserts the same thing from the outside — see
/// `vocabulary_test.dart`.
///
/// Refuses on seeded entries: MER owns those strings, a later stage splits
/// medication out on them, and Help describes them.
Future<VocabularyEntry> renameEntry(
  DatabaseExecutor db,
  String table,
  VocabularyEntry entry,
  String newLabel,
) async {
  if (entry.isSeeded) {
    throw const VocabularyRuleError(
      'This one comes with the app and cannot be renamed. You can hide it and '
      'add your own instead.',
    );
  }
  final text = newLabel.trim();
  if (text.isEmpty) {
    throw const VocabularyRuleError('A name cannot be empty.');
  }
  await db.update(table, <String, Object?>{'label': text},
      where: 'id = ?', whereArgs: <Object?>[entry.id]);
  return entry.copyWith(label: text);
}

/// Retires an entry so pickers stop offering it. Records keep rendering.
///
/// Refuses on [VocabularyEntry.isProtected] — "Medication taken" only.
Future<VocabularyEntry> setActive(
  DatabaseExecutor db,
  String table,
  VocabularyEntry entry,
  bool active,
) async {
  if (!active && entry.isProtected) {
    throw const VocabularyRuleError(
      'Medication is recorded separately from events, and a future version of '
      'MER moves it out of this list. Hiding it now would leave records that '
      'move cannot identify.',
    );
  }
  await db.update(table, <String, Object?>{'is_active': active ? 1 : 0},
      where: 'id = ?', whereArgs: <Object?>[entry.id]);
  return entry.copyWith(isActive: active);
}

/// There is no delete.
///
/// Not "delete is discouraged" — the function does not exist. Deleting a row a
/// record references is the one operation that cannot be undone from within the
/// app, and `is_active` covers every reason someone would want it.
const String kWhyNoDelete =
    'Entries are hidden, never deleted, so records that already use them keep '
    'reading correctly.';
