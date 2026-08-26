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
import 'vocabulary.dart';
import 'vocabulary_store.dart';

/* ===========================
   ENUMS
   =========================== */

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

enum EventSeverity { mild, moderate, severe }

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

  EventRecord({
    required this.id,
    required this.timestamp,
    required this.duration,
    this.durationSeconds,
    this.detailsCompleted,
    required this.feelings,
    required this.referralRequired,
    required this.notes,
    this.eventType,
    this.severity,
    this.triggers  = const [],
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

String buildCsv(List<EventRecord> items) {
  final fmtDate = DateFormat('yyyy-MM-dd');
  final fmtTime = DateFormat.jm();
  final sb      = StringBuffer();

  sb.write('\uFEFF'); // UTF-8 BOM — tells Excel to read as UTF-8

  sb.writeln([
    'timestamp_iso',
    'date',
    'time',
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
    'referral_required',
    'notes',
  ].map(_csvEscape).join(','));

  for (final r in items.reversed) {
    sb.writeln([
      r.timestamp.toIso8601String(),
      fmtDate.format(r.timestamp),
      fmtTime.format(r.timestamp).replaceAll('\u202F', ' '),
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
      csvJoinList(csvOrderedTriggers(r.triggers)),
      r.referralRequired ? 'Yes' : 'No',
      r.notes,
    ].map(_csvEscape).join(','));
  }
  return sb.toString();
}

/* ===========================
   EXPORT OPTIONS
   =========================== */

/// The shape marker. `..._20260826_223000.v2.csv`.
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
  return '${p}_$ts.v2.csv';
}

Future<File> _buildCsvTempFile(
  List<EventRecord> items, {
  String? filenamePrefix,
}) async {
  final csv = buildCsv(items);
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/${csvFilename(prefix: filenamePrefix)}');
  await file.writeAsString(csv, flush: true);
  return file;
}

Future<void> exportCsvShare(
  BuildContext context,
  List<EventRecord> items, {
  String? filenamePrefix,
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
        await _buildCsvTempFile(items, filenamePrefix: filenamePrefix);
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
}) async {
  if (items.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No events to export.')),
    );
    return;
  }

  final csv = buildCsv(items);
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