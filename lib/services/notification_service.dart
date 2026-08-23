import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show Color;
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// constants.dart is gone too: kEventStorageKey was the only thing this file
// took from it, and nothing here names the record store any more.
//
// Deliberately NOT models/event_record.dart. Under the inbox this file posts
// facts and never touches a record: no EventRecord, no toMap, no decode of the
// stored list. capture_instruction.dart imports no model either, so the
// background isolate's surface is the schema and nothing more. Four of the
// seven historical notification failures lived in that isolate.
import '../models/capture_instruction.dart';

// ── IDs & storage keys ────────────────────────────────────────────────────────

const _persistentId   = 1;
const _feedbackId     = 2;

const _btnStart       = 'QUICK_LOG_START';
const _btnEnd         = 'QUICK_LOG_END';

const _chanActive     = 'mer_active_v2';
const _chanFeedback   = 'mer_feedback';

const _activeEventKey = 'mer_active_event';

const _timeoutMins    = 30;

// ── Formatting helpers ────────────────────────────────────────────────────────

String _fmtTime(DateTime t) => DateFormat('h:mm a').format(t);

String _fmtElapsed(DateTime start, DateTime end) {
  final secs = end.difference(start).inSeconds.clamp(0, 9999);
  final m    = secs ~/ 60;
  final s    = secs  % 60;
  if (m == 0) return '${s}s';
  if (s == 0) return '${m}m';
  return '${m}m ${s}s';
}

/// The live in-progress marker, parsed.
class _ActiveEvent {
  final String id;
  final DateTime startedAt;
  const _ActiveEvent(this.id, this.startedAt);
}

// `_durationFromDiff` lived here and computed a stored bucket in the background
// isolate. It moved to `bucketFromSeconds` in models/capture_inbox.dart: the
// writer now posts SECONDS and the drain decides the bucket, so the mapping
// belongs with the one writer of the store. Nothing here computes a bucket, and
// nothing here needs the record model.

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
            defaultColor:       const Color(0xFF0D4F82),
          ),
          NotificationChannel(
            channelKey:         _chanFeedback,
            channelName:        'MER Quick Log',
            channelDescription: 'Confirmation shown after a quick log action',
            importance:         NotificationImportance.High,
            defaultPrivacy:     NotificationPrivacy.Public,
            defaultColor:       const Color(0xFF0D4F82),
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
      await prefs.setBool('mer_open_latest_event', true);
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
          defaultColor:       const Color(0xFF0D4F82),
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
      // with the one writer of the store; the drain applies bucketFromSeconds.
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
        payload: {'action': 'openLatest'},
      );
    }

    await prefs.remove(_activeEventKey);
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
    final active = jsonDecode(activeRaw) as Map<String, dynamic>;
    final start  = DateTime.parse(active['startIso'] as String);
    if (DateTime.now().difference(start).inMinutes >= _timeoutMins) {
      await prefs.remove(_activeEventKey);
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

  // ── Notification builders ─────────────────────────────────────────────────

  Future<void> _showNormal() async {
    if (Platform.isIOS) return; // Swift owns iOS persistent notification
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
          color:              const Color(0xFF0D4F82),
          autoDismissible:    true,
          timeoutAfter:       Platform.isAndroid ? timeout : null,
          payload:            payload,
        ),
      );
}
