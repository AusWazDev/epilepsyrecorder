import 'dart:convert';
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
/// Sentinel for [VocabularyEntry.copyWith], so a nullable field can be CLEARED
/// rather than only set. See the note on `copyWith`.
const Object _unset = Object();

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
    this.emoji,
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

  /// PRESENTATION ONLY. Never part of `value`, never exported, never searched.
  ///
  /// ⚠️ **THIS COLUMN EXISTS BECAUSE PUTTING THE EMOJI IN THE VALUE CAUSED A
  /// REAL DEFECT.** The original vocabulary stored `😵 Confused` as the value,
  /// so the glyph was inside the record, inside every backup file, and inside
  /// every CSV. Three consequences followed, all of them observed rather than
  /// predicted:
  ///
  ///   * History rows rendered it as MOJIBAKE on the tablet — that text style
  ///     has no emoji coverage, and `ð..µ Confused` is what a clinician saw;
  ///   * three records on the device carry a mis-decoded form of it whose cause
  ///     is still unknown, and the corruption was invisible because the glyph
  ///     was data;
  ///   * `DATA-MODEL.md` §6 requires emoji stripped from values as well as
  ///     headers, which a value containing one cannot satisfy.
  ///
  /// Separating it fixes all three at once. The chips show the glyph, the
  /// record stores the word, and the two can never disagree because only one of
  /// them is stored.
  final String? emoji;

  /// What a picker shows. What a RECORD shows is [label] — deliberately
  /// different, so an emoji-less text style can never mangle a stored value.
  String get display => emoji == null ? label : '$emoji $label';

  /// ⚠️ `conditionId` takes a SENTINEL, not a plain null, because null is a
  /// meaningful VALUE here — it is what unassigning a type looks like. A plain
  /// `int? conditionId` could not distinguish 'leave it alone' from 'clear it'.
  VocabularyEntry copyWith({
    String? label,
    bool? isActive,
    int? sortOrder,
    Object? conditionId = _unset,
  }) =>
      VocabularyEntry(
        id: id,
        value: value,
        label: label ?? this.label,
        isSeeded: isSeeded,
        isActive: isActive ?? this.isActive,
        isProtected: isProtected,
        sortOrder: sortOrder ?? this.sortOrder,
        conditionId: identical(conditionId, _unset)
            ? this.conditionId
            : conditionId as int?,
        emoji: emoji,
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
        'emoji': emoji,
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
        emoji: row['emoji'] as String?,
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
    'sort_order INTEGER NOT NULL, '
    // Presentation only. See [VocabularyEntry.emoji].
    'emoji TEXT)';

// ── SEEDS ────────────────────────────────────────────────────────────────────

/// The value stored for medication events. Protected — see [seedEventTypes].
const String kMedicationValue = 'medication';

/// The value stored for the no-fit escape hatch, in BOTH vocabularies.
const String kOtherEventTypeValue = 'other';
const String kOtherObservationValue = 'Other';

/// The trigger vocabulary's catch-all: no known trigger.
///
/// ⚠️ It had NO CONSTANT until 29 Aug 2026 — it existed only as the bare
/// string `'Unknown'` inside `kSeedTriggers`, which is why it was missing
/// from the forced-last comparison in `offerable`. The two entries that HAD
/// constants were the two that were handled.
const String kUnknownTriggerValue = 'Unknown';

/// A seed row, before it has an id.
class VocabularySeed {
  const VocabularySeed(
    this.value,
    this.label, {
    this.isActive = true,
    this.isProtected = false,
    this.emoji,
  });
  final String value;
  final String label;
  final bool isActive;
  final bool isProtected;

  /// Presentation only, never written into a record. See
  /// [VocabularyEntry.emoji] for why this is a separate field.
  final String? emoji;
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
/// ⚠️ **Each carries its ORIGINAL glyph in `emoji` as well as inside `value`.**
/// The value keeps it because the value is stored data and must not change; the
/// `emoji` field is what a chip renders. So a record holding
/// `😴 Tired and weary` shows exactly the chip it has always shown, while the
/// CSV and the History row get the plain label.
const List<VocabularySeed> kLegacyObservations = <VocabularySeed>[
  VocabularySeed('😴 Tired and weary', 'Tired and weary', isActive: false, emoji: '😴'),
  VocabularySeed('😪 Just tired', 'Just tired', isActive: false, emoji: '😪'),
  VocabularySeed('😩 Just weary', 'Just weary', isActive: false, emoji: '😩'),
  VocabularySeed('🤕 Experiencing a headache', 'Experiencing a headache',
      isActive: false, emoji: '🤕'),
  VocabularySeed('😢 Sad', 'Sad', isActive: false, emoji: '😢'),
  VocabularySeed('😵 Confused', 'Confused', isActive: false, emoji: '😵'),
  VocabularySeed('😠 Annoyed', 'Annoyed', isActive: false, emoji: '😠'),
  VocabularySeed('😡 Angry', 'Angry', isActive: false, emoji: '😡'),
  VocabularySeed('😰 Anxious', 'Anxious', isActive: false, emoji: '😰'),
  VocabularySeed('🤢 Nauseous', 'Nauseous', isActive: false, emoji: '🤢'),
  VocabularySeed('😣 In pain', 'In pain', isActive: false, emoji: '😣'),
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
/// ⚠️ **NINE OF THESE GLYPHS ARE CARRIED OVER, FOUR ARE PROPOSALS.** The
/// distinction matters: a carried-over glyph is the one this app has shown for
/// that concept since launch, and changing it would change what a user
/// recognises. A proposed glyph is my choice and is one line to change.
///
///   CARRIED OVER, concept unchanged — not a judgement call:
///     Tired 😴 (was "Tired and weary")   Confused 😵
///     Headache 🤕 (was "Experiencing a headache")
///     Nauseous 🤢   Sad 😢   Anxious 😰   Angry 😡
///     Irritable 😠 (was "Annoyed", which collapsed into it)
///     Sore or aching 😣 (was "In pain"; the wince fits the narrower word
///                        better than it fit the broad one)
///
///   PROPOSED — MY CHOICE, and each is a guess about legibility at chip size:
///     Weak 🪫              a low battery, not a body part. Postictal weakness
///                          is sometimes one-sided and any limb glyph would
///                          assert which side.
///     Memory gap 🕳️        a hole. 🌫️ fog is the commoner patient metaphor
///                          and was rejected for overlapping "Confused".
///     Speech difficulty 🗣️ marks the FIELD, as 🤕 marks "headache" rather
///                          than the absence of pain. 🤐 reads as refusal.
///     Other ✏️             matches the pencil the form's "Other / custom"
///                          tile already uses.
const List<VocabularySeed> kSeedObservations = <VocabularySeed>[
  VocabularySeed('Tired', 'Tired', emoji: '😴'),
  VocabularySeed('Weak', 'Weak', emoji: '🪫'),
  VocabularySeed('Memory gap', 'Memory gap', emoji: '🕳️'),
  VocabularySeed('Speech difficulty', 'Speech difficulty', emoji: '🗣️'),
  VocabularySeed('Confused', 'Confused', emoji: '😵'),
  VocabularySeed('Headache', 'Headache', emoji: '🤕'),
  VocabularySeed('Sore or aching', 'Sore or aching', emoji: '😣'),
  VocabularySeed('Nauseous', 'Nauseous', emoji: '🤢'),
  VocabularySeed('Sad', 'Sad', emoji: '😢'),
  VocabularySeed('Anxious', 'Anxious', emoji: '😰'),
  VocabularySeed('Angry', 'Angry', emoji: '😡'),
  VocabularySeed('Irritable', 'Irritable', emoji: '😠'),
  VocabularySeed(kOtherObservationValue, 'Other', emoji: '✏️'),
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
      'emoji': s.emoji,
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
    if (m != null) {
      // The glyph comes from the CLEAN value, not the mangled one — the point
      // is that a corrupted record renders correctly, and rendering its own
      // corruption back at it would defeat that.
      out.add(VocabularySeed(m, s.label, isActive: false, emoji: s.emoji));
    }
  }
  return out;
}

/// Brings SEEDED rows' presentation fields up to date with the seed list.
///
/// ⚠️ **`seedVocabulary` SKIPS ANY VALUE ALREADY PRESENT, so a field added to an
/// existing seed never reaches a database that already has the row.** That is
/// not hypothetical — it is exactly how the mis-decoded twins failed to reach
/// the tablet one build ago, and the fix then was to run the seed on every open.
/// Running it changes nothing here, because the row already exists.
///
/// So presentation fields need their own pass. This one updates `emoji` and
/// `label` on rows MER owns, matched by `value`.
///
/// **`is_seeded = 1` ONLY.** A user's entry is theirs: MER does not relabel it
/// and does not decorate it. And `value` is never touched, by anything, ever —
/// that is what keeps records attached to their entry.
Future<void> syncSeededPresentation(
  DatabaseExecutor db,
  String table,
  List<VocabularySeed> seeds,
) async {
  for (final s in seeds) {
    await db.update(
      table,
      <String, Object?>{'emoji': s.emoji, 'label': s.label},
      where: 'value = ? AND is_seeded = 1',
      whereArgs: <Object?>[s.value],
    );
  }
}

/// Applies every seed list. Idempotent on `value`, and MUST RUN ON EVERY OPEN.
///
/// ⚠️ **THIS IS SEPARATE FROM CREATION FOR A REASON THAT COST A BUILD.** The
/// first version put the seeds inside the v2 -> v3 upgrade branch and noted in
/// a comment that they were "safe to re-run when a later version adds a seed".
/// They were safe to re-run and NOTHING RE-RAN THEM. The mis-decoded twins were
/// added a build later, the tablet's database was already at v3, so `from < 3`
/// was false and the new seeds never reached the device — the records they
/// exist to resolve still rendered as mojibake, and it took a device check to
/// notice, because every test opened a FRESH database where onCreate seeded
/// everything.
///
/// A seed list that grows needs a seed pass that runs. Two SELECTs on open.
///
/// Legacy observations sort at a HIGH base so that if one is ever re-activated
/// it appears after the revised set rather than in the middle of it; the
/// mis-decoded twins sort higher still.
Future<void> ensureSeeded(DatabaseExecutor db) async {
  await seedVocabulary(db, kEventTypeTable, kSeedEventTypes);
  await seedVocabulary(db, kObservationTable, kSeedObservations);
  await seedVocabulary(db, kObservationTable, kLegacyObservations,
      sortBase: 1000);
  // The mis-decoded twins, so records carrying them read correctly. Retired,
  // like the originals — see [latin1Mangled].
  await seedVocabulary(db, kObservationTable, mangledLegacyObservations(),
      sortBase: 2000);

  // AFTER the inserts, so a row that already existed gets the presentation
  // fields the insert above skipped. See `syncSeededPresentation`.
  await syncSeededPresentation(db, kEventTypeTable, kSeedEventTypes);
  await syncSeededPresentation(db, kObservationTable, kSeedObservations);
  await syncSeededPresentation(db, kObservationTable, kLegacyObservations);
  await syncSeededPresentation(
      db, kObservationTable, mangledLegacyObservations());
}

/// Creates both tables and seeds them.
Future<void> createAndSeedVocabularies(DatabaseExecutor db) async {
  for (final t in kVocabularyTables) {
    await db.execute(createVocabularySql(t));
  }
  await ensureSeeded(db);
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

/// The catch-all entry of a vocabulary — the one that must render LAST
/// wherever its list is shown, whatever its `sort_order` says.
///
/// ## ⛔ WHY THIS IS A FUNCTION AND NOT TWO `||` COMPARISONS
///
/// [offerable] used to inline `value == kOtherEventTypeValue || value ==
/// kOtherObservationValue`. That list was CORRECT and INCOMPLETE, which is the
/// dangerous combination: **`Unknown` on the trigger vocabulary is a catch-all
/// too and was not in it.** Nothing showed, because `Unknown` is the last seed
/// in `kSeedTriggers` and its `sort_order` put it last anyway — so the closed
/// list and the seed order agreed by coincidence, and the first trigger
/// appended after it would have separated them.
///
/// Which is exactly what happened: the migraine pass appends three. Had this
/// stayed a two-value comparison, `Unknown` would have rendered mid-list
/// immediately, on the shipped epilepsy path, from a migraine change.
///
/// ## ⚠️ SCOPED BY (TABLE, VALUE), NOT BY VALUE ALONE
///
/// The same discipline as [isShippedHidden]: a defect lives at an address, not
/// in a word. Keyed on the value alone, a USER'S OWN observation typed as
/// "Unknown" would be silently dragged to the end of their list — their entry,
/// reordered by a rule about somebody else's table.
///
/// ⚠️ **`sort_order` cannot do this job**, which is why the rule is applied at
/// read time rather than fixed in the data. `seedVocabulary` skips values that
/// already exist and `syncSeededPresentation` updates only `label` and `emoji`
/// — **nothing rewrites `sort_order` on a row that is already there.** So on
/// every existing database the catch-all keeps the order it was inserted with,
/// and any entry appended after it sorts later. Forcing it last on the way out
/// is the only fix that reaches a device already in the field.
bool isCatchAll(String table, String value) {
  if (table == kEventTypeTable) return value == kOtherEventTypeValue;
  if (table == kObservationTable) return value == kOtherObservationValue;
  if (table == kTriggerTable) return value == kUnknownTriggerValue;
  return false;
}

/// Orders a vocabulary for display: the catch-all last, everything else in
/// `sort_order`.
///
/// Used by [offerable] and by the management screen, which shows INACTIVE
/// entries too and therefore cannot go through it.
List<VocabularyEntry> catchAllLast(String table, List<VocabularyEntry> list) =>
    <VocabularyEntry>[
      ...list.where((e) => !isCatchAll(table, e.value)),
      ...list.where((e) => isCatchAll(table, e.value)),
    ];

/// What a picker offers: active entries, the catch-all forced last.
List<VocabularyEntry> offerable(String table, List<VocabularyEntry> all) =>
    catchAllLast(table, all.where((e) => e.isActive).toList());

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

/// Values MER itself SHIPPED hidden, which a user must not be able to show.
///
/// ## ⛔ `is_active` CONFLATES TWO DIFFERENT DECISIONS, AND ONLY ONE IS THE
/// USER'S TO REVERSE
///
/// Found the moment the management screen first rendered on the device: every
/// retired observation got a **Show** button. Those are the pre-revision
/// values, and the glyph is INSIDE the stored value — `😵 Confused`, not
/// `Confused` with a separate emoji column. Showing one puts it back in the
/// picker, and the next record written with it puts an emoji back into
/// `feelings_json`, into every CSV and into every backup.
///
/// **That is precisely what the revision existed to prevent** and what
/// `DATA-MODEL.md` §6 forbids. A one-tap path to it is worse than no hide
/// feature at all.
///
///     retired by MER      a shipped decision   NOT reversible by the user
///     hidden by the user  the user's choice    reversible, or hide is a delete
///
/// The flag cannot tell them apart, so this does. Membership is derived from
/// the seed constants rather than declared as a list, so a future retirement is
/// covered by adding the seed and nothing else.
bool isShippedHidden(String table, String value) {
  if (table == kEventTypeTable) {
    // Retired by `retireMedicationEventType`, whose own doc comment says
    // leaving it offered invites the defect the medication split removed.
    return value == kMedicationValue;
  }
  if (table == kObservationTable) {
    for (final s in kLegacyObservations) {
      if (s.value == value) return true;
    }
    for (final s in mangledLegacyObservations()) {
      if (s.value == value) return true;
    }
  }
  // Triggers have never been revised, so nothing shipped hidden. Verified from
  // the device: every stored trigger is ASCII and every seed is active.
  return false;
}

/// A value that exists ONLY to resolve a corrupted stored string.
///
/// ## ⛔ PRESENT IN THE VOCABULARY, ABSENT FROM THE MANAGEMENT SCREEN
///
/// The mis-decoded twins are not entries anybody chose. A user never picked
/// one, cannot pick one, and cannot act on one — they exist so that a record
/// holding `ðµ Confused` resolves to the readable word `Confused` instead of
/// rendering its own corruption.
///
/// On "Your lists" they rendered as a SECOND row identical to the clean legacy
/// entry: same label, same "replaced by newer wording" note, same lock. Eleven
/// of the twenty-two retired rows were duplicates of the other eleven, and five
/// labels appeared THREE times because the current seed set carries the same
/// word again.
///
/// ⚠️ **HIDING THEM IS ONLY SAFE BECAUSE OF A STRUCTURAL GUARANTEE**, and it is
/// asserted rather than assumed: [mangledLegacyObservations] is DERIVED from
/// [kLegacyObservations], so every twin has a clean sibling carrying an
/// identical label. The label a user can encounter therefore stays reachable
/// and explained; only the duplicate row goes. `vocabulary_screen_test` pins
/// that sibling property, because if it ever broke a twin's label would become
/// unreachable and the screen would start lying.
///
/// This is deliberately SEPARATE from [isShippedHidden] and must not be folded
/// into it. That one answers "may the user un-hide this" and governs a data
/// guard; this one answers "is there anything here for a person to read" and
/// governs a widget. A twin is both; a clean legacy entry is only the first.
bool isMisdecodedTwin(String table, String value) {
  if (table != kObservationTable) return false;
  for (final s in mangledLegacyObservations()) {
    if (s.value == value) return true;
  }
  return false;
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
  if (active && isShippedHidden(table, entry.value)) {
    throw const VocabularyRuleError(
      'This entry was replaced by a newer version of the same wording. It '
      'still shows on records that already use it, but offering it again '
      'would store an older format in new records.',
    );
  }
  await db.update(table, <String, Object?>{'is_active': active ? 1 : 0},
      where: 'id = ?', whereArgs: <Object?>[entry.id]);
  return entry.copyWith(isActive: active);
}

/// Assigns an event type to a condition, or clears it with null.
///
/// ## ⛔ ONE CONDITION PER TYPE, AND THE COLUMN SHAPE IS THE ENFORCEMENT
///
/// `condition_id` holds ONE value. There is no join table for this and there
/// must not be one — the whole attribution model rests on a type belonging to
/// exactly one condition, because that is what lets a record's condition be
/// DERIVED from its type instead of stored on 72 records by a migration nobody
/// asked for.
///
/// **Two conditions cannot meaningfully share a type.** A type is the name of a
/// thing that happened; if it belonged to two conditions an event of that type
/// could be either, which is not a type but an ambiguity. The edge case is a
/// generic word — "Headache" is plausible for epilepsy and migraine both — and
/// the honest handling is **two types carrying the same word, one per
/// condition**, because a headache in a seizure cluster and a migraine headache
/// are different clinical events even when the word matches.
///
/// ⚠️ **THE CONSTRAINT FAILS VISIBLY, WHICH IS THE POINT.** A user who tries to
/// put one type under two conditions finds they cannot — the field holds one
/// value, so the second assignment REPLACES the first and the screen says so.
/// That is a conversation, not a silent wrong answer. Nothing here needs to
/// throw: the shape refuses before the code has to.
///
/// Only [kEventTypeTable] may be assigned. Observations and triggers are SHARED
/// across conditions by DATA-MODEL §1 principle 4 — one trigger list, one
/// observation list — so assigning one would contradict the model.
Future<VocabularyEntry> setConditionFor(
  DatabaseExecutor db,
  String table,
  VocabularyEntry entry,
  int? conditionId,
) async {
  if (table != kEventTypeTable) {
    throw const VocabularyRuleError(
      'Only event types belong to a condition. Observations and what was '
      'happening beforehand are shared across every condition you track, so '
      'you never have to set them up twice.',
    );
  }
  await db.update(table, <String, Object?>{'condition_id': conditionId},
      where: 'id = ?', whereArgs: <Object?>[entry.id]);
  return entry.copyWith(conditionId: conditionId);
}

/// There is no delete.
///
/// Not "delete is discouraged" — the function does not exist. Deleting a row a
/// record references is the one operation that cannot be undone from within the
/// app, and `is_active` covers every reason someone would want it.
const String kWhyNoDelete =
    'Entries are hidden, never deleted, so records that already use them keep '
    'reading correctly.';

/// Retires `medication` as an event type.
///
/// ## ⛔ THE PROTECTION WAS GUARDING AN EMPTY SET, AND IT HAS NOW SERVED ITS
/// PURPOSE
///
/// `isProtected` was put on this entry so that the medication/event split could
/// still FIND the records filed under it. It was carried through every
/// vocabulary change on that reasoning. When the split was designed, the
/// records were counted: **zero, across 527 record-instances in sixteen
/// artefacts spanning 24-27 August.** Not one dose was ever logged as an event.
///
/// So there is nothing to migrate, and the protection now only keeps offering a
/// type whose whole purpose moved to `medication_note`. **Leaving it offered
/// would invite the defect the split exists to remove**: someone logs a dose as
/// an event tomorrow, the home screen's month count inflates, and then there IS
/// something to migrate.
///
/// ## Why this is a direct UPDATE rather than `setActive`
///
/// `setActive` refuses on a protected entry, by design, and that refusal is
/// still right for every OTHER caller. This is the one-time lifting of a
/// protection whose condition has been met, so it says so in SQL rather than
/// weakening the guard that will still be there tomorrow.
///
/// ## What does NOT happen
///
/// **No record is touched.** Retiring an entry stops it being OFFERED; it does
/// not alter anything that references it, and `labelForValue` still resolves it
/// so any record that ever did would keep rendering. Idempotent, so re-running
/// the migration changes nothing.
Future<void> retireMedicationEventType(DatabaseExecutor db) async {
  await db.update(
    kEventTypeTable,
    <String, Object?>{'is_active': 0, 'is_protected': 0},
    where: 'value = ?',
    whereArgs: <Object?>[kMedicationValue],
  );
}

/// Links an event to an observation row. The normalised form of
/// `event.feelings_json`.
///
/// ## ⛔ THIS IS A MIGRATION OF STORED DATA, AND IT IS ADDITIVE ON PURPOSE
///
/// `feelings_json` is **kept and stays authoritative**. This table is populated
/// alongside it, not instead of it.
///
/// That is not timidity, it is the only version that satisfies the rule this
/// project has held throughout: **nothing rewrites what a user recorded.** A
/// migration that dropped the column would have to be right first time, on a
/// once-only pass, over a medical history, with the previous value gone. An
/// additive one can be re-run, checked against the source, and reverted by
/// dropping a table nothing reads yet.
///
/// **What it buys:** `condition_observation` in DATA-MODEL.md §2 maps relevance
/// per condition, and it needs observation ROWS to point at. That mapping is
/// the next pass. When something finally READS this table, dropping
/// `feelings_json` becomes a decision with a consumer behind it rather than a
/// tidy-up.
const String kEventObservationTable = 'event_observation';

const String createEventObservationSql =
    'CREATE TABLE $kEventObservationTable ('
    // The event's `id`, not its `ordinal`. Ordinal is a position in a rewritten
    // list and moves on every save; id is the record's identity.
    'event_id TEXT NOT NULL, '
    'observation_id INTEGER NOT NULL, '
    // Order within the record, so "Confused; Tired" does not become
    // "Tired; Confused" if this ever becomes the read path.
    'position INTEGER NOT NULL)';

const String createEventObservationIndexSql =
    'CREATE INDEX idx_event_observation_event '
    'ON $kEventObservationTable(event_id)';

/// Finds the vocabulary row for a stored string, creating one if it is unknown.
///
/// ## ⛔ THE THREE SUB-CASES, AND WHY THE THIRD IS THE POINT
///
/// A stored observation string is one of four things, and on the tablet the
/// live one is the third:
///
///   1. **SEEDED** — one of the revised twelve. Matches an active row.
///   2. **LEGACY, CLEAN** — `😵 Confused`. Already a row, `is_active: 0`,
///      carried by [kLegacyObservations] so records still render.
///   3. **LEGACY, MIS-DECODED** — `ðµ Confused`, the UTF-8 bytes of the emoji
///      read back as Latin-1. Already a row, via [mangledLegacyObservations].
///      **This is 3 of the 72 records on the device and ALL of its observation
///      data.** A migration handling only 1 and 2 would orphan every
///      observation the user has, and the failure would look like the mojibake
///      that was already found and fixed once — the worst kind of regression to
///      reintroduce.
///   4. **UNKNOWN** — anything else: a user entry from a device whose
///      vocabulary this install does not have, or a hand-edited backup.
///
/// Cases 1-3 all resolve by lookup, because all three are already rows. Only 4
/// creates anything.
///
/// ## What a created row looks like, and why
///
/// `value` is **the stored string, verbatim**. Never normalised, never
/// re-encoded, never repaired. `is_active: 0` because it was RECORDED but is
/// not OFFERED — the same state the retired legacy set is in, which is exactly
/// what it is: a value from a vocabulary this install does not have.
Future<int> observationRowFor(DatabaseExecutor db, String value) async {
  final existing = await db.query(
    kObservationTable,
    columns: <String>['id'],
    where: 'value = ?',
    whereArgs: <Object?>[value],
    limit: 1,
  );
  if (existing.isNotEmpty) return existing.first['id']! as int;

  return db.insert(kObservationTable, <String, Object?>{
    'condition_id': null,
    'value': value,
    // The label is the value. There is nothing else honest to use: this install
    // has never seen the string, so it has no nicer name for it.
    'label': value,
    'is_seeded': 0,
    'is_active': 0,
    'is_protected': 0,
    'sort_order': 9000,
  });
}

/// Populates [kEventObservationTable] from every event's `feelings_json`.
///
/// **Idempotent** — clears the table first, so a re-run rebuilds rather than
/// duplicating. Safe to call from both `onCreate` and `onUpgrade`.
///
/// ⚠️ **Reads `feelings_json` and writes NOTHING back to `event`.** The column
/// is untouched, which is what makes this reversible.
Future<int> migrateObservationsToTable(DatabaseExecutor db) async {
  await db.delete(kEventObservationTable);

  final rows = await db.query('event', columns: <String>['id', 'feelings_json']);
  var links = 0;
  for (final r in rows) {
    final id = r['id'];
    if (id is! String || id.isEmpty) continue;
    final raw = r['feelings_json'];
    if (raw is! String || raw.isEmpty) continue;

    List<dynamic> decoded;
    try {
      final d = jsonDecode(raw);
      if (d is! List) continue;
      decoded = d;
    } catch (_) {
      // A record whose JSON cannot be read keeps its column and gains no rows.
      // Skipping is right: the source of truth is unharmed and the gap is
      // visible as a count mismatch rather than as invented data.
      continue;
    }

    for (var i = 0; i < decoded.length; i++) {
      final value = decoded[i].toString();
      if (value.isEmpty) continue;
      final obsId = await observationRowFor(db, value);
      await db.insert(kEventObservationTable, <String, Object?>{
        'event_id': id,
        'observation_id': obsId,
        'position': i,
      });
      links++;
    }
  }
  return links;
}

/// The beforehand vocabulary. The LAST field to stop being a const list.
///
/// ## ⚠️ NOT ADDED TO [kVocabularyTables], DELIBERATELY
///
/// That constant is walked by the v4 step, which ALTERs every table in it to
/// add `emoji`. A database upgrading from v3 would then ALTER a table that v9
/// has not created yet — the fixture trap this project has now paid for four
/// times. This table is created and seeded by its own step and nothing loops
/// over it.
const String kTriggerTable = 'trigger_option';

/// ⛔ **THREE SUB-CASES BECOME TWO HERE, AND THAT IS A FACT FROM THE DATA
/// RATHER THAN AN ASSUMPTION.**
///
/// Observations had seeded / legacy-clean / legacy-MIS-DECODED, and the live
/// case was the third — `ðµ Confused`, a Latin-1 mis-decode of an emoji that
/// was inside the stored value.
///
/// Checked against the device before building rather than reasoned about:
///
///     every stored trigger string     'Poor sleep' x1, ASCII only
///     any byte above U+007F           NONE
///     the seven shipped options       all ASCII
///     stored values not in the list   NONE
///
/// **No trigger option has ever carried a glyph, so there was never anything to
/// mis-decode.** There is no retired set either — these seven strings have
/// never changed, so no legacy-clean case exists. Only seeded, and unknown.
const List<VocabularySeed> kSeedTriggers = <VocabularySeed>[
  VocabularySeed('Stress', 'Stress'),
  VocabularySeed('Poor sleep', 'Poor sleep'),
  VocabularySeed('Missed medication', 'Missed medication'),
  VocabularySeed('Alcohol', 'Alcohol'),
  VocabularySeed('Flashing lights', 'Flashing lights'),
  VocabularySeed('Illness', 'Illness'),
  VocabularySeed(kUnknownTriggerValue, 'Unknown'),

  // ── APPENDED 29 AUG 2026, from the migraine research pass ────────────────
  //
  // ⛔ APPENDED, NOT INSERTED, AND THAT IS MECHANICAL RATHER THAN STYLISTIC.
  // `seedVocabulary` sets `sort_order = sortBase + listIndex` and SKIPS any
  // value already present, while `syncSeededPresentation` updates only `label`
  // and `emoji`. So on a database that already exists, the rows above keep the
  // orders they were inserted with, and an entry inserted MID-LIST would take
  // an index that one of them already holds — leaving the picker to break the
  // tie by `id`. New seeds go at the end or the order becomes arbitrary.
  //
  // `Unknown` therefore no longer sorts last, which is why `isCatchAll` had to
  // learn about it in the same pass. It is forced last at read time now.
  //
  // ⚠️ THE OBSERVATIONS FROM THE SAME PASS ARE DELIBERATELY NOT HERE. Eleven
  // were sourced and are held: MER records BEFOREHAND and AFTERWARDS, migraine
  // has four phases, and entries like "Yawning" belong to prodrome. Offering a
  // prodrome symptom under "How were things afterwards?" invites recording it
  // as postdrome — a false statement about WHEN, stored verbatim, in the one
  // artefact a clinician reads. Vocabularies are append-only, so that is a
  // one-way door. The phase question is scoped separately.
  //
  // These three carry no phase question at all: a trigger is a trigger.
  //
  // Source: The Migraine Trust's own diary guidance and headache diary fact
  // sheet, patient-facing, which is the same tier the epilepsy set came from.
  // NOT peer-reviewed literature and not clinically validated.
  VocabularySeed('Period or hormonal', 'Period or hormonal'),
  VocabularySeed('Certain foods', 'Certain foods'),
  // ⚠️ INFERRED, NOT SOURCED — stated here rather than in a caveat elsewhere,
  // because a caveat somewhere else is not attached to the thing it qualifies.
  // The Migraine Trust names diet, the menstrual cycle, sleep, stress and
  // medication directly; it does NOT name dehydration. This entry was derived
  // from a prodrome finding about thirst, which is a different claim about a
  // different phase. It is the only value in this pass without a direct
  // source, and it should be the first one reconsidered if the set is revised.
  VocabularySeed('Dehydration', 'Dehydration'),
];

/// Links an event to trigger rows. The normalised form of `triggers_json`.
///
/// ## ⛔ ADDITIVE, EXACTLY LIKE `event_observation`
///
/// `triggers_json` is **kept and stays authoritative**. This table is populated
/// alongside it, never instead of it.
///
/// A once-only irreversible migration over a medical history did not need to be
/// irreversible. This one can be re-run, checked against its source, and
/// reverted by dropping a table nothing reads yet. When `condition_trigger`
/// finally reads it, dropping the column becomes a decision with a consumer
/// behind it rather than a tidy-up.
const String kEventTriggerTable = 'event_trigger';

const String createEventTriggerSql = 'CREATE TABLE $kEventTriggerTable ('
    'event_id TEXT NOT NULL, '
    'trigger_id INTEGER NOT NULL, '
    'position INTEGER NOT NULL)';

const String createEventTriggerIndexSql =
    'CREATE INDEX idx_event_trigger_event ON $kEventTriggerTable(event_id)';

/// Creates and seeds the trigger vocabulary. Idempotent.
Future<void> createAndSeedTriggers(DatabaseExecutor db) async {
  await db.execute(createVocabularySql(kTriggerTable));
  await ensureTriggersSeeded(db);
}

/// Idempotent seed, safe to run on every open once the table exists.
Future<void> ensureTriggersSeeded(DatabaseExecutor db) async {
  await seedVocabulary(db, kTriggerTable, kSeedTriggers);
  await syncSeededPresentation(db, kTriggerTable, kSeedTriggers);
}

/// Finds the row for a stored trigger string, creating one if unknown.
///
/// Only TWO cases, per [kSeedTriggers]: seeded (resolve) and unknown (create).
/// An unknown value is stored **verbatim**, `is_active: 0` — recorded but not
/// offered, which is what a value from another device's vocabulary is.
Future<int> triggerRowFor(DatabaseExecutor db, String value) async {
  final existing = await db.query(kTriggerTable,
      columns: <String>['id'],
      where: 'value = ?',
      whereArgs: <Object?>[value],
      limit: 1);
  if (existing.isNotEmpty) return existing.first['id']! as int;

  return db.insert(kTriggerTable, <String, Object?>{
    'condition_id': null,
    'value': value,
    'label': value,
    'is_seeded': 0,
    'is_active': 0,
    'is_protected': 0,
    'sort_order': 9000,
  });
}

/// Populates [kEventTriggerTable] from every event's `triggers_json`.
///
/// ⚠️ Reads the column and writes **nothing** back to `event`. That is what
/// makes it reversible.
Future<int> migrateTriggersToTable(DatabaseExecutor db) async {
  await db.delete(kEventTriggerTable);
  final rows = await db.query('event', columns: <String>['id', 'triggers_json']);
  var links = 0;
  for (final r in rows) {
    final id = r['id'];
    if (id is! String || id.isEmpty) continue;
    final raw = r['triggers_json'];
    if (raw is! String || raw.isEmpty) continue;
    List<dynamic> decoded;
    try {
      final d = jsonDecode(raw);
      if (d is! List) continue;
      decoded = d;
    } catch (_) {
      continue;
    }
    for (var i = 0; i < decoded.length; i++) {
      final value = decoded[i].toString();
      if (value.isEmpty) continue;
      await db.insert(kEventTriggerTable, <String, Object?>{
        'event_id': id,
        'trigger_id': await triggerRowFor(db, value),
        'position': i,
      });
      links++;
    }
  }
  return links;
}
