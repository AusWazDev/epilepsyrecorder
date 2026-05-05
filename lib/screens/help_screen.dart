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

class _HelpScreenState extends State<HelpScreen> {
  bool _notificationsAllowed = true;
  bool _showPreviewsAlways   = true;

  static const _navChannel = MethodChannel('au.com.notiva.mer/navigation');

  @override
  void initState() {
    super.initState();
    if (!Platform.isWindows) _checkNotifications();
    if (Platform.isIOS) _checkShowPreviews();
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
              _NotificationWarningCard(onOpenSettings: _openNotificationSettings),
              const SizedBox(height: 16),
            ],

            _Section(
              title: 'RECORDING EVENTS',
              children: const [
                _HelpRow(
                  icon:  Icons.circle,
                  iconColor: Color(0xFFD32F2F),
                  title: 'Quick record',
                  body:  'Tap the red Record Event button to instantly log an event with the current timestamp.',
                ),
                _HelpRow(
                  icon:  Icons.tune,
                  title: 'Record with details',
                  body:  'Use the blue Record with details button to add notes, duration, triggers, and severity before saving.',
                ),
                _HelpRow(
                  icon:  Icons.edit_outlined,
                  title: 'Edit a record',
                  body:  'Tap any event in the list to open it and make changes. Tap the ⋮ menu on the event card for more options.',
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
                  icon:  Icons.download_outlined,
                  title: 'Export to CSV',
                  body:  'Tap ⋮ → Export CSV (all events) to share your event data as a spreadsheet file.',
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
                  body:  'MER keeps a notification in your notification shade at all times. You can log an event directly from there — without unlocking your phone.',
                ),
                if (Platform.isIOS) ...[
                  const _HelpRow(
                    icon:  Icons.swipe_down_outlined,
                    title: 'Starting an event',
                    body:  'Pull down the notification shade and long-press the MER notification to reveal the action button, then tap "Log Event Now". A timer starts immediately — no need to open the app.',
                  ),
                  const _HelpRow(
                    icon:  Icons.lock_outline,
                    title: 'Starting from the lock screen',
                    body:  'Go to iPhone Settings → Notifications → Medical Event Recorder → Show Previews → Always. Long-press the MER notification on your lock screen and tap "Log Event Now" — your phone stays locked.',
                  ),
                  const _HelpRow(
                    icon:  Icons.timer_outlined,
                    title: 'Live Activity timer',
                    body:  'After starting an event, a live timer appears on the Dynamic Island or as a banner on the lock screen showing how long the event has been running. When the event is over, tap "Event Ended" directly on the timer — your phone can stay locked.',
                  ),
                  const _HelpRow(
                    icon:  Icons.open_in_new,
                    title: 'Reviewing the event',
                    body:  'After tapping "Event Ended", a notification shows the recorded duration. Tap that notification to open MER directly on the event\'s edit screen — add notes, triggers, and severity while the details are still fresh.',
                  ),
                ] else ...[
                  const _HelpRow(
                    icon:  Icons.swipe_down_outlined,
                    title: 'Using from the notification shade',
                    body:  'Pull down from the top of your screen. Find the MER notification and tap "Log Event Now" to start recording. Tap "Event Ended" to stop and save the duration.',
                  ),
                  const _HelpRow(
                    icon:  Icons.lock_outline,
                    title: 'Using from the lock screen',
                    body:  'Go to Settings → Notifications → Notifications on lock screen → Show all notifications. Once set, pull down the shade on your lock screen to access MER without unlocking.',
                  ),
                ],
                const _HelpRow(
                  icon:  Icons.refresh,
                  title: 'If the notification disappears',
                  body:  'The notification can be swiped away accidentally. Simply open the MER app and it will restore automatically.',
                ),
                if (Platform.isIOS)
                  _HelpRow(
                    icon:  _showPreviewsAlways
                        ? Icons.lock_open_outlined
                        : Icons.lock_outlined,
                    iconColor: _showPreviewsAlways
                        ? const Color(0xFF388E3C)
                        : const Color(0xFFF57C00),
                    title: 'Lock screen access',
                    body:  _showPreviewsAlways
                        ? 'Show Previews is set to "Always" — lock screen notification actions are available without unlocking.'
                        : 'Show Previews is not set to "Always". To start events from the lock screen without unlocking, go to iPhone Settings → Notifications → Medical Event Recorder → Show Previews → Always.',
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
                    icon:  _notificationsAllowed
                        ? Icons.notifications_active_outlined
                        : Icons.notifications_off_outlined,
                    iconColor: _notificationsAllowed
                        ? const Color(0xFF388E3C)
                        : const Color(0xFFF57C00),
                    title: 'Notification status',
                    body:  _notificationsAllowed
                        ? 'Notifications are enabled for MER.'
                        : 'Use the button at the top of this page to enable notifications. Once enabled, close and reopen MER to restore the quick-log notification.',
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

// ── Notification warning banner ───────────────────────────────────────────────

class _NotificationWarningCard extends StatelessWidget {
  final VoidCallback onOpenSettings;
  const _NotificationWarningCard({required this.onOpenSettings});

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
                  'Notifications are disabled',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color:      const Color(0xFFE65100),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap the button below to open MER\'s notification settings, then toggle the Notifications switch to ON.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color:  const Color(0xFFBF360C),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: onOpenSettings,
                  icon:  const Icon(Icons.settings_outlined, size: 16),
                  label: const Text('Open Notification Settings'),
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
