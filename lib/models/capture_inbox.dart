import 'package:shared_preferences/shared_preferences.dart';

import 'capture_instruction.dart';
import 'event_record.dart';

/// The drain: the main isolate applies posted facts to the record list.
///
/// This is the only half of the inbox that knows what a record is. The writer
/// half (`capture_instruction.dart`) deliberately does not import this file or
/// `event_record.dart`.
///
/// Everything here is pure: [applyInbox] takes a list and returns a list. It
/// does no I/O, holds no state, and reports nothing itself — anomalies come
/// back in the result for the caller to report, which is what makes the whole
/// drain testable without a widget, a platform channel, or Sentry.

/// What a drain would do, and what it is safe to delete afterwards.
class InboxDrainResult {
  /// The record list with every applicable instruction applied.
  final List<EventRecord> merged;

  /// Keys that were consumed and may be deleted — but ONLY after the write of
  /// [merged] has been confirmed. Includes keys whose effect was a no-op
  /// (a replayed start, an end that already carried the right bucket) and
  /// orphan ends, which are dropped deliberately.
  final List<String> drainableKeys;

  /// Keys left in place because this build cannot apply them.
  final List<String> deferredKeys;

  /// Distinct reasons, for a once-per-session report.
  final Set<InboxDefer> deferReasons;

  /// Ids of end instructions that match nothing at all — no record, and no
  /// deferred entry either. Dropped, and reported by the caller.
  ///
  /// A record is deliberately NOT fabricated: that would require inventing a
  /// start time, and a wrong timestamp in a medical record is worse than an
  /// absent duration. The case this covers is a record the user deleted in
  /// History.
  ///
  /// An end whose start is merely DEFERRED is not here — it is held back in
  /// [deferredKeys] under [InboxDefer.awaitingDeferredStart] instead, because
  /// its start is present and readable and only waiting on a build that
  /// understands it. The two stay separate so telemetry can tell a drop from a
  /// deferral.
  final List<String> orphanEndIds;

  /// Whether [merged] actually differs from what was passed in. False means the
  /// drain was all replays, orphans and deferrals.
  final bool changed;

  const InboxDrainResult({
    required this.merged,
    required this.drainableKeys,
    required this.deferredKeys,
    required this.deferReasons,
    required this.orphanEndIds,
    required this.changed,
  });
}

/// Applies [entries] to [existing].
///
/// ## Ordering
///
/// Instructions are sorted by `at` for determinism, then applied in two passes:
/// every start, then every end. So **a start always applies before the end for
/// the same id, regardless of `at`** — which matters on a device whose clock can
/// move between the two captures, where the end could legitimately carry an
/// earlier `at` than its own start.
///
/// The two passes are safe to reorder relative to each other across different
/// ids, because a start only adds the record for its own id and an end only
/// modifies the record for its own id, so operations on distinct ids commute.
/// Sorting by `at` therefore fixes a deterministic order without the order
/// across ids being load-bearing.
///
/// ## Idempotency
///
/// Both kinds are idempotent, so a crash between the write and the delete
/// causes replay rather than duplication:
///
///  * a start whose id is already present is a no-op (merge-by-id);
///  * an end sets a bucket, and setting the same bucket twice is the same
///    bucket.
InboxDrainResult applyInbox(
  List<EventRecord> existing,
  List<InboxEntry> entries,
) {
  final deferredKeys = <String>[];
  final deferReasons = <InboxDefer>{};
  final instructions = <CaptureInstruction>[];

  /// Ids carried by entries this build cannot apply. An `end` matching one of
  /// these is not an orphan — its start is in the inbox, just not yet legible.
  final deferredIds = <String>{};

  // Every entry lands in exactly one bucket: applicable or deferred. Nothing is
  // silently outside the classification.
  for (final entry in entries) {
    final instruction = entry.instruction;
    if (instruction == null) {
      deferredKeys.add(entry.key);
      final reason = entry.defer;
      if (reason != null) deferReasons.add(reason);
      final id = entry.id;
      if (id != null) deferredIds.add(id);
      continue;
    }
    instructions.add(instruction);
  }

  instructions.sort((a, b) => a.at.compareTo(b.at));

  // Insertion order is preserved so the pre-sort arrangement is stable; the
  // final list is re-sorted newest-first to match EventStore.load().
  final byId = <String, EventRecord>{};
  final order = <String>[];
  for (final record in existing) {
    if (byId.containsKey(record.id)) continue;
    byId[record.id] = record;
    order.add(record.id);
  }

  final drainableKeys = <String>[];
  final orphanEndIds = <String>[];

  var changed = false;

  // ── PASS 1 — starts ──
  for (final instruction in instructions.where((i) => i.isStart)) {
    drainableKeys.add(instruction.key);

    // Merge by id, `planRestore` semantics: an id already present is already
    // recorded, so this is a replay and does nothing.
    //
    // ⚠️ EXACT STRING EQUALITY — DO NOT CASE-FOLD, here or anywhere else that
    // compares a record id. Swift generates UPPERCASE UUIDs, Dart lowercase,
    // and records already in the wild carry both. Restore matches on id by
    // exact equality too (`planRestore`), so folding case here would make the
    // drain and restore disagree, and would break matching against every
    // backup file ever written.
    if (byId.containsKey(instruction.id)) continue;

    // Facts in, defaults here. A start carries only an id and a time; the rest
    // is what the old `_handleStart` used to write, moved to the drain.
    byId[instruction.id] = EventRecord(
      id: instruction.id,
      timestamp: instruction.at,
      // NULL, not lt1. At the moment a start is drained the duration genuinely
      // IS unknown — only the matching end knows it. `lt1` here was an
      // invention, and every abandoned event inherited it: an event left for
      // 37 minutes read "< 1 minute".
      //
      // This is the ONE producer for both platforms. iOS builds no record
      // either — handleQuickLogStart posts a start fact and defers every
      // default to this drain — so fixing it here fixes Android and iOS at
      // once, and the abandonment timeout needs no involvement at all.
      duration: null,
      // eventType and severity are LEFT UNSET, which now means NULL. The
      // constructor used to default them to `seizure` and `mild`, so this one
      // line produced a type and a comparison nobody made — 71 records in the
      // export read "Seizure / fit · Mild" on that basis.
      //
      // Left unset rather than written as `null` on purpose: the defaults are
      // gone from the constructor, so naming them here would only invite
      // someone to put a value back.
      feelings: const [],
      referralRequired: false,
      notes: '',
      // FALSE, not null. A quick-recorded event is a PARTIAL — created after
      // the wizard exists, carrying a timestamp and nothing anyone chose. Null
      // is reserved for the records that predate the concept, and writing it
      // here would deny every new event the guided path it exists for.
      detailsCompleted: false,
    );
    order.add(instruction.id);
    changed = true;
  }

  // ── PASS 2 — ends ──
  for (final instruction in instructions.where((i) => i.isEnd)) {
    final record = byId[instruction.id];

    if (record == null) {
      // THE DEFERRED-START CASE. The orphan rule exists for an end whose record
      // the user deleted in History — there is genuinely nothing to attach to,
      // and inventing a record would mean inventing a start time. It was NOT
      // written for an end whose start is sitting undrained in this same inbox,
      // waiting for a build that understands it. Dropping it there loses a
      // duration that is present and readable.
      //
      // So: hold it back alongside its start. A later build that understands
      // the deferred kind drains both together — pass 1 creates the record,
      // pass 2 sets the duration — and the outcome is the same as if neither
      // had ever been deferred. Still idempotent: nothing is written and the
      // key is untouched, so a repeat drain repeats this decision.
      if (deferredIds.contains(instruction.id)) {
        deferredKeys.add(instruction.key);
        deferReasons.add(InboxDefer.awaitingDeferredStart);
        continue;
      }

      // A genuine orphan: matches nothing at all, deferred or applied. Dropped
      // and reported, unchanged.
      drainableKeys.add(instruction.key);
      orphanEndIds.add(instruction.id);
      continue;
    }

    drainableKeys.add(instruction.key);

    final secs = instruction.seconds!;
    if (record.durationSeconds == secs) continue; // replay, or already correct

    byId[instruction.id] = EventRecord(
      id: record.id,
      timestamp: record.timestamp,
      // The bucket is NOT set from the seconds. A measured event carries a
      // number; deriving a range from it as well would create a second, coarser
      // copy of the same fact that could later disagree.
      duration: record.duration,
      durationSeconds: secs,
      feelings: record.feelings,
      referralRequired: record.referralRequired,
      notes: record.notes,
      eventType: record.eventType,
      severity: record.severity,
      triggers: record.triggers,
      // Carried, never re-defaulted. An end can drain AFTER the user has walked
      // the wizard, and rebuilding without this would silently reopen a record
      // they had finished.
      detailsCompleted: record.detailsCompleted,
    );
    changed = true;
  }

  final merged = [for (final id in order) byId[id]!]
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  return InboxDrainResult(
    merged: merged,
    drainableKeys: drainableKeys,
    deferredKeys: deferredKeys,
    deferReasons: deferReasons,
    orphanEndIds: orphanEndIds,
    changed: changed,
  );
}

/// What a completed drain did, for the caller to render and report.
class InboxDrainOutcome {
  /// The list to show. On a successful drain this is the merged list; when
  /// there was nothing to drain it is what was passed in; when the write FAILED
  /// it is still the merged list, so the user sees captures that are on screen
  /// but not yet in storage — which is exactly what the unsaved-events banner
  /// raised by [persistEvents] means.
  final List<EventRecord> records;

  /// True when there was something drainable and the write of it succeeded.
  final bool wrote;

  /// True when the inbox held at least one drainable entry.
  final bool attempted;

  final Set<InboxDefer> deferReasons;
  final int deferredCount;
  final List<String> orphanEndIds;

  const InboxDrainOutcome({
    required this.records,
    required this.wrote,
    required this.attempted,
    required this.deferReasons,
    required this.deferredCount,
    required this.orphanEndIds,
  });
}

/// Where inbox entries come from, and where the ack goes.
///
/// Introduced for step 2 and no wider than step 2 needs. On Android the inbox
/// lives in the same `SharedPreferences` the main isolate already reads, so the
/// transport is a thin wrapper. On iOS it cannot: `shared_preferences` reads
/// `UserDefaults.standard` and filters to the `flutter.` prefix, while the
/// inbox has to live in the App Group so a widget extension in another process
/// can write it. Giving `shared_preferences` a suite name would relocate every
/// preference in the app, so the iOS transport goes over a method channel
/// instead — Swift enumerates, Dart applies, Dart acks, Swift deletes.
///
/// [applyInbox] is deliberately NOT part of this. The whole correctness surface
/// — ordering, idempotency, merge-by-id, defaults, orphan versus deferral — is
/// pure and shared by both transports unchanged.
abstract class CaptureInboxTransport {
  /// Every entry currently present, parsed. Must not throw: a transport that
  /// cannot be reached returns empty, and the keys are read again next
  /// foreground.
  Future<List<InboxEntry>> read();

  /// Removes drained keys. Called ONLY after the write that consumed them was
  /// confirmed.
  Future<void> delete(Iterable<String> keys);
}

/// The Android transport: the inbox is in the same store the drain writes.
class PrefsInboxTransport implements CaptureInboxTransport {
  const PrefsInboxTransport(this.prefs);

  final SharedPreferences prefs;

  @override
  Future<List<InboxEntry>> read() async => readInboxEntries(prefs);

  @override
  Future<void> delete(Iterable<String> keys) => deleteInboxKeys(prefs, keys);
}

/// Drains the inbox into [store]: apply, write, verify, and only then delete.
///
/// The order is the whole point. Clearing the keys before the write is
/// confirmed would lose every capture the write failed to persist, and a
/// foreground is exactly when that failure is survivable if the keys are still
/// there. Deleting only on success makes a failed drain a retry rather than a
/// loss, which is safe because every instruction is idempotent.
///
/// Reports nothing itself: anomalies come back in the outcome so the caller
/// owns Sentry and the once-per-session bookkeeping, and so this stays testable
/// without a widget or an initialised Sentry.
Future<InboxDrainOutcome> drainInbox({
  required CaptureInboxTransport transport,
  required EventStore store,
  required List<EventRecord> loaded,
}) async {
  final entries = await transport.read();
  if (entries.isEmpty) {
    return InboxDrainOutcome(
      records: loaded,
      wrote: false,
      attempted: false,
      deferReasons: const <InboxDefer>{},
      deferredCount: 0,
      orphanEndIds: const <String>[],
    );
  }

  final plan = applyInbox(loaded, entries);

  var wrote = false;
  var records = loaded;
  if (plan.drainableKeys.isNotEmpty) {
    wrote = await persistEvents(store, plan.merged);
    records = plan.merged;
    if (wrote) await transport.delete(plan.drainableKeys);
  }

  return InboxDrainOutcome(
    records: records,
    wrote: wrote,
    attempted: plan.drainableKeys.isNotEmpty,
    deferReasons: plan.deferReasons,
    deferredCount: plan.deferredKeys.length,
    orphanEndIds: plan.orphanEndIds,
  );
}
