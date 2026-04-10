import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

                  // App card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'APP',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 12),
                          _InfoRow(
                            label: 'Developer',
                            value: kCompanyName,
                          ),
                          _InfoRow(
                            label: 'Version',
                            value: kAppVersion,
                          ),
                          _InfoRow(
                            label: 'Platforms',
                            value: 'iOS · Android · Windows',
                          ),
                          _InfoRow(
                            label: 'Data storage',
                            value: 'Local device only',
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Links card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LINKS',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 12),
                          _LinkRow(
                            label: 'Website',
                            url:   kWebsiteUrl,
                          ),
                          _LinkRow(
                            label: 'Privacy Policy',
                            url:   kPrivacyUrl,
                          ),
                          _LinkRow(
                            label:  'Support',
                            url:    'mailto:$kSupportEmail',
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
                          const Divider(height: 20, thickness: 0.5),
                          Text(
                            'For personal record‑keeping only. Not a medical '
                            'device. Does not diagnose, treat, or replace '
                            'professional medical advice. All data is stored '
                            'locally on your device.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(height: 1.6),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
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

}

/* ===========================
   LINK ROW
   =========================== */

class _LinkRow extends StatelessWidget {
  final String label;
  final String url;
  final bool   isLast;

  const _LinkRow({
    required this.label,
    required this.url,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () => launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Row(
                  children: [
                    Text(
                      url.startsWith('mailto:')
                          ? url.replaceFirst('mailto:', '')
                          : url
                              .replaceFirst('https://', '')
                              .replaceFirst('www.', ''),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color:      MERColours.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.open_in_new,
                      size:  14,
                      color: MERColours.primary,
                    ),
                  ],
                ),
              ],
            ),
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