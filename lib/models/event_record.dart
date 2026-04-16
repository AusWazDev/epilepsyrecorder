import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import '../constants.dart';

/* ===========================
   ENUMS
   =========================== */

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

enum EventType { seizure, absence, medication, other }

String eventTypeLabel(EventType t) {
  switch (t) {
    case EventType.seizure:
      return 'Seizure / fit';
    case EventType.absence:
      return 'Absence episode';
    case EventType.medication:
      return 'Medication taken';
    case EventType.other:
      return 'Other / custom';
  }
}

enum EventSeverity { mild, moderate, severe }

String severityLabel(EventSeverity s) {
  switch (s) {
    case EventSeverity.mild:
      return 'Mild';
    case EventSeverity.moderate:
      return 'Moderate';
    case EventSeverity.severe:
      return 'Severe';
  }
}

/* ===========================
   MODEL
   =========================== */

class EventRecord {
  final String id;
  final DateTime timestamp;
  final DurationCategory duration;
  final List<String> feelings;
  final bool referralRequired;
  final String notes;

  // New fields — all have safe defaults for old saved records
  final EventType eventType;
  final EventSeverity severity;
  final List<String> triggers;

  EventRecord({
    required this.id,
    required this.timestamp,
    required this.duration,
    required this.feelings,
    required this.referralRequired,
    required this.notes,
    this.eventType = EventType.seizure,
    this.severity  = EventSeverity.mild,
    this.triggers  = const [],
  });

  Map<String, dynamic> toMap() => {
        'id':               id,
        'timestamp':        timestamp.toIso8601String(),
        'duration':         duration.name,
        'feelings':         feelings,
        'referralRequired': referralRequired,
        'notes':            notes,
        'eventType':        eventType.name,
        'severity':         severity.name,
        'triggers':         triggers,
      };

  static EventRecord fromMap(Map<String, dynamic> map) {
    final feelingsRaw = map['feelings'];
    final triggersRaw = map['triggers'];
    final notesRaw    = map['notes'];
    final referralRaw = map['referralRequired'];

    return EventRecord(
      id:        (map['id'] ?? '') as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      duration: DurationCategory.values.firstWhere(
        (e) => e.name == map['duration'],
        orElse: () => DurationCategory.lt1,
      ),
      feelings: (feelingsRaw is List)
          ? feelingsRaw.map((e) => e.toString()).toList()
          : <String>[],
      referralRequired: (referralRaw is bool) ? referralRaw : false,
      notes:            (notesRaw is String) ? notesRaw : '',
      // New fields — safe fallbacks for old records
      eventType: EventType.values.firstWhere(
        (e) => e.name == map['eventType'],
        orElse: () => EventType.seizure,
      ),
      severity: EventSeverity.values.firstWhere(
        (e) => e.name == map['severity'],
        orElse: () => EventSeverity.mild,
      ),
      triggers: (triggersRaw is List)
          ? triggersRaw.map((e) => e.toString()).toList()
          : <String>[],
    );
  }
}

/* ===========================
   STORAGE
   =========================== */

class EventStore {
  static const String _storageKey = 'epilepsy_event_records_v1';

  Future<List<EventRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map((e) => EventRecord.fromMap(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> save(List<EventRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(records.map((e) => e.toMap()).toList()),
    );
  }

  Future<SharedPreferences> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    return prefs;
  }
}

/* ===========================
   HELPERS
   =========================== */

Rect shareOriginRect(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return const Rect.fromLTWH(0, 0, 1, 1);
  final rect = box.localToGlobal(Offset.zero) & box.size;
  if (rect.width == 0 || rect.height == 0) {
    return const Rect.fromLTWH(0, 0, 1, 1);
  }
  return rect;
}

/* ===========================
   CSV EXPORT
   =========================== */

String _csvEscape(String v) {
  final needsQuotes = v.contains(',') ||
      v.contains('"') ||
      v.contains('\n') ||
      v.contains('\r');
  if (!needsQuotes) return v;
  return '"${v.replaceAll('"', '""')}"';
}

String buildCsv(List<EventRecord> items) {
  final fmtLocal = DateFormat.yMMMd().add_jm();
  final sb       = StringBuffer();

  sb.writeln('# $kAppName export');
  sb.writeln('# referral_required: Yes = medical referral was required');
  sb.writeln(
    '# Column order: timestamp_iso, timestamp_local, event_type, '
    'duration, severity, feelings, triggers, referral_required, notes',
  );

  sb.writeln([
    'timestamp_iso',
    'timestamp_local',
    'event_type',
    'duration',
    'severity',
    'feelings',
    'triggers',
    'referral_required',
    'notes',
  ].join(','));

  for (final r in items.reversed) {
    sb.writeln([
      r.timestamp.toIso8601String(),
      fmtLocal.format(r.timestamp),
      eventTypeLabel(r.eventType),
      durationLabel(r.duration),
      severityLabel(r.severity),
      r.feelings.join('; '),
      r.triggers.join('; '),
      r.referralRequired ? 'Yes' : 'No',
      r.notes,
    ].map(_csvEscape).join(','));
  }
  return sb.toString();
}

/* ===========================
   EXPORT OPTIONS
   =========================== */

Future<File> _buildCsvTempFile(
  List<EventRecord> items, {
  String? filenamePrefix,
}) async {
  final csv = buildCsv(items);
  final dir = await getTemporaryDirectory();
  final ts  = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
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
  final file =
      await _buildCsvTempFile(items, filenamePrefix: filenamePrefix);
  if (!context.mounted) return;
  await SharePlus.instance.share(
    ShareParams(
      subject: '$kAppName export (CSV)',
      text:    '$kAppName CSV export',
      files:   [XFile(file.path, mimeType: 'text/csv')],
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
  final ts  = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  final prefix = (filenamePrefix == null || filenamePrefix.isEmpty)
      ? 'medical_event_recorder'
      : filenamePrefix;
  final filename = '${prefix}_$ts.csv';

  // ── ANDROID — save to Downloads ──
  if (Platform.isAndroid) {
    try {
      final dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) await dir.create(recursive: true);
      final file = File('${dir.path}/$filename');
      await file.writeAsString(csv, flush: true);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved to Downloads/$filename'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save to Downloads. Try Share instead.'),
        ),
      );
    }
    return;
  }

  // ── DESKTOP — file picker save dialog ──
  final location = await getSaveLocation(
    suggestedName: filename,
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
              await Process.start('explorer', [location.path],
                  runInShell: true);
            } else if (Platform.isMacOS) {
              await Process.start('open', [location.path],
                  runInShell: true);
            } else if (Platform.isLinux) {
              await Process.start('xdg-open', [location.path],
                  runInShell: true);
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No events to export.')),
    );
    return;
  }
  await showModalBottomSheet(
    context:       context,
    showDragHandle: true,
    builder: (ctx) {
      final isIOS = Platform.isIOS;
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

            // ── HEADER LABEL ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Row(
                children: [
                  const Text(
                    'Export events',
                    style: TextStyle(
                      fontSize:   13,
                      fontWeight: FontWeight.w600,
                      color:      Colors.black45,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const Spacer(),
                  const _ExportIconWidget(),
                ],
              ),
            ),
            const Divider(height: 1),

            // ── SHARE ──
            ListTile(
              leading: Container(
                width:  36,
                height: 36,
                decoration: BoxDecoration(
                  color:        const Color(0xFFEAF4FB),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.ios_share,
                  size:  18,
                  color: Color(0xFF1A8FCB),
                ),
              ),
              title: const Text(
                'Share to apps',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: const Text(
                'Email, cloud storage, spreadsheets',
              ),
              onTap: () async {
                Navigator.pop(ctx);
                await exportCsvShare(
                  context,
                  items,
                  filenamePrefix: filenamePrefix,
                );
              },
            ),

            // ── SAVE (non-iOS only) ──
            if (!isIOS)
              ListTile(
                leading: Container(
                  width:  36,
                  height: 36,
                  decoration: BoxDecoration(
                    color:        const Color(0xFFEAF4FB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.save_alt,
                    size:  18,
                    color: Color(0xFF1A8FCB),
                  ),
                ),
                title: const Text(
                  'Save to device',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: const Text(
                  'Choose location and file name',
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await exportCsvSaveAs(
                    context,
                    items,
                    filenamePrefix: filenamePrefix,
                  );
                },
              ),

            // ── CANCEL ──
            ListTile(
              leading: Container(
                width:  36,
                height: 36,
                decoration: BoxDecoration(
                  color:        const Color(0xFFFAECE7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.close,
                  size:  18,
                  color: Color(0xFFE05B3A),
                ),
              ),
              title: const Text(
                'Cancel',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color:      Color(0xFFE05B3A),
                ),
              ),
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
   EXPORT ICON WIDGET
   =========================== */

class _ExportIconWidget extends StatelessWidget {
  const _ExportIconWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  30,
      height: 30,
      decoration: BoxDecoration(
        color:        Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(
        Icons.download_outlined,
        size:  18,
        color: Colors.white,
      ),
    );
  }
}