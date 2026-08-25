/// The capture inbox contract: how a capture path that is NOT the main isolate
/// hands a fact to the one writer of the record list.
///
/// ## The property
///
/// Dart's main isolate is the only writer of `kEventStorageKey`. Every other
/// capture path posts a fact here and touches no record. The inbox is the
/// mechanism; single-writer is the property.
///
/// This file deliberately does **not** import `event_record.dart`. A writer
/// needs the schema and nothing else — no `EventRecord`, no `toMap`, no decode
/// of the record list. That is the point: four of the seven historical
/// notification failures lived in the background isolate, and the less code
/// that runs there the better. The apply side lives in `capture_inbox.dart`,
/// which is the only half that knows about records.
///
/// ## Two kinds, facts only
///
/// ```
/// start : v, kind, id, at
/// end   : v, kind, id, at, seconds
/// ```
///
/// Facts only — the drain applies defaults. A start carries no duration, no
/// event type, no severity; those are the drain's business. An end carries
/// SECONDS, not a bucket, because the bucket is a storage decision and belongs
/// with the writer of the store.
///
/// One key per instruction, `mer_inbox_<uuidv4>`. Never an array append:
/// appending to a JSON array is itself a read-modify-write, and an inbox built
/// that way fixes nothing.
///
/// There is deliberately **no timestamp in the key**. Ordering comes from the
/// `at` field in the payload, so a future non-Dart writer is not required to
/// produce a byte-compatible sortable key format.
///
/// ## Cross-platform, by construction
///
/// This is a contract, not an Android detail. Step 2 adds a second transport
/// (iOS App Group keys, written by Swift in two processes) against this same
/// schema. Anything here that assumes a Dart writer is a step-2 defect waiting
/// to happen — see [parseInstructionAt].
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Key prefix for every inbox entry. `shared_preferences` adds its own
/// `flutter.` prefix on Android; [SharedPreferences.getKeys] returns keys
/// without it, so matching on this prefix is correct on both sides.
const String kInboxKeyPrefix = 'mer_inbox_';

/// Schema version carried by every instruction as `v`.
///
/// Missing, unreadable, or higher than this: the entry is LEFT IN PLACE,
/// reported once per session, and not applied. Never deleted, never guessed at.
/// An instruction written by a newer build is data this build does not
/// understand, not garbage.
const int kInboxSchemaVersion = 1;

const String kInboxKindStart = 'start';
const String kInboxKindEnd = 'end';

/// The 30-minute abandonment timeout. Carries NO seconds, deliberately: the
/// point is that the duration is UNKNOWN, not that it is zero.
///
/// A new KIND rather than an `end` with seconds omitted, because the parse gate
/// below correctly REFUSES an end without seconds — and because an older build
/// then defers this instead of misreading it. Forward compatibility for an
/// unrecognised kind is already designed and tested; see [InboxDefer.unknownKind].
const String kInboxKindAbandon = 'abandon';

/// Why an entry could not be applied. Every one of these means "leave the key
/// alone", never "delete it".
enum InboxDefer {
  /// `v` absent, not an int, or newer than [kInboxSchemaVersion].
  unsupportedVersion,

  /// `kind` is neither [kInboxKindStart] nor [kInboxKindEnd].
  unknownKind,

  /// Structurally unreadable: not JSON, not a map, or a required field is
  /// missing or the wrong type.
  malformed,

  /// A readable `end` whose record does not exist YET, because the matching
  /// start is itself deferred in this same inbox.
  ///
  /// The odd one out: every other reason is decided while parsing one entry,
  /// this one is decided while applying, by looking at the rest of the inbox.
  /// It shares the enum because it has the same consequence — leave the key
  /// alone — and callers report deferrals as one class.
  awaitingDeferredStart,
}

/// Parses an instruction's `at` field.
///
/// ⚠️ CONTRACT — this MUST stay identical to `EventRecord._parseTimestamp`:
///
/// ```dart
/// DateTime.tryParse(raw)?.toLocal()
/// ```
///
/// **Never a bare `DateTime.parse`.** The two writers produce two shapes and
/// they must not be treated as different instants:
///
///  * Dart writes naive local ISO — `2026-08-22T18:18:35.180820`, no zone
///    suffix — because `toIso8601String()` on a local `DateTime` omits the
///    offset. `tryParse` returns a local `DateTime`, and `toLocal()` is then a
///    no-op.
///  * Swift writes UTC with a `Z` — `2026-08-22T06:29:59.000Z` — because
///    `ISO8601DateFormatter` does. `tryParse` returns a UTC `DateTime`, and
///    `toLocal()` is what makes it comparable to the Dart-written ones.
///
/// A bare parse would leave the UTC ones ten hours out in AEST. That is the
/// identical mismatch behind the display bug fixed in `e48d91b`, and skipping
/// the `toLocal()` here would reintroduce it at step 2 — on iOS only, after a
/// lock-screen capture, in a path that is hard to observe. It is caught here by
/// a test written while both writers are still Dart.
DateTime? parseInstructionAt(dynamic raw) =>
    (raw is String) ? DateTime.tryParse(raw)?.toLocal() : null;

/// A parsed, applicable instruction.
class CaptureInstruction {
  /// The `SharedPreferences` key this came from, so the drain can delete
  /// exactly the entries it applied and nothing else.
  final String key;
  final String kind;

  /// The event id. Compared by exact string equality — see the note in
  /// `capture_inbox.dart` on why case is never folded.
  final String id;
  final DateTime at;

  /// Elapsed seconds. Present on `end`, null on `start`.
  final int? seconds;

  const CaptureInstruction({
    required this.key,
    required this.kind,
    required this.id,
    required this.at,
    this.seconds,
  });

  bool get isStart => kind == kInboxKindStart;
  bool get isEnd => kind == kInboxKindEnd;
  bool get isAbandon => kind == kInboxKindAbandon;
}

/// One inbox key, either parsed or deferred. Exactly one of [instruction] and
/// [defer] is non-null, so nothing is silently outside the classification.
class InboxEntry {
  final String key;
  final CaptureInstruction? instruction;
  final InboxDefer? defer;

  /// The event id, read opportunistically even when the entry is deferred, or
  /// null when it could not be read at all.
  ///
  /// A deferred entry still needs an id so a related `end` can be held back
  /// with it instead of being dropped as an orphan. See the note in
  /// [parseInboxEntry] on why reading exactly this one field out of an
  /// otherwise un-inspectable payload is safe.
  final String? id;

  const InboxEntry._(this.key, this.instruction, this.defer, this.id);

  factory InboxEntry.ok(CaptureInstruction i) =>
      InboxEntry._(i.key, i, null, i.id);
  factory InboxEntry.deferred(String key, InboxDefer reason, {String? id}) =>
      InboxEntry._(key, null, reason, id);

  bool get isDeferred => instruction == null;
}

/// Parses one raw inbox value. Never throws: an entry that cannot be trusted
/// comes back deferred, which means "leave the key in place".
InboxEntry parseInboxEntry(String key, String? raw) {
  if (raw == null || raw.isEmpty) {
    return InboxEntry.deferred(key, InboxDefer.malformed);
  }

  Map<String, dynamic> map;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return InboxEntry.deferred(key, InboxDefer.malformed);
    }
    map = Map<String, dynamic>.from(decoded);
  } catch (_) {
    return InboxEntry.deferred(key, InboxDefer.malformed);
  }

  // `id` is read FIRST, and it is the one field read out of a payload this
  // build may not otherwise understand.
  //
  // Why that is safe, and why it is worth doing: a deferred entry that carries
  // no id cannot be matched, so a readable `end` whose start is deferred would
  // look like an orphan and be dropped — losing a duration that is sitting
  // three keys away, present and readable. `id` is the join key of the whole
  // contract and the one field that cannot change meaning without the schema
  // ceasing to be the same schema.
  //
  // It is used ONLY to decide whether to hold a related entry back. Nothing is
  // applied from a deferred payload. If a future version did redefine `id`, the
  // worst outcome is holding back an end that could have been dropped, which
  // deletes nothing.
  final rawId = map['id'];
  final id = (rawId is String && rawId.isNotEmpty) ? rawId : null;

  // Version next: an instruction from a newer build must not be inspected
  // further, because this build does not know what its other fields mean.
  final v = map['v'];
  if (v is! int || v != kInboxSchemaVersion) {
    return InboxEntry.deferred(key, InboxDefer.unsupportedVersion, id: id);
  }

  final kind = map['kind'];
  if (kind != kInboxKindStart &&
      kind != kInboxKindEnd &&
      kind != kInboxKindAbandon) {
    return InboxEntry.deferred(key, InboxDefer.unknownKind, id: id);
  }

  if (id == null) {
    return InboxEntry.deferred(key, InboxDefer.malformed);
  }

  final at = parseInstructionAt(map['at']);
  if (at == null) {
    return InboxEntry.deferred(key, InboxDefer.malformed, id: id);
  }

  int? seconds;
  if (kind == kInboxKindEnd) {
    final raw = map['seconds'];
    // A negative elapsed is not a duration. Deferred rather than clamped:
    // clamping would invent a number, and the clock is the suspect.
    if (raw is! int || raw < 0) {
      return InboxEntry.deferred(key, InboxDefer.malformed, id: id);
    }
    seconds = raw;
  }

  return InboxEntry.ok(CaptureInstruction(
    key: key,
    kind: kind as String,
    id: id,
    at: at,
    seconds: seconds,
  ));
}

String _newInboxKey() => '$kInboxKeyPrefix${const Uuid().v4()}';

/// Posts a start fact. Writes one key and reads nothing.
Future<void> writeStartInstruction(
  SharedPreferences prefs, {
  required String id,
  required DateTime at,
}) =>
    prefs.setString(
      _newInboxKey(),
      jsonEncode({
        'v': kInboxSchemaVersion,
        'kind': kInboxKindStart,
        'id': id,
        'at': at.toIso8601String(),
      }),
    );

/// Posts an end fact carrying SECONDS, not a bucket. Writes one key and reads
/// no record.
/// Records that an in-progress event was ABANDONED — the 30-minute timeout
/// fired and no end ever arrived.
///
/// Before this the timeout simply dropped the active marker, and the record
/// kept the `lt1` it was created with: wrong data, indistinguishable from a
/// real short event. Confirmed on hardware — 37 minutes recorded as
/// "< 1 minute".
Future<void> writeAbandonInstruction(
  SharedPreferences prefs, {
  required String id,
  required DateTime at,
}) =>
    prefs.setString(
      _newInboxKey(),
      jsonEncode({
        'v': kInboxSchemaVersion,
        'kind': kInboxKindAbandon,
        'id': id,
        'at': at.toIso8601String(),
      }),
    );

Future<void> writeEndInstruction(
  SharedPreferences prefs, {
  required String id,
  required DateTime at,
  required int seconds,
}) =>
    prefs.setString(
      _newInboxKey(),
      jsonEncode({
        'v': kInboxSchemaVersion,
        'kind': kInboxKindEnd,
        'id': id,
        'at': at.toIso8601String(),
        'seconds': seconds,
      }),
    );

/// Every inbox entry currently present, parsed. Key order is stable but carries
/// no meaning — ordering is decided from `at` by the drain.
List<InboxEntry> readInboxEntries(SharedPreferences prefs) {
  final keys = prefs.getKeys().where((k) => k.startsWith(kInboxKeyPrefix)).toList()
    ..sort();
  return [for (final k in keys) parseInboxEntry(k, prefs.getString(k))];
}

/// Removes drained keys. Called ONLY after the write that consumed them has
/// been confirmed — a foreground that clears first and fails second loses the
/// captures.
Future<void> deleteInboxKeys(
  SharedPreferences prefs,
  Iterable<String> keys,
) async {
  for (final key in keys) {
    await prefs.remove(key);
  }
}
