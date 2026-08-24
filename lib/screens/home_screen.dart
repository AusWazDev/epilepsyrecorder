import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';

import 'package:sentry_flutter/sentry_flutter.dart';

import '../constants.dart';
import '../services/backup_service.dart';
import '../services/ios_capture_bridge.dart';
import '../services/notification_service.dart';
import '../models/capture_inbox.dart';
import '../models/event_record.dart';
import '../screens/about_screen.dart';
import '../screens/disclaimer_screen.dart';
import '../screens/help_screen.dart';
import '../screens/history_screen.dart';
import '../screens/log_event_screen.dart';
import '../screens/your_data_screen.dart';
import '../theme/mer_theme.dart';
import '../widgets/mer_icon_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// Four items, not six.
///
/// Export CSV, Back up now and Restore from backup moved behind Your data. They
/// were three of six flat items with no grouping or icons, mixed in with
/// navigation, and nothing distinguished Export from Back up — so someone
/// wanting to preserve their history could pick the one file that cannot
/// restore it.
enum _HomeMenuAction {
  history,
  yourData,
  about,
  help,
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const _navChannel = MethodChannel('au.com.notiva.mer/navigation');

  final _store = EventStore();
  final _uuid  = const Uuid();

  List<EventRecord> _records = [];
  Map<String, dynamic>? _activeEvent;
  bool _loaded = false;
  bool _buttonFlash = false;
  bool _notificationsAllowed = true;
  bool _showPreviewsAlways   = true;

  /// Decorative flash on the record button. A Timer, not an awaited delay, so
  /// it cannot sit in the path between a tap and the record being written.
  Timer? _flashTimer;

  // ── UNSAVED-WRITE WARNING STATE ──
  // Set when a write failed and the list on screen is ahead of storage. Loaded
  // at startup as well as set at runtime, because the condition outlives the
  // session that caused it.
  bool _hasUnsavedEvents = false;
  bool _retryingPersist  = false;

  // ── BACKUP REMINDER STATE ──
  // The capture path is load-bearing: the banner must never gate, delay or
  // obstruct logging an event. Each of these suppresses it outright.
  bool _openedFromNotification = false; // cold-started by a notification action

  /// Guards the "open the latest event" funnel against a double push.
  ///
  /// Two independent signals now arrive for the SAME notification tap, by
  /// design: the durable `mer_open_latest_event` flag and the transient
  /// `openLatestEvent` channel call. Making the native side send both is what
  /// removes its dependence on the Flutter engine being ready at `didReceive`
  /// time — see the comment in AppDelegate's default-action branch. This is what
  /// stops both of them landing and opening the edit screen twice.
  ///
  /// Held across the push, so it stays true for as long as the edit screen is
  /// open and clears when the user closes it. A genuinely new tap later is still
  /// honoured.
  bool _openingLatest = false;
  bool _loggedThisSession      = false; // an event was logged in this session
  bool _backupBannerDismissed  = false; // user dismissed it
  int  _eventsSinceBackup      = 0;

  /// An event in progress suppresses the banner too, but needs no flag: the
  /// active-event branch of the banner chain already takes precedence.
  ///
  /// The backup reminder is advisory; the unsaved-write warning is about data at
  /// risk right now. When both would apply the reminder yields, so the two never
  /// compete for the same space.
  bool get _showBackupReminder =>
      _loaded &&
      !_hasUnsavedEvents &&
      !_openedFromNotification &&
      !_loggedThisSession &&
      !_backupBannerDismissed &&
      _eventsSinceBackup >= kBackupReminderThreshold;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!Platform.isWindows) _checkNotificationStatus();
    _navChannel.setMethodCallHandler(_handleNativeCall);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadRecords(initial: true);
      // Cold-start: iOS uses native channel flag; Android uses SharedPreferences flag
      if (await _drainPendingOpenLatest()) return;
      if (Platform.isAndroid) {
        final prefs = await SharedPreferences.getInstance();
        for (int i = 0; i < 8; i++) {
          await prefs.reload();
          if (prefs.getBool('mer_open_latest_event') ?? false) {
            await prefs.remove('mer_open_latest_event');
            _openedFromNotification = true;
            if (mounted && _records.isNotEmpty) _openLogScreen(existing: _records.first);
            break;
          }
          await Future.delayed(const Duration(milliseconds: 250));
        }
      }
    });
  }

  /// Opens the newest record's edit screen, at most once at a time.
  ///
  /// [reload] is false when the caller has just loaded the list — which both
  /// drain sites have. Reloading again would put a second reconciliation and
  /// inbox drain on the cold-start path, where four of the seven historical
  /// notification failures lived.
  Future<void> _openLatestEvent({required bool reload}) async {
    if (_openingLatest) return;
    _openingLatest = true;
    try {
      if (reload) await _loadRecords();
      if (!mounted || _records.isEmpty) return;
      _openedFromNotification = true;
      await _openLogScreen(existing: _records.first);
    } finally {
      _openingLatest = false;
    }
  }

  /// Reads and CLEARS the native pending-open flag, then acts on it.
  ///
  /// The read happens even when the funnel is busy, deliberately: the native
  /// `getPendingOpenLatest` consumes the flag as it reads it, so draining here is
  /// what stops a flag set alongside a channel call firing spuriously on some
  /// later foreground. Returns whether it opened anything.
  Future<bool> _drainPendingOpenLatest() async {
    bool pending = false;
    try {
      pending = await _navChannel.invokeMethod<bool>('getPendingOpenLatest') ?? false;
    } catch (_) {}
    if (!pending) return false;
    await _openLatestEvent(reload: false);
    return true;
  }

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'openLatestEvent') {
      if (!mounted) return;
      await _openLatestEvent(reload: true);
    }
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _handleResume();
  }

  Future<void> _handleResume() async {
    await _loadRecords();
    NotificationService.instance.restoreNotification();
    if (!Platform.isWindows) _checkNotificationStatus();
    if (Platform.isIOS) {
      // iOS had NO resume-time consumer for the pending-open flag: the only read
      // was the cold-start one in initState, which does not run again on a warm
      // resume. That is why tapping the feedback notification landed on the
      // dashboard whenever the app was already alive — which on 16.2-16.x is
      // always, because the app serviced the END action itself.
      //
      // One read, not a retry loop. The Android loop below exists for a
      // different reason and is left alone.
      await _drainPendingOpenLatest();
    }
    if (Platform.isAndroid) {
      // Poll for the flag set by onActionReceived — it may arrive slightly
      // after resume since the background isolate skips channel init now.
      final prefs = await SharedPreferences.getInstance();
      for (int i = 0; i < 8; i++) {
        await prefs.reload();
        if (prefs.getBool('mer_open_latest_event') ?? false) {
          await prefs.remove('mer_open_latest_event');
          if (mounted && _records.isNotEmpty) _openLogScreen(existing: _records.first);
          return;
        }
        await Future.delayed(const Duration(milliseconds: 250));
      }
    }
  }

  Future<void> _checkNotificationStatus() async {
    final allowed = await AwesomeNotifications().isNotificationAllowed();
    bool previewsAlways = true;
    if (Platform.isIOS) {
      try {
        final s = await _navChannel.invokeMethod<String>('getShowPreviewsSetting');
        previewsAlways = s == 'always';
      } catch (_) {}
    }
    if (mounted) setState(() {
      _notificationsAllowed = allowed;
      _showPreviewsAlways   = previewsAlways;
    });
  }

  Future<void> _openNotificationSettings() async {
    await AwesomeNotifications().showNotificationConfigPage();
    if (!Platform.isWindows) _checkNotificationStatus();
  }

  void _openHelp() => Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => const HelpScreen()),
  );

  /// Reports inbox anomalies. Version and kind deferrals are reported once per
  /// session — an instruction this build cannot apply stays in the inbox and
  /// would otherwise be reported on every single foreground.
  static bool _inboxDeferralReported = false;

  /// Drains the capture inbox, then loads.
  ///
  /// ## Why the drain lives here
  ///
  /// This is the one place that already reloads prefs and replaces the record
  /// list wholesale, and it is off the capture path: the record button calls
  /// `_quickRecord`, which is untouched. The drain must never sit between a tap
  /// and a record being written.
  ///
  /// ## Order matters
  ///
  /// Apply, write, verify, and only then delete the keys. A foreground that
  /// cleared first and failed second would lose the captures outright.
  ///
  /// `_loaded` is not set true until the drain has run, so the list is never
  /// rendered while an unapplied capture sits in the inbox. If the write FAILS
  /// the merged list is still shown — the user sees their captures — the keys
  /// survive for the next attempt, and `persistEvents` raises the unsaved-events
  /// banner, which is exactly its existing meaning: the list on screen is ahead
  /// of storage. Re-draining is safe because every instruction is idempotent.
  Future<void> _loadRecords({bool initial = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    var base = await _store.load();

    // ── ONE-TIME iOS RECONCILIATION ──
    // Folds the pre-inbox App Group record mirror into the store, then retires
    // it. Runs before the drain so an `end` instruction can attach to a record
    // recovered from the mirror in the same foreground. iOS only: no other
    // platform ever had a second mirror.
    if (Platform.isIOS) {
      final fold = await reconcileLegacySharedRecords(
        channel: _navChannel,
        prefs:   prefs,
        store:   _store,
        loaded:  base,
        onError: reportCaptureChannelError,
      );
      base = fold.records;
      if (fold.addedIds.isNotEmpty || fold.durationsRecovered.isNotEmpty) {
        await Sentry.captureMessage(
          'iOS handoff: legacy shared records folded in',
          level: SentryLevel.info,
          withScope: (scope) => scope.setContexts('handoff', {
            'added':              fold.addedIds.length,
            'durationsRecovered': fold.durationsRecovered.length,
            'wrote':              fold.wrote,
          }),
        );
      }
    }

    final drain = await drainInbox(
      transport: _inboxTransport(prefs),
      store:     _store,
      loaded:    base,
    );
    final loaded = drain.records;

    for (final id in drain.orphanEndIds) {
      // An end with no record to attach to. Dropped, never fabricated: a
      // record invented here would need a start time, and a wrong timestamp in
      // a medical record is worse than an absent duration.
      await Sentry.captureMessage(
        'Capture inbox: end instruction with no matching record',
        level: SentryLevel.warning,
        withScope: (scope) => scope.setContexts('inbox', {'eventId': id}),
      );
    }

    // Once per session: a deferred entry stays in the inbox by design, so
    // reporting per drain would report it on every foreground forever.
    if (drain.deferReasons.isNotEmpty && !_inboxDeferralReported) {
      _inboxDeferralReported = true;
      await Sentry.captureMessage(
        'Capture inbox: entries left in place, not applied',
        level: SentryLevel.warning,
        withScope: (scope) => scope.setContexts('inbox', {
          'reasons': drain.deferReasons.map((r) => r.name).toList(),
          'count':   drain.deferredCount,
        }),
      );
    }

    final activeRaw = prefs.getString('mer_active_event');
    Map<String, dynamic>? active;
    if (activeRaw != null) {
      try { active = jsonDecode(activeRaw) as Map<String, dynamic>; } catch (_) {}
    }
    // A warning raised in an earlier session must come back with the app.
    final unsaved = await hasUnsavedEvents();
    if (!mounted) return;
    setState(() {
      _records          = loaded;
      _activeEvent      = active;
      _hasUnsavedEvents = unsaved;
      if (initial) _loaded = true;
    });
    await _refreshBackupCount();
  }

  /// The inbox transport for this platform.
  ///
  /// iOS goes over the navigation channel because Dart cannot read the App
  /// Group, and the App Group is where the inbox must live for a widget
  /// extension in another process to write it. Everything else reads the same
  /// store the drain writes.
  ///
  /// The channel transport never throws: a missing, erroring or hung channel
  /// degrades to "no entries this time", which costs one foreground and loses
  /// nothing, because deletion is gated on a confirmed write. Letting it throw
  /// would take the first render of the list with it — and this sits on the
  /// cold-start path, where four of the seven historical notification failures
  /// lived.
  CaptureInboxTransport _inboxTransport(SharedPreferences prefs) =>
      Platform.isIOS
          ? IosChannelInboxTransport(_navChannel,
              onError: reportCaptureChannelError)
          : PrefsInboxTransport(prefs);

  Future<void> _endActiveEvent() async {
    if (Platform.isIOS) return; // iOS: Live Activity owns event end
    await NotificationService.instance.endEvent();
    await _loadRecords();
  }

  /// Writes the event list, surfacing a failure instead of losing it.
  ///
  /// Never throws: [persistEvents] reports to Sentry and returns false, and the
  /// warning banner is the user-visible half. Every call site is a user action
  /// that has already been confirmed on screen.
  Future<void> _persist() async {
    final ok = await persistEvents(_store, _records);
    if (!mounted) return;
    setState(() => _hasUnsavedEvents = !ok);
    await _refreshBackupCount();
  }

  /// Re-attempts the write behind the warning banner.
  Future<void> _retryPersist() async {
    setState(() => _retryingPersist = true);
    final ok = await persistEvents(_store, _records);
    if (!mounted) return;
    setState(() {
      _retryingPersist = false;
      _hasUnsavedEvents = !ok;
    });
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Events saved')),
      );
    }
    await _refreshBackupCount();
  }

  Future<void> _refreshBackupCount() async {
    final count = await eventsSinceLastBackup(_records);
    if (!mounted) return;
    setState(() => _eventsSinceBackup = count);
  }

  // ── STATS ──
  int get _thisMonthCount {
    final now   = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    return _records.where((r) => r.timestamp.isAfter(start)).length;
  }

  int get _daysSinceLastEvent {
    if (_records.isEmpty) return 0;
    return DateTime.now().difference(_records.first.timestamp).inDays;
  }

  int get _referralCount =>
      _records.where((r) => r.referralRequired).length;

  // ── QUICK RECORD ──
  /// Records an event. Synchronous by design.
  ///
  /// Everything that matters — the timestamp, the insert, and handing the
  /// payload to the store — happens before this returns, with no `await` in
  /// between, so there is no window in which a second tap can interleave with
  /// the first. That is what makes the handler non-re-entrant: not a guard that
  /// drops the second tap, but an ordering in which two taps deterministically
  /// produce two records.
  ///
  /// A debounce was considered and rejected. Taps 150 ms apart are how this
  /// button is actually used — the device test produced a run of them — so
  /// suppressing the second would silently discard a real event on the capture
  /// path. Losing a seizure to a debounce is worse than the race it would hide.
  ///
  /// Order: timestamp, insert, write started, confirmation, flash. The 200 ms
  /// flash used to sit before the timestamp and be awaited, which both delayed
  /// the recorded time by 200 ms and created the re-entrancy window. It is now
  /// decorative and gates nothing.
  void _quickRecord() {
    HapticFeedback.heavyImpact();

    final rec = EventRecord(
      id:               _uuid.v4(),
      timestamp:        DateTime.now(),
      duration:         DurationCategory.lt1,
      feelings:         const [],
      triggers:         const [],
      referralRequired: false,
      notes:            '',
    );

    setState(() {
      _records.insert(0, rec);
      _loggedThisSession = true;
      _buttonFlash       = true;
    });

    // Started, deliberately NOT awaited: the confirmation must not wait on
    // storage. A failure raises the warning banner instead of being silent.
    unawaited(_persist());

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Event recorded')),
    );

    // Decorative only. Restarted on each tap so a run of taps keeps flashing.
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _buttonFlash = false);
    });
  }

  // ── RECORD WITH DETAILS ──
  Future<void> _recordWithDetails() async {
    await _openLogScreen(existing: null);
  }

  // ── OPEN LOG SCREEN ──
  Future<void> _openLogScreen({
    EventRecord? existing,
    bool confirmOnSave = false,
  }) async {
    final result = await Navigator.of(context).push<EventRecord>(
      MaterialPageRoute(
        builder: (_) => LogEventScreen(
          existing:      existing,
          confirmOnSave: confirmOnSave,
        ),
      ),
    );

    if (result == null) return;

    setState(() {
      _loggedThisSession = true;
      if (existing == null) {
        _records.insert(0, result);
      } else {
        final index = _records.indexWhere((r) => r.id == result.id);
        if (index != -1) _records[index] = result;
      }
      _records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });

    await _persist();
    // Reschedule the persistent notification — app stays in foreground so
    // applicationDidBecomeActive won't fire to do this automatically.
    try { await _navChannel.invokeMethod<void>('restoreNotification'); } catch (_) {}
  }

  // ── YOUR DATA ──
  /// The three data actions stay here rather than moving into the screen: this
  /// State owns _records and _persist, and a restore has to write through them.
  /// YourDataScreen passes its own context back so sheets and dialogs anchor to
  /// the screen the user is looking at.
  void _openYourData() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => YourDataScreen(
          onExport: (ctx) => showExportOptions(
            ctx,
            _records,
            filenamePrefix: 'medical_event_recorder_all',
            sheetTitle: 'Export all events',
          ),
          onBackUp: (ctx) async {
            await showBackupOptions(ctx, _records);
            await _refreshBackupCount();
          },
          onRestore: (ctx) async {
            final merged = await restoreFromBackup(ctx, _records);
            // Null means "no list to write", and restoreFromBackup has already
            // said whatever needed saying: a _refuse dialog for a real failure,
            // a snackbar for a dismissed confirm, and deliberate silence for an
            // explicit cancellation. This return is only silent because the
            // messaging belongs to the function that knows WHICH outcome it was.
            if (merged == null) return;
            final added = merged.length - _records.length;
            setState(() => _records = merged);
            await _persist();
            if (!ctx.mounted) return;
            ScaffoldMessenger.of(ctx).showSnackBar(
              SnackBar(
                content: Text('Restored $added '
                    '${added == 1 ? "event" : "events"}'),
              ),
            );
          },
        ),
      ),
    );
  }

  // ── HISTORY ──
  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HistoryScreen(
          records:          _records,
          onRecordsChanged: (updated) async {
            setState(() => _records = updated);
            await _persist();
          },
          onEdit: (existing, {required confirmOnSave}) =>
              _openLogScreen(
                existing:      existing,
                confirmOnSave: confirmOnSave,
              ),
        ),
      ),
    );
  }

  // ── RESET ──
  Future<void> _confirmResetDisclaimer() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset app?'),
        content: const Text(
          'This will clear all events and show the disclaimer again.\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (ok != true) return;
    await _store.clearAll();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const _SplashRedirect()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // No wrapper on the icon: the artwork is already a rounded blue
        // badge, and a tile inside a tile was costing ~40% of the footprint.
        title: const Row(
          children: [
            MERIconWidget(size: 40, style: MERIconStyle.mark),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize:       MainAxisSize.min,
              children: [
                Text(
                  kAppName,
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w600,
                    color:      Colors.white,
                  ),
                ),
                Text(
                  'Record · Review · Share',
                  style: TextStyle(
                    fontSize: 10,
                    color:    Colors.white54,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<_HomeMenuAction>(
            onSelected: (action) async {
              switch (action) {
                case _HomeMenuAction.history:
                  _openHistory();
                  break;
                case _HomeMenuAction.yourData:
                  _openYourData();
                  break;
                case _HomeMenuAction.about:
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AboutScreen(
                        onReset: _confirmResetDisclaimer,
                      ),
                    ),
                  );
                  break;
                case _HomeMenuAction.help:
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const HelpScreen(),
                    ),
                  );
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _HomeMenuAction.history,
                child: Text('History'),
              ),
              PopupMenuItem(
                value: _HomeMenuAction.yourData,
                child: Text('Your data'),
              ),
              PopupMenuItem(
                value: _HomeMenuAction.about,
                child: Text('About'),
              ),
              PopupMenuItem(
                value: _HomeMenuAction.help,
                child: Text('Help'),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 40,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // ── UNSAVED-WRITE WARNING ──
                        // Rendered ABOVE the banner chain below, not as another
                        // branch of it. The chain is exclusive, so putting this
                        // in it would hide whichever banner it displaced —
                        // including the active-event banner, whose End button is
                        // the only way to end an event on Android. Data at risk
                        // and an event in progress are both worth showing, so
                        // this stacks. The advisory backup reminder yields to it
                        // instead, via _showBackupReminder.
                        if (_hasUnsavedEvents) ...[
                          _UnsavedEventsBanner(
                            onRetry: _retryPersist,
                            retrying: _retryingPersist,
                          ),
                          const SizedBox(height: 12),
                        ],

                        // ── SETTINGS NUDGE / ACTIVE EVENT BANNER ──
                        if (!_notificationsAllowed && !Platform.isWindows) ...[
                          _SettingsNudgeCard(
                            icon:      Icons.notifications_off_outlined,
                            iconColor: const Color(0xFFF57C00),
                            title:    'Notifications are off',
                            body:     'Quick log won\'t work until notifications are enabled.',
                            bgColor:  const Color(0xFFFFF3E0),
                            bdColor:  const Color(0xFFFFB74D),
                            onOpenSettings: _openNotificationSettings,
                            onHelp:         _openHelp,
                          ),
                          const SizedBox(height: 12),
                        ] else if (!_showPreviewsAlways && Platform.isIOS) ...[
                          _SettingsNudgeCard(
                            icon:      Icons.lock_outlined,
                            iconColor: const Color(0xFF1976D2),
                            title:    'Starting events from the lock screen requires a password',
                            body:     'Set Show Previews to Always for instant lock screen logging — no authentication needed to start.',
                            bgColor:  const Color(0xFFE3F2FD),
                            bdColor:  const Color(0xFF90CAF9),
                            onOpenSettings: _openNotificationSettings,
                            onHelp:         _openHelp,
                          ),
                          const SizedBox(height: 12),
                        ] else if (_activeEvent != null) ...[
                          _ActiveEventBanner(
                            // .toLocal() for the same reason EventRecord
                            // normalises: AppDelegate.swift writes startIso
                            // with ISO8601DateFormatter, so on iOS this is UTC
                            // and DateFormat rendered its UTC wall clock —
                            // "Started 10:38 AM · 5s ago" at 8:38 PM, a banner
                            // contradicting itself because the elapsed counter
                            // is instant-based and correct while the start time
                            // was not. This value does not pass through
                            // EventRecord.fromMap, so it needs its own
                            // conversion. No-op on Android, which writes naive
                            // local.
                            startTime: DateTime.parse(
                                    _activeEvent!['startIso'] as String)
                                .toLocal(),
                            onEnd:         _endActiveEvent,
                            showEndButton: !Platform.isIOS,
                          ),
                          const SizedBox(height: 12),
                        ] else if (_showBackupReminder) ...[
                          _BackupReminderBanner(
                            count: _eventsSinceBackup,
                            onBackUp: () async {
                              await showBackupOptions(context, _records);
                              await _refreshBackupCount();
                            },
                            onDismiss: () =>
                                setState(() => _backupBannerDismissed = true),
                          ),
                          const SizedBox(height: 12),
                        ],

                        // ── RECORD EVENT BUTTON ──
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _quickRecord,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _buttonFlash
                                  ? Colors.white
                                  : MERColours.alert,
                              foregroundColor: Colors.white,
                              elevation:       0,
                              padding: const EdgeInsets.symmetric(
                                vertical: 36,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'Record Event',
                                  style: TextStyle(
                                    fontSize:   26,
                                    fontWeight: FontWeight.w700,
                                    color:      Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Tap to timestamp now',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.65),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // ── RECORD WITH DETAILS ──
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _recordWithDetails,
                            icon: const Icon(Icons.tune, size: 18),
                            label: const Text('Record with details'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: MERColours.primary,
                              foregroundColor: Colors.white,
                              elevation:       0,
                              padding: const EdgeInsets.symmetric(
                                vertical: 20,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              textStyle: const TextStyle(
                                fontSize:   14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── STATS ROW ──
                        if (_loaded)
                          _StatsRow(
                            thisMonth:  _thisMonthCount,
                            totalSaved: _records.length,
                            daysFree:   _daysSinceLastEvent,
                            referrals:  _referralCount,
                          ),
                        const SizedBox(height: 12),

                        // ── LAST EVENT ──
                        if (_loaded && _records.isNotEmpty)
                          _LastEventCard(
                            record:    _records.first,
                            onEdit:    () => _openLogScreen(
                              existing:      _records.first,
                              confirmOnSave: true,
                            ),
                            onHistory: _openHistory,
                          ),

                        if (_loaded && _records.isEmpty)
                          _GettingStartedCard(
                            onHelpTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const HelpScreen(),
                              ),
                            ),
                          ),

                        if (_loaded && _records.isNotEmpty)
                          _HelpLinkCard(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const HelpScreen(),
                              ),
                            ),
                          ),

                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/* ===========================
   ACTIVE EVENT BANNER
   =========================== */

class _ActiveEventBanner extends StatefulWidget {
  final DateTime     startTime;
  final VoidCallback onEnd;
  final bool         showEndButton;

  const _ActiveEventBanner({
    required this.startTime,
    required this.onEnd,
    this.showEndButton = true,
  });

  @override
  State<_ActiveEventBanner> createState() => _ActiveEventBannerState();
}

class _ActiveEventBannerState extends State<_ActiveEventBanner> {
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed    = DateTime.now().difference(widget.startTime);
    final m          = elapsed.inMinutes;
    final s          = elapsed.inSeconds % 60;
    final elapsedStr = m > 0 ? '${m}m ${s}s' : '${s}s';
    final timeStr    = DateFormat('h:mm a').format(widget.startTime);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color:        const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEF9A9A)),
      ),
      child: Row(
        children: [
          Container(
            width:  10,
            height: 10,
            decoration: const BoxDecoration(
              color: Color(0xFFD32F2F),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Event in progress',
                  style: TextStyle(
                    fontSize:   14,
                    fontWeight: FontWeight.w700,
                    color:      Color(0xFFB71C1C),
                  ),
                ),
                Text(
                  'Started $timeStr · $elapsedStr ago',
                  style: const TextStyle(
                    fontSize: 12,
                    color:    Color(0xFFD32F2F),
                  ),
                ),
                // iOS gets no End button: showEndButton is !Platform.isIOS and
                // _endActiveEvent returns early there, because the Live Activity
                // owns ending an event. Without this line the banner shows a
                // running timer and no way to stop it — and if the notification
                // has been dismissed and the Live Activity is gone, the event
                // auto-clears after 30 minutes with duration left at its lt1
                // default, which is wrong data rather than missing data.
                // An End button here would route through native code: v1.2.0.
                if (Platform.isIOS)
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Text(
                      'End this event from the Lock Screen or the '
                      'notification.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height:   1.3,
                        color:    Color(0xFFD32F2F),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (widget.showEndButton) ...[
            const SizedBox(width: 8),
            FilledButton(
              onPressed: widget.onEnd,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: const TextStyle(
                  fontSize:   13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('End Event'),
            ),
          ],
        ],
      ),
    );
  }
}

/* ===========================
   SETTINGS NUDGE CARD
   =========================== */

/// Dismissible reminder that events have been logged since the last backup.
///
/// A banner, not a modal and not a notification: it must never sit between the
/// user and the record button, and a backup reminder must never compete with
/// the event notification channel. It renders below the settings nudges and
/// the active-event banner, and is suppressed entirely near the capture path.
/// Shown when the list on screen is ahead of what is in storage.
///
/// Deliberately has no dismiss control. The condition is not advice the user can
/// judge and set aside — it means events they can see are not stored — so the
/// only ways out are a write that succeeds or the app being reinstalled. The
/// banner clears itself the moment one succeeds.
///
/// Amber rather than red: the events are still on screen and still recoverable,
/// and the person reading this may have just logged a seizure. It needs to be
/// noticed and acted on, not to frighten.
class _UnsavedEventsBanner extends StatelessWidget {
  final Future<void> Function() onRetry;
  final bool retrying;

  const _UnsavedEventsBanner({
    required this.onRetry,
    required this.retrying,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF9800), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.save_outlined,
                  size: 20, color: Color(0xFFE65100)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Some events aren't saved yet",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE65100),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // The last sentence is only honest because the backup path
          // serialises the in-memory list, not stored prefs: buildBackupJson
          // takes the records it is handed, and ⋮ → Back up now passes
          // _records. So a backup taken while this banner is up DOES contain
          // the unsaved events. Verified by test; if the backup path is ever
          // changed to read from storage, this sentence must go.
          const Text(
            "They're in your list, but this device hasn't stored them. Tap "
            'Retry, and avoid closing the app until it succeeds. If it keeps '
            'failing, use Back up now to save a copy.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: Color(0xFFE65100),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: retrying ? null : onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE65100),
                foregroundColor: Colors.white,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(retrying ? 'Saving…' : 'Retry'),
            ),
          ),
        ],
      ),
    );
  }
}

class _BackupReminderBanner extends StatelessWidget {
  final int count;
  final Future<void> Function() onBackUp;
  final VoidCallback onDismiss;

  const _BackupReminderBanner({
    required this.count,
    required this.onBackUp,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF81C784), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.backup_outlined,
                  size: 20, color: Color(0xFF2E7D32)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$count ${count == 1 ? "event" : "events"} since your last '
                  'backup',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1B5E20),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: const Color(0xFF2E7D32),
                visualDensity: VisualDensity.compact,
                onPressed: onDismiss,
                tooltip: 'Dismiss',
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Your events are stored only on this device. A backup is the only '
            'way to get them onto another one.',
            style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: onBackUp,
              child: const Text('Back up now'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsNudgeCard extends StatelessWidget {
  final IconData     icon;
  final Color        iconColor;
  final String       title;
  final String       body;
  final Color        bgColor;
  final Color        bdColor;
  final VoidCallback onOpenSettings;
  final VoidCallback onHelp;

  const _SettingsNudgeCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    required this.bgColor,
    required this.bdColor,
    required this.onOpenSettings,
    required this.onHelp,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color:        bgColor,
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: bdColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w700,
                    color:      iconColor,
                  ),
                ),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 12,
                    color:    iconColor.withValues(alpha: 0.85),
                    height:   1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onOpenSettings,
                style: TextButton.styleFrom(
                  foregroundColor: iconColor,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(
                    fontSize:   12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Open Settings'),
              ),
              TextButton(
                onPressed: onHelp,
                style: TextButton.styleFrom(
                  foregroundColor: iconColor,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: const TextStyle(fontSize: 11),
                ),
                child: const Text('Help →'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/* ===========================
   STATS ROW
   =========================== */

class _StatsRow extends StatelessWidget {
  final int thisMonth;
  final int totalSaved;
  final int daysFree;
  final int referrals;

  const _StatsRow({
    required this.thisMonth,
    required this.totalSaved,
    required this.daysFree,
    required this.referrals,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        MERColours.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MERColours.border,
          width: 0.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(
        vertical:   12,
        horizontal: 14,
      ),
      child: Row(
        children: [
          _StatCell(
            value:      thisMonth.toString(),
            label:      'This month',
            valueColor: thisMonth > 0
                ? MERColours.alert
                : MERColours.primary,
          ),
          _StatDivider(),
          _StatCell(
            value: totalSaved.toString(),
            label: 'Total saved',
          ),
          _StatDivider(),
          _StatCell(
            value: daysFree.toString(),
            label: 'Days since',
          ),
          _StatDivider(),
          _StatCell(
            value: referrals.toString(),
            label: 'Referrals',
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String value;
  final String label;
  final Color? valueColor;

  const _StatCell({
    required this.value,
    required this.label,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize:   20,
              fontWeight: FontWeight.w600,
              color:      valueColor ?? MERColours.primary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 9,
              color:    MERColours.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width:  0.5,
      height: 36,
      color:  MERColours.border,
    );
  }
}

/* ===========================
   LAST EVENT CARD
   =========================== */

class _LastEventCard extends StatelessWidget {
  final EventRecord  record;
  final VoidCallback onEdit;
  final VoidCallback onHistory;

  const _LastEventCard({
    required this.record,
    required this.onEdit,
    required this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${_pad(record.timestamp.day)} '
        '${_month(record.timestamp.month)} '
        '${record.timestamp.year}  ·  '
        '${_pad(record.timestamp.hour)}:'
        '${_pad(record.timestamp.minute)}';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        MERColours.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MERColours.border,
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── HEADER ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LAST EVENT',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const Icon(
                Icons.access_time_rounded,
                size:  14,
                color: MERColours.textMuted,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // ── TIMESTAMP ──
          Text(
            timeStr,
            style: const TextStyle(
              fontSize:   13,
              fontWeight: FontWeight.w500,
              color:      MERColours.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Tap edit to update details',
            style: TextStyle(
              fontSize:  10,
              color:     MERColours.textMuted.withOpacity(0.7),
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 10),

          // ── BUTTONS ──
          Row(
            children: [

              // Edit details
              Expanded(
                child: GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color:        MERColours.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: MERColours.border,
                        width: 0.5,
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.edit_outlined,
                          size:  13,
                          color: MERColours.primary,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'Edit details',
                          style: TextStyle(
                            fontSize:   11,
                            fontWeight: FontWeight.w500,
                            color:      MERColours.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // All history
              Expanded(
                child: GestureDetector(
                  onTap: onHistory,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color:        MERColours.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.list_alt_outlined,
                          size:  13,
                          color: Colors.white,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'All history',
                          style: TextStyle(
                            fontSize:   11,
                            fontWeight: FontWeight.w500,
                            color:      Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _pad(int n)   => n.toString().padLeft(2, '0');
  String _month(int m) {
    const months = [
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return months[m - 1];
  }
}

/* ===========================
   GETTING STARTED CARD
   =========================== */

class _GettingStartedCard extends StatelessWidget {
  final VoidCallback onHelpTap;
  const _GettingStartedCard({required this.onHelpTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color:        MERColours.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MERColours.border, width: 0.5),
      ),
      clipBehavior: Clip.hardEdge,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          tilePadding:     const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            'GETTING STARTED',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          iconColor:         MERColours.textMuted,
          collapsedIconColor: MERColours.textMuted,
          children: [
            const Divider(height: 1, thickness: 0.5),
            const SizedBox(height: 14),
            _HowToRow(
              icon:  Icons.touch_app_outlined,
              title: 'Quick record',
              body:  'Tap the red Record Event button to instantly log an event with the current timestamp.',
            ),
            const SizedBox(height: 12),
            _HowToRow(
              icon:  Icons.tune,
              title: 'Record with details',
              body:  'Add notes, duration, triggers, and severity using the blue button.',
            ),
            const SizedBox(height: 12),
            _HowToRow(
              icon:  Icons.more_vert,
              title: 'History & export',
              body:  'Use the ⋮ menu in the top right to view your event history or export as CSV.',
            ),
            const SizedBox(height: 12),
            Divider(height: 1, thickness: 0.5, color: MERColours.border),
            InkWell(
              onTap:        onHelpTap,
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.help_outline, size: 16, color: MERColours.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'More Help',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: MERColours.textMuted,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, size: 16, color: MERColours.textMuted),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpLinkCard extends StatelessWidget {
  final VoidCallback onTap;
  const _HelpLinkCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(
        color:        MERColours.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MERColours.border, width: 0.5),
      ),
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.help_outline,
                  size: 18, color: MERColours.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Need Help with MER?',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: MERColours.textMuted,
                  ),
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 18, color: MERColours.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _HowToRow extends StatelessWidget {
  final IconData icon;
  final String   title;
  final String   body;

  const _HowToRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: MERColours.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color:      MERColours.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                body,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/* ===========================
   SPLASH REDIRECT
   =========================== */

class _SplashRedirect extends StatefulWidget {
  const _SplashRedirect();

  @override
  State<_SplashRedirect> createState() => _SplashRedirectState();
}

class _SplashRedirectState extends State<_SplashRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs           = await SharedPreferences.getInstance();
      final acceptedVersion = prefs.getString('disclaimerAcceptedVersion') ?? '';
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => acceptedVersion == kDisclaimerVersion
              ? const HomeScreen()
              : const DisclaimerScreen(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}