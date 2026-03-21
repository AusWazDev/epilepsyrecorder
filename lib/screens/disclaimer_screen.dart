import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/mer_theme.dart';
import '../widgets/mer_icon_widget.dart';
import 'home_screen.dart';

class DisclaimerScreen extends StatelessWidget {
  const DisclaimerScreen({super.key});

  Future<void> _accept(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('disclaimerAccepted', true);
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
        title: Row(
          children: [
            Container(
              width:  28,
              height: 28,
              decoration: BoxDecoration(
                color:        Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: MERIconWidget(size: 18),
              ),
            ),
            const SizedBox(width: 10),
            const Column(
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
                            'record‑keeping purposes only. It is not a '
                            'medical device and is not intended to diagnose, '
                            'treat, cure, or prevent any disease or medical '
                            'condition.',
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
                            Text(
                              'This app must not be used in emergency '
                              'situations. If you believe you are experiencing '
                              'a medical emergency, contact emergency services '
                              'immediately.',
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
                              'All data entered into this application is '
                              'stored locally on your device. The developer '
                              'does not collect, transmit, or store your '
                              'personal or medical information.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.5,
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
            SizedBox(
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