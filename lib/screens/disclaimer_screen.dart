import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants.dart';
import '../theme/mer_theme.dart';
import '../widgets/mer_icon_widget.dart';
import 'home_screen.dart';

class DisclaimerScreen extends StatelessWidget {
  const DisclaimerScreen({super.key});

  Future<void> _accept(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('disclaimerAcceptedVersion', kDisclaimerVersion);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            MERIconWidget(size: 40, style: MERIconStyle.mark),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize:       MainAxisSize.min,
              children: [
                Text(
                  'Medical Event Recorder',
                  style: TextStyle(
                    fontSize:   13,
                    fontWeight: FontWeight.w600,
                    color:      Colors.white,
                  ),
                ),
                Text(
                  'Medical & Legal Disclaimer',
                  style: TextStyle(
                    fontSize: 10,
                    color:    Colors.white54,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // ── WARNING CARD ──
                    Container(
                      width:   double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color:        const Color(0xFFFAECE7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: MERColours.alert,
                          width: 0.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Important Notice',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color:      const Color(0xFF712B13),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'This application is provided for personal '
                            'record‑keeping purposes only.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color:  const Color(0xFF993C1D),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'It is not a medical device. It is not intended '
                            'to diagnose, screen for, prevent, monitor, '
                            'predict, make a prognosis of, mitigate, '
                            'alleviate, treat or cure any disease, condition, '
                            'ailment or defect, and it is not intended to '
                            'make or support any recommendation or decision '
                            'about treatment.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color:  const Color(0xFF993C1D),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // ── LIMITATIONS ──
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LIMITATIONS',
                              style: theme.textTheme.labelLarge,
                            ),
                            const SizedBox(height: 10),
                            const _DisclaimerBullet(
                              text: 'This app does not provide medical advice '
                                  'or clinical recommendations.',
                            ),
                            const _DisclaimerBullet(
                              text: 'This app does not analyse, interpret or '
                                  'draw conclusions from what you record.',
                            ),
                            const _DisclaimerBullet(
                              text: 'Data recorded may be incomplete, '
                                  'inaccurate, or misinterpreted.',
                            ),
                            const _DisclaimerBullet(
                              text: 'Must not be used as a substitute for '
                                  'professional medical assessment or care.',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── MEDICAL ADVICE ──
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'MEDICAL ADVICE',
                              style: theme.textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Always seek the advice of a qualified '
                              'healthcare professional with any questions '
                              'regarding a medical condition. Never disregard '
                              'professional medical advice because of '
                              'information recorded in this app.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── EMERGENCY ──
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'EMERGENCY SITUATIONS',
                              style: theme.textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            Text.rich(
                              const TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Medical Event Recorder records '
                                        'events; it does not respond to them '
                                        'and cannot summon help. ',
                                  ),
                                  TextSpan(
                                    text: 'Never delay calling for help in '
                                        'order to record an event.',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' In a medical emergency, call 000 '
                                        '(Australia) or your local emergency '
                                        'number immediately.',
                                  ),
                                ],
                              ),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── PRIVACY ──
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DATA STORAGE & PRIVACY',
                              style: theme.textTheme.labelLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'All event data entered into this application '
                              'is stored locally on your device. The '
                              'developer does not collect, transmit or store '
                              'your personal or medical information.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'The app sends anonymous crash reports to a '
                              'third-party error-monitoring service so faults '
                              'can be diagnosed and fixed. These reports '
                              'contain no event data and no information that '
                              'identifies you.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text.rich(
                              const TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'Because there is no account and no '
                                        'cloud copy, ',
                                  ),
                                  TextSpan(
                                    text: 'deleting the app deletes every '
                                        'event with it, and neither you nor '
                                        'Notiva can recover them.',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' Your events are included in a '
                                        'normal device backup, so restoring '
                                        'one onto a new phone does bring them '
                                        'across. Backing up or exporting to a '
                                        'file is the only way to keep a copy '
                                        'that does not depend on this device.',
                                  ),
                                ],
                              ),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: () => launchUrl(
                                Uri.parse(kPrivacyUrl),
                                mode: LaunchMode.externalApplication,
                              ),
                              child: Text(
                                'Read our full Privacy Policy →',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color:           MERColours.primary,
                                  fontWeight:      FontWeight.w600,
                                  decoration:      TextDecoration.underline,
                                  decorationColor: MERColours.primary,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => launchUrl(
                                Uri.parse(kTermsUrl),
                                mode: LaunchMode.externalApplication,
                              ),
                              child: Text(
                                'Read our full Terms of Service →',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color:           MERColours.primary,
                                  fontWeight:      FontWeight.w600,
                                  decoration:      TextDecoration.underline,
                                  decorationColor: MERColours.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── AGREE BUTTON ──
            SafeArea(
              top: false,
              child: SizedBox(
                width:  double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: () => _accept(context),
                  child: const Text(
                    'I Understand and Agree',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DisclaimerBullet extends StatelessWidget {
  final String text;
  const _DisclaimerBullet({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '•  ',
            style: TextStyle(
              fontSize: 18,
              color:    MERColours.textMuted,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}