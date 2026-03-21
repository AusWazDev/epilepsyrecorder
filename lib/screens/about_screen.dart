import 'package:flutter/material.dart';

import '../constants.dart';
import '../theme/mer_theme.dart';
import '../widgets/mer_icon_widget.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize:       MainAxisSize.min,
          children: [
            Text(
              'About',
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
        child: Column(
          children: [

            // ── HERO ──
            Container(
              width:  double.infinity,
              color:  MERColours.primary,
              padding: const EdgeInsets.symmetric(
                vertical:   32,
                horizontal: 24,
              ),
              child: Column(
                children: [
                  Container(
                    width:  72,
                    height: 72,
                    decoration: BoxDecoration(
                      color:        Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.22),
                        width: 1.5,
                      ),
                    ),
                    child: const Center(
                      child: MERIconWidget(size: 44),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    kAppName,
                    style: TextStyle(
                      fontSize:   18,
                      fontWeight: FontWeight.w700,
                      color:      Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version $kAppVersion',
                    style: TextStyle(
                      fontSize: 13,
                      color:    Colors.white.withOpacity(0.55),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Track · Record · Understand',
                    style: TextStyle(
                      fontSize:      11,
                      color:         Colors.white.withOpacity(0.4),
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            // ── DETAILS ──
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // App info card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'APP INFO',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 12),
                          _InfoRow(
                            label: 'Version',
                            value: kAppVersion,
                          ),
                          _InfoRow(
                            label: 'Platform',
                            value: _platformName(),
                          ),
                          _InfoRow(
                            label: 'Data storage',
                            value: 'Local device only',
                          ),
                          _InfoRow(
                            label: 'Purpose',
                            value: 'Personal record‑keeping',
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Legal card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LEGAL',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'This application is provided for personal '
                            'record‑keeping purposes only. It is not a '
                            'medical device and is not intended to diagnose, '
                            'treat, cure, or prevent any disease or medical '
                            'condition.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(height: 1.6),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'All data is stored locally on your device. '
                            'The developer does not collect, transmit, or '
                            'store any personal or medical information.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(height: 1.6),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Developer card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DEVELOPER',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 12),
                          _InfoRow(
                            label: 'App',
                            value: kAppName,
                          ),
                          _InfoRow(
                            label: 'Built with',
                            value: 'Flutter',
                          ),
                          _InfoRow(
                            label: 'Platforms',
                            value: 'iOS · Android · Windows',
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Emergency notice
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
                          'Emergency Notice',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color:      const Color(0xFF712B13),
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'This app must not be used in emergency '
                          'situations. If you believe you are experiencing '
                          'a medical emergency, contact emergency services '
                          'immediately.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color:  const Color(0xFF993C1D),
                                height: 1.5,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _platformName() {
    try {
      if (const bool.fromEnvironment('dart.library.io')) {
        return 'Desktop / Mobile';
      }
    } catch (_) {}
    return 'Unknown';
  }
}

/* ===========================
   INFO ROW
   =========================== */

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool   isLast;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color:      MERColours.textPrimary,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height:    1,
            thickness: 0.5,
            color:     MERColours.border,
          ),
      ],
    );
  }
}