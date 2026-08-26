import 'dart:io';

import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
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

            // Both settings facts, stated ONCE. They previously appeared as
            // warning cards here AND as status rows at the bottom of the
            // notification section. Same two conditions as before: notifications
            // on every platform but Windows, Show Previews on iOS only.
            _StatusBand(
              showNotifications:    !Platform.isWindows,
              notificationsAllowed: _notificationsAllowed,
              showPreviewsRow:      Platform.isIOS,
              showPreviewsAlways:   _showPreviewsAlways,
              onOpenSettings:       _openNotificationSettings,
            ),

            const _Section(
              title: 'RECORDING EVENTS',
              children: [
                _HelpRow(
                  icon:      Icons.circle,
                  iconColor: Color(0xFFD32F2F),
                  title:     'Quick record',
                  // Accurate before and after the nullable work — a quick record now
                  // genuinely carries a timestamp and nothing else. What it lacked was
                  // the NEXT step: it read as though that is all one can ever be.
                  body:      'Tap the red Record Event button to instantly log an event with the '
                             'current timestamp — nothing else is recorded and nothing is guessed. '
                             'Add the details whenever you are ready, from the last event on the '
                             'home screen or from History.',
                ),
                _HelpRow(
                  icon:  Icons.tune,
                  title: 'Record with details',
                  // ⚠️ REWRITTEN 26-Aug-26. This row described a SINGLE FORM. The
                  // blue button opens the WIZARD — four guided steps with a summary —
                  // and the row listed the fields in the single page's order, which is
                  // not even the order the wizard asks them in: duration is first
                  // there.
                  //
                  // Found by checking the BUTTON against the running app rather than by
                  // reading this file. The copy was internally coherent and pointed at
                  // a screen that button no longer opens.
                  //
                  // It now describes the SHAPE of the flow rather than enumerating
                  // fields in an order that will move again. The old rule — "named in
                  // the order the fields appear on the details screen" — retires with
                  // it: there are two screens now and they order things differently on
                  // purpose.
                  body:  'Use the blue Record with details button for a guided version: one question '
                         'at a time — how long it lasted, what happened, what was going on beforehand, '
                         'and how you felt afterwards — with a summary before you save. You can skip '
                         'any step, and whatever you have entered is kept if you back out. Anything '
                         'you add to a list is offered next time.',
                ),
                _HelpRow(
                  icon:   Icons.edit_outlined,
                  title:  'Edit a record',
                  // There is no per-event ⋮ menu anywhere in the app. The only
                  // PopupMenuButton is the AppBar overflow in home_screen.dart;
                  // Icons.more_vert in the Getting Started card is decoration.
                  // What a History row actually offers, verified in
                  // history_screen.dart: onTap opens the editor, and a trailing
                  // delete IconButton whose handler confirms first.
                  // The routing is invisible and a user WILL notice the screens differ,
                  // so the row says why rather than leaving it as apparent inconsistency.
                  body:   'Tap any event in the list to open it and make changes. An event you '
                          'started adding details to reopens in the guided steps so you can '
                          'carry on; everything else opens as a single form. In History, each '
                          'row also has a delete button, and deleting asks you to confirm first.',
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 12),

            const _Section(
              title: 'HISTORY & EXPORT',
              children: [
                _HelpRow(
                  icon:  Icons.history,
                  title: 'View history',
                  // Names BOTH routes. The ⋮ path was the only one documented,
                  // and "All history" on the Last Event card is the more
                  // prominent of the two on the running screen.
                  body:  'Tap "All history" on the last event, or ⋮ (top right) → History, to see '
                         'all past events with edit and delete options.',
                ),
                _HelpRow(
                  icon:   Icons.filter_list,
                  title:  'Narrowing what you see',
                  // ⚠️ THIS ROW EXISTS BECAUSE DISCOVERABILITY MOVED OFF THE
                  // SCREEN. The filters used to be chips and a toggle sitting
                  // in the list, so a user found them by looking. They are now
                  // behind an AppBar icon, and Help is where someone learns
                  // they exist at all.
                  //
                  // Help NEVER described the filter controls — verified, not
                  // assumed: the only mention of the word in this file was
                  // inside the export row below, which says "your current
                  // search and filters" without ever saying where they are.
                  // That was survivable when they were self-evident on screen.
                  // It is not now.
                  //
                  // The badge and the banner are named deliberately: they are
                  // the two things that tell a user a filter is still on, and
                  // a forgotten filter is what makes an exported history
                  // incomplete.
                  body:   'Your history can be narrowed — by a word you search for, by event '
                          'type, by date range, or to just the events that needed a referral. '
                          'The controls are not on the screen: they are behind the filter icon '
                          'at the top of History, so tap that to open them. A number on the icon '
                          'shows how many filters are on, and a red bar above the list says what '
                          'they are and how many events you are seeing. Tap "Clear" on that bar '
                          'to see everything again.',
                ),
                _HelpRow(
                  icon:   Icons.download_outlined,
                  title:  'Export to CSV',
                  body:   'Tap ⋮ → Your data → Export all events to share your events as a '
                          'spreadsheet file. A CSV cannot be read back into the app — it is a '
                          'copy to share, not a backup.',
                ),
                _HelpRow(
                  icon:   Icons.filter_alt_outlined,
                  title:  'Exporting only what you are looking at',
                  // "your current search and filters" was accurate and gave a
                  // user nowhere to look. It now points at the icon and at the
                  // bar, because this row is where someone realises their
                  // export was narrowed and needs to know what to undo.
                  body:   'The share button at the top of the History screen exports just the '
                          'events your filters are showing, not all of them — including a word '
                          'left in the search box. The sheet that opens says how many, and it '
                          'says "Export all" only when nothing is filtered. If the red bar is '
                          'above your list, your export will be narrowed too.',
                ),
                _HelpRow(
                  icon:   Icons.backup_outlined,
                  title:  'Back up and restore',
                  // NOT "a file you choose": on iOS the save option does not
                  // exist and Share is the only route, so nothing offers a
                  // location to choose.
                  body:   'Tap ⋮ → Your data → Back up now to save every event to a file you '
                          'can share or store. Restore from a backup on the same screen reads '
                          'one back in. Restoring only adds events — anything already on this '
                          'device is left exactly as it is.',
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 12),

            _Section(
              title: 'YOUR DATA — PLEASE READ',
              children: [
                const _HelpRow(
                  icon:  Icons.phone_iphone,
                  title: 'It is on this device and nowhere else',
                  body:  'Every event you record is stored on this device only. '
                         'There is no account, no cloud copy, and no server. '
                         'Notiva never receives your events and cannot recover them for you.',
                ),
                _HelpRow(
                  icon:      Icons.delete_forever_outlined,
                  iconColor: const Color(0xFFD32F2F),
                  title:     'Deleting the app deletes your events',
                  body:      Platform.isIOS
                      ? 'Deleting Medical Event Recorder removes every event stored on this device. '
                        'Offloading is different: Settings → General → iPhone Storage → Offload App '
                        'frees up space but keeps your data, and reinstalling brings it back. '
                        'It is Delete App that destroys it.'
                      : 'Uninstalling Medical Event Recorder removes every event stored on this device. '
                        'Clearing app storage in Android settings does the same thing.',
                ),
                const _HelpRow(
                  icon:      Icons.phonelink_setup_outlined,
                  iconColor: Color(0xFF388E3C),
                  title:     'Moving to a new phone is different',
                  body:      'Your events are included in a normal device backup. Restoring that '
                             'backup onto a new phone brings them across with the app. '
                             'That is not the same as deleting and reinstalling the app on this '
                             'phone, which starts you with nothing.',
                ),
                const _HelpRow(
                  icon:      Icons.compare_arrows,
                  iconColor: Color(0xFF1976D2),
                  title:     'Export and backup do different jobs',
                  // Mirrors the Your data screen's own framing deliberately, so
                  // the two cannot drift, and points at that screen rather than
                  // re-explaining where things live. This is the distinction
                  // users get wrong.
                  body:      'A CSV export is a copy to share or work with — it opens in a '
                             'spreadsheet and cannot be read back into the app. A backup file '
                             'is your copy — it restores your history onto a new phone but is '
                             'not a spreadsheet file. Both live under Your data in the menu.',
                ),
                const _HelpRow(
                  icon:      Icons.save_alt,
                  iconColor: Color(0xFF1976D2),
                  title:     'A backup file is the only copy you control',
                  body:      'Exporting or backing up is the only way to keep your events '
                             'independently of this device. Save the file somewhere else — a '
                             'computer, cloud storage, an email to yourself — and it will still '
                             'be there whatever happens to the phone.',
                  isLast:    true,
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (!Platform.isWindows)
            _Section(
              title: 'QUICK LOG NOTIFICATION',
              // ⚠️ NEVER COLLAPSED. This is the only documentation of the
              // long-press on iOS and of the notification-settings path on
              // Android. Behind a collapsed heading, a user never learns either.
              //
              // ⚠️ THE TWO INSTRUCTIONS ARE OPPOSITE AND BOTH ARE CORRECT. iOS
              // needs a long-press to reveal the action; Android shows it
              // directly. The Android build shipped the iOS wording until
              // CR-43. Do not unify them and do not write one from the other.
              alwaysVisible: Platform.isIOS
                  ? const _HelpRow(
                      icon:   Icons.swipe_down_outlined,
                      title:  'Starting an event',
                      body:   'Pull down from the top of your screen and long-press the MER notification to reveal the action button, then tap "Log Event Now". A timer starts immediately.',
                      isLast: true,
                    )
                  : const _HelpRow(
                      icon:   Icons.swipe_down_outlined,
                      title:  'Starting an event',
                      body:   'Pull down from the top of your screen, find the MER notification, and tap "Log Event Now". Tap "Event Ended" when it\'s over to save the duration.',
                      isLast: true,
                    ),
              children: [
                const _HelpRow(
                  icon:  Icons.notifications_outlined,
                  title: 'What is it?',
                  body:  'MER keeps a notification available at all times so you can log events without opening the app — even from the lock screen.',
                ),
                if (Platform.isIOS) ...[
                  const _HelpRow(
                    icon:  Icons.lock_outline,
                    title: 'Starting from the lock screen',
                    // The unlock caveat that used to close this row now has its
                    // own row below, because it is the single most useful
                    // sentence in the section and was buried at the end of a
                    // paragraph about starting.
                    body:  'Long-press the MER notification on your lock screen and tap "Log Event Now". With Show Previews set to Always, no password is needed — the event starts immediately.',
                  ),
                  const _HelpRow(
                    icon:  Icons.lock_open_outlined,
                    title: 'Ending an event needs your phone unlocked',
                    // iOS ONLY, and this is a correction to the brief, which
                    // asserted the wording is "accurate everywhere". It is not.
                    // On Android both notification actions are
                    // ActionType.SilentAction — they fire without opening the
                    // app and without unlocking, so ending from a locked device
                    // works there. Rendering this on Android would tell users to
                    // do something unnecessary.
                    //
                    // No iOS version is named and the sub-17 behaviour is not
                    // described as a fault: the instruction that works is the
                    // useful content. On 17+ the system demands authentication
                    // before ending; on 16.2-16.x a locked device does not
                    // deliver the action at all.
                    body:  'Starting an event never does — one tap from the Lock Screen and it is recorded. Ending one is different: unlock your phone first, then tap "Event Ended" on the timer or the notification.',
                  ),
                  const _HelpRow(
                    icon:  Icons.timer_outlined,
                    title: 'Live Activity timer',
                    // Deliberately makes NO claim about ending while locked, and
                    // does not say the button is on the timer.
                    //   - "your phone can stay locked" was false: iOS 26 demands
                    //     authentication for this button despite
                    //     authenticationPolicy .alwaysAllowed (checklist §8).
                    //   - "tap Event Ended on the timer" was false below iOS 17:
                    //     Button(intent:) is gated on #available(iOS 17.0) in
                    //     MERLiveActivity.swift, and the deployment target is 15.0.
                    // The two end surfaces are mutually exclusive by version — the
                    // Live Activity button on 17+, the active notification below it,
                    // since handleQuickLogStart only schedules that notification
                    // when #available(iOS 17.0) is false — so "whichever your
                    // iPhone shows" is accurate on every version and stays accurate
                    // after the deployment target rises. No version conditional to
                    // become dead code.
                    // The unlock caveat lives in its own row above ("Ending an
                    // event needs your phone unlocked"); repeating it here would
                    // duplicate.
                    body:  'After starting an event, a live timer appears on the Dynamic Island or as a banner on the lock screen. To end the event, tap "Event Ended" on the timer or on the MER notification, whichever your iPhone shows.',
                  ),
                  const _HelpRow(
                    icon:  Icons.open_in_new,
                    title: 'Reviewing the event',
                    body:  'After tapping "Event Ended", a notification shows the recorded duration. Tap it to open MER directly on the event\'s edit screen — add notes, what was happening beforehand, and severity while the details are still fresh.',
                  ),
                ] else ...[
                  const _HelpRow(
                    icon:  Icons.lock_outline,
                    title: 'Using from the lock screen',
                    body:  'Go to Settings → Notifications → Notifications on lock screen → Show all notifications. Once set, pull down from the top of your lock screen to access MER without unlocking.',
                  ),
                  const _HelpRow(
                    icon:  Icons.open_in_new,
                    title: 'Reviewing the event',
                    body:  'After tapping "Event Ended", a notification shows the recorded duration. Tap it to open MER directly on the event\'s edit screen — add notes, what was happening beforehand, and severity while the details are still fresh.',
                  ),
                ],
                const _HelpRow(
                  icon:   Icons.refresh,
                  title:  'If the notification disappears',
                  body:   'The notification can be swiped away accidentally. Open the MER app and it will restore automatically.',
                  isLast: true,
                ),
              ],
            ),
            // Windows has no notification path at all: NotificationService.init()
            // returns before any channel is created. Said plainly rather than
            // omitted — a Windows user who finds nothing here cannot tell
            // whether the section is missing or the feature is absent.
            if (Platform.isWindows)
              const _Section(
                title: 'QUICK LOG NOTIFICATION',
                alwaysVisible: _HelpRow(
                  icon:   Icons.desktop_windows_outlined,
                  title:  'Not available on Windows',
                  body:   'The quick log notification is a phone feature. On Windows, record events in the app — everything else works the same way.',
                  isLast: true,
                ),
                children: [],
              ),
            if (Platform.isWindows) const SizedBox(height: 12),

            const _Section(
              title: 'GETTING HELP',
              children: [
                _HelpRow(
                  icon:  Icons.mail_outline,
                  title: 'Contact support',
                  body:  'Email $kSupportEmail with what happened and what you '
                         'expected. Your events are never included — they stay on '
                         'this device, so anything you want us to see has to be '
                         'described or attached by you.',
                ),
                _HelpRow(
                  icon:   Icons.info_outline,
                  title:  'Version, privacy and terms',
                  // Points at About rather than restating it. The same reason
                  // the Your data row points at the Your data screen: two copies
                  // of the same fact drift, and About already carries the
                  // version, the privacy policy and the terms as live links.
                  body:   'The About screen shows which version you are running and links to the privacy policy and terms. Open it from the menu in the top right.',
                  isLast: true,
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

// ── Status band ───────────────────────────────────────────────────────────────

/// The two settings facts, stated once, always visible.
///
/// These used to appear TWICE: as warning cards above every section, and again
/// as status rows buried at the bottom of the notification section. A user with
/// notifications off read it twice; a user with everything correct had to scroll
/// to the end to find that out.
///
/// A warning state must read as needing attention rather than as information,
/// so the row carries colour, a dot, and an explicit "tap to" instruction — the
/// whole row is the target, and it opens the same Settings page the old warning
/// card's button did.
///
/// ⚠️ The Show Previews wording deliberately does NOT assert what happens when
/// it is not "Always". That claim was downgraded to "believed, not tested" on
/// 24 August 2026: its only source is this screen's own prose, the notification
/// action is registered `options: []`, and the app therefore does not decide it.
/// The row says what the SETTING is, not what iOS will do about it.
class _StatusBand extends StatelessWidget {
  final bool showNotifications;
  final bool notificationsAllowed;
  final bool showPreviewsRow;
  final bool showPreviewsAlways;
  final VoidCallback onOpenSettings;

  const _StatusBand({
    required this.showNotifications,
    required this.notificationsAllowed,
    required this.showPreviewsRow,
    required this.showPreviewsAlways,
    required this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      if (showNotifications)
        _StatusRow(
          ok:      notificationsAllowed,
          label:   'Notifications',
          okText:  'Active',
          badText: 'Off — tap to enable',
          okIcon:  Icons.notifications_active_outlined,
          badIcon: Icons.notifications_off_outlined,
          onTap:   onOpenSettings,
        ),
      if (showPreviewsRow)
        _StatusRow(
          ok:      showPreviewsAlways,
          label:   'Show Previews',
          okText:  'Always',
          badText: 'Not set to Always — tap to fix',
          okIcon:  Icons.lock_open_outlined,
          badIcon: Icons.lock_outlined,
          onTap:   onOpenSettings,
        ),
    ];

    // Windows reaches neither row. An empty band is quieter than an explained
    // absence — a Windows user does not need to be told what is not there.
    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color:        MERColours.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MERColours.border, width: 0.5),
      ),
      child: Column(children: rows),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final bool         ok;
  final String       label;
  final String       okText;
  final String       badText;
  final IconData     okIcon;
  final IconData     badIcon;
  final VoidCallback onTap;

  const _StatusRow({
    required this.ok,
    required this.label,
    required this.okText,
    required this.badText,
    required this.okIcon,
    required this.badIcon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colour = ok ? const Color(0xFF388E3C) : const Color(0xFFF57C00);
    return InkWell(
      // Tappable in BOTH states, deliberately: someone whose setting is correct
      // may still want the Settings page, and a row that is only sometimes a
      // target is a row people stop trying.
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(ok ? okIcon : badIcon, size: 18, color: colour),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color:      MERColours.textPrimary,
                ),
              ),
            ),
            Container(
              width:  10,
              height: 10,
              decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                ok ? okText : badText,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color:      colour,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────────────

/// A collapsible section, closed by default.
///
/// Not tabs: tabs hide content behind a choice made before the user knows what
/// is in each one. Collapsed headings show the whole map at a glance and cost
/// one tap. Someone opening Help usually has a single question, and the map is
/// what they need first.
///
/// [alwaysVisible] survives collapsing. It exists for one specific hazard: the
/// platform-specific instruction for STARTING an event is the only documentation
/// of the long-press on iOS and the notification-settings path on Android.
/// Collapsed by default, a user would never learn either.
///
/// State is NOT persisted between visits, deliberately. Someone returning to
/// Help usually has a different question, so a remembered layout is a remembered
/// wrong answer.
class _Section extends StatefulWidget {
  final String       title;
  final List<Widget> children;
  final Widget?      alwaysVisible;

  const _Section({
    required this.title,
    required this.children,
    this.alwaysVisible,
  });

  @override
  State<_Section> createState() => _SectionState();
}

class _SectionState extends State<_Section> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        MERColours.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MERColours.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.title,
                        style: Theme.of(context).textTheme.labelLarge),
                  ),
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    size:  22,
                    color: MERColours.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (widget.alwaysVisible != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: widget.alwaysVisible,
            ),
          if (_open)
            Padding(
              padding: EdgeInsets.fromLTRB(
                  14, widget.alwaysVisible == null ? 0 : 4, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.children,
              ),
            ),
        ],
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

  const _HelpRow({
    required this.icon,
    this.iconColor,
    required this.title,
    required this.body,
    this.isLast   = false,
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
                ],
              ),
            ),
          ],
        ),
        if (!isLast) ...[
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 0.5, color: MERColours.border),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
