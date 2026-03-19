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

Future<File> _buildCsvTempFile(
  List<EventRecord> items, {
  String? filenamePrefix,
}) async {
  final csv = buildCsv(items);
  final dir = await getTemporaryDirectory();
  final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final prefix = (filenamePrefix == null || filenamePrefix.isEmpty)
      ? 'medical_event_recorder'
      : filenamePrefix;

  final file = File('${dir.path}/${prefix}_$ts.csv');
  await file.writeAsString(csv, flush: true);
  return file;
}

Future<void> exportCsvShare(
  BuildContext context,
  List<EventRecord> items, {
  String? filenamePrefix,
}) async {
  if (items.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No events to export.')),
    );
    return;
  }

  final file = await _buildCsvTempFile(items, filenamePrefix: filenamePrefix);

  if (!context.mounted) return;

  await SharePlus.instance.share(
    ShareParams(
      subject: '$kAppName export (CSV)',
      text: '$kAppName CSV export',
      files: [XFile(file.path, mimeType: 'text/csv')],
      sharePositionOrigin: shareOriginRect(context),
    ),
  );
}

Future<void> exportCsvSaveAs(
  BuildContext context,
  List<EventRecord> items, {
  String? filenamePrefix,
}) async {
  if (items.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No events to export.')),
    );
    return;
  }

  final csv = buildCsv(items);
  final ts = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final prefix = (filenamePrefix == null || filenamePrefix.isEmpty)
      ? 'medical_event_recorder'
      : filenamePrefix;

  final location = await getSaveLocation(
    suggestedName: '${prefix}_$ts.csv',
    acceptedTypeGroups: const [
      XTypeGroup(label: 'CSV files', extensions: ['csv']),
    ],
  );

  if (location == null) return;

  await File(location.path).writeAsString(csv, flush: true);

  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('CSV saved'),
      action: SnackBarAction(
        label: 'Open',
        onPressed: () async {
          try {
            if (Platform.isWindows) {
              await Process.start('explorer', [location.path], runInShell: true);
            } else if (Platform.isMacOS) {
              await Process.start('open', [location.path], runInShell: true);
            } else if (Platform.isLinux) {
              await Process.start('xdg-open', [location.path], runInShell: true);
            }
          } catch (_) {}
        },
      ),
    ),
  );
}

Future<void> showExportOptions(
  BuildContext context,
  List<EventRecord> items, {
  String? filenamePrefix,
}) async {
  if (items.isEmpty) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('No events to export.')));
    return;
  }

  await showModalBottomSheet(
    context: context,
    showDragHandle: true,
    builder: (ctx) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.ios_share),
              title: const Text('Share to apps'),
              subtitle: const Text('OneDrive, iCloud, Google Drive, Files, email'),
              onTap: () async {
                Navigator.pop(ctx);
                await exportCsvShare(
                  context,
                  items,
                  filenamePrefix: filenamePrefix,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: const Text('Save to device'),
              subtitle: const Text('Choose location and file name'),
              onTap: () async {
                Navigator.pop(ctx);
                await exportCsvSaveAs(
                  context,
                  items,
                  filenamePrefix: filenamePrefix,
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 8),
          ],
        ),
      );
    },
  );
}

/* ===========================
   HOME (Record-only + menu)
   =========================== */

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _HomeMenuAction {
  history,
  exportAll,
  resetDisclaimer,
  about,
}

class _HomeScreenState extends State<HomeScreen> {
  final _store = EventStore();
  final _uuid = const Uuid();

  List<EventRecord> _records = [];
  bool _loaded = false;

  final List<String> _feelingsOptions = const [
    'Tired and weary',
    'Just Tired',
    'Just Weary',
    'Experiencing a headache',
    'Sad',
    'Confused',
    'Annoyed',
    'Angry',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final loaded = await _store.load();
      if (!mounted) return;
      setState(() {
        _records = loaded;
        _loaded = true;
      });
    });
  }

  Future<void> _persist() => _store.save(_records);

  Future<void> _quickRecord() async {
    final rec = EventRecord(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      duration: DurationCategory.lt1,
      feelings: const [],
      referralRequired: false,
      notes: '',
    );

    setState(() => _records.insert(0, rec));
    await _persist();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Event recorded'),
        action: SnackBarAction(
          label: 'Edit',
          onPressed: () => _editEvent(existing: rec),
        ),
      ),
    );
  }

  Future<void> _recordWithDetails() async {
    await _editEvent(existing: null);
  }

  Future<EventRecord?> _editEvent({EventRecord? existing, bool confirmOnSave = false}) async {
    DurationCategory duration = existing?.duration ?? DurationCategory.lt1;
    final selectedFeelings = (existing?.feelings ?? const <String>[]).toSet();
    bool referralRequired = existing?.referralRequired ?? false;
    final notesController = TextEditingController(text: existing?.notes ?? '');
    final isNew = existing == null;

    final originalDuration = existing?.duration;
    final originalFeelings = (existing?.feelings ?? const <String>[]).toSet();
    final originalReferral = existing?.referralRequired ?? false;
    final originalNotes = (existing?.notes ?? '').trim();

    bool sameSet(Set<String> a, Set<String> b) =>
        a.length == b.length && a.containsAll(b);

    final result = await showModalBottomSheet<EventRecord>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 8,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSheetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isNew ? 'Record event' : 'Edit event',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text('Duration', style: Theme.of(ctx).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  DurationTiles(
                    selected: duration,
                    onSelected: (d) => setSheetState(() => duration = d),
                  ),
                  const SizedBox(height: 12),
                  Text('Feelings', style: Theme.of(ctx).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: _feelingsOptions.map((f) {
                      final isSelected = selectedFeelings.contains(f);
                      return FilterChip(
                        label: Text(
                          f,
                          style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                                fontWeight:
                                    isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                        ),
                        selected: isSelected,
                        showCheckmark: true,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        labelPadding:
                            const EdgeInsets.symmetric(horizontal: 6),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        selectedColor:
                            Theme.of(ctx).colorScheme.primaryContainer,
                        checkmarkColor: Theme.of(ctx).colorScheme.primary,
                        side: BorderSide(
                          color: isSelected
                              ? Theme.of(ctx).colorScheme.primary
                              : Theme.of(ctx).colorScheme.outlineVariant,
                          width: isSelected ? 2 : 1,
                        ),
                        onSelected: (sel) {
                          setSheetState(() {
                            sel
                                ? selectedFeelings.add(f)
                                : selectedFeelings.remove(f);
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  Text('Medical referral required?',
                      style: Theme.of(ctx).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      ChoiceChip(
                        label: Text(
                          'No',
                          style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                                fontWeight: referralRequired
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                              ),
                        ),
                        selected: !referralRequired,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        labelPadding:
                            const EdgeInsets.symmetric(horizontal: 6),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        selectedColor:
                            Theme.of(ctx).colorScheme.primaryContainer,
                        side: BorderSide(
                          color: !referralRequired
                              ? Theme.of(ctx).colorScheme.primary
                              : Theme.of(ctx).colorScheme.outlineVariant,
                          width: !referralRequired ? 2 : 1,
                        ),
                        onSelected: (_) =>
                            setSheetState(() => referralRequired = false),
                      ),
                      ChoiceChip(
                        label: Text(
                          'Yes',
                          style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(
                                fontWeight: referralRequired
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                        ),
                        selected: referralRequired,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        labelPadding:
                            const EdgeInsets.symmetric(horizontal: 6),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        selectedColor:
                            Theme.of(ctx).colorScheme.primaryContainer,
                        side: BorderSide(
                          color: referralRequired
                              ? Theme.of(ctx).colorScheme.primary
                              : Theme.of(ctx).colorScheme.outlineVariant,
                          width: referralRequired ? 2 : 1,
                        ),
                        onSelected: (_) =>
                            setSheetState(() => referralRequired = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Notes (optional)'),
                    children: [
                      TextField(
                        controller: notesController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Add notes if helpful',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () async {
                          final updated = EventRecord(
                            id: existing?.id ?? _uuid.v4(),
                            timestamp: existing?.timestamp ?? DateTime.now(),
                            duration: duration,
                            feelings: selectedFeelings.toList(),
                            referralRequired: referralRequired,
                            notes: notesController.text.trim(),
                          );

                          final hasChanges = existing == null
                              ? true
                              : updated.duration != originalDuration ||
                                  updated.referralRequired != originalReferral ||
                                  updated.notes.trim() != originalNotes ||
                                  !sameSet(updated.feelings.toSet(), originalFeelings);

                          if (confirmOnSave && existing != null) {
                            if (!hasChanges) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('No changes to save.')),
                                );
                              }
                              if (ctx.mounted) Navigator.pop(ctx);
                              return;
                            }

                            final changes = <String>[];
                            if (updated.duration != originalDuration) {
                              changes.add(
                                'Duration: ${durationLabel(originalDuration!)} → ${durationLabel(updated.duration)}',
                              );
                            }
                            if (updated.referralRequired != originalReferral) {
                              changes.add(
                                'Medical referral: ${originalReferral ? "Yes" : "No"} → ${updated.referralRequired ? "Yes" : "No"}',
                              );
                            }
                            if (!sameSet(updated.feelings.toSet(), originalFeelings)) {
                              changes.add('Feelings updated');
                            }
                            if (updated.notes.trim() != originalNotes) {
                              changes.add('Notes updated');
                            }

                            final ok = await showDialog<bool>(
                              context: ctx,
                              builder: (dCtx) => AlertDialog(
                                title: const Text('Confirm changes'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Save the following changes?'),
                                    const SizedBox(height: 12),
                                    ...changes.map((c) => Padding(
                                          padding:
                                              const EdgeInsets.only(bottom: 6),
                                          child: Text('• $c'),
                                        )),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(dCtx, false),
                                    child: const Text('Keep editing'),
                                  ),
                                  FilledButton(
                                    onPressed: () => Navigator.pop(dCtx, true),
                                    child: const Text('Save'),
                                  ),
                                ],
                              ),
                            );

                            if (ok != true) return;
                          }

                          setState(() {
                            if (isNew) {
                              _records.insert(0, updated);
                            } else {
                              final index = _records.indexWhere((r) => r.id == existing.id);
                              if (index != -1) _records[index] = updated;
                            }
                          });

                          await _persist();
                          if (ctx.mounted) Navigator.pop(ctx, updated);
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    return result;
  }

  Future<void> _confirmResetDisclaimer() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset app?'),
        content: const Text(
          'This will clear all events and show the disclaimer again.\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppBootstrap()),
        (route) => false,
      );
    }
  }

  void _openHistory() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HistoryScreen(
          records: _records,
          feelingsOptions: _feelingsOptions,
          onRecordsChanged: (updated) async {
            setState(() => _records = updated);
            await _persist();
          },
          onEdit: (existing, {required confirmOnSave}) =>
              _editEvent(existing: existing, confirmOnSave: confirmOnSave),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final countText = _loaded ? '${_records.length} saved' : 'Loading…';

    return Scaffold(
      appBar: AppBar(
        title: const Text(kAppName),
        actions: [
          PopupMenuButton<_HomeMenuAction>(
            onSelected: (action) async {
              switch (action) {
                case _HomeMenuAction.history:
                  _openHistory();
                  break;
                case _HomeMenuAction.exportAll:
                  await showExportOptions(
                    context,
                    _records,
                    filenamePrefix: 'medical_event_recorder_all',
                  );
                  break;
                case _HomeMenuAction.resetDisclaimer:
                  await _confirmResetDisclaimer();
                  break;
                case _HomeMenuAction.about:
                  showAboutDialog(
                    context: context,
                    applicationName: kAppName,
                    applicationVersion: 'v$kAppVersion',
                    applicationLegalese: 'For personal record‑keeping only.\n'
                        'Not a medical device.\n\n'
                        'All data is stored locally on your device.',
                  );
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _HomeMenuAction.history,
                child: Text('History'),
              ),
              PopupMenuItem(
                value: _HomeMenuAction.exportAll,
                child: Text('Export CSV (all events)'),
              ),
              PopupMenuItem(
                value: _HomeMenuAction.resetDisclaimer,
                child: Text('Reset app (clear all data)'),
              ),
              PopupMenuItem(
                value: _HomeMenuAction.about,
                child: Text('About'),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 320,
                height: 88,
                child: FilledButton(
                  onPressed: _quickRecord,
                  child: const Text('Record Event', style: TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.tune),
                  label: const Text('Record with details'),
                  onPressed: _recordWithDetails,
                ),
              ),
              const SizedBox(height: 18),
              Text(countText, style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 6),
              Text(
                'Tip: Use the menu (⋮) for History, Export CSV, and Reset App.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Text(
                'Version $kAppVersion',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ===========================
   HISTORY / SEARCH PAGE
   =========================== */

class HistoryScreen extends StatefulWidget {
  final List<EventRecord> records;
  final List<String> feelingsOptions;
  final Future<void> Function(List<EventRecord> updated) onRecordsChanged;

  final Future<EventRecord?> Function(EventRecord existing, {required bool confirmOnSave}) onEdit;

  const HistoryScreen({
    super.key,
    required this.records,
    required this.feelingsOptions,
    required this.onRecordsChanged,
    required this.onEdit,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late List<EventRecord> _records;

  final DateFormat _uiTimeFmt = DateFormat('EEE d MMM yyyy, h:mm a');
  final TextEditingController _searchController = TextEditingController();

  String _searchText = '';
  bool _referralOnly = false;

  @override
  void initState() {
    super.initState();
    _records = List<EventRecord>.from(widget.records);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<EventRecord> get _filteredRecords {
    final q = _searchText.trim().toLowerCase();

    return _records.where((r) {
      if (_referralOnly && !r.referralRequired) return false;

      if (q.isEmpty) return true;
      final haystack = [
        durationLabel(r.duration),
        r.feelings.join(' '),
        'referral: ${r.referralRequired ? "yes" : "no"}',
        r.notes,
        _uiTimeFmt.format(r.timestamp),
      ].join(' ').toLowerCase();

      return haystack.contains(q);
    }).toList();
  }

  Future<void> _deleteAndPersist(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this event?'),
        content: const Text(
          'This action cannot be undone.\n\nAre you sure you want to delete this event?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _records.removeWhere((r) => r.id == id));
    await widget.onRecordsChanged(_records);
  }

  @override
  Widget build(BuildContext context) {
    final shown = _filteredRecords;

    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        actions: [
          IconButton(
            tooltip: 'Export CSV (filtered)',
            icon: const Icon(Icons.ios_share),
            onPressed: () => showExportOptions(
              context,
              shown,
              filenamePrefix: 'medical_event_recorder_filtered',
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchText.isNotEmpty
                    ? IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchText = '';
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                hintText: 'Search notes, feelings, duration, referral…',
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) => setState(() => _searchText = value),
            ),
            const SizedBox(height: 10),
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: SwitchListTile(
                title: Text(
                  'Referral required only',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                subtitle: const Text('Show only events that required medical referral'),
                value: _referralOnly,
                onChanged: (value) => setState(() => _referralOnly = value),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: shown.isEmpty
                  ? const Center(
                      child: Text(
                        'No events yet.\nTap “Record Event” to get started.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.separated(
                      itemCount: shown.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final r = shown[i];
                        final notesShort = r.notes.trim().isEmpty
                            ? ''
                            : (r.notes.trim().length > 60
                                ? '${r.notes.trim().substring(0, 60)}…'
                                : r.notes.trim());

                        final line1 = durationLabel(r.duration);
                        final line2Parts = <String>[
                          if (r.feelings.isNotEmpty) r.feelings.join(', '),
                          if (r.referralRequired) 'Referral: Yes',
                          if (notesShort.isNotEmpty) 'Notes: $notesShort',
                        ];
                        final line2 = line2Parts.join(' • ');

                        return ListTile(
                          onTap: () async {
                            final updated = await widget.onEdit(r, confirmOnSave: true);
                            if (updated != null) {
                              setState(() {
                                final index = _records.indexWhere((e) => e.id == updated.id);
                                if (index != -1) _records[index] = updated;
                                _records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
                              });
                            }
                          },
                          title: Text(_uiTimeFmt.format(r.timestamp)),
                          subtitle: Text(line2.isEmpty ? line1 : '$line1\n$line2'),
                          isThreeLine: line2.isNotEmpty,
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _deleteAndPersist(r.id),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}