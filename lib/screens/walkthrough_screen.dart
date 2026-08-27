import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../theme/mer_theme.dart';

/// The first-run walkthrough. See `docs/WALKTHROUGH-SPEC.md`.
///
/// ## What it is for
///
/// MER's difficulty is not complexity — it is that **the best feature is
/// invisible**. The notification path is one tap from a locked phone, and
/// nothing tells a new user it exists.
///
/// Two more reasons, both of which grew since the spec was first written:
///
///  * **A quick record now captures a timestamp and nothing else.** Duration,
///    type and severity are all NULL meaning NOT ASKED. That is the honest
///    design, and its cost is a user who only quick-records and does not find
///    out until they open the export. Step 5 exists for that.
///  * **Learning by exploring creates junk records** in a medical diary, and
///    that hazard got WORSE: a junk record is now blank rather than claiming
///    "< 1 minute", so it is indistinguishable from a real deferred capture.
///
/// ## The rules, which are load-bearing rather than stylistic
///
///  * **NOT INTERACTIVE.** No "try tapping Record Event now" — that creates
///    exactly the junk record this exists to prevent. Every step SHOWS.
///  * **Skippable from step one**, not buried and not only on the last step.
///  * **Nothing gated.** The seen-flag is written when the walkthrough is
///    SHOWN, not when it is finished, so force-quitting midway lands in a
///    working app rather than back at step one.
///  * **The disclaimer comes first and is untouched.**
class WalkthroughScreen extends StatefulWidget {
  const WalkthroughScreen({super.key, this.markSeen = true});

  /// Whether reaching this screen records that the walkthrough has been seen.
  ///
  /// False for the Help re-run: replaying it must not be the thing that marks
  /// it seen, and by then it already is.
  final bool markSeen;

  @override
  State<WalkthroughScreen> createState() => _WalkthroughScreenState();
}

/// One page of the walkthrough.
class _Step {
  const _Step({required this.title, required this.paragraphs, this.icon});
  final String title;
  final List<String> paragraphs;
  final IconData? icon;
}

class _WalkthroughScreenState extends State<WalkthroughScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    // ⚠️ MARKED SEEN ON PRESENTATION, NOT ON COMPLETION, and that is the rule
    // rather than a shortcut.
    //
    // "Force-quitting mid-walkthrough lands the user in a working app, not
    // back at step one." Writing the flag at the end would do the opposite:
    // someone who quits on step 3 would meet the walkthrough again on every
    // launch until they finished it, which is a gate.
    if (widget.markSeen) _recordSeen();
  }

  Future<void> _recordSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kWalkthroughSeenVersionKey, kWalkthroughVersion);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// The steps, in order, for THIS platform.
  ///
  /// ⚠️ **Windows drops step 2 and gets four. Stated as a RULE, not a count** —
  /// the previous spec said "four steps become three", which was a count of the
  /// arrangement at the time and stopped being true when a fifth step landed.
  /// `NotificationService.init()` returns at its first line on Windows, so no
  /// channel is ever created and the step would describe something absent.
  List<_Step> get _steps => <_Step>[
        const _Step(
          icon: Icons.radio_button_checked,
          title: 'Record an event the moment it happens',
          paragraphs: <String>[
            'The red Record Event button saves the time instantly. One tap — '
                'nothing to choose, nothing to type.',
            // The interaction claim and the record claim are SEPARATE
            // sentences, deliberately. "Nothing to fill in" conflated them and
            // was true of the tap while misleading about the record.
            'That is all it saves: the time it happened, and nothing guessed.',
            // "when things are calmer" carries the reason, and does the work a
            // warning would otherwise do. No word here may imply deficiency —
            // tapping a button during a seizure and filling the rest in
            // afterwards is the app working as intended.
            'The rest — how long it lasted, what it was, how it felt — you add '
                'when things are calmer.',
          ],
        ),
        if (!Platform.isWindows) _notificationStep(),
        const _Step(
          icon: Icons.filter_list,
          title: 'Your history, and what to bring to an appointment',
          paragraphs: <String>[
            'Every event is listed in History, grouped by day. Use the filter '
                'icon at the top to narrow the list — by date, by type, or to '
                'the events that still need details.',
            // THE STEP'S REAL JOB. Discoverability moved off the screen when
            // the chips became a sheet, so this is the only place a first-time
            // user meets a control they do not yet know to ask about.
            'What you see is what you export. A number on the icon means a '
                'filter is on.',
          ],
        ),
        const _Step(
          icon: Icons.phone_android,
          title: 'It is on this device, and only here',
          paragraphs: <String>[
            // Quoted from help_screen and your_data_screen rather than
            // redrafted. Those texts are correct and have been corrected nine
            // times; a fresh draft would be a fourth thing to keep in step.
            'There is no account and no cloud copy. Notiva never receives your '
                'events and cannot recover them.',
            // "the only copy YOU control" is precise and must stay precise:
            // Help also states events are included in a normal device backup.
            'A backup file is the only copy you control. Take one, and keep it '
                'somewhere else.',
          ],
        ),
        const _Step(
          icon: Icons.edit_note,
          title: 'Finishing a record',
          paragraphs: <String>[
            'A quick record saves the time and nothing else. When you are '
                'ready, Edit details on the home screen walks you through the '
                'rest — one question at a time, and you can stop at any point.',
            // The sentence that makes stopping safe to OFFER. Without it a user
            // treats the flow as all-or-nothing and defers it entirely.
            'Anything you have entered is kept, whether you finish or not.',
          ],
        ),
      ];

  /// Step 2, whose instruction is **opposite on iOS and Android**.
  ///
  /// ⛔ **DO NOT UNIFY THEM AND DO NOT WRITE ONE FROM THE OTHER.** iOS needs a
  /// long-press to reveal the action button; Android shows it directly. The
  /// Android build shipped the iOS wording until CR-43, and re-deriving one
  /// from the other is exactly how that happened.
  ///
  /// **Starting works on every platform. Ending does not** — iOS refuses the
  /// end action on a locked device, so Help carries an iOS-only row saying so.
  /// This step claims only starting, which is true everywhere.
  _Step _notificationStep() => _Step(
        icon: Icons.notifications_active,
        title: kNotificationStepTitle,
        paragraphs: <String>[
          kNotificationStepLead,
          notificationInstruction(isIOS: Platform.isIOS),
        ],
      );

  bool get _isLast => _page == _steps.length - 1;

  void _next() {
    if (_isLast) {
      Navigator.of(context).maybePop();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final steps = _steps;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to MER'),
        automaticallyImplyLeading: false,
        actions: [
          // SKIP FROM STEP ONE, and from every step. Not buried, and not only
          // on the last page where it would be pointless.
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: TextButton.styleFrom(foregroundColor: Colors.white),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: steps.length,
                itemBuilder: (_, i) => _StepPage(step: steps[i]),
              ),
            ),
            _Dots(count: steps.length, active: _page),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  // BACK from step two onward, never from step one. An
                  // always-present disabled control reads as a fault.
                  if (_page > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _controller.previousPage(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOut,
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                  if (_page > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _next,
                      child: Text(_isLast ? 'Get started' : 'Next'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepPage extends StatelessWidget {
  const _StepPage({required this.step});
  final _Step step;

  @override
  Widget build(BuildContext context) {
    // SCROLLABLE, because five pages of fixed copy is the layout most likely
    // to break at large accessibility text sizes and nothing else in the app
    // is full-screen fixed copy. Named as a risk in the spec; handled here
    // rather than left to be discovered on a device with big text.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (step.icon != null) ...[
            Icon(step.icon, size: 44, color: MERColours.primary),
            const SizedBox(height: 20),
          ],
          Text(
            step.title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 18),
          ...step.paragraphs.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(p, style: const TextStyle(fontSize: 16, height: 1.45)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.active});
  final int count;
  final int active;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          count,
          (i) => Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == active
                  ? MERColours.primary
                  : MERColours.primary.withValues(alpha: 0.25),
            ),
          ),
        ),
      );
}

/// Whether the walkthrough still needs to be shown.
///
/// ⛔ **THE TEST IS "HAS ANY VERSION BEEN SEEN", NOT "HAS THIS VERSION BEEN
/// SEEN".** The stored version is recorded and never compared, deliberately -
/// see [kWalkthroughSeenVersionKey]. Someone who has used MER for a year does
/// not want a five-step tour because a step gained a sentence.
///
/// Changing this to a comparison is a decision with its own reasoning, not a
/// consequence of the version being available.
Future<bool> shouldShowWalkthrough() async {
  final prefs = await SharedPreferences.getInstance();

  final seen = prefs.getString(kWalkthroughSeenVersionKey);
  if (seen != null && seen.isNotEmpty) return false;

  // LEGACY, and it upgrades in place so this runs at most once per install.
  // Build 37 recorded a bool; ignoring it would re-show the walkthrough to
  // someone who had already seen it.
  if (prefs.getBool(kWalkthroughSeenLegacyBoolKey) ?? false) {
    await prefs.setString(kWalkthroughSeenVersionKey, kWalkthroughVersion);
    return false;
  }

  return true;
}

/// Step 2's title and lead, hoisted so a test can name them without
/// reproducing them.
const String kNotificationStepTitle = 'You do not need to open the app';

/// Claims **starting** only, which is true on every platform.
///
/// Ending from a locked device works on Android and NOT on iOS, so this must
/// never say "start and end". Help carries the iOS-only caveat.
const String kNotificationStepLead =
    'MER keeps a notification available at all times, so you can start an '
    'event without unlocking or opening anything.';

/// The platform instruction for step 2.
///
/// ⛔ **THE TWO ARE OPPOSITE AND BOTH ARE CORRECT. DO NOT UNIFY THEM AND DO
/// NOT WRITE ONE FROM THE OTHER.** iOS needs a long-press to reveal the action
/// button; Android shows it directly. The Android build shipped the iOS
/// wording until CR-43, and re-deriving one from the other is how that
/// happened.
///
/// ## Why this is a FUNCTION OF A BOOL rather than a read of `Platform`
///
/// Taking the platform as an argument is what makes the pair testable. A test
/// runs on ONE host - Windows here - so a direct `Platform.isIOS` read means
/// the iOS string is never exercised by any test on any developer machine, and
/// the branch that shipped wrong once would be the branch nobody checks.
String notificationInstruction({required bool isIOS}) => isIOS
    ? 'Pull down from the top of your screen and long-press the MER '
        'notification to reveal the action button, then tap "Log Event Now".'
    : 'Pull down from the top of your screen, find the MER notification, and '
        'tap "Log Event Now".';
