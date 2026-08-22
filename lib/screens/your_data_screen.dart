import 'package:flutter/material.dart';

import '../theme/mer_theme.dart';

/// The two ways to get a copy of your events off this device.
///
/// Exists because the home menu had six flat items with no grouping, mixing
/// four data actions with navigation, and nothing distinguished the two that
/// look alike. Someone reaching for "back up my data" who picks Export gets a
/// CSV, which cannot be read back into the app — so their history does not come
/// with them to a new phone. The whole point of this screen is to make Export
/// and Back up hard to confuse.
///
/// Restore sits on the backup card rather than having its own entry: it is the
/// other half of the same action, and splitting them is part of why the old menu
/// read as four unrelated things.
///
/// Deliberately says nothing about what the data means. It describes what each
/// file IS, never what it would tell anyone.
class YourDataScreen extends StatelessWidget {
  const YourDataScreen({
    super.key,
    required this.onExport,
    required this.onBackUp,
    required this.onRestore,
  });

  /// Each takes the screen's own [BuildContext] so sheets, dialogs and
  /// SnackBars anchor to the screen the user is looking at.
  final Future<void> Function(BuildContext context) onExport;
  final Future<void> Function(BuildContext context) onBackUp;
  final Future<void> Function(BuildContext context) onRestore;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your data',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            Text(
              'Medical Event Recorder',
              style: TextStyle(fontSize: 10, color: Colors.white54),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 0, 4, 16),
                    child: Text(
                      'Your events are stored on this device only. These are '
                      'the two ways to get a copy off it — they do different '
                      'jobs.',
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.45,
                        color: MERColours.textMuted,
                      ),
                    ),
                  ),

                  // ── EXPORT ──
                  _DataCard(
                    // Same icon History uses for its export button.
                    icon: Icons.ios_share,
                    title: 'Export a spreadsheet',
                    body: const [
                      'A CSV file of your events, ready to open in Excel or '
                          'Numbers, or send to your specialist. Every event, '
                          'oldest first, one row each.',
                      'This is a copy to share or work with. It cannot be read '
                          'back into the app.',
                    ],
                    actions: [
                      _CardAction(
                        label: 'Export all events',
                        primary: true,
                        onPressed: () => onExport(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // ── BACKUP ──
                  _DataCard(
                    // Deliberately NOT ios_share: the two cards have to be
                    // told apart at a glance, and the share glyph is spoken
                    // for by Export above.
                    icon: Icons.backup_outlined,
                    title: 'Back up your history',
                    body: const [
                      'A backup file holds everything, so you can bring your '
                          'events onto a new phone or recover them if this one '
                          'is lost. Save it somewhere off this device.',
                      // "not readable in a spreadsheet" was overstated: Excel
                      // can import JSON via Power Query. This says the same
                      // thing without the claim that is not quite true.
                      'This is your copy. It is not a spreadsheet file.',
                    ],
                    actions: [
                      _CardAction(
                        label: 'Back up now',
                        primary: true,
                        onPressed: () => onBackUp(context),
                      ),
                      _CardAction(
                        label: 'Restore from a backup',
                        primary: false,
                        onPressed: () => onRestore(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // ── FOOTER ──
                  const Padding(
                    padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
                    child: Text(
                      'Notiva never receives your events and cannot recover '
                      'them for you. A file you have saved somewhere else is '
                      'the only copy that survives losing this phone.',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: MERColours.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One action on a [_DataCard]. [primary] gets the filled treatment.
class _CardAction {
  const _CardAction({
    required this.label,
    required this.primary,
    required this.onPressed,
  });

  final String label;
  final bool primary;
  final Future<void> Function() onPressed;
}

class _DataCard extends StatelessWidget {
  const _DataCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.actions,
  });

  final IconData icon;
  final String title;
  final List<String> body;
  final List<_CardAction> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MERColours.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  // An existing token rather than primary.withOpacity(): no new
                  // colour literal, and withOpacity is deprecated.
                  color: MERColours.background,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 19, color: MERColours.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: MERColours.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final paragraph in body) ...[
            Text(
              paragraph,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: MERColours.textMuted,
              ),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 2),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final action in actions)
                action.primary
                    ? FilledButton(
                        onPressed: action.onPressed,
                        child: Text(action.label),
                      )
                    : OutlinedButton(
                        onPressed: action.onPressed,
                        child: Text(action.label),
                      ),
            ],
          ),
        ],
      ),
    );
  }
}
