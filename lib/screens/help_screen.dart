import 'dart:io';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/mer_theme.dart';

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});

  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> with WidgetsBindingObserver {
  bool _notificationsAllowed = true;
  bool _showPreviewsAlways   = true;

  static const _navChannel = MethodChannel('au.com.notiva.mer/navigation');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!Platform.isWindows) _checkNotifications();
    if (Platform.isIOS) _checkShowPreviews();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!Platform.isWindows) _checkNotifications();
      if (Platform.isIOS) _checkShowPreviews();
    }
  }

  Future<void> _checkNotifications() async {
    final allowed = await AwesomeNotifications().isNotificationAllowed();
    if (mounted) setState(() => _notificationsAllowed = allowed);
  }

  Future<void> _checkShowPreviews() async {
    try {
      final setting = await _navChannel.invokeMethod<String>('getShowPreviewsSetting');
      if (mounted) setState(() => _showPreviewsAlways = setting == 'always');
    } catch (_) {}
  }

  Future<void> _openNotificationSettings() async {
    await AwesomeNotifications().showNotificationConfigPage();
    await _checkNotifications();
    if (Platform.isIOS) await _checkShowPreviews();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize:       MainAxisSize.min,
          children: [
            Text(
              'Help',
              style: TextStyle(
                fontSize:   15,
                fontWeight: FontWeight.w600,
                color:      Colors.white,
              ),
            ),
            Text(
              'Medical Event Recorder',
              style: TextStyle(
                fontSize: 10,
                color:    Colors.white54,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            if (!_notificationsAllowed && !Platform.isWindows) ...[
              _WarningCard(
                title:          'Notifications are disabled',
                body:           'Tap the button below to open notification settings, then turn on notifications for MER.',
                buttonLabel:    'Open Notification Settings',
                onOpenSettings: _openNotificationSettings,
              ),
              const SizedBox(height: 12),
            ],

            if (!_showPreviewsAlways && Platform.isIOS) ...[
              _WarningCard(
                title:          'Starting events from the lock screen requires a password',
                body:           'To log instantly without unlocking, tap the button below and set Show Previews to Always.',
                buttonLabel:    'Open Notification Settings',
                onOpenSettings: _openNotificationSettings,
              ),
              const SizedBox(height: 12),
            ],

            _Section(
              title: 'RECORDING EVENTS',
              children: const [
                _HelpRow(
                  icon:      Icons.circle,
                  iconColor: Color(0xFFD32F2F),
                  title:     'Quick record',
                  body:      'Tap the red Record Event button to instantly log an event with the current timestamp.',
                ),
                _HelpRow(
                  icon:  Icons.tune,
                  title: 'Record with details',
                  body:  'Use the blue Record with details button to add notes, duration, triggers, and severity before saving.',
                ),
                _HelpRow(
                  icon:   Icons.edit_outlined,
                  title:  'Edit a record',
                  body:   'Tap any event in the list to open it and make changes. Tap the ⋮ menu on the event card for more options.',
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 12),

            _Section(
              title: 'HISTORY & EXPORT',
              children: const [
                _HelpRow(
                  icon:  Icons.history,
                  title: 'View history',
                  body:  'Tap ⋮ (top right) → History to see all past events with edit and delete options.',
                ),
                _HelpRow(
                  icon:   Icons.download_outlined,
                  title:  'Export to CSV',
                  body:   'Tap ⋮ → Export CSV (all events) to share your event data as a spreadsheet file.',
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (!Platform.isWindows)
            _Section(
              title: 'QUICK LOG NOTIFICATION',
              children: [
                const _HelpRow(
                  icon:  Icons.notifications_outlined,
                  title: 'What is it?',
                  body:  'MER keeps a notification available at all times so you can log events without opening the app — even from the lock screen.',
                ),
                if (Platform.isIOS) ...[
                  const _HelpRow(
                    icon:  Icons.swipe_down_outlined,
                    title: 'Starting an event',
                    body:  'Pull down from the top of your screen and long-press the MER notification to reveal the action button, then tap "Log Event Now". A timer starts immediately.',
                  ),
                  const _HelpRow(
                    icon:  Icons.lock_outline,
                    title: 'Starting from the lock screen',
                    body:  'Long-press the MER notification on your lock screen and tap "Log Event Now". With Show Previews set to Always, no password is needed — the event starts immediately. Ending the event requires unlocking, which is the right time to add details.',
                  ),
                  const _HelpRow(
                    icon:  Icons.timer_outlined,
                    title: 'Live Activity timer',
                    body:  'After starting an event, a live timer appears on the Dynamic Island or as a banner on the lock screen. When the event is over, tap "Event Ended" on the timer — your phone can stay locked.',
                  ),
                  const _HelpRow(
                    icon:  Icons.open_in_new,
                    title: 'Reviewing the event',
                    body:  'After tapping "Event Ended", a notification shows the recorded duration. Tap it to open MER directly on the event\'s edit screen — add notes, triggers, and severity while the details are still fresh.',
                  ),
                ] else ...[
                  const _HelpRow(
                    icon:  Icons.swipe_down_outlined,
                    title: 'Starting an event',
                    body:  'Pull down from the top of your screen, find the MER notification, and tap "Log Event Now". Tap "Event Ended" when it\'s over to save the duration.',
                  ),
                  const _HelpRow(
                    icon:  Icons.lock_outline,
                    title: 'Using from the lock screen',
                    body:  'Go to Settings → Notifications → Notifications on lock screen → Show all notifications. Once set, pull down from the top of your lock screen to access MER without unlocking.',
                  ),
                ],
                const _HelpRow(
                  icon:  Icons.refresh,
                  title: 'If the notification disappears',
                  body:  'The notification can be swiped away accidentally. Open the MER app and it will restore automatically.',
                ),
                if (Platform.isIOS)
                  _HelpRow(
                    icon:      _showPreviewsAlways
                        ? Icons.lock_open_outlined
                        : Icons.lock_outlined,
                    iconColor: _showPreviewsAlways
                        ? const Color(0xFF388E3C)
                        : const Color(0xFFF57C00),
                    title: 'Lock screen access',
                    body:  _showPreviewsAlways
                        ? 'Show Previews is set to "Always" — events can be started from the lock screen without a password.'
                        : 'With default settings, starting an event from the lock screen requires a password. Use the button at the top of this page to set Show Previews to Always.',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width:  10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _showPreviewsAlways
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFF57C00),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _showPreviewsAlways ? 'Active' : 'Not set',
                          style: TextStyle(
                            fontSize:   13,
                            fontWeight: FontWeight.w600,
                            color: _showPreviewsAlways
                                ? const Color(0xFF388E3C)
                                : const Color(0xFFF57C00),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (!Platform.isWindows)
                  _HelpRow(
                    icon:      _notificationsAllowed
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                    iconColor: _notificationsAllowed
                        ? const Color(0xFF388E3C)
                        : const Color(0xFFF57C00),
                    title:  'Notification status',
                    body:   _notificationsAllowed
                        ? 'Notifications are enabled for MER.'
                        : 'Tap the button at the top of this page to open notification settings and turn on notifications for MER.',
                    isLast: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width:  10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _notificationsAllowed
                                ? const Color(0xFF4CAF50)
                                : const Color(0xFFF57C00),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _notificationsAllowed ? 'Active' : 'Disabled',
                          style: TextStyle(
                            fontSize:   13,
                            fontWeight: FontWeight.w600,
                            color: _notificationsAllowed
                                ? const Color(0xFF388E3C)
                                : const Color(0xFFF57C00),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Warning banner (notifications disabled / lock screen not configured) ───────

class _WarningCard extends StatelessWidget {
  final String       title;
  final String       body;
  final String       buttonLabel;
  final VoidCallback onOpenSettings;

  const _WarningCard({
    required this.title,
    required this.body,
    required this.buttonLabel,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        const Color(0xFFFFF3E0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB74D), width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFF57C00), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color:      const Color(0xFFE65100),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:  const Color(0xFFBF360C),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: onOpenSettings,
                  icon:  const Icon(Icons.settings_outlined, size: 16),
                  label: Text(buttonLabel),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF57C00),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical:   6,
                    ),
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String         title;
  final List<Widget>   children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        MERColours.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MERColours.border, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ── Help row ──────────────────────────────────────────────────────────────────

class _HelpRow extends StatelessWidget {
  final IconData  icon;
  final Color?    iconColor;
  final String    title;
  final String    body;
  final bool      isLast;
  final Widget?   trailing;

  const _HelpRow({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.body,
    this.isLast   = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18,
                color: iconColor ?? MERColours.primary),
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
                    style: Theme.of(context).textTheme.bodySmall
                        ?.copyWith(height: 1.5),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(height: 8),
                    trailing!,
                  ],
                ],
              ),
            ),
          ],
        ),
        if (!isLast) ...[
          const SizedBox(height: 10),
          Divider(height: 1, thickness: 0.5, color: MERColours.border),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
