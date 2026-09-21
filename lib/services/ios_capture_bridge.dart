/// The iOS half of the capture inbox: a transport, and a one-time reconciliation.
///
/// Everything here exists because **Dart cannot read the App Group.**
/// `shared_preferences` on iOS reads `UserDefaults.standard` and filters to the
/// `flutter.` prefix; the inbox has to live in the App Group so
/// `EndMEREventIntent`, running in a separate widget-extension process, can
/// write it. Giving `shared_preferences` a suite name would relocate every
/// preference in the app, on the same release as this change.
///
/// So Swift enumerates, Dart applies, Dart acks, Swift deletes. The ack is what
/// makes drain-then-clear structural rather than a convention someone has to
/// remember.
///
/// Nothing here interprets a record. The classification of an entry — applicable,
/// deferred, or an orphan end — happens in `applyInbox` on the Dart side, so the
/// channel carries raw strings only and **cannot collapse a genuine drop into a
/// benign deferral.** That distinction is the difference between telemetry that
/// shows data loss and telemetry that hides it.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/capture_inbox.dart';
import '../models/capture_instruction.dart';
import '../models/event_record.dart';

/// Set once, when the pre-inbox App Group record mirror has been folded into
/// the store and retired. Lives in Dart's own namespace because Dart owns the
/// once-only semantics.
const String kSharedRecordsReconciledKey = 'mer_shared_records_reconciled';

/// How long a channel call may take before the drain gives up for this
/// foreground.
///
/// A bound matters more than its value. The channel handshake sits on the
/// cold-start path, which is where four of the seven historical notification
/// failures lived, and an unbounded call there would hold the first render of
/// the event list. On timeout the inbox is simply read again next foreground:
/// the keys are untouched, because deletion is gated on a confirmed write.
const Duration kCaptureChannelTimeout = Duration(seconds: 3);

/// Reads and acks the App Group inbox over the navigation channel.
///
/// Never throws. A channel that is missing, erroring or hung degrades to "no
/// entries this time", which costs one foreground of latency and loses nothing —
/// the alternative, letting it throw, would take the whole list render with it.
class IosChannelInboxTransport implements CaptureInboxTransport {
  IosChannelInboxTransport(this.channel, {this.onError});

  final MethodChannel channel;

  /// Called with a description when a channel call fails, so the caller owns
  /// reporting. This class stays testable without an initialised Sentry.
  final void Function(Object error, StackTrace stack)? onError;

  @override
  Future<List<InboxEntry>> read() async {
    try {
      final raw = await channel
          .invokeMapMethod<String, String>('readCaptureInbox')
          .timeout(kCaptureChannelTimeout);
      if (raw == null || raw.isEmpty) return const <InboxEntry>[];

      // Key order carries no meaning — ordering is decided from `at` by the
      // drain — but sorting keeps the pre-sort arrangement stable.
      final keys = raw.keys.toList()..sort();
      return [for (final k in keys) parseInboxEntry(k, raw[k])];
    } catch (e, st) {
      onError?.call(e, st);
      return const <InboxEntry>[];
    }
  }

  @override
  Future<void> delete(Iterable<String> keys) async {
    final list = keys.toList();
    if (list.isEmpty) return;
    try {
      await channel
          .invokeMethod<void>('deleteCaptureInbox', list)
          .timeout(kCaptureChannelTimeout);
    } catch (e, st) {
      // The write already succeeded, so the records are safe. Undeleted keys
      // are replayed next foreground, and every instruction is idempotent, so a
      // failed delete costs a repeated no-op rather than a duplicate.
      onError?.call(e, st);
    }
  }
}

/// What the one-time reconciliation did.
class SharedRecordsReconcileOutcome {
  const SharedRecordsReconcileOutcome({
    required this.records,
    required this.ran,
    required this.wrote,
    required this.addedIds,
    required this.durationsRecovered,
  });

  /// The list to carry forward — merged when the reconciliation ran and wrote,
  /// otherwise exactly what was passed in.
  final List<EventRecord> records;

  /// True when this device still had the legacy mirror to fold in.
  final bool ran;

  /// True when the merged list was persisted, which is what allows the mirror
  /// to be retired.
  final bool wrote;

  /// Ids present only in the App Group mirror.
  final List<String> addedIds;

  /// Ids where the mirror carried a duration the store had lost — the exact
  /// aftermath of the defect this whole change closes.
  final List<String> durationsRecovered;
}

/// Folds the pre-inbox App Group record mirror into the store, once, then
/// retires it.
///
/// ## Why this exists
///
/// Before this change, `handleQuickLogStart` and `handleQuickLogEnd` wrote the
/// whole record list to BOTH `UserDefaults.standard` and the App Group, while
/// `EndMEREventIntent` wrote only the App Group. Two full-list mirrors with
/// wholesale one-directional copies and no sequence marker. A device can
/// therefore arrive here with the two disagreeing, and the disagreement is not
/// random: it is the duration the extension recorded and a later
/// `handleQuickLogStart` overwrote.
///
/// ## The rules
///
///  * **Union by id.** Never a wholesale copy in either direction — that is the
///    defect, and doing it here would be doing it one last time.
///  * Where an id is in both and only the mirror has a **non-default** duration,
///    take the mirror's. That is precisely the destroyed value.
///  * Otherwise the store wins, because Dart is the writer of record and may
///    hold user edits the mirror never saw.
///  * Ids are compared by **exact string equality**. Swift writes uppercase
///    UUIDs and Dart lowercase; folding case would break matching against every
///    backup file ever written.
///
/// ## Ordering
///
/// Runs BEFORE the inbox drain, so an `end` instruction can attach to a record
/// recovered from the mirror in the same foreground.
///
/// Drain-then-clear applies here too: the mirror is retired only after the
/// merged list is confirmed written. A failure leaves the flag unset and the
/// mirror in place, and the whole thing is retried next foreground — safe,
/// because a union by id is idempotent.
Future<SharedRecordsReconcileOutcome> reconcileLegacySharedRecords({
  required MethodChannel channel,
  required SharedPreferences prefs,
  required EventStore store,
  required List<EventRecord> loaded,
  void Function(Object error, StackTrace stack)? onError,
}) async {
  const none = <String>[];

  if (prefs.getBool(kSharedRecordsReconciledKey) ?? false) {
    return SharedRecordsReconcileOutcome(
      records: loaded, ran: false, wrote: false,
      addedIds: none, durationsRecovered: none,
    );
  }

  String? raw;
  try {
    raw = await channel
        .invokeMethod<String>('readLegacySharedRecords')
        .timeout(kCaptureChannelTimeout);
  } catch (e, st) {
    // Unreachable channel: leave the flag unset and try again next foreground.
    onError?.call(e, st);
    return SharedRecordsReconcileOutcome(
      records: loaded, ran: false, wrote: false,
      addedIds: none, durationsRecovered: none,
    );
  }

  if (raw == null || raw.isEmpty) {
    // Nothing to fold in — a fresh install, or a device that only ever captured
    // in-app. Mark it done so this never runs again.
    await prefs.setBool(kSharedRecordsReconciledKey, true);
    try {
      await channel
          .invokeMethod<void>('clearLegacySharedRecords')
          .timeout(kCaptureChannelTimeout);
    } catch (e, st) {
      onError?.call(e, st);
    }
    return SharedRecordsReconcileOutcome(
      records: loaded, ran: false, wrote: false,
      addedIds: none, durationsRecovered: none,
    );
  }

  final parse = _parseMirroredRecords(raw);
  final mirrored = parse.records;

  // ⛔ REPORTED AS SOON AS IT IS KNOWN, not at the retirement sites. The counts
  // are what make it actionable: "3 of 11 elements produced no record" can be
  // investigated; "something failed" cannot.
  if (!parse.complete && !_incompleteReported) {
    _incompleteReported = true;
    onError?.call(
      StateError('Legacy mirror read INCOMPLETE — ${parse.failure}. '
          'kept ${parse.records.length} of ${parse.elements}. '
          'The mirror is NOT being retired; this will retry next foreground.'),
      StackTrace.current,
    );
  }

  final merged = <EventRecord>[];
  final order = <String>[];
  final byId = <String, EventRecord>{};
  for (final r in loaded) {
    if (byId.containsKey(r.id)) continue;
    byId[r.id] = r;
    order.add(r.id);
  }

  final addedIds = <String>[];
  final durationsRecovered = <String>[];

  for (final m in mirrored) {
    final existing = byId[m.id];
    if (existing == null) {
      byId[m.id] = m;
      order.add(m.id);
      addedIds.add(m.id);
      continue;
    }
    // Both have it. The only field the mirror can legitimately be ahead on is
    // duration, and only when the store still holds the default it was created
    // with.
    // NULL is now the honest "not known"; lt1 is the historical default that
    // used to stand in for it. Both mean the store has nothing to lose, so a
    // mirror carrying a real duration may fill either.
    //
    // The lt1 arm is kept DELIBERATELY: records written before nullable
    // duration still carry lt1 where nobody answered, and dropping it would
    // silently stop recovering their durations. It stays imprecise in the one
    // direction it always has — a GENUINE sub-minute event looks unset — and
    // that is exactly the imprecision nullable duration retires going forward.
    if ((existing.duration == null ||
            existing.duration == DurationCategory.lt1) &&
        m.duration != null &&
        m.duration != existing.duration) {
      byId[m.id] = EventRecord(
        id:               existing.id,
        timestamp:        existing.timestamp,
        duration:         m.duration,
        // Both carried. This branch rebuilds an EXISTING record to recover a
        // duration, so every field it does not set is a field it destroys —
        // seconds the user measured, and a wizard they had completed.
        durationSeconds:  existing.durationSeconds,
        detailsCompleted: existing.detailsCompleted,
        feelings:         existing.feelings,
        referralRequired: existing.referralRequired,
        notes:            existing.notes,
        eventType:        existing.eventType,
        severity:         existing.severity,
        triggers:         existing.triggers,
        // ⛔ SAME OMISSION AS capture_inbox, and this file's own comment
        // above already stated the rule it was breaking. The rescue
        // fields have been destroyed here since 216bef7; occurredAt would
        // have been the fourth.
        occurredAt:           existing.occurredAt,
        rescueMedGiven:       existing.rescueMedGiven,
        rescueMedHelped:      existing.rescueMedHelped,
        rescueMedSecondDose:  existing.rescueMedSecondDose,
        // CARRIED. Dropping it here is AUDIT.md §13(cj) failure mode (b), "a
        // hidden record could silently unhide", on the pathway the developer
        // names as the most used.
        hidden:               existing.hidden,
        // ⛔ CARRIED, NOT STAMPED. This fold has NO user behind it -- it
        // recovers a duration from a retired mirror on the next foreground.
        // Stamping here would let a device that merely launched outrank a
        // device where somebody edited something.
        updatedAt:            existing.updatedAt,
      );
      durationsRecovered.add(m.id);
    }
  }

  merged
    ..addAll([for (final id in order) byId[id]!])
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  final changed = addedIds.isNotEmpty || durationsRecovered.isNotEmpty;
  if (!changed) {
    // ⛔ COMPLETENESS OF THE READ, NOT ABSENCE OF CHANGE, EARNS THE DELETE.
    // "The two agreed" and "the payload could not be read" both arrive here
    // with an empty `mirrored`, and before 21 September 2026 they were
    // indistinguishable — four different meanings taking one branch.
    if (!parse.complete) {
      return SharedRecordsReconcileOutcome(
        records: loaded, ran: true, wrote: false,
        addedIds: none, durationsRecovered: none,
      );
    }
    // The two agreed. Retire the mirror without a write.
    await prefs.setBool(kSharedRecordsReconciledKey, true);
    try {
      await channel
          .invokeMethod<void>('clearLegacySharedRecords')
          .timeout(kCaptureChannelTimeout);
    } catch (e, st) {
      onError?.call(e, st);
    }
    return SharedRecordsReconcileOutcome(
      records: loaded, ran: true, wrote: false,
      addedIds: none, durationsRecovered: none,
    );
  }

  final wrote = await persistEvents(store, merged);
  // ⛔ THE WORST OF THE THREE, AND THE ONE Brief 75 PART A ADDED. `wrote` says
  // the merged list was PERSISTED. It says nothing about whether the merge was
  // built from everything that was there — so a payload that decoded partially,
  // folded its survivors and wrote them successfully used to delete the records
  // it had just dropped. `wrote == true` is the strongest signal of success at
  // this line, and a partially-failed read was producing it.
  //
  // ⭐ The survivors are still folded and still written. Partial recovery is
  // better than none and that behaviour is unchanged. Only the DELETE waits.
  if (wrote && parse.complete) {
    await prefs.setBool(kSharedRecordsReconciledKey, true);
    try {
      await channel
          .invokeMethod<void>('clearLegacySharedRecords')
          .timeout(kCaptureChannelTimeout);
    } catch (e, st) {
      onError?.call(e, st);
    }
  }

  return SharedRecordsReconcileOutcome(
    records: merged,
    ran: true,
    wrote: wrote,
    addedIds: addedIds,
    durationsRecovered: durationsRecovered,
  );
}

/// What a parse of the mirror SAW, alongside what it KEPT.
///
/// ⛔ **THE FUNCTION BELOW ANSWERS TWO DIFFERENT QUESTIONS AND USED TO RETURN
/// ONLY ENOUGH FOR ONE.** "What can I fold?" is answered by the survivors.
/// "Is it safe to DELETE the source?" is not — and both decisions were being
/// taken from the same `List<EventRecord>`.
///
/// ⭐ **The parse rule itself is unchanged and is NOT the defect**: one
/// unreadable record still never costs the others, exactly as
/// `EventStore.load` behaves. Partial recovery is better than none. What
/// changes is that the caller can now tell a partial recovery from a total one.
class MirrorParse {
  const MirrorParse({
    required this.records,
    required this.elements,
    required this.complete,
    this.failure,
  });

  /// The records that could be built. Survivors only, as before.
  final List<EventRecord> records;

  /// How many elements the decoded JSON List contained. 0 when it was not a
  /// List or the decode threw.
  final int elements;

  /// ⛔ **COMPLETE means: it decoded as a List, EVERY element produced a
  /// record, and nothing threw.** Anything else is incomplete, and an
  /// incomplete read must never be allowed to retire the mirror.
  final bool complete;

  /// Why it was incomplete, for the report. Null when complete.
  final String? failure;

  /// Elements that decoded but produced no record.
  int get dropped => elements - records.length;
}

/// Parses the legacy mirror payload. One unreadable record never costs the
/// others — the same rule `EventStore.load` follows.
///
/// ⚠️ Now reports completeness alongside the survivors. See [MirrorParse].
MirrorParse _parseMirroredRecords(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return const MirrorParse(
        records: <EventRecord>[], elements: 0,
        complete: false, failure: 'payload did not decode as a List',
      );
    }
    final records = decoded
        .whereType<Map>()
        .map((e) => EventRecord.fromMap(Map<String, dynamic>.from(e)))
        .whereType<EventRecord>()
        .toList();
    final complete = records.length == decoded.length;
    return MirrorParse(
      records: records,
      elements: decoded.length,
      complete: complete,
      failure: complete
          ? null
          : '${decoded.length - records.length} of ${decoded.length} '
              'elements produced no record',
    );
  } catch (e) {
    return MirrorParse(
      records: const <EventRecord>[], elements: 0,
      complete: false, failure: 'decode threw: $e',
    );
  }
}

/// ⚠️ ONE REPORT PER PROCESS, and the reason is that an incomplete read now
/// RECURS. Before this change a bad mirror was read once and deleted; now it is
/// read on every foreground until it parses or the user reinstalls. A
/// permanently unparseable payload would otherwise become a Sentry firehose.
///
/// ⭐ Per-process rather than a durable key, deliberately: the reconciliation
/// runs at most once per foreground load, so a process-scoped flag already
/// bounds this to roughly one report per app launch — without adding a
/// persisted key, which contract `#18` makes permanent once shipped.
bool _incompleteReported = false;

@visibleForTesting
void debugResetIncompleteReport() => _incompleteReported = false;

/// Reports a channel failure without letting it reach the caller.
void reportCaptureChannelError(Object error, StackTrace stack) {
  unawaited(Sentry.captureException(error, stackTrace: stack));
}

/// Whether a failure on `au.com.notiva.mer/navigation` is worth reporting.
///
/// ⛔ **THE PLATFORM CHECK IS ABOUT THE FAILURE, NOT ABOUT THE CALL.** The call
/// is made on every platform, deliberately. A guard that stopped it off iOS
/// would also stop iOS ever reporting a handler that has GONE missing — a
/// channel or method rename on the Swift side — and that is the failure most
/// worth hearing about, because it has no other detector: the call would
/// silently become a no-op on iOS too and every test would stay green.
///
/// The channel is registered in `ios/Runner/AppDelegate.swift` and **nowhere
/// else** — `MainActivity.kt` is a bare `FlutterActivity` and `windows/runner`
/// registers nothing — so off iOS a [MissingPluginException] is the expected
/// and only outcome. Reporting it would fire on every cold start and every
/// save, which is noise that would bury the signal above.
///
/// | platform | `MissingPluginException` | anything else |
/// |---|---|---|
/// | iOS | report | report |
/// | Android, Windows | swallow | report |
///
/// ⛔ **DO NOT "SIMPLIFY" THIS BACK INTO `if (Platform.isIOS)` AROUND A CALL
/// SITE.** That is the shape this replaced. It is silent in the one place
/// silence costs something, and it reads as tidier.
///
/// ⭐ `isIOS` is a PARAMETER rather than a read of `Platform.isIOS`, and that is
/// the point of the signature: a test host renders exactly ONE platform, so a
/// policy that read the platform itself could only ever be exercised on one
/// side of the table while the other side passed by never running. Both rows
/// are behavioural tests because of this parameter.
bool shouldReportNavChannelFailure(Object error, {required bool isIOS}) =>
    isIOS || error is! MissingPluginException;

/// Applies [shouldReportNavChannelFailure], then routes through the existing
/// [reportCaptureChannelError]. Deliberately not a second reporting path.
///
/// `isIOS` defaults to the real platform; tests pass it explicitly.
void reportNavChannelFailure(Object error, StackTrace stack, {bool? isIOS}) {
  if (!shouldReportNavChannelFailure(error, isIOS: isIOS ?? Platform.isIOS)) return;
  reportCaptureChannelError(error, stack);
}
