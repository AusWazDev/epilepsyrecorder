import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../theme/mer_theme.dart';

// constants.dart is gone too: kEventStorageKey was the only thing this file
// took from it, and nothing here names the record store any more.
//
// Deliberately NOT models/event_record.dart. Under the inbox this file posts
// facts and never touches a record: no EventRecord, no toMap, no decode of the
// stored list. capture_instruction.dart imports no model either, so the
// background isolate's surface is the schema and nothing more. Four of the
// seven historical notification failures lived in that isolate.
// constants.dart is safe here for the same reason the two below are: it has
// ZERO imports of its own, so it adds no surface to the isolate. The rule
// above is about not dragging models and plugins in, not about strings.
import '../constants.dart';
import '../models/capture_instruction.dart';
import '../models/duration_format.dart';
import 'ios_capture_bridge.dart' show reportCaptureChannelError;

// ── IDs & storage keys ────────────────────────────────────────────────────────

const _persistentId   = 1;
const _feedbackId     = 2;

const _btnStart       = 'QUICK_LOG_START';
const _btnEnd         = 'QUICK_LOG_END';

const _chanActive     = 'mer_active_v2';
const _chanFeedback   = 'mer_feedback';

const _activeEventKey = 'mer_active_event';

/// ── Unreadable-marker quarantine ─────────────────────────────────────────
///
/// ⛔ **PRESERVATION ONLY.** Nothing in the app reads these. They exist because
/// deleting an active marker that could not be parsed is IRREVERSIBLE — the
/// marker holds the only copy of the event's start time, so losing it makes the
/// running event's duration permanently unrecoverable. That asymmetry is the
/// whole justification and there is no other.
///
/// ⭐ **DELIBERATELY THE SAME SHAPE AND THE SAME NAMES AS THE SWIFT SIDE'S
/// QUARANTINE IN `a2df73c`** — most-recent value plus a count. Symmetry, not
/// coincidence: one marker at a time, the payload is two fields, and bounded
/// storage beats completeness nobody reads. The COUNT is what tells a later
/// reader whether it recurred.
///
/// ⚠️ **THE IDENTICAL NAMES CANNOT COLLIDE, AND THE REASON IS STRUCTURAL.**
/// Swift's live in `UserDefaults(suiteName: group.au.com.notiva.…)`; these live
/// in `SharedPreferences`, which on iOS reads `UserDefaults.standard` and
/// filters to the `flutter.` prefix. **`shared_preferences` cannot address a
/// suite name at all**, so Dart is incapable of becoming a second writer of the
/// App Group keys even by mistake. See `ios_capture_bridge.dart`'s header.
///
/// ⛔ **AND THE WORD THAT DOES NOT BELONG HERE: these keys are not "reportable".
/// They are PRESERVATION.** The report is the Sentry event raised alongside
/// them — a separate thing, in a separate place, with a separate name. The
/// Swift side could not report at all, which is why `a2df73c` has only an
/// os_log; Dart has Sentry and does both.
const _quarantineKey      = 'mer_active_quarantine';
const _quarantineCountKey = 'mer_active_quarantine_count';

/// ⚠️ Per-process, reset only by a restart. See the report block in
/// [resolveActiveMarker] for why this is not a persisted key.
bool _unreadableReported = false;

@visibleForTesting
void debugResetUnreadableReport() => _unreadableReported = false;

const _timeoutMins    = 30;

/// What the active marker turned out to be.
enum MarkerState {
  /// Parsed. Safe to act on and safe to remove.
  readable,

  /// Present but unparseable. ⛔ **Must be preserved, never removed.**
  unreadable,

  /// Not there at all. Nothing to preserve and nothing to remove.
  ///
  /// ⚠️ Distinguished from [unreadable] DELIBERATELY. `_decodeActive` returns
  /// null for both, and quarantining an absent marker would manufacture
  /// evidence of a loss that did not happen.
  absent,
}

/// Disposes of the active marker according to what it turned out to be.
///
/// Returns the state it classified, so a caller can act on it.
///
/// ⭐ **THIS IS THE INBOX DRAIN'S SHAPE, NOT A NEW INVENTION.** `applyInbox`
/// already solves exactly this: an entry that cannot be parsed becomes
/// `InboxEntry.deferred(key, InboxDefer.malformed)` — an OBSERVABLE STATE — and
/// is excluded from `drainableKeys`, so it is never acked. Per-element evidence
/// about the very thing being destroyed. The mirror lacked that and cost a
/// one-way door; this had the same gap and is closed the same way.
///
/// ⛔ **PLATFORM-FREE ON PURPOSE.** The callers are gated (`endEvent` returns on
/// Windows, `onActionReceived` on iOS), so a behavioural test of the policy
/// would otherwise be host-bound by construction — the exact class Brief 68
/// exists for. Taking `prefs` and `onReport` as parameters, and reading
/// `Platform` nowhere, makes every row of this decision testable on any host.
/// The rationale for that shape is written at
/// `walkthrough_screen.dart:361-366`; this is its third application.
@visibleForTesting
Future<MarkerState> resolveActiveMarker(
  SharedPreferences prefs, {
  required bool decodedOk,
  void Function(Object error, StackTrace stack)? onReport,
}) async {
  final raw = prefs.getString(_activeEventKey);

  if (raw == null || raw.isEmpty) return MarkerState.absent;

  if (decodedOk) {
    await prefs.remove(_activeEventKey);
    return MarkerState.readable;
  }

  // ⛔ UNREADABLE. Preserve first, remove nothing. A failure decides that this
  // branch runs, and a failure must not be allowed to destroy the only copy.
  final count = (prefs.getInt(_quarantineCountKey) ?? 0) + 1;
  await prefs.setString(_quarantineKey, raw);
  await prefs.setInt(_quarantineCountKey, count);

  // ⭐ THE REPORT, which is a different thing from the preservation above, and
  // carries the count — "this is the third time" is actionable, "something
  // failed" is not.
  //
  // ⛔ ONCE PER PROCESS, NOT ONCE PER OCCURRENCE, AND THE FIX ITSELF IS WHY.
  // Because an unreadable marker is no longer REMOVED, it persists — so every
  // subsequent end-button press in the same session re-reads the same bad value
  // and would report again. Preserving the marker is what creates the
  // recurrence, so the report has to be bounded or the fix manufactures a
  // firehose out of one stuck value.
  //
  // ⭐ Same choice and same reasoning as `_incompleteReported` in
  // `ios_capture_bridge.dart`, and deliberately NOT a persisted key: contract
  // `#18` makes a durable key permanent once shipped, and the COUNT above is
  // already the durable signal. The count keeps rising while the reports stay
  // at one per launch, so a later reader still sees how often it recurred.
  if (!_unreadableReported) {
    _unreadableReported = true;
    onReport?.call(
      StateError('Active event marker could not be read. PRESERVED, not '
          'removed — the start time is the only copy and deleting it would '
          "make the running event's duration unrecoverable. occurrence "
          '#$count.'),
      StackTrace.current,
    );
  }
  return MarkerState.unreadable;
}

// ── Formatting helpers ────────────────────────────────────────────────────────

String _fmtTime(DateTime t) => DateFormat('h:mm a').format(t);

/// Delegates to `durationSecondsLabel`, so the duration a user is shown when an
/// event ends is the SAME STRING History shows for it afterwards. Two copies of
/// this formatting is exactly the drift a test cannot see.
String _fmtElapsed(DateTime start, DateTime end) =>
    durationSecondsLabel(end.difference(start).inSeconds);

/// The live in-progress marker, parsed.
class _ActiveEvent {
  final String id;
  final DateTime startedAt;
  const _ActiveEvent(this.id, this.startedAt);
}

// `_durationFromDiff` lived here and computed a stored bucket in the background
// isolate. The writer now posts SECONDS and the drain STORES them: duration is
// a quantity, so there is no bucket to compute anywhere and
// `bucketFromSeconds` has been deleted rather than left unused. Nothing here
// needs the record model.

// ── Service ───────────────────────────────────────────────────────────────────

@pragma('vm:entry-point')
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  Future<void> init() async {
    // iOS: Swift (AppDelegate) owns all notification management.
    // awesome_notifications must NOT initialize on iOS — its initialize()
    // call resets UNUserNotificationCenter.delegate to itself, breaking
    // our native locked-screen action handler.
    if (Platform.isWindows || Platform.isIOS) return;

    try {
      await AwesomeNotifications().initialize(
        Platform.isAndroid ? 'resource://drawable/ic_launcher_foreground' : null,
        [
          NotificationChannel(
            channelKey:         _chanActive,
            channelName:        'MER Active',
            channelDescription: 'Persistent quick-log action — always available',
            importance:         NotificationImportance.Default,
            playSound:          false,
            enableVibration:    false,
            defaultPrivacy:     NotificationPrivacy.Public,
            defaultColor:       MERColours.primary,
          ),
          NotificationChannel(
            channelKey:         _chanFeedback,
            channelName:        'MER Quick Log',
            channelDescription: 'Confirmation shown after a quick log action',
            importance:         NotificationImportance.High,
            defaultPrivacy:     NotificationPrivacy.Public,
            defaultColor:       MERColours.primary,
          ),
        ],
      );

      await AwesomeNotifications().setListeners(
        onActionReceivedMethod: onActionReceived,
      );

      final allowed = await AwesomeNotifications().isNotificationAllowed();
      if (!allowed) {
        await AwesomeNotifications().requestPermissionToSendNotifications();
      }

      await _clearIfTimedOut();

      final nowAllowed = await AwesomeNotifications().isNotificationAllowed();
      if (nowAllowed) await _restoreNotification();
    } catch (_) {
      // Notification setup failure must never prevent the app from loading.
    }
  }

  // Must be static with @pragma for awesome_notifications to call it
  // from any isolate context.
  @pragma('vm:entry-point')
  static Future<void> onActionReceived(ReceivedAction action) async {
    // iOS action buttons are handled natively in AppDelegate — no Dart
    // background isolate needed (and none is reliable in release builds).
    if (Platform.isIOS) return;

    // Handle feedback notification body tap before initializing channels —
    // avoids race with HomeScreen._handleResume by writing the flag as fast
    // as possible, without waiting for the channel init overhead.
    if (action.buttonKeyPressed.isEmpty &&
        action.payload?['action'] == 'openLatest') {
      final prefs = await SharedPreferences.getInstance();
      final id = action.payload?['id'];

      // ⛔ THE LEGACY BOOLEAN IS KEPT, AND IT CARRIES A REMOVAL CONDITION.
      // A notification posted by a PRE-ID build carries no 'id', and one can
      // still be sitting in the tray across an upgrade. Those taps fall back
      // to the boolean and resolve by position.
      //
      // 🔴 REMOVABLE once no pre-id notification can still be in flight — i.e.
      // after one release has fully rolled. Recorded 19 September 2026.
      // ⭐ A compatibility shim without an expiry is how temporary becomes
      // architecture.
      if (id != null && id.isNotEmpty) {
        await prefs.setString('mer_open_event_id', id);
      } else {
        await prefs.setBool('mer_open_latest_event', true);
      }
      return;
    }

    // Channels must be registered in the background isolate before
    // createNotification() can succeed (main isolate init doesn't carry over).
    await AwesomeNotifications().initialize(
      Platform.isAndroid ? 'resource://drawable/ic_launcher_foreground' : null,
      [
        NotificationChannel(
          channelKey:         _chanActive,
          channelName:        'MER Active',
          channelDescription: 'Persistent quick-log action — always available',
          importance:         NotificationImportance.Default,
          playSound:          false,
          enableVibration:    false,
          defaultPrivacy:     NotificationPrivacy.Public,
          defaultColor:       MERColours.primary,
        ),
        NotificationChannel(
          channelKey:         _chanFeedback,
          channelName:        'MER Quick Log',
          channelDescription: 'Confirmation shown after a quick log action',
          importance:         NotificationImportance.High,
          defaultPrivacy:     NotificationPrivacy.Public,
        ),
      ],
    );

    if (action.buttonKeyPressed == _btnStart) {
      await instance._handleStart();
    } else if (action.buttonKeyPressed == _btnEnd) {
      await instance._handleEnd();
    }
  }

  // ── Handlers ─────────────────────────────────────────────────────────────

  /// Posts a start fact. Reads no record and writes no record list.
  ///
  /// This used to build a full [EventRecord], decode the whole stored list,
  /// insert and re-encode — a read-modify-write from the background isolate,
  /// racing the main isolate's own unawaited saves. That was backlog item 13,
  /// reachable through ordinary use. The main isolate now drains this
  /// instruction in `_loadRecords` and is the only writer of the record list.
  Future<void> _handleStart() async {
    final prefs = await SharedPreferences.getInstance();
    final now   = DateTime.now();
    final id    = const Uuid().v4();

    await writeStartInstruction(prefs, id: id, at: now);

    // mer_active_event stays STATE, not an instruction: it is the live
    // in-progress marker the banner and the end handler read, and it is
    // removed when the event ends rather than being applied and drained.
    await prefs.setString(_activeEventKey, jsonEncode({
      'id':       id,
      'startIso': now.toIso8601String(),
    }));

    await _showActive(now);
    // iOS: the "Event in progress" notification is itself the confirmation —
    // a second feedback notification stacks on top and confuses the action button.
    if (!Platform.isIOS) {
      await _showFeedback(
        title: 'Event started · ${_fmtTime(now)}',
        body:  'Tap "Event Ended" in the notification when it stops',
      );
    }
  }

  Future<void> _handleEnd() async {
    final prefs     = await SharedPreferences.getInstance();
    final activeRaw = prefs.getString(_activeEventKey);

    final active = _decodeActive(activeRaw);
    // An unreadable marker means the start time is unknown. No end instruction
    // is posted and no elapsed is shown: a fabricated zero would become a
    // "< 1 minute" bucket on a real event. The record keeps the default it was
    // created with, and the notification is still restored below — previously a
    // bare DateTime.parse threw here, so the active notification stuck.
    if (active != null) {
      final eventId   = active.id;
      final startTime = active.startedAt;
      final endTime   = DateTime.now();

      // SECONDS, not a bucket. The bucket is a storage decision and belongs
      // with the one writer of the store; the drain stores the seconds.
      await writeEndInstruction(
        prefs,
        id:      eventId,
        at:      endTime,
        seconds: endTime.difference(startTime).inSeconds,
      );

      final elapsed = _fmtElapsed(startTime, endTime);
      await _showFeedback(
        title:   'Event ended · $elapsed',
        body:    'Open MER to add details',
        timeout: null,
          // ⛔ THE ID TRAVELS, 19 September 2026. This carried only
        // {'action': 'openLatest'} while `eventId` sat in scope four lines
        // above, so the tap resolved by POSITION on the receiving side.
        // ⭐ A notification concerns a SPECIFIC event; which event that is
        // must not depend on a view preference, or on nothing else having
        // been recorded in between.
        payload: {'action': 'openLatest', 'id': eventId},
      );
    }

    // ⛔ THE REMOVE IS NOW INSIDE THE DECISION, 21 September 2026. It sat here
    // UNCONDITIONALLY, outside the `if (active != null)` above — so an
    // unreadable marker wrote no end instruction, showed no feedback, AND WAS
    // DELETED ANYWAY, taking the only copy of the start time with it and making
    // that event's duration permanently unrecoverable.
    //
    // ⭐ THE TRADE AT :226 IS NOT REVERSED. Continuing past an unreadable marker
    // was a deliberate fix for a stuck active notification, and it still
    // continues: `_showNormal()` below runs in every case. Only the DELETION
    // changed.
    await resolveActiveMarker(prefs,
        decodedOk: active != null, onReport: reportCaptureChannelError);
    // Delay restoring the persistent notification so the end-event feedback
    // notification settles at the top of the shade first.
    await Future.delayed(const Duration(seconds: 3));
    await _showNormal();
  }

  /// Ends the active event from the in-app banner.
  ///
  /// No isolate-awareness: this and `onActionReceived` run identical code, so
  /// the banner and the notification action cannot diverge.
  Future<void> endEvent() async {
    // Windows has no notification path at all — init() returns before any
    // channel is created, so nothing ever writes mer_active_event and the
    // banner that calls this can never appear. That made this unreachable by a
    // two-step argument about another key rather than by a guard. Guarding
    // service-side covers every caller, present and future. Backlog item 14.
    if (Platform.isWindows) return;
    try {
      await _handleEnd();
    } catch (_) {}
  }

  /// The live in-progress marker, or null if absent or unreadable.
  _ActiveEvent? _decodeActive(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final id = decoded['id'];
      if (id is! String || id.isEmpty) return null;
      // Same normalisation as the inbox and EventRecord — never a bare parse.
      // Dart writes this key naive-local, so toLocal() is a no-op today; Swift
      // writes it UTC with a Z, and step 2 makes that shape reachable here.
      final startedAt = parseInstructionAt(decoded['startIso']);
      if (startedAt == null) return null;
      return _ActiveEvent(id, startedAt);
    } catch (_) {
      return null;
    }
  }

  // On iOS, Swift's applicationDidBecomeActive handles this natively.
  Future<void> restoreNotification() async {
    if (Platform.isIOS) return;
    try {
      final allowed = await AwesomeNotifications().isNotificationAllowed();
      if (allowed) await _restoreNotification();
    } catch (_) {}
  }

  // ── Startup helpers ───────────────────────────────────────────────────────

  Future<void> _clearIfTimedOut() async {
    final prefs     = await SharedPreferences.getInstance();
    final activeRaw = prefs.getString(_activeEventKey);
    if (activeRaw == null) return;

    // ⛔ WAS `jsonDecode(activeRaw) as Map` AND `DateTime.parse(...)`, BOTH
    // BARE. That was SAFE — they THREW on an unreadable marker, so the remove
    // below was never reached — but safe by an exception nobody chose, while
    // `_decodeActive` four methods away returns null for the same input.
    //
    // ⭐ AND THE REPOSITORY HAD ALREADY DECIDED AGAINST THIS THROW ONCE: the
    // comment in `_handleEnd` records that "previously a bare DateTime.parse
    // threw here, so the active notification stuck", and treats that as a bug
    // worth fixing. Pinning the throw as load-bearing would have argued against
    // that precedent. Two functions in one file now take ONE shape.
    //
    // ⚠️ THIS DOES PARSE WHERE IT USED TO THROW, which is the cost of the
    // symmetry and is stated rather than hidden.
    final decoded = _decodeActive(activeRaw);
    if (decoded == null) {
      await resolveActiveMarker(prefs,
          decodedOk: false, onReport: reportCaptureChannelError);
      return;
    }
    final start = decoded.startedAt;
    if (DateTime.now().difference(start).inMinutes >= _timeoutMins) {
      // Clears the MARKER only, and deliberately leaves the record alone. The
      // record is created at start with a NULL duration, so an abandoned event
      // is already honest — there is nothing here to correct.
      //
      // An `abandon` instruction was built here and REMOVED: it solved a problem
      // that belongs at creation, it only ever reached Android because the iOS
      // timeout is native, and it could null a duration the user had since
      // filled in by hand.
      //
      // ⭐ THROUGH THE POLICY, not a bare remove. The marker decoded, so this is
      // the readable branch and behaves exactly as before — but routing it here
      // means `prefs.remove(_activeEventKey)` exists in ONE place in this file,
      // which is what makes the source scan a complete check rather than a
      // sample.
      await resolveActiveMarker(prefs, decodedOk: true);
    }
  }

  Future<void> _restoreNotification() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final activeRaw = prefs.getString(_activeEventKey);
    if (activeRaw != null) {
      final active = jsonDecode(activeRaw) as Map<String, dynamic>;
      final start  = DateTime.parse(active['startIso'] as String);
      await _showActive(start);
    } else {
      await _showNormal();
    }
  }

  // ── KNOWN LIMITATION, AND WHY THERE IS NO FOREGROUND SERVICE ──────────────
  //
  // BOTH persistent notifications are dismissible, and cannot be made otherwise.
  // Since Android 14 (API 34) FLAG_ONGOING_EVENT is advisory: only a running
  // foreground service or a call-style notification resists user dismissal.
  // `locked: true` is set on the standing state and DOES reach the notification
  // (verified on device: flags=SHOW_LIGHTS|ONGOING_EVENT) — the system simply
  // declines to act on it. It still pins on API <= 33, and minSdk is 24.
  //
  // CONSEQUENCE, recorded rather than described as solved: a user who dismisses
  // the ACTIVE-EVENT notification cannot end that event from the lock screen
  // until they unlock and open the app. Restoration on resume (below) shortens
  // that window; it does not remove it. iOS has the matching limitation while
  // the device is locked.
  //
  // A FOREGROUND SERVICE WOULD FIX THE ANDROID HALF. It was considered and
  // REJECTED. Do not reach for it again without re-reading these three:
  //
  //   1. ONE ANSWER BEATS TWO. iOS has the identical defect and no foreground
  //      service exists there, so this buys a fix for half the problem with
  //      machinery that cannot be reused.
  //   2. THE COST RECURS. A permission, a manifest declaration, a Play Console
  //      justification defended at every review, a service lifecycle on the
  //      capture path, and a system notice telling users the app runs in the
  //      background — against an app whose pitch is that it does nothing behind
  //      your back.
  //   3. IT DOES NOT CLOSE THE HOLE. `shortService` caps at three minutes,
  //      wrong for a long event. `health` covers it but asserts a clinical
  //      purpose this app deliberately does not claim — the same overreach
  //      corrected across the store copy and the website.
  //
  // Mechanically, this plugin could not express it honestly in any case: its
  // ForegroundServiceType enum has no specialUse, health or shortService, and
  // its own manifest hardcodes android:foregroundServiceType="phoneCall".
  //
  // ── Notification builders ─────────────────────────────────────────────────

  /// Whether the standing notification should be posted. Absent means YES.
  ///
  /// Read fresh every time rather than cached: this also runs in the
  /// background isolate, which does not share the main isolate's memory, and a
  /// cached flag there would be whatever it was when the isolate spawned.
  static Future<bool> standingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getBool(kStandingNotificationKey) ?? true;
  }

  /// Turns the standing notification on or off and applies it immediately.
  ///
  /// ⚠️ **Turning it OFF while an event is running cancels nothing.**
  /// `_showActive` and `_showNormal` share `_persistentId`, so cancelling here
  /// would take down the ACTIVE notification and with it the only way to end
  /// an event from the lock screen. The standing one simply does not come back
  /// when that event finishes, because `_showNormal` checks the flag.
  Future<void> setStandingEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kStandingNotificationKey, enabled);
    if (Platform.isWindows || Platform.isIOS) return;

    if (enabled) {
      await restoreNotification();
      return;
    }
    await prefs.reload();
    final active = prefs.getString(_activeEventKey) != null;
    if (!active) await AwesomeNotifications().cancel(_persistentId);
  }

  Future<void> _showNormal() async {
    if (Platform.isIOS) return; // Swift owns iOS persistent notification
    // ⛔ THE ONLY ENFORCEMENT POINT, deliberately. Both callers reach the
    // standing notification through here — the restore on launch and the
    // re-post three seconds after an event ends — and putting the check at
    // either call site would leave the other one posting it. A third caller
    // added later inherits the behaviour instead of having to remember it.
    if (!await standingEnabled()) {
      await AwesomeNotifications().cancel(_persistentId);
      return;
    }
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id:                 _persistentId,
        channelKey:         _chanActive,
        title:              'Medical Event Recorder',
        body:               'Tap "Log Event Now" to start logging an event',
        notificationLayout: NotificationLayout.BigText,
        category:           NotificationCategory.Service,
        largeIcon:          'resource://drawable/ic_notification_large',
        autoDismissible:    false,
        // Ongoing (Android setOngoing). A DELIBERATE reduction in user control,
        // not inherited from the category: this notification IS the capture path
        // when an event starts, and burying it under a busy shade costs the
        // one-tap-from-the-lock-screen property it exists for.
        //
        // Control is relocated, not removed: the MER Active channel and the app
        // can both still be blocked in system settings.
        //
        // Android 14+ lets users dismiss ongoing notifications anyway, so this
        // only pins on API <= 33. Above that it buys section placement, not
        // permanence.
        //
        // Applied to the STANDING state ONLY. Note _showActive posts the SAME id
        // on the SAME channel, so an active event REPLACES this content and the
        // ongoing flag goes with it — the active-event notification stays
        // dismissible as a consequence of that replacement, not because it
        // carries its own flag.
        locked:             true,
      ),
      actionButtons: [
        NotificationActionButton(
          key:             _btnStart,
          label:           'Log Event Now',
          actionType:      ActionType.SilentAction,
          autoDismissible: false,
        ),
      ],
    );
  }

  Future<void> _showActive(DateTime start) async {
    if (Platform.isIOS) return; // Swift owns iOS persistent notification
    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id:                 _persistentId,
        channelKey:         _chanActive,
        title:              'Event in progress · ${_fmtTime(start)}',
        body:               'Tap "Event Ended" when the event stops',
        notificationLayout: NotificationLayout.BigText,
        category:           NotificationCategory.Service,
        largeIcon:          'resource://drawable/ic_notification_large',
        autoDismissible:    false,
      ),
      actionButtons: [
        NotificationActionButton(
          key:             _btnEnd,
          label:           'Event Ended',
          actionType:      ActionType.SilentAction,
          autoDismissible: false,
        ),
      ],
    );
  }

  Future<void> _showFeedback({
    required String title,
    required String body,
    Duration? timeout = const Duration(seconds: 4),
    Map<String, String>? payload,
  }) =>
      AwesomeNotifications().createNotification(
        content: NotificationContent(
          id:                 _feedbackId,
          channelKey:         _chanFeedback,
          title:              title,
          body:               body,
          notificationLayout: NotificationLayout.BigText,
          largeIcon:          'resource://drawable/ic_notification_large',
          color:              MERColours.primary,
          autoDismissible:    true,
          timeoutAfter:       Platform.isAndroid ? timeout : null,
          payload:            payload,
        ),
      );
}
