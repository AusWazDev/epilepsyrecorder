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

  static DateTime? _parseTimestamp(dynamic raw) =>
      (raw is String) ? DateTime.tryParse(raw) : null;

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

  /// Parses a stored record, or returns null if it cannot be trusted.
  ///
  /// A record with an absent or unparseable timestamp yields null and must be
  /// skipped by the caller. It is deliberately NOT defaulted to the current
  /// date: a silently wrong date in a medical record is worse than an
  /// omission. Every other field already falls back to a safe default.
  static EventRecord? fromMap(Map<String, dynamic> map) {
    final timestamp = _parseTimestamp(map['timestamp']);
    if (timestamp == null) return null;

    final feelingsRaw = map['feelings'];
    final triggersRaw = map['triggers'];
    final notesRaw    = map['notes'];
    final referralRaw = map['referralRequired'];

    return EventRecord(
      id:        (map['id'] is String) ? map['id'] as String : '',
      timestamp: timestamp,
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
  /// One unreadable record must never cost the user the whole history: every
  /// record lives in a single JSON string under a single key, so an
  /// exception here would make all of them unreachable. Entries that are not
  /// maps, and records fromMap rejects, are skipped individually.
  Future<List<EventRecord>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw   = prefs.getString(kEventStorageKey);
    if (raw == null || raw.isEmpty) return [];
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .whereType<Map>()
        .map((e) => EventRecord.fromMap(Map<String, dynamic>.from(e)))
        .whereType<EventRecord>()
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> save(List<EventRecord> records) async {
    final prefs = await SharedPreferences.getInstance();
    await writeEventPayload(
      prefs,
      jsonEncode(records.map((e) => e.toMap()).toList()),
    );
  }

  Future<SharedPreferences> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    return prefs;
  }
}

/// Writes the event payload, keeping the previous payload under
/// [kEventRollbackKey] first.
///
/// Every record lives in a single string under a single key, so a write
/// interrupted midway (process killed, device powers off) can leave that key
/// truncated and unreadable. The rollback copy bounds the loss to whatever the
/// in-flight save was adding, rather than the entire history.
///
/// On first run there is no previous payload, so nothing is copied and the
/// rollback key simply does not exist yet. It appears on the second save.
Future<void> writeEventPayload(SharedPreferences prefs, String payload) async {
  // ── DO NOT REMOVE THIS GUARD ──────────────────────────────────────────────
  // iOS deliberately keeps NO rollback copy.
  //
  // On iOS the quick-log capture path is native Swift, not Dart:
  // AppDelegate.handleQuickLogStart writes flutter.epilepsy_event_records_v1
  // in UserDefaults directly, and EndMEREventIntent (the Live Activity button,
  // running in the widget extension process) mutates it again. Neither goes
  // through this function and neither knows the rollback key exists.
  //
  // So on iOS the primary payload advances while a rollback copy would sit
  // frozen at whenever Dart last wrote. Restoring from it later would
  // resurrect deleted events and lose recent ones. An absent copy is safe; a
  // silently stale one is a data-loss mechanism.
  //
  // The proper long-term fix is to replicate this snapshot in the Swift write
  // paths so iOS gets real protection. That is a native change, deliberately
  // out of scope for v1.1.0, which does not touch ios/ at all.
  if (Platform.isIOS) {
    // Clear anything a pre-guard build left behind, so nothing misleading
    // remains on a device that ran an internal build.
    if (prefs.containsKey(kEventRollbackKey)) {
      await prefs.remove(kEventRollbackKey);
    }
  } else {
    final previous = prefs.getString(kEventStorageKey);
    if (previous != null && previous.isNotEmpty) {
      await prefs.setString(kEventRollbackKey, previous);
    }
  }
  await prefs.setString(kEventStorageKey, payload);
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

// Strip leading emoji + space from a feelings option label for use as a column header.
// e.g. '😪 Just tired' → 'Just tired'
String _feelingHeader(String option) =>
    option.replaceFirst(RegExp(r'^\S+\s+'), '');

String buildCsv(List<EventRecord> items) {
  final fmtDate = DateFormat('yyyy-MM-dd');
  final fmtTime = DateFormat.jm();
  final sb      = StringBuffer();

  sb.write('\uFEFF'); // UTF-8 BOM — tells Excel to read as UTF-8

  sb.writeln([
    'timestamp_iso',
    'date',
    'time',
    'event_type',
    'duration',
    'severity',
    ...kFeelingsOptions.map(_feelingHeader),
    ...kTriggerOptions,
    'referral_required',
    'notes',
  ].map(_csvEscape).join(','));

  for (final r in items.reversed) {
    sb.writeln([
      r.timestamp.toIso8601String(),
      fmtDate.format(r.timestamp),
      fmtTime.format(r.timestamp).replaceAll('\u202F', ' '),
      eventTypeLabel(r.eventType),
      durationLabel(r.duration),
      severityLabel(r.severity),
      ...kFeelingsOptions.map((f) => r.feelings.contains(f) ? 'Yes' : ''),
      ...kTriggerOptions.map((t) => r.triggers.contains(t) ? 'Yes' : ''),
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