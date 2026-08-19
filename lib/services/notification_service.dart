import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' show Color;
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../constants.dart';
import '../models/event_record.dart';

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

DurationCategory _durationFromDiff(DateTime start, DateTime end) {
  final secs = end.difference(start).inSeconds;
  if (secs < 60)  return DurationCategory.lt1;
  if (secs < 300) return DurationCategory.oneToFive;
  return DurationCategory.gt5;
}

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

  Future<void> _handleStart() async {
    final prefs = await SharedPreferences.getInstance();
    final now   = DateTime.now();

    final record = EventRecord(
      id:               const Uuid().v4(),
      timestamp:        now,
      duration:         DurationCategory.lt1,
      feelings:         const [],
      triggers:         const [],
      referralRequired: false,
      notes:            '',
      eventType:        EventType.seizure,
      severity:         EventSeverity.mild,
    );

    final raw  = prefs.getString(kEventStorageKey);
    final list = raw == null || raw.isEmpty
        ? <dynamic>[]
        : jsonDecode(raw) as List<dynamic>;
    list.insert(0, record.toMap());
    await prefs.setString(kEventStorageKey, jsonEncode(list));

    await prefs.setString(_activeEventKey, jsonEncode({
      'id':       record.id,
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

    if (activeRaw != null) {
      final active    = jsonDecode(activeRaw) as Map<String, dynamic>;
      final eventId   = active['id']       as String;
      final startTime = DateTime.parse(active['startIso'] as String);
      final endTime   = DateTime.now();

      final raw  = prefs.getString(kEventStorageKey);
      final list = raw == null || raw.isEmpty
          ? <dynamic>[]
          : jsonDecode(raw) as List<dynamic>;

      final idx = list.indexWhere(
          (e) => (e as Map<String, dynamic>)['id'] == eventId);
      if (idx != -1) {
        final existing =
            EventRecord.fromMap(list[idx] as Map<String, dynamic>);
        // A record we cannot parse is left untouched rather than rebuilt —
        // skipping the duration update is preferable to discarding it.
        if (existing != null) {
          list[idx] = EventRecord(
            id:               existing.id,
            timestamp:        existing.timestamp,
            duration:         _durationFromDiff(startTime, endTime),
            feelings:         existing.feelings,
            triggers:         existing.triggers,
            referralRequired: existing.referralRequired,
            notes:            existing.notes,
            eventType:        existing.eventType,
            severity:         existing.severity,
          ).toMap();
        }
      }
      await prefs.setString(kEventStorageKey, jsonEncode(list));

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

  Future<void> endEvent() async {
    try {
      await _handleEnd();
    } catch (_) {}
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
