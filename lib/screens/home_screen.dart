import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import '../services/notification_service.dart';
import '../models/event_record.dart';
import '../screens/about_screen.dart';
import '../screens/disclaimer_screen.dart';
import '../screens/help_screen.dart';
import '../screens/history_screen.dart';
import '../screens/log_event_screen.dart';
import '../theme/mer_theme.dart';
import '../widgets/mer_icon_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _HomeMenuAction {
  history,
  exportAll,
  about,
  help,
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final _store = EventStore();
  final _uuid  = const Uuid();

  List<EventRecord> _records = [];
  Map<String, dynamic>? _activeEvent;
  bool _loaded = false;
  bool _buttonFlash = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _loadRecords(initial: true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadRecords();
      NotificationService.instance.restoreNotification();
    }
  }

  Future<void> _loadRecords({bool initial = false}) async {
    final prefs    = await SharedPreferences.getInstance();
    final loaded   = await _store.load();
    final activeRaw = prefs.getString('mer_active_event');
    Map<String, dynamic>? active;
    if (activeRaw != null) {
      try { active = jsonDecode(activeRaw) as Map<String, dynamic>; } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _records     = loaded;
      _activeEvent = active;
      if (initial) _loaded = true;
    });
  }

  Future<void> _endActiveEvent() async {
    await NotificationService.instance.endEvent();
    await _loadRecords();
  }

  Future<void> _persist() => _store.save(_records);

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
  Future<void> _quickRecord() async {
    // ── HAPTIC FEEDBACK ──
    HapticFeedback.heavyImpact();

    // ── BUTTON FLASH ──
    setState(() => _buttonFlash = true);
    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) setState(() => _buttonFlash = false);

    final rec = EventRecord(
      id:               _uuid.v4(),
      timestamp:        DateTime.now(),
      duration:         DurationCategory.lt1,
      feelings:         const [],
      triggers:         const [],
      referralRequired: false,
      notes:            '',
    );

    setState(() => _records.insert(0, rec));
    await _persist();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Event recorded'),
      ),
    );
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
      if (existing == null) {
        _records.insert(0, result);
      } else {
        final index = _records.indexWhere((r) => r.id == result.id);
        if (index != -1) _records[index] = result;
      }
      _records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    });

    await _persist();
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
        title: Row(
          children: [
            Container(
              width:  30,
              height: 30,
              decoration: BoxDecoration(
                color:        Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: MERIconWidget(size: 20),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
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
                  'Track · Record · Understand',
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
                case _HomeMenuAction.exportAll:
                  await showExportOptions(
                    context,
                    _records,
                    filenamePrefix: 'medical_event_recorder_all',
                  );
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
                value: _HomeMenuAction.exportAll,
                child: Text('Export CSV (all events)'),
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

                        // ── ACTIVE EVENT BANNER ──
                        if (_activeEvent != null) ...[
                          _ActiveEventBanner(
                            startTime: DateTime.parse(
                                _activeEvent!['startIso'] as String),
                            onEnd: _endActiveEvent,
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

  const _ActiveEventBanner({required this.startTime, required this.onEnd});

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
              ],
            ),
          ),
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