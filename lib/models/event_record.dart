import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import '../constants.dart';
import 'duration_format.dart';
import 'medication_note.dart';
import 'vocabulary.dart';
import 'vocabulary_store.dart';

/* ===========================
   ENUMS
   =========================== */

/// ⛔ **THESE NAMES ARE STORED DATA, AND THEY DIVERGE FROM THEIR LABELS ON
/// PURPOSE. DO NOT TIDY THEM.**
///
/// `lt1` is persisted verbatim — `.name` is what reaches `duration` in the
/// record, in `event.duration_bucket`, and in every backup file ever taken.
/// `EventSeverity` is the same. Renaming one is not a rename: `fromMap` reads
/// enums with `firstWhere(orElse:)`, so an unrecognised name falls back
/// SILENTLY and reclassifies every historical record carrying it.
///
/// The divergence is the tell that makes them look untidy, and it is
/// deliberate:
///
///     lt1        -> "< 1 minute"
///     oneToFive  -> "1-5 minutes"
///     gt5        -> "More than 5 minutes"
///
/// A label is a sentence for a person and a name is an identifier for a
/// record; making them match would mean either an unreadable label or a
/// renamed identifier, and the identifier is the half that cannot move.
///
/// **There is no user-facing reason to care, which is the other half of why
/// this note exists.** History search matches LABELS, never these names — so
/// nobody ever sees `lt1` and no search returns a record because of it.
/// `search_matches_labels_test` pins that with these two names specifically,
/// because `lt1` and `oneToFive` are the only identifiers in the app whose
/// text does not appear inside their own label and can therefore tell a
/// label-matching search from a key-matching one.
///
/// See also DATA-MODEL.md §2a, which draws the same value/label line for
/// vocabulary entries, and ARCHITECTURE.md §4 on why a rename here is
/// dangerous where adding a field is not.
enum DurationCategory { lt1, oneToFive, gt5 }

/// ⚠️ `durationLabel` and `severityLabel` are STRUCTURALLY IDENTICAL — both are
/// bare exhaustive switches over a NON-NULLABLE enum with no default arm. Do not
/// assume duration's tolerates null because duration is nullable: it does not,
/// and it cannot be passed null without a compile error.
///
/// That compile error is the FEATURE. When severity is made nullable, every call
/// site fails to build and has to decide what absence renders as, rather than a
/// default silently appearing in a medical record. Nullability is handled AT THE
/// CALL SITE here for exactly that reason.
String durationLabel(DurationCategory c) {
  switch (c) {
    case DurationCategory.lt1:
      return '< 1 minute';
    case DurationCategory.oneToFive:
      return '1–5 minutes';
    case DurationCategory.gt5:
      return '> 5 minutes';
  }
}

/// Resolves a stored duration name, or NULL when it is absent or unrecognised.
///
/// Replaced an `orElse: () => DurationCategory.lt1` that turned every unanswered
/// duration into a confident "< 1 minute" — wrong data, and indistinguishable
/// from a real short event.
DurationCategory? durationFromName(Object? raw) {
  for (final d in DurationCategory.values) {
    if (d.name == raw) return d;
  }
  return null;
}

/// The CSV cell. EXPLICIT, never blank: a clinician reading a blank cannot tell
/// "unknown" from "not recorded" from a broken export.
/// What a record's duration READS AS, across all three states.
///
/// Seconds win where present; otherwise the bucket; otherwise null, which every
/// caller renders as absence rather than as a word.
String? durationDisplay(DurationCategory? bucket, int? seconds) {
  if (seconds != null) return durationSecondsLabel(seconds);
  if (bucket != null) return durationLabel(bucket);
  return null;
}

String durationCsv(DurationCategory? bucket, int? seconds) =>
    durationDisplay(bucket, seconds) ?? 'unknown';

/// The event type is a **STRING**, not an enum, and that is the whole change.
///
/// An enum can only ever hold values MER shipped. A user who tracks cluster
/// headaches needs a type MER has never heard of, and the record has to carry
/// it — so the field holds a vocabulary `value` and the vocabulary decides what
/// exists.
///
/// **The wire format did not change.** It has always been a string:
/// `toMap` wrote `eventType.name`, so every record already stores `seizure`,
/// `absence`, `medication` or `other`, and every backup file ever written is
/// still readable. What changed is that the model stops narrowing that string
/// to four cases on the way in.
///
/// These constants exist so code that means a SPECIFIC seeded type says so,
/// rather than repeating a bare literal.
const String kTypeSeizure = 'seizure';
const String kTypeAbsence = 'absence';
const String kTypeMedication = kMedicationValue;
const String kTypeOther = kOtherEventTypeValue;

/// Whether anything a user could have supplied is still unset.
///
/// ⚠️ **FIELD INSPECTION, NOT `detailsCompleted`, and they answer different
/// questions.** `detailsCompleted` records whether someone WALKED the guided
/// flow; this records whether the record HAS anything. A record can be
/// `detailsCompleted == true` with every field null — three taps: open the
/// wizard, Skip to end, Save — and that record is exactly the one a user
/// hunting for gaps is looking for. Driving this off the flag would hide it.
///
/// ## Where the line falls, and the rule that draws it
///
/// **A field is in scope if and only if it is NULLABLE.** Nullability already
/// means "NULL means not asked" throughout this model — `occurredAt`,
/// `detailsCompleted`, duration, and now type and severity. Nothing else has
/// an absent state to detect:
///
///   duration      IN. Null in both halves — no bucket and no seconds.
///   eventType     IN.
///   severity      IN.
///   feelings      OUT. An empty list is an ANSWER: "nothing afterwards" is
///                 data, not a gap.
///   triggers      OUT. Same.
///   notes         OUT. Absence of notes is not incompleteness.
///   referral      OUT. A non-nullable bool has no absent state at all.
///
/// ## Catch-all
///
/// ANY unset field qualifies, not all of them. A record missing only its
/// severity is still incomplete, and "incomplete" is what is being asked.
bool isIncomplete(EventRecord r) =>
    (r.duration == null && r.durationSeconds == null) ||
    r.eventType == null ||
    r.severity == null;

/// Which fields are missing, for a reader.
///
/// Returned in the order the guided flow asks them, so the list doubles as the
/// route through. Empty for a complete record.
List<String> missingFields(EventRecord r) => <String>[
      if (r.duration == null && r.durationSeconds == null) 'duration',
      if (r.eventType == null) 'type',
      if (r.severity == null) 'severity',
    ];

/// The label for a stored type value.
///
/// Resolves through the loaded vocabulary, so a user-defined type reads as its
/// own name. An unrecognised value renders AS ITSELF rather than as a fallback:
/// a record restored from a backup made on another device may carry a type this
/// device has never seen, and showing the raw string beats showing the wrong
/// one. That is the same rule the duration work established — never substitute a
/// confident value for an unknown one.
String eventTypeLabel(String value) =>
    Vocabularies.labelFor(kEventTypeTable, value);

/// What a SCREEN shows, or null to show nothing.
///
/// Null-returning on purpose, exactly like [durationDisplay]: a caller that
/// gets null omits the element rather than rendering a word for absence. The
/// History row already does this for duration, and absence reading as absence
/// is the established rule.
String? eventTypeDisplay(String? value) =>
    value == null ? null : eventTypeLabel(value);

/// What the CSV writes. EXPLICIT, never blank — the duration decision, applied.
///
/// A clinician reading a blank cell cannot tell "not asked" from "not recorded"
/// from a broken export. `duration` writes `unknown` for exactly this reason
/// and these two columns are the same kind of text column.
String eventTypeCsv(String? value) => eventTypeDisplay(value) ?? 'unknown';

/// See [eventTypeDisplay].
String? severityDisplay(EventSeverity? s) => s == null ? null : severityLabel(s);

/// See [eventTypeCsv].
String severityCsv(EventSeverity? s) => severityDisplay(s) ?? 'unknown';

/// ⛔ **STORED DATA. See [DurationCategory] for why these names must not be
/// renamed** — the same `.name` persistence and the same silent `orElse`
/// fallback apply here.
///
/// These three happen to match their labels case-insensitively (`mild` ->
/// "Mild"), which makes them look safer than the duration names. They are not:
/// the hazard is the persistence, not the spelling.
enum EventSeverity { mild, moderate, severe }

/// Did the rescue medication help?
///
/// ⛔ **STORED DATA. See [DurationCategory].** `.name` is persisted, so these
/// three words are permanent the moment one is written.
///
/// THREE VALUES, not a bool, because "partly" is the commonest honest answer
/// and the field is worthless without it. Sources that record rescue response
/// record degree, not a yes/no - and a user forced to round "it took the edge
/// off" to yes or no gives a specialist a worse answer than no answer.
enum RescueResponse { helped, partly, didNotHelp }

String rescueResponseLabel(RescueResponse r) {
  switch (r) {
    case RescueResponse.helped:
      return 'Yes';
    case RescueResponse.partly:
      return 'Partly';
    case RescueResponse.didNotHelp:
      return 'No';
  }
}

/// What a SCREEN shows, or null to show nothing. See [severityDisplay].
String? rescueResponseDisplay(RescueResponse? r) =>
    r == null ? null : rescueResponseLabel(r);

/// What the CSV writes. BLANK when unanswered, not "unknown".
///
/// Different from [severityCsv] deliberately, and the difference is the whole
/// rescue-medication design: severity is asked of every event, so a blank there
/// cannot distinguish "not asked" from "asked and skipped". These three are
/// asked of almost no event - they are gated behind "was rescue medication
/// given", which is itself usually no - so a column of the word "unknown" on
/// every row would be noise standing in for a question that was never
/// applicable.
String rescueResponseCsv(RescueResponse? r) => rescueResponseDisplay(r) ?? '';

/// A nullable yes/no, rendered for the CSV. Blank when unanswered.
String yesNoCsv(bool? v) => v == null ? '' : (v ? 'Yes' : 'No');

/// Whether the two follow-up questions should be RENDERED for this record.
///
/// ## The gate, and the exception that is the point
///
/// Normally: only when rescue medication was given. Asking "did it help" about
/// medication that was not given produces a state no reviewer can interpret -
/// "did it help: yes" beside "given: no" is a contradiction, and neither half
/// can be identified as the wrong one. **Preventing an impossible state beats
/// recording it faithfully**, because the export carries the contradiction to a
/// clinician who cannot ask what was meant.
///
/// ⚠️ **BUT a record that ALREADY carries a child value shows it regardless.**
/// The gate exists to stop the state being created, not to hide it once it
/// exists. Silently withholding a stored value would be the more serious
/// failure of the two - a reviewer would see a record that looks answered when
/// it is not, and the value would still be in the export and the backup with
/// nothing on screen corresponding to it.
///
/// That case cannot arise from this app today. It can arise from a restored
/// backup written by a future version, or by a hand-edited file. Cheap to
/// handle, and the alternative is a screen that lies about its own record.
bool rescueChildrenVisible(EventRecord r) =>
    r.rescueMedGiven == true ||
    r.rescueMedHelped != null ||
    r.rescueMedSecondDose != null;


String severityLabel(EventSeverity s) {
  switch (s) {
    case EventSeverity.mild:
      return 'Mild';
    case EventSeverity.moderate:
      return 'Moderate';
    case EventSeverity.severe:
      return 'Severe';
  }
}

/* ===========================
   MODEL
   =========================== */

class EventRecord {
  final String id;
  final DateTime timestamp;

  /// WHEN IT HAPPENED, where that differs from when it was written down.
  ///
  /// ## ⛔ NULL MEANS NOT ASKED — the same rule as everything else here
  ///
  /// Null is not "it happened when it was logged". It is **nobody said**, and
  /// every record written before 29 Aug 2026 carries null correctly, because
  /// no screen could express it. There is NO derivation and there never can be
  /// one: `condition` could be derived from the event type and duration had a
  /// stored value to read, but nothing anywhere records when an untimed past
  /// event actually occurred. **Those records are permanently logged-at only.**
  ///
  /// ## ⭐ WHY THE COALESCE IS SAFE
  ///
  /// Readers use `whenHappened` — `occurredAt ?? timestamp`. Because the field
  /// is null on **every** record that predates it, that expression evaluates to
  /// exactly today's behaviour for all of them: no record changes meaning, no
  /// filter changes result, and no migration runs. The compatibility is by
  /// construction rather than by care.
  ///
  /// ## THE COLUMN HAS BEEN THERE SINCE v1
  ///
  /// `occurred_at TEXT` is in the ORIGINAL DDL — verified against the v1
  /// fixture in `sqlite_upgrade_v2_test` — so every database that has ever
  /// existed already has it, and this needed **no ALTER and no schema bump**.
  /// It was written as a literal `null` at both write sites and read nowhere.
  ///
  /// ⚠️ Never a future time. The picker's `lastDate` enforces it at the only
  /// place a value enters.
  final DateTime? occurredAt;

  /// The time this record is ABOUT. The one expression every reader uses.
  ///
  /// Sorting, filtering, grouping and the export all go through here so that
  /// "when" means one thing across the app. Writing `occurredAt ?? timestamp`
  /// at each call site is how the two drift apart.
  DateTime get whenHappened => occurredAt ?? timestamp;

  /// Whether this record says it happened at a different time from its writing.
  ///
  /// Used to decide whether to SHOW the distinction. A record with no
  /// `occurredAt`, or one saved the moment it happened, should not display two
  /// times that say the same thing.
  bool get isBackdated => occurredAt != null;
  /// The BUCKET. Never derived from [durationSeconds], and never derived FROM.
  ///
  /// Records captured before duration became a quantity hold a range and will
  /// never hold a number: "1-5 minutes" contains no number, and inventing a
  /// midpoint would put a fabricated quantity in a medical record. Same rule
  /// the migration held to for occurred_at.
  final DurationCategory? duration;

  /// The QUANTITY, in seconds. Measured, never estimated.
  ///
  /// Only the notification path produces one: it already computes the elapsed
  /// time exactly and, before this, threw it away at drain. A quick record
  /// measures nothing and leaves this null.
  ///
  /// THREE STATES, and every surface must handle all three:
  ///   seconds != null                  a real quantity
  ///   seconds == null, bucket != null  a legacy range, no number
  ///   both null                        unknown
  final int? durationSeconds;

  /// Whether the guided wizard was walked to its end for this record.
  ///
  /// THREE STATES, and the third is the point:
  ///   true   the wizard was completed
  ///   false  a partial — created by the wizard and abandoned, or a capture
  ///          that has not been through it
  ///   NULL   PREDATES THE CONCEPT. The 71 records captured before the wizard
  ///          existed are neither complete nor incomplete; asserting either
  ///          would be a claim about work nobody did.
  ///
  /// ROUTES ONLY, never gates. Null and true open the single-page editor —
  /// null because those records were captured under a design the wizard does
  /// not describe, and walking them through it would ask about a shape they
  /// never had.
  ///
  /// Nothing back-fills it. Only the wizard's summary step sets it true.
  final bool? detailsCompleted;
  final List<String> feelings;
  final bool referralRequired;
  final String notes;

  // New fields — all have safe defaults for old saved records
  /// NULL means NOT ASKED. Third field to take this rule, after `duration` and
  /// `detailsCompleted`, and the last of the three that still fabricated.
  ///
  /// A one-tap capture measures nothing and chooses nothing, so it asserts
  /// nothing. This read `seizure` because that is the first enum value, and
  /// `severityLabel(mild)` because that is the first of those — 71 records in
  /// the export today read "Seizure / fit · Mild" with nobody having been
  /// asked, and a clinician could not tell an answer from a default.
  final String? eventType;

  /// NULL means NOT ASSESSED. See [eventType].
  ///
  /// Severity is a RELATIVE self-assessment — how this event felt compared with
  /// the person's other events. A default is worse here than in most fields:
  /// it is a comparison nobody made.
  final EventSeverity? severity;
  final List<String> triggers;

  /// ── RESCUE MEDICATION ───────────────────────────────────────────────────
  ///
  /// A FIELD ON AN EVENT, not a record of its own. Regular medication is a
  /// separate stream because its value is the pattern over time; rescue
  /// medication's value is per-event, and the frequency of it is itself a
  /// signal. See DATA-MODEL.md section 2.
  ///
  /// All three NULL means NOT ASKED, like every other nullable field here.
  ///
  /// ⚠️ **[rescueMedHelped] and [rescueMedSecondDose] are meaningless unless
  /// [rescueMedGiven] is true, and the UI enforces that by construction** - it
  /// does not render them otherwise, and clears them when the parent goes to
  /// no. See `rescueChildrenVisible`.
  ///
  /// **The model does NOT enforce it.** A record that arrives with children
  /// populated and a false or null parent keeps them, exports them and shows
  /// them. Storage records what it was given; only the UI prevents the state
  /// being CREATED. Dropping a value because it looks inconsistent is the one
  /// thing this project has refused throughout.
  final bool? rescueMedGiven;

  /// Did it help? See [RescueResponse] for why this is not a bool.
  final RescueResponse? rescueMedHelped;

  /// Was a second dose needed? Recorded because sources that track rescue
  /// response consistently track it - a first dose that failed and a second
  /// that worked is a different event from one dose that worked.
  final bool? rescueMedSecondDose;

  EventRecord({
    required this.id,
    required this.timestamp,
    this.occurredAt,
    required this.duration,
    this.durationSeconds,
    this.detailsCompleted,
    required this.feelings,
    required this.referralRequired,
    required this.notes,
    this.eventType,
    this.severity,
    this.triggers  = const [],
    this.rescueMedGiven,
    this.rescueMedHelped,
    this.rescueMedSecondDose,
  });

  /// Parses a stored timestamp and normalises it to local wall-clock time.
  ///
  /// Two writers produce two shapes, and they must not display differently:
  ///
  ///  * Dart writes naive local time — `2026-08-22T18:18:35.180820`, no zone
  ///    suffix — because [toMap] calls `toIso8601String()` on a local
  ///    `DateTime`. `DateTime.tryParse` returns a local `DateTime` for these.
  ///  * Native iOS capture writes UTC — `2026-08-22T06:29:59.000Z` — because
  ///    `AppDelegate.swift` uses `ISO8601DateFormatter` (`:248`). That is the
  ///    Lock Screen and Live Activity path, which is the PRIMARY way events are
  ///    captured on iOS. `DateTime.tryParse` returns a UTC `DateTime` for
  ///    these.
  ///
  /// `DateFormat` renders whatever wall clock the `DateTime` carries, so
  /// without this conversion a UTC record displayed at its UTC time — ten hours
  /// early in AEST, year-round. Sorting hid it: `compareTo` compares absolute
  /// instants, so the order was right while the times were wrong.
  ///
  /// `toLocal()` returns the receiver unchanged when it is already local, so
  /// Dart-written records are untouched; only the UTC ones move, and they move
  /// to the same instant expressed locally.
  ///
  /// Normalising here rather than at each display site is deliberate: there are
  /// four consumers today (history list, home event tiles, the month count, CSV
  /// export) and every future one would have to remember.
  ///
  /// Stored data is deliberately NOT rewritten. A UTC timestamp is not wrong,
  /// it is unambiguous, and a migration that rewrote timestamps would risk far
  /// more than a parse-time conversion.
  static DateTime? _parseTimestamp(dynamic raw) =>
      (raw is String) ? DateTime.tryParse(raw)?.toLocal() : null;

  Map<String, dynamic> toMap() => {
        'id':               id,
        'timestamp':        timestamp.toIso8601String(),
        // ALWAYS WRITTEN, including as null -- the same rule as `severity` and
        // `triggers` below. A reader must be able to tell "asked and not
        // answered" from a payload written before the field existed.
        'occurredAt':       occurredAt?.toIso8601String(),
        'duration':         duration?.name,
        'durationSeconds':  durationSeconds,
        'detailsCompleted': detailsCompleted,
        'feelings':         feelings,
        'referralRequired': referralRequired,
        'notes':            notes,
        'eventType':        eventType,
        // Null stays null. The key is still WRITTEN so a reader can tell
        // "asked and unanswered" from a payload that predates the field.
        'severity':         severity?.name,
        'triggers':         triggers,
        // Same rule as `severity`: the key is always WRITTEN, so a reader can
        // tell "asked and unanswered" from a payload that predates the field.
        'rescueMedGiven':      rescueMedGiven,
        'rescueMedHelped':     rescueMedHelped?.name,
        'rescueMedSecondDose': rescueMedSecondDose,
      };

  /// Parses a stored record, or returns null if it cannot be trusted.
  ///
  /// A record with an absent or unparseable timestamp yields null and must be
  /// skipped by the caller. It is deliberately NOT defaulted to the current
  /// date: a silently wrong date in a medical record is worse than an
  /// omission. Every other field already falls back to a safe default.
  static EventRecord? fromMap(Map<String, dynamic> map) {
    final timestamp = _parseTimestamp(map['timestamp']);
    if (timestamp == null) return null;

    final feelingsRaw = map['feelings'];
    final triggersRaw = map['triggers'];
    final notesRaw    = map['notes'];
    final referralRaw = map['referralRequired'];

    return EventRecord(
      id:        (map['id'] is String) ? map['id'] as String : '',
      timestamp: timestamp,
      // Reuses the timestamp parser, so an occurred time gets the SAME
      // UTC-to-local normalisation the log time gets. Two different parsers
      // for two times in one record is how a one-hour offset appears in
      // exactly one column.
      occurredAt: _parseTimestamp(map['occurredAt']),
      duration: durationFromName(map['duration']),
      durationSeconds:
          (map['durationSeconds'] is int) ? map['durationSeconds'] as int : null,
      // Absent means NULL, not false. A backup written before the wizard
      // existed must not come back asserting its records were incomplete.
      detailsCompleted:
          (map['detailsCompleted'] is bool) ? map['detailsCompleted'] as bool : null,
      feelings: (feelingsRaw is List)
          ? feelingsRaw.map((e) => e.toString()).toList()
          : <String>[],
      referralRequired: (referralRaw is bool) ? referralRaw : false,
      notes:            (notesRaw is String) ? notesRaw : '',
      // New fields — safe fallbacks for old records
      // Kept VERBATIM. The old code narrowed anything unrecognised to
      // `seizure`; a user-defined type would have been silently rewritten to
      // "Seizure / fit" by a round trip through a backup file. An absent key
      // still reads as `seizure`, unchanged, because that is what every record
      // written before this already stores and §9 forbids changing them.
      // ABSENT MEANS NULL, not the first enum value. The `orElse` that produced
      // `seizure` and `mild` here is the defect: it turned "the key is not in
      // this map" into a confident clinical claim, permanently, on the way in.
      //
      // A record written before this change still carries its key explicitly —
      // `toMap` has always written both — so nothing existing becomes null by
      // reading it back. Only a payload that genuinely lacks the key does.
      eventType:
          (map['eventType'] is String && (map['eventType'] as String).isNotEmpty)
              ? map['eventType'] as String
              : null,
      severity: EventSeverity.values
          .where((e) => e.name == map['severity'])
          .firstOrNull,
      triggers: (triggersRaw is List)
          ? triggersRaw.map((e) => e.toString()).toList()
          : <String>[],
      // ABSENT MEANS NULL. Every record written before this change lacks these
      // keys entirely and must read as "not asked", never as "no" - a false
      // negative about rescue medication is a clinical claim.
      //
      // Read INDEPENDENTLY of each other and of the parent. A backup carrying
      // a child without its parent is inconsistent, and this reads it anyway:
      // see [EventRecord.rescueMedGiven] for why storage does not enforce what
      // the UI prevents.
      rescueMedGiven:
          (map['rescueMedGiven'] is bool) ? map['rescueMedGiven'] as bool : null,
      rescueMedHelped: RescueResponse.values
          .where((e) => e.name == map['rescueMedHelped'])
          .firstOrNull,
      rescueMedSecondDose: (map['rescueMedSecondDose'] is bool)
          ? map['rescueMedSecondDose'] as bool
          : null,
    );
  }
}

/* ===========================
   STORAGE
   =========================== */

class EventStore {
  /// Serialises every store operation, so two can never interleave.
  ///
  /// Every record lives in one string under one key, so a write is
  /// read-modify-write over the whole history and two overlapping ones are a
  /// lost update. That is not hypothetical: the quick-record button was
  /// re-entrant, so taps 150 ms apart each started their own save, and whichever
  /// `setString` happened to land last won. Live device data showed 27
  /// Dart-written records from about 29 taps.
  ///
  /// [load] joins the same chain as [save]. A read that jumped the queue would
  /// return pre-write state, and `_loadRecords` assigns that straight over the
  /// in-memory list — so a resume racing a write could drop a just-logged event
  /// from memory and the next save would then make the loss permanent.
  ///
  /// Static because it guards a single storage key, not an instance: two
  /// `EventStore` objects still write the same string and must share the queue.
  static Future<void> _queue = Future<void>.value();

  /// Appends [operation] to the queue and returns its result.
  ///
  /// The chain is kept alive across failures: a rejected Future would poison
  /// every later operation, so what is stored back is a Future that always
  /// completes. The caller still sees the real error.
  /// Public so `SqliteEventStore` shares ONE queue with this store.
  /// A fallback launch can have opened SQLite before verification failed, so
  /// one queue is what stops an operation on either backend overlapping one
  /// on the other.
  static Future<T> serialise<T>(Future<T> Function() operation) {
    final result = _queue.then((_) => operation());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// One unreadable record must never cost the user the whole history: every
  /// record lives in a single JSON string under a single key, so an
  /// exception here would make all of them unreachable. Entries that are not
  /// maps, and records fromMap rejects, are skipped individually.
  Future<List<EventRecord>> load() => serialise(_load);

  static Future<List<EventRecord>> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(kEventStorageKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .whereType<Map>()
        .map((e) => EventRecord.fromMap(Map<String, dynamic>.from(e)))
        .whereType<EventRecord>()
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  /// Writes [records] as they are at the moment of the call.
  ///
  /// The payload is encoded synchronously, before anything is awaited, so the
  /// write is a snapshot rather than a view of a list that keeps changing.
  /// Callers pass `_records`, which is mutated in place by `insert` and replaced
  /// wholesale by `_loadRecords`; encoding after an await meant a save could
  /// serialise records it never intended to, or state from before a reload.
  Future<void> save(List<EventRecord> records) {
    final payload = jsonEncode(records.map((e) => e.toMap()).toList());
    return serialise(() => _write(payload));
  }

  static Future<void> _write(String payload) async {
    final prefs = await SharedPreferences.getInstance();
    await writeEventPayload(prefs, payload);
  }

  Future<SharedPreferences> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    return prefs;
  }
}

/// Writes the event payload, keeping the previous payload under
/// [kEventRollbackKey] first.
///
/// Every record lives in a single string under a single key, so a write
/// interrupted midway (process killed, device powers off) can leave that key
/// truncated and unreadable. The rollback copy bounds the loss to whatever the
/// in-flight save was adding, rather than the entire history.
///
/// On first run there is no previous payload, so nothing is copied and the
/// rollback key simply does not exist yet. It appears on the second save.
Future<void> writeEventPayload(SharedPreferences prefs, String payload) async {
  // ── DO NOT REMOVE THIS GUARD ──────────────────────────────────────────────
  // iOS deliberately keeps NO rollback copy.
  //
  // On iOS the quick-log capture path is native Swift, not Dart:
  // AppDelegate.handleQuickLogStart writes flutter.epilepsy_event_records_v1
  // in UserDefaults directly, and EndMEREventIntent (the Live Activity button,
  // running in the widget extension process) mutates it again. Neither goes
  // through this function and neither knows the rollback key exists.
  //
  // So on iOS the primary payload advances while a rollback copy would sit
  // frozen at whenever Dart last wrote. Restoring from it later would
  // resurrect deleted events and lose recent ones. An absent copy is safe; a
  // silently stale one is a data-loss mechanism.
  //
  // The proper long-term fix is to replicate this snapshot in the Swift write
  // paths so iOS gets real protection. That is a native change, deliberately
  // out of scope for v1.1.0, which does not touch ios/ at all.
  if (Platform.isIOS) {
    // Clear anything a pre-guard build left behind, so nothing misleading
    // remains on a device that ran an internal build.
    if (prefs.containsKey(kEventRollbackKey)) {
      await prefs.remove(kEventRollbackKey);
    }
  } else {
    final previous = prefs.getString(kEventStorageKey);
    if (previous != null && previous.isNotEmpty) {
      await prefs.setString(kEventRollbackKey, previous);
    }
  }
  await prefs.setString(kEventStorageKey, payload);
}

/* ===========================
   OPTIMISTIC PERSIST
   =========================== */

/// Whether a previous write of the event list failed and has not since
/// succeeded.
Future<bool> hasUnsavedEvents() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  return prefs.getBool(kUnsavedEventsKey) ?? false;
}

/// Records that events are in memory but not in storage.
Future<void> setUnsavedEventsWarning() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(kUnsavedEventsKey, true);
}

/// Clears the warning. Called only where a write demonstrably succeeded.
Future<void> clearUnsavedEventsWarning() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(kUnsavedEventsKey);
}

/// Saves [records] and reports whether it worked, without ever throwing.
///
/// Returns true when the write succeeded and any standing warning was cleared,
/// false when it failed and the warning was raised.
///
/// The failure is optimistic by design and the caller has already confirmed to
/// the user. Three deliberate choices sit behind that:
///
///  * The confirmation is not delayed until the write returns. This is the
///    capture path — someone logging a seizure — and latency there is the one
///    cost not worth paying for correctness elsewhere.
///  * The record is NOT removed from the list on failure. A just-logged event
///    disappearing in front of the person who logged it is the worst outcome
///    available, even when it is the truthful one.
///  * So the gap between what is on screen and what is in storage is made
///    visible instead: a persistent warning the user can act on, rather than a
///    silent divergence they discover after a restart.
///
/// Reported to Sentry explicitly on every failure, never swallowed: before
/// this, an exception here escaped into a discarded Future and was captured by
/// the guarded zone with nothing shown on screen at all.
Future<bool> persistEvents(EventStore store, List<EventRecord> records) async {
  try {
    await store.save(records);
    await clearUnsavedEventsWarning();
    return true;
  } catch (e, st) {
    await Sentry.captureException(e, stackTrace: st);
    try {
      await setUnsavedEventsWarning();
    } catch (_) {
      // Storage is failing; the in-memory banner still shows for this session.
    }
    return false;
  }
}

/* ===========================
   HELPERS
   =========================== */

Rect shareOriginRect(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return const Rect.fromLTWH(0, 0, 1, 1);
  final rect = box.localToGlobal(Offset.zero) & box.size;
  if (rect.width == 0 || rect.height == 0) {
    return const Rect.fromLTWH(0, 0, 1, 1);
  }
  return rect;
}

/// Reports a failure to Sentry AND tells the user, for a failure that would
/// otherwise be invisible.
///
/// Every export and backup action runs inside an async callback whose Future
/// the framework discards — a `ListTile` `onTap`, a `PopupMenuButton`
/// `onSelected`. An exception escaping one of those becomes an unhandled zone
/// error: recorded by Sentry's guarded zone and rendered on screen as nothing
/// whatsoever. That is how "Restore from backup does nothing on iOS" presented,
/// and every path here had the same shape.
///
/// Both audiences are served deliberately: the exception is still captured, so
/// the diagnostic value that made that defect findable is not lost, and the
/// user is told, so a failure can never again look like a no-op.
///
/// Callers must only reach this for a genuine failure. A cancelled dialog is
/// not a failure and must stay silent.
///
/// Takes the messenger rather than a [BuildContext] so no context crosses an
/// async gap: callers resolve `ScaffoldMessenger.of(context)` synchronously
/// before starting work, and this checks the messenger is still mounted before
/// using it. Sentry is told either way — a user who has navigated away still
/// deserves the bug to be fixed.
Future<void> reportUserFacingFailure(
  ScaffoldMessengerState messenger,
  Object error,
  StackTrace stackTrace,
  String message,
) async {
  await Sentry.captureException(error, stackTrace: stackTrace);
  if (!messenger.mounted) return;
  messenger.showSnackBar(SnackBar(content: Text(message)));
}

/* ===========================
   CSV EXPORT
   =========================== */

String _csvEscape(String v) {
  final needsQuotes = v.contains(',') ||
      v.contains('"') ||
      v.contains('\n') ||
      v.contains('\r');
  if (!needsQuotes) return v;
  return '"${v.replaceAll('"', '""')}"';
}

// GONE, with the eleven one-hot columns it existed to name. Emoji are now
// stripped by a different and better mechanism: the CSV writes each
// observation's LABEL, and a legacy entry's label is its value without the
// emoji. A regex that guessed at "leading non-space run" is no longer between
// the stored string and the export.
//
// The replacement is not a better regex, it is a DIFFERENT KIND OF THING. The
// old stripper was POSITIONAL: it removed the leading non-space run, whatever
// that run happened to be. Against the shipped values that looked correct,
// because every one of them started with an emoji. Against a user-defined
// entry it would have eaten the first WORD - "Dizzy spell" exported as "spell"
// - and a positional rule cannot tell the two cases apart, because it never
// looks at what it is removing. Looking the value up removes the guess: an
// entry's label is a stored fact about that entry, and an entry with no emoji
// has a label identical to its value.

/// What separates two entries inside one cell.
///
/// Semicolon-space, not a comma: a comma inside an already-quoted CSV field is
/// legal but reads as a column break to anyone eyeballing the raw file, and
/// "; " renders cleanly in a spreadsheet cell.
const String kCsvListDelimiter = '; ';

/// Joins entries into one cell, quoting any entry that contains the delimiter.
///
/// ## The problem, and why it is not theoretical
///
/// A user-defined entry is free text. Someone can type "Dizzy; unsteady", and
/// then one entry is indistinguishable from two - in the one artefact a
/// clinician actually reads, with nothing on screen to reveal it.
///
/// ## Why quoting rather than the alternatives
///
/// - **Substituting** the delimiter inside the value (";" becomes ",") would
///   silently alter the words someone chose. This project does not rewrite a
///   user's wording anywhere else and will not start in the export.
/// - **A backslash escape** puts an escape character in a clinical spreadsheet
///   cell. It is recoverable, but it is noise in a document a specialist reads.
/// - **Refusing the character at entry** would make the file format a
///   constraint on what someone may call their own symptom. The word wins.
///
/// So: the same convention CSV already uses, applied one level down. An entry
/// containing the delimiter or a quote is wrapped in quotes with its own
/// quotes doubled. A reader sees the original words with quotation marks
/// around the one that needed them, and a splitter can recover the set exactly.
///
/// The outer [_csvEscape] then quotes the whole cell and doubles these quotes
/// again, which is correct: a spreadsheet unwraps exactly one layer.
String csvJoinList(Iterable<String> values) => values
    .map((v) => (v.contains(';') || v.contains('"'))
        ? '"${v.replaceAll('"', '""')}"'
        : v)
    .join(kCsvListDelimiter);

/// Triggers in the order the picker offers them, with anything unrecognised
/// appended.
///
/// ## Both halves are load-bearing
///
/// **Canonical order first** preserves what the seven one-hot columns did. A
/// column is comparable down the page only if the same set always renders the
/// same way; storage order is tap order, so "Stress; Illness" and
/// "Illness; Stress" would be the same record read two ways.
///
/// **The remainder is the whole point of the change.** A one-hot export had no
/// column for a value it did not ship, so such a value vanished from the file.
/// Filtering [kTriggerOptions] alone would reproduce that exactly. Anything
/// stored and unrecognised - from a restored backup, or from triggers becoming
/// user-defined later - lands at the end of the cell instead of nowhere.
List<String> csvOrderedTriggers(List<String> stored) => <String>[
      ...kTriggerOptions.where(stored.contains),
      ...stored.where((t) => !kTriggerOptions.contains(t)),
    ];

/// The two values `record_kind` may hold.
///
/// ⚠️ **A THIRD IS EXPECTED**, and the column is written to accommodate
/// one from the outset: DATA-MODEL.md §9's `daily_entry`. Writing this as a
/// two-valued flag would make that a breaking change to the export rather than
/// an addition.
const String kRecordKindEvent = 'event';
const String kRecordKindMedication = 'medication_note';

/// Builds the export.
///
/// ⚠️ **[notes] defaults to empty, so every existing caller is unchanged
/// and single-stream.** The multi-stream file is opt-in at the call site rather
/// than something every caller inherits - which matters because one of those
/// callers is the FILTERED export, and a filter that narrows events must not
/// silently start emitting every medication note.
String buildCsv(
  List<EventRecord> items, {
  List<MedicationNote> notes = const <MedicationNote>[],
}) {
  final fmtDate = DateFormat('yyyy-MM-dd');
  final fmtTime = DateFormat.jm();
  final sb      = StringBuffer();

  sb.write('\uFEFF'); // UTF-8 BOM — tells Excel to read as UTF-8

  sb.writeln([
    // ⛔ THESE THREE MEAN "WHEN IT HAPPENED", AND THAT IS A CHANGE (v6).
    //
    // They used to mean two different things in one column, decided by
    // `record_kind`: an EVENT row wrote `r.timestamp` (when it was logged) and
    // a MEDICATION row wrote `n.occurredAt` (when it happened). For a user
    // whose events are timed those coincide and nothing showed. For a user
    // recording a flare two days later they are days apart, so the rows
    // interleaved in the wrong order and the same column carried two meanings.
    //
    // Both kinds now write WHEN THE THING HAPPENED. For events that is
    // `whenHappened` — `occurredAt ?? timestamp` — which is byte-identical to
    // the old behaviour for every record that does not set an occurred time,
    // i.e. every record written before 29 Aug 2026.
    //
    // ⚠️ CONSEQUENCE, STATED RATHER THAN BURIED: where the two differ, the
    // LOG TIME IS NO LONGER IN THE CSV. It is not lost — it is in the JSON
    // backup and in `event.logged_at` — but a clinician reading only the file
    // cannot see that a record was written three days late. A fourth time
    // column was considered and rejected: the file already carries three, and
    // one consistent meaning is worth more here than a completeness nobody
    // asked for.
    'timestamp_iso',
    'date',
    'time',
    // ⛔ MULTI-STREAM. The file now carries two record kinds on ONE
    // timeline, sorted together, which is what lets a specialist see a missed
    // dose sitting three days before a cluster.
    //
    // It sits after the time columns rather than first, so a row still reads
    // WHEN, then WHAT KIND, then the detail. And it resolves a collision the
    // delimited change created: a blank cell means "not noted", but on a
    // medication row `duration` and `severity` are NOT APPLICABLE. Different
    // facts, and `record_kind` is what tells them apart.
    //
    // ⚠️ MER DOES NOT CORRELATE THE STREAMS. Both are in the file on
    // the same timeline; the specialist does the reading. Charting the
    // connection would be interpretation - the boundary the analysis tier was
    // rejected over.
    'record_kind',
    // ⛔ DERIVED, NEVER STORED. `event.condition_id` is NULL on every row and
    // stays that way — a record's condition is a FUNCTION OF ITS EVENT TYPE,
    // which is what let 71 of 72 records attribute themselves from one user
    // statement instead of a migration nobody asked for.
    //
    // It sits BEFORE event_type because that is the reading order a specialist
    // wants: which condition, then what happened within it.
    //
    // ⚠️ `unknown`, not blank, and the precedent is split so this is a
    // decision. Duration, event type and severity write `unknown` because a
    // blank SCALAR cannot distinguish "not asked" from "not recorded" from a
    // truncated file. Observations and beforehand write blank because they are
    // DELIMITED and `unknown` there would parse as a member of the set.
    // Condition is a scalar and applies to every event, so it takes the scalar
    // rule. A user who has named nothing gets `unknown` on every row — the
    // same shape a quick-log-only user already gets in `event_type`.
    'condition',
    'event_type',
    'duration',
    // NEW COLUMN, deliberately, despite the multi-stream rewrite coming. One
    // column cannot serve both readers: a clinician wants the readable value, and
    // anyone computing a mean or a trend needs the number and cannot recover it
    // from "1-5 minutes". Neither column ever contains a fabrication.
    'duration_seconds',
    'severity',
    // ONE DELIMITED COLUMN, forced early and not by preference.
    //
    // The eleven one-hot columns could only ever hold values MER shipped. The
    // moment someone adds "Dizzy", a one-hot export has NO COLUMN FOR IT and
    // the value disappears from the file - silent loss in the one artefact a
    // clinician actually reads, with nothing on screen to reveal it. So
    // user-defined observations force DATA-MODEL.md §6's delimited-column
    // change NOW rather than at the final stage.
    //
    // Semicolon, not comma: a comma would need quoting inside an already
    // quoted field, and "; " reads cleanly in a spreadsheet cell. See
    // [csvJoinList] for what happens when a value contains one.
    'observations',
    // AND NOW THE BEFOREHAND FIELD TOO, which completes DATA-MODEL.md
    // section 6. It moved a stage later than observations only because
    // observations were forced first - a user-defined observation had nowhere
    // to go. These are still seeded-only, so nothing was being LOST today;
    // what the seven columns cost was width. Seven columns of "Yes" and blank,
    // read left to right to reconstruct one short list, in a file whose reader
    // is a person.
    //
    // ⚠️ `beforehand`, NOT `triggers`. The seven one-hot columns were the
    // OPTION NAMES with no group heading over them, so the export never had to
    // name this field. Collapsing them to one column forces a name, and
    // "triggers" asserts that what is listed CAUSED the event - the claim the
    // single-page form, the wizard and Help were all changed to avoid. The
    // export is the most consequential place to make it, because a clinician
    // reads it and the app is not there to qualify it. `beforehand` is the
    // word already on both screens. See beforehand_wording_test, which failed
    // on `triggers` and is why this reads as it does.
    'beforehand',
    // RESCUE MEDICATION, three columns, immediately after the beforehand
    // field and before referral - so the row still reads in the order the
    // event happened: what, how long, how bad, what after, what before, what
    // was given, referral, notes.
    //
    // Three columns rather than one, because they answer three questions and a
    // specialist may want to count any of them. Collapsing them into a single
    // delimited cell would make "how often did a second dose follow" a text
    // search instead of a column.
    'rescue_med_given',
    'rescue_med_helped',
    'rescue_med_second_dose',
    'referral_required',
    // A COLUMN OF ITS OWN, not `event_type` reused. missed/late/changed is a
    // different question from what kind of event happened, and one column
    // holding two meanings is the defect `record_kind` exists to prevent.
    'medication_kind',
    'notes',
  ].map(_csvEscape).join(','));

  // ⛔ ONE TIMELINE, SORTED TOGETHER. The whole point of `record_kind` is
  // that a reader can see the two streams interleaved; emitting events then
  // notes would put every deviation at the bottom and lose the adjacency that
  // makes the file worth reading.
  //
  // Events are OLDEST FIRST (`items.reversed`), which the export has always
  // been, so notes sort into the same order on `occurredAt`.
  final rows = <({DateTime at, List<String> cells})>[
    for (final n in notes)
      (at: n.occurredAt, cells: _medicationCells(n, fmtDate, fmtTime)),
  ];

  for (final r in items.reversed) {
    // `whenHappened`, NOT `timestamp` — both as the cells and as the SORT
    // KEY, or a backdated record would print one time and sort by another.
    // The medication rows below have always sorted on their occurred time.
    rows.add((at: r.whenHappened, cells: [
      r.whenHappened.toIso8601String(),
      fmtDate.format(r.whenHappened),
      fmtTime.format(r.whenHappened).replaceAll('\u202F', ' '),
      kRecordKindEvent,
      // The derivation, through the same static `buildCsv` already uses for
      // labels. No database, no new parameter, no field on EventRecord.
      Vocabularies.conditionNameForEventType(r.eventType) ?? 'unknown',
      eventTypeCsv(r.eventType),
      durationCsv(r.duration, r.durationSeconds),
      // EMPTY, not `unknown`, when there is no number. A word in a numeric
      // column breaks every formula that touches it; a blank there is
      // unambiguous in a way a blank in a text column is not.
      r.durationSeconds?.toString() ?? '',
      severityCsv(r.severity),
      // LABELS, not stored values - which strips the emoji for free, because a
      // legacy entry's label is its value without one. DATA-MODEL.md §6 requires
      // emoji stripped from values as well as headers, and the raw strings
      // already render as mojibake in History rows on the tablet.
      csvJoinList(
          r.feelings.map((v) => Vocabularies.labelFor(kObservationTable, v))),
      // BLANK when nothing was recorded, not the word "none".
      //
      // Deliberate, and the opposite of the duration and severity rule three
      // lines up - because the question is different. Duration has three
      // states and a blank could not distinguish "not asked" from "asked and
      // not answered", so those columns spell it out. Observations have two:
      // recorded, or not. And a seven-column one-hot has ALWAYS written blank
      // for "not noted", so a blank here says exactly what the file has always
      // said.
      //
      // "none" would also be a VALUE, indistinguishable from a user-defined
      // observation literally called "None" - which is a thing someone may
      // reasonably add.
      // ⛔ THROUGH THE VOCABULARY, like observations eleven lines up. Ordering
      // happens on the STORED VALUES — `kTriggerOptions` is a list of values
      // and the canonical column order must not move when a label changes —
      // and the label resolution happens after.
      //
      // Output-identical for every trigger that exists today: `addUserEntry`
      // sets label = value, and all seven seeds are ASCII with label = value.
      // The divergence is latent, not live, which is exactly why it would have
      // been missed — the first rename would have made History and the CSV
      // disagree about the same record.
      csvJoinList(csvOrderedTriggers(r.triggers)
          .map((v) => Vocabularies.labelFor(kTriggerTable, v))),
      // WHATEVER IS STORED, never what the UI would have shown. The screen
      // hides the two children when rescue medication was not given; the
      // export does not, because a value that exists in the record must appear
      // in the file. If the two ever disagree, the file is the one a clinician
      // reads.
      yesNoCsv(r.rescueMedGiven),
      rescueResponseCsv(r.rescueMedHelped),
      yesNoCsv(r.rescueMedSecondDose),
      r.referralRequired ? 'Yes' : 'No',
      // Blank on an event row. Not applicable, and `record_kind` says which.
      '',
      r.notes,
    ]));
  }

  rows.sort((a, b) => a.at.compareTo(b.at));
  for (final row in rows) {
    sb.writeln(row.cells.map(_csvEscape).join(','));
  }
  return sb.toString();
}

/// One medication row, in the same column order as an event row.
///
/// Every event-only column is BLANK. That is not laziness: `record_kind` tells
/// the reader which columns apply, so a blank here means NOT APPLICABLE rather
/// than the "not noted" a blank means on an event row. Without `record_kind`
/// those two would be indistinguishable, which is the collision that column
/// was added to resolve.
List<String> _medicationCells(
  MedicationNote n,
  DateFormat fmtDate,
  DateFormat fmtTime,
) =>
    <String>[
      n.occurredAt.toIso8601String(),
      fmtDate.format(n.occurredAt),
      fmtTime.format(n.occurredAt).replaceAll(String.fromCharCode(0x202F), ' '),
      kRecordKindMedication,
      // ⚠️ NOT DERIVABLE, and deliberately `unknown` rather than blank. A
      // medication note has no event type, so there is nothing to derive
      // from. `medication_note.condition_id` exists and is unpopulated —
      // when it is populated this reads it instead.
      'unknown', // condition
      '', // event_type
      '', // duration
      '', // duration_seconds
      '', // severity
      '', // observations
      '', // beforehand
      '', // rescue_med_given
      '', // rescue_med_helped
      '', // rescue_med_second_dose
      '', // referral_required
      medicationDeviationLabel(n.kind),
      n.notes,
    ];

/* ===========================
   EXPORT OPTIONS
   =========================== */

/// The current CSV shape. Bump it whenever [buildCsv]'s HEADER ROW changes.
///
/// ⛔ **THE RULE, AND IT IS DELIBERATELY MECHANICAL: the marker tracks the
/// header row. ANY change to the column set bumps it - added, removed,
/// renamed or reordered. No judgement about whether a change is "real".**
///
/// The temptation is to bump only for changes that break something. That
/// requires someone to predict what a consumer does, and consumers here are
/// spreadsheets someone built by hand: a template written against eleven
/// columns breaks on fourteen exactly as surely as on a reshape, because every
/// formula after the insertion point now points one column left. A rule
/// requiring judgement gets the easy calls right and the tired ones wrong.
///
/// Mechanical also makes the FILENAME A RELIABLE STATEMENT ABOUT THE FILE.
/// `v2` and `v3` are guaranteed to differ in their header; `v3` files are
/// guaranteed to match each other. Neither guarantee survives a marker that
/// moves only sometimes.
///
/// **Nothing reads it, and that is unchanged.** No compatibility mode, no
/// second export option, no negotiation - the standing decision of 26 August
/// 2026. The marker identifies a shape; it does not enable branching on one.
///
///     v1   the original one-hot export        26 columns
///     v2   observations and beforehand became delimited columns   11
///     v3   rescue medication added three columns                  14
///     v4   multi-stream: record_kind and medication_kind           16
///     v5   condition, derived from the event type                    17
///     v6   the three time columns mean WHEN IT HAPPENED on BOTH      17
///          record kinds. No column added or removed - a MEANING
///          change, which is exactly what a shape marker is for: a
///          reader computing on column 1 gets a different answer, and
///          nothing in the header would have told them.
const String kCsvShapeVersion = 'v6';

/// The shape marker. `..._20260827_154500.v3.csv`.
///
/// ## Why the filename and not a column
///
/// A column would repeat the same value on all 71 rows, and it would sit
/// INSIDE the data a clinician reads - a field about the file, filed among
/// fields about the patient. The filename is metadata about the file, which is
/// what this is. It is also readable BEFORE the file is opened, which is when
/// someone deciding whether a spreadsheet will line up actually wants it.
///
/// ## What v2 means, and what it does not
///
/// It marks the shape, and nothing reads it. There is no compatibility mode,
/// no second export option and no version negotiation, per the standing
/// decision of 26 August 2026: MER has one user, known to the developer, and
/// amending their spreadsheet by hand once is acceptable. The marker exists so
/// a file's shape is identifiable, not so code can branch on it.
///
/// ⚠️ ONE FUNCTION, called by BOTH export paths. They previously built the
/// same name from the same three parts independently, which is how a marker
/// ends up on the shared file and not the saved one.
String csvFilename({String? prefix, DateTime? when}) {
  final p = (prefix == null || prefix.isEmpty)
      ? 'medical_event_recorder'
      : prefix;
  final ts = DateFormat('yyyyMMdd_HHmmss').format(when ?? DateTime.now());
  return '${p}_$ts.$kCsvShapeVersion.csv';
}

Future<File> _buildCsvTempFile(
  List<EventRecord> items, {
  String? filenamePrefix,
  List<MedicationNote> notes = const <MedicationNote>[],
}) async {
  final csv = buildCsv(items, notes: notes);
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${csvFilename(prefix: filenamePrefix)}');
  await file.writeAsString(csv, flush: true);
  return file;
}

Future<void> exportCsvShare(
  BuildContext context,
  List<EventRecord> items, {
  String? filenamePrefix,
  List<MedicationNote> notes = const <MedicationNote>[],
}) async {
  if (items.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No events to export.')),
    );
    return;
  }
  // Resolved before any await so no BuildContext crosses an async gap.
  final messenger = ScaffoldMessenger.of(context);

  try {
    final file =
        await _buildCsvTempFile(items,
            filenamePrefix: filenamePrefix, notes: notes);
    if (!context.mounted) return;
    // No `text` alongside `files`. iOS treats a text parameter as a second
    // shared item, so "Save to Files" wrote a stray companion file containing
    // only the text — leaving the user two files from one export. `subject` is
    // metadata (the mail subject line) and does not become an item, so it
    // stays. Same fix as the backup share in b7df6f1; this one has been in the
    // shipped app since CSV export existed.
    await SharePlus.instance.share(
      ShareParams(
        subject: '$kAppName export (CSV)',
        files:   [XFile(file.path, mimeType: 'text/csv')],
        sharePositionOrigin: shareOriginRect(context),
      ),
    );
  } catch (e, st) {
    await reportUserFacingFailure(
      messenger,
      e,
      st,
      'Could not prepare the CSV to share. Your events have not been changed.',
    );
  }
}

Future<void> exportCsvSaveAs(
  BuildContext context,
  List<EventRecord> items, {
  String? filenamePrefix,
  List<MedicationNote> notes = const <MedicationNote>[],
}) async {
  if (items.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No events to export.')),
    );
    return;
  }

  final csv = buildCsv(items, notes: notes);
  final filename = csvFilename(prefix: filenamePrefix);

  // ── ANDROID — save to Downloads ──
  if (Platform.isAndroid) {
    try {
      final dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File('${dir.path}/$filename');
      await file.writeAsString(csv, flush: true);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to Downloads/$filename'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save to Downloads. Try Share instead.'),
        ),
      );
    }
    return;
  }

  // ── DESKTOP — file picker save dialog ──
  // Resolved before any await so no BuildContext crosses an async gap.
  final messenger = ScaffoldMessenger.of(context);

  FileSaveLocation? location;
  try {
    location = await getSaveLocation(
      suggestedName: filename,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'CSV files', extensions: ['csv']),
      ],
    );
  } catch (e, st) {
    await reportUserFacingFailure(
      messenger,
      e,
      st,
      'Could not open the save dialog. Try Share instead.',
    );
    return;
  }

  // Cancelling is not a failure and must stay silent.
  if (location == null) return;

  // Bound to a non-nullable local so the "Open" action below can close over the
  // path: promotion of a mutable local does not reach inside a closure.
  final savedPath = location.path;

  try {
    await File(savedPath).writeAsString(csv, flush: true);
  } catch (e, st) {
    await reportUserFacingFailure(
      messenger,
      e,
      st,
      'Could not write the CSV file. Your events have not been changed.',
    );
    return;
  }
  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('CSV saved'),
      action: SnackBarAction(
        label: 'Open',
        onPressed: () async {
          try {
            if (Platform.isWindows) {
              await Process.start('explorer', [savedPath],
                  runInShell: true);
            } else if (Platform.isMacOS) {
              await Process.start('open', [savedPath],
                  runInShell: true);
            } else if (Platform.isLinux) {
              await Process.start('xdg-open', [savedPath],
                  runInShell: true);
            }
          } catch (_) {}
        },
      ),
    ),
  );
}

/// [sheetTitle] overrides the header label so the sheet can state its own
/// scope. That matters most from History, whose AppBar button exports only the
/// filtered list but says so in a tooltip — and tooltips need hover or a long
/// press, so no iPhone user ever sees it. The sheet header is the only place
/// the scope can be stated where it will actually be read.
Future<void> showExportOptions(
  BuildContext context,
  List<EventRecord> items, {
  String? filenamePrefix,
  List<MedicationNote> notes = const <MedicationNote>[],
  String? sheetTitle,
}) async {
  if (items.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No events to export.')),
    );
    return;
  }
  await showModalBottomSheet(
    context:       context,
    showDragHandle: true,
    builder: (ctx) {
      final isIOS = Platform.isIOS;
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

            // ── HEADER LABEL ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  // Expanded, not a bare Text + Spacer: a scope-bearing title
                  // is longer than "Export events" and must not overflow.
                  Expanded(
                    child: Text(
                      sheetTitle ?? 'Export events',
                      style: const TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                        color:      Colors.black45,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const _ExportIconWidget(),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── SHARE ──
            ListTile(
              leading: Container(
                width:  36,
                height: 36,
                decoration: BoxDecoration(
                  color:        const Color(0xFFEAF4FB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.ios_share,
                  size:  18,
                  color: Color(0xFF1A8FCB),
                ),
              ),
              title: const Text(
                'Share to apps',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: const Text(
                'Email, cloud storage, spreadsheets',
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await exportCsvShare(
                  context,
                  items,
                  filenamePrefix: filenamePrefix,
                  // ⚠️ FORWARDED. This was DROPPED in the first version: the
                  // sheet accepted `notes` and never passed it on, so the
                  // multi-stream export silently emitted events only. No test
                  // caught it because every export test calls `buildCsv`
                  // directly and skips this sheet entirely — the device
                  // export is what found it.
                  notes: notes,
                );
              },
            ),

            // ── SAVE (non-iOS only) ──
            if (!isIOS)
              ListTile(
                leading: Container(
                  width:  36,
                  height: 36,
                  decoration: BoxDecoration(
                    color:        const Color(0xFFEAF4FB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.save_alt,
                    size:  18,
                    color: Color(0xFF1A8FCB),
                  ),
                ),
                title: const Text(
                  'Save to device',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: const Text(
                  'Choose location and file name',
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await exportCsvSaveAs(
                    context,
                    items,
                    filenamePrefix: filenamePrefix,
                    notes: notes,
                  );
                },
              ),

            // ── CANCEL ──
            ListTile(
              leading: Container(
                width:  36,
                height: 36,
                decoration: BoxDecoration(
                  color:        const Color(0xFFFAECE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.close,
                  size:  18,
                  color: Color(0xFFE05B3A),
                ),
              ),
              title: const Text(
                'Cancel',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color:      Color(0xFFE05B3A),
                ),
              ),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}
/* ===========================
   EXPORT ICON WIDGET
   =========================== */

class _ExportIconWidget extends StatelessWidget {
  const _ExportIconWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  30,
      height: 30,
      decoration: BoxDecoration(
        color:        Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.download_outlined,
        size:  18,
        color: Colors.white,
      ),
    );
  }
}