import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

const String kAppName = 'Medical Event Recorder';
const String kAppVersion = '1.0.0';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AppBootstrap());
}

/* ===========================
   BOOTSTRAP + DISCLAIMER
   =========================== */

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  bool _ready = false;
  bool _accepted = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = await SharedPreferences.getInstance();
      final accepted = prefs.getBool('disclaimerAccepted') ?? false;

      if (!mounted) return;
      setState(() {
        _accepted = accepted;
        _ready = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),

      // ✅ GLOBAL KEYBOARD DISMISS: tap anywhere outside to hide keyboard
      builder: (context, child) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: child ?? const SizedBox.shrink(),
        );
      },

      home: !_ready
          ? const SplashLoadingScreen()
          : (_accepted ? const HomeScreen() : const DisclaimerScreen()),
    );
  }
}

class SplashLoadingScreen extends StatelessWidget {
  const SplashLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

/* ===========================
   DISCLAIMER (Official format)
   =========================== */

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
        title: const Text('Medical & Legal Disclaimer'),
        centerTitle: true,
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
                    Text(
                      'Important Notice',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This application is provided for personal record‑keeping purposes only.',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'It is not a medical device and is not intended to diagnose, treat, cure, or prevent any disease or medical condition.',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 0,
                      color: theme.colorScheme.surfaceContainerHighest,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Limitations',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const _DisclaimerBullet(
                              text:
                                  'This app does not provide medical advice or clinical recommendations.',
                            ),
                            const _DisclaimerBullet(
                              text:
                                  'Data recorded in this app may be incomplete, inaccurate, or misinterpreted.',
                            ),
                            const _DisclaimerBullet(
                              text:
                                  'The app must not be used as a substitute for professional medical assessment or care.',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Medical Advice',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Always seek the advice of a qualified healthcare professional with any questions regarding a medical condition. '
                      'Never disregard professional medical advice or delay seeking it because of information recorded in this app.',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Emergency Situations',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This app must not be used in emergency situations. '
                      'If you believe you are experiencing a medical emergency, contact emergency services immediately.',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Data Storage & Privacy',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All data entered into this application is stored locally on your device. '
                      'The developer does not collect, transmit, or store your personal or medical information.',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
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
          const Text('•  ', style: TextStyle(fontSize: 18)),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ],
      ),
    );
  }
}

/* ===========================
   HELPERS
   =========================== */

Rect shareOriginRect(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return const Rect.fromLTWH(0, 0, 1, 1);
  final rect = box.localToGlobal(Offset.zero) & box.size;
  if (rect.width == 0 || rect.height == 0) return const Rect.fromLTWH(0, 0, 1, 1);
  return rect;
}

enum DurationCategory { lt1, oneToFive, gt5 }

String durationLabel(DurationCategory c) {
  switch (c) {
    case DurationCategory.lt1:
      return '< 1 minute';
    case DurationCategory.oneToFive:
      return '1–5 minutes';
    case DurationCategory.gt5:
      return '> 5 minutes';
  }
}

/* ===========================
   DURATION SELECTOR (Responsive chips)
   =========================== */

class DurationTiles extends StatelessWidget {
  final DurationCategory selected;
  final ValueChanged<DurationCategory> onSelected;

  const DurationTiles({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isWide = constraints.maxWidth >= 520;

        Widget chip(DurationCategory d, {bool expand = false}) {
          final isSelected = selected == d;
          final scheme = Theme.of(ctx).colorScheme;

          final chipWidget = FilterChip(
            label: Text(
              durationLabel(d),
              style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
            selected: isSelected,
            showCheckmark: true,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            labelPadding: const EdgeInsets.symmetric(horizontal: 6),
            materialTapTargetSize: MaterialTapTargetSize.padded,
            selectedColor: scheme.primaryContainer,
            checkmarkColor: scheme.primary,
            side: BorderSide(
              color: isSelected ? scheme.primary : scheme.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
            onSelected: (_) => onSelected(d),
          );

          return expand ? Expanded(child: chipWidget) : chipWidget;
        }

        if (isWide) {
          return Row(
            children: [
              chip(DurationCategory.lt1, expand: true),
              const SizedBox(width: 10),
              chip(DurationCategory.oneToFive, expand: true),
              const SizedBox(width: 10),
              chip(DurationCategory.gt5, expand: true),
            ],
          );
        }

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            chip(DurationCategory.lt1),
            chip(DurationCategory.oneToFive),
            chip(DurationCategory.gt5),
          ],
        );
      },
    );
  }
}

/* ===========================
   MODEL + STORAGE
   =========================== */

class EventRecord {
  final String id;
  final DateTime timestamp;
  final DurationCategory duration;
  final List<String> feelings;
  final bool referralRequired;
  final String notes;

  EventRecord({
    required this.id,
    required this.timestamp,
    required this.duration,
    required this.feelings,
    required this.referralRequired,
    required this.notes,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'duration': duration.name,
        'feelings': feelings,
        'referralRequired': referralRequired,
        'notes': notes,
      };

  static EventRecord fromMap(Map<String, dynamic> map) {
    final feelingsRaw = map['feelings'];
    final notesRaw = map['notes'];
    final referralRaw = map['referralRequired'];

    return EventRecord(
      id: (map['id'] ?? '') as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      duration: DurationCategory.values.firstWhere(
        (e) => e.name == map['duration'],
        orElse: () => DurationCategory.oneToFive,
      ),
      feelings:
          (feelingsRaw is List) ? feelingsRaw.map((e) => e.toString()).toList() : <String>[],
      referralRequired: (referralRaw is bool) ? referralRaw : false,
      notes: (notesRaw is String) ? notesRaw : '',
    );
  }
}

class EventStore {
  static const String _storageKey = 'epilepsy_event_records_v1';

  Future<List<EventRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    final list =
        decoded.map((e) => EventRecord.fromMap(e as Map<String, dynamic>)).toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  Future<void> save(List<EventRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(records.map((e) => e.toMap()).toList());
    await prefs.setString(_storageKey, payload);
  }
}

/* ===========================
   CSV EXPORT (column order + header note)
   =========================== */

String _csvEscape(String v) {
  final needsQuotes =
      v.contains(',') || v.contains('"') || v.contains('\n') || v.contains('\r');
  if (!needsQuotes) return v;
  return '"${v.replaceAll('"', '""')}"';
}

String buildCsv(List<EventRecord> items) {
  final fmtLocal = DateFormat.yMMMd().add_jm();
  final sb = StringBuffer();

  sb.writeln('# $kAppName export');
  sb.writeln('# referral_required: Yes = medical referral was required');
  sb.writeln(
      '# Column order: timestamp_iso, timestamp_local, duration, feelings, referral_required, notes');

  final header = [
    'timestamp_iso',
    'timestamp_local',
    'duration',
    'feelings',
    'referral_required',
    'notes',
  ];
  sb.writeln(header.join(','));

  for (final r in items.reversed) {
    final row = [
      r.timestamp.toIso8601String(),
      fmtLocal.format(r.timestamp),
      durationLabel(r.duration),
      r.feelings.join('; '),
      r.referralRequired ? 'Yes' : 'No',
      r.notes,
    ];
    sb.writeln(row.map(_csvEscape).join(','));
  }
  return sb.toString();
}

/* ===========================
   EXPORT (3 OPTIONS WIRED IN)
   =========================== */

