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

  final mirrored = _parseMirroredRecords(raw);
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
    if (existing.duration == DurationCategory.lt1 &&
        m.duration != DurationCategory.lt1) {
      byId[m.id] = EventRecord(
        id:               existing.id,
        timestamp:        existing.timestamp,
        duration:         m.duration,
        feelings:         existing.feelings,
        referralRequired: existing.referralRequired,
        notes:            existing.notes,
        eventType:        existing.eventType,
        severity:         existing.severity,
        triggers:         existing.triggers,
      );
      durationsRecovered.add(m.id);
    }
  }

  merged
    ..addAll([for (final id in order) byId[id]!])
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  final changed = addedIds.isNotEmpty || durationsRecovered.isNotEmpty;
  if (!changed) {
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
  if (wrote) {
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

/// Parses the legacy mirror payload. One unreadable record never costs the
/// others — the same rule `EventStore.load` follows.
List<EventRecord> _parseMirroredRecords(String raw) {
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return const <EventRecord>[];
    return decoded
        .whereType<Map>()
        .map((e) => EventRecord.fromMap(Map<String, dynamic>.from(e)))
        .whereType<EventRecord>()
        .toList();
  } catch (_) {
    return const <EventRecord>[];
  }
}

/// Reports a channel failure without letting it reach the caller.
void reportCaptureChannelError(Object error, StackTrace stack) {
  unawaited(Sentry.captureException(error, stackTrace: stack));
}
