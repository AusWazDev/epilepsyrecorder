import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import '../constants.dart';

/* ===========================
   ENUMS
   =========================== */

enum DurationCategory { lt1, oneToFive, gt5 }

/// ⚠️ `durationLabel` and `severityLabel` are STRUCTURALLY IDENTICAL — both are
/// bare exhaustive switches over a NON-NULLABLE enum with no default arm. Do not
/// assume duration's tolerates null because duration is nullable: it does not,
/// and it cannot be passed null without a compile error.
///
/// That compile error is the FEATURE. When severity is made nullable, every call
/// site fails to build and has to decide what absence renders as, rather than a
/// default silently appearing in a medical record. Nullability is handled AT THE
/// CALL SITE here for exactly that reason.
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

/// Resolves a stored duration name, or NULL when it is absent or unrecognised.
///
/// Replaced an `orElse: () => DurationCategory.lt1` that turned every unanswered
/// duration into a confident "< 1 minute" — wrong data, and indistinguishable
/// from a real short event.
DurationCategory? durationFromName(Object? raw) {
  for (final d in DurationCategory.values) {
    if (d.name == raw) return d;
  }
  return null;
}

/// The CSV cell. EXPLICIT, never blank: a clinician reading a blank cannot tell
/// "unknown" from "not recorded" from a broken export.
String durationCsv(DurationCategory? c) =>
    c == null ? 'unknown' : durationLabel(c);

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
  /// NULL means UNKNOWN — not zero, and not short.
  ///
  /// Only the abandonment timeout produces one today; the wizard makes it
  /// reachable by a user in a later stage. Every migrated record has a
  /// bucket, so nothing existing is null.
  final DurationCategory? duration;
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

  /// Parses a stored timestamp and normalises it to local wall-clock time.
  ///
  /// Two writers produce two shapes, and they must not display differently:
  ///
  ///  * Dart writes naive local time — `2026-08-22T18:18:35.180820`, no zone
  ///    suffix — because [toMap] calls `toIso8601String()` on a local
  ///    `DateTime`. `DateTime.tryParse` returns a local `DateTime` for these.
  ///  * Native iOS capture writes UTC — `2026-08-22T06:29:59.000Z` — because
  ///    `AppDelegate.swift` uses `ISO8601DateFormatter` (`:248`). That is the
  ///    Lock Screen and Live Activity path, which is the PRIMARY way events are
  ///    captured on iOS. `DateTime.tryParse` returns a UTC `DateTime` for
  ///    these.
  ///
  /// `DateFormat` renders whatever wall clock the `DateTime` carries, so
  /// without this conversion a UTC record displayed at its UTC time — ten hours
  /// early in AEST, year-round. Sorting hid it: `compareTo` compares absolute
  /// instants, so the order was right while the times were wrong.
  ///
  /// `toLocal()` returns the receiver unchanged when it is already local, so
  /// Dart-written records are untouched; only the UTC ones move, and they move
  /// to the same instant expressed locally.
  ///
  /// Normalising here rather than at each display site is deliberate: there are
  /// four consumers today (history list, home event tiles, the month count, CSV
  /// export) and every future one would have to remember.
  ///
  /// Stored data is deliberately NOT rewritten. A UTC timestamp is not wrong,
  /// it is unambiguous, and a migration that rewrote timestamps would risk far
  /// more than a parse-time conversion.
  static DateTime? _parseTimestamp(dynamic raw) =>
      (raw is String) ? DateTime.tryParse(raw)?.toLocal() : null;

  Map<String, dynamic> toMap() => {
        'id':               id,
        'timestamp':        timestamp.toIso8601String(),
        'duration':         duration?.name,
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
      duration: durationFromName(map['duration']),
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
  /// Serialises every store operation, so two can never interleave.
  ///
  /// Every record lives in one string under one key, so a write is
  /// read-modify-write over the whole history and two overlapping ones are a
  /// lost update. That is not hypothetical: the quick-record button was
  /// re-entrant, so taps 150 ms apart each started their own save, and whichever
  /// `setString` happened to land last won. Live device data showed 27
  /// Dart-written records from about 29 taps.
  ///
  /// [load] joins the same chain as [save]. A read that jumped the queue would
  /// return pre-write state, and `_loadRecords` assigns that straight over the
  /// in-memory list — so a resume racing a write could drop a just-logged event
  /// from memory and the next save would then make the loss permanent.
  ///
  /// Static because it guards a single storage key, not an instance: two
  /// `EventStore` objects still write the same string and must share the queue.
  static Future<void> _queue = Future<void>.value();

  /// Appends [operation] to the queue and returns its result.
  ///
  /// The chain is kept alive across failures: a rejected Future would poison
  /// every later operation, so what is stored back is a Future that always
  /// completes. The caller still sees the real error.
  /// Public so `SqliteEventStore` shares ONE queue with this store.
  /// A fallback launch can have opened SQLite before verification failed, so
  /// one queue is what stops an operation on either backend overlapping one
  /// on the other.
  static Future<T> serialise<T>(Future<T> Function() operation) {
    final result = _queue.then((_) => operation());
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  /// One unreadable record must never cost the user the whole history: every
  /// record lives in a single JSON string under a single key, so an
  /// exception here would make all of them unreachable. Entries that are not
  /// maps, and records fromMap rejects, are skipped individually.
  Future<List<EventRecord>> load() => serialise(_load);

  static Future<List<EventRecord>> _load() async {
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

  /// Writes [records] as they are at the moment of the call.
  ///
  /// The payload is encoded synchronously, before anything is awaited, so the
  /// write is a snapshot rather than a view of a list that keeps changing.
  /// Callers pass `_records`, which is mutated in place by `insert` and replaced
  /// wholesale by `_loadRecords`; encoding after an await meant a save could
  /// serialise records it never intended to, or state from before a reload.
  Future<void> save(List<EventRecord> records) {
    final payload = jsonEncode(records.map((e) => e.toMap()).toList());
    return serialise(() => _write(payload));
  }

  static Future<void> _write(String payload) async {
    final prefs = await SharedPreferences.getInstance();
    await writeEventPayload(prefs, payload);
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
   OPTIMISTIC PERSIST
   =========================== */

/// Whether a previous write of the event list failed and has not since
/// succeeded.
Future<bool> hasUnsavedEvents() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.reload();
  return prefs.getBool(kUnsavedEventsKey) ?? false;
}

/// Records that events are in memory but not in storage.
Future<void> setUnsavedEventsWarning() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(kUnsavedEventsKey, true);
}

/// Clears the warning. Called only where a write demonstrably succeeded.
Future<void> clearUnsavedEventsWarning() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(kUnsavedEventsKey);
}

/// Saves [records] and reports whether it worked, without ever throwing.
///
/// Returns true when the write succeeded and any standing warning was cleared,
/// false when it failed and the warning was raised.
///
/// The failure is optimistic by design and the caller has already confirmed to
/// the user. Three deliberate choices sit behind that:
///
///  * The confirmation is not delayed until the write returns. This is the
///    capture path — someone logging a seizure — and latency there is the one
///    cost not worth paying for correctness elsewhere.
///  * The record is NOT removed from the list on failure. A just-logged event
///    disappearing in front of the person who logged it is the worst outcome
///    available, even when it is the truthful one.
///  * So the gap between what is on screen and what is in storage is made
///    visible instead: a persistent warning the user can act on, rather than a
///    silent divergence they discover after a restart.
///
/// Reported to Sentry explicitly on every failure, never swallowed: before
/// this, an exception here escaped into a discarded Future and was captured by
/// the guarded zone with nothing shown on screen at all.
Future<bool> persistEvents(EventStore store, List<EventRecord> records) async {
  try {
    await store.save(records);
    await clearUnsavedEventsWarning();
    return true;
  } catch (e, st) {
    await Sentry.captureException(e, stackTrace: st);
    try {
      await setUnsavedEventsWarning();
    } catch (_) {
      // Storage is failing; the in-memory banner still shows for this session.
    }
    return false;
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

/// Reports a failure to Sentry AND tells the user, for a failure that would
/// otherwise be invisible.
///
/// Every export and backup action runs inside an async callback whose Future
/// the framework discards — a `ListTile` `onTap`, a `PopupMenuButton`
/// `onSelected`. An exception escaping one of those becomes an unhandled zone
/// error: recorded by Sentry's guarded zone and rendered on screen as nothing
/// whatsoever. That is how "Restore from backup does nothing on iOS" presented,
/// and every path here had the same shape.
///
/// Both audiences are served deliberately: the exception is still captured, so
/// the diagnostic value that made that defect findable is not lost, and the
/// user is told, so a failure can never again look like a no-op.
///
/// Callers must only reach this for a genuine failure. A cancelled dialog is
/// not a failure and must stay silent.
///
/// Takes the messenger rather than a [BuildContext] so no context crosses an
/// async gap: callers resolve `ScaffoldMessenger.of(context)` synchronously
/// before starting work, and this checks the messenger is still mounted before
/// using it. Sentry is told either way — a user who has navigated away still
/// deserves the bug to be fixed.
Future<void> reportUserFacingFailure(
  ScaffoldMessengerState messenger,
  Object error,
  StackTrace stackTrace,
  String message,
) async {
  await Sentry.captureException(error, stackTrace: stackTrace);
  if (!messenger.mounted) return;
  messenger.showSnackBar(SnackBar(content: Text(message)));
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
      durationCsv(r.duration),
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
  // Resolved before any await so no BuildContext crosses an async gap.
  final messenger = ScaffoldMessenger.of(context);

  try {
    final file =
        await _buildCsvTempFile(items, filenamePrefix: filenamePrefix);
    if (!context.mounted) return;
    // No `text` alongside `files`. iOS treats a text parameter as a second
    // shared item, so "Save to Files" wrote a stray companion file containing
    // only the text — leaving the user two files from one export. `subject` is
    // metadata (the mail subject line) and does not become an item, so it
    // stays. Same fix as the backup share in b7df6f1; this one has been in the
    // shipped app since CSV export existed.
    await SharePlus.instance.share(
      ShareParams(
        subject: '$kAppName export (CSV)',
        files:   [XFile(file.path, mimeType: 'text/csv')],
        sharePositionOrigin: shareOriginRect(context),
      ),
    );
  } catch (e, st) {
    await reportUserFacingFailure(
      messenger,
      e,
      st,
      'Could not prepare the CSV to share. Your events have not been changed.',
    );
  }
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
  // Resolved before any await so no BuildContext crosses an async gap.
  final messenger = ScaffoldMessenger.of(context);

  FileSaveLocation? location;
  try {
    location = await getSaveLocation(
      suggestedName: filename,
      acceptedTypeGroups: const [
        XTypeGroup(label: 'CSV files', extensions: ['csv']),
      ],
    );
  } catch (e, st) {
    await reportUserFacingFailure(
      messenger,
      e,
      st,
      'Could not open the save dialog. Try Share instead.',
    );
    return;
  }

  // Cancelling is not a failure and must stay silent.
  if (location == null) return;

  // Bound to a non-nullable local so the "Open" action below can close over the
  // path: promotion of a mutable local does not reach inside a closure.
  final savedPath = location.path;

  try {
    await File(savedPath).writeAsString(csv, flush: true);
  } catch (e, st) {
    await reportUserFacingFailure(
      messenger,
      e,
      st,
      'Could not write the CSV file. Your events have not been changed.',
    );
    return;
  }
  if (!context.mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('CSV saved'),
      action: SnackBarAction(
        label: 'Open',
        onPressed: () async {
          try {
            if (Platform.isWindows) {
              await Process.start('explorer', [savedPath],
                  runInShell: true);
            } else if (Platform.isMacOS) {
              await Process.start('open', [savedPath],
                  runInShell: true);
            } else if (Platform.isLinux) {
              await Process.start('xdg-open', [savedPath],
                  runInShell: true);
            }
          } catch (_) {}
        },
      ),
    ),
  );
}

/// [sheetTitle] overrides the header label so the sheet can state its own
/// scope. That matters most from History, whose AppBar button exports only the
/// filtered list but says so in a tooltip — and tooltips need hover or a long
/// press, so no iPhone user ever sees it. The sheet header is the only place
/// the scope can be stated where it will actually be read.
Future<void> showExportOptions(
  BuildContext context,
  List<EventRecord> items, {
  String? filenamePrefix,
  String? sheetTitle,
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
                  // Expanded, not a bare Text + Spacer: a scope-bearing title
                  // is longer than "Export events" and must not overflow.
                  Expanded(
                    child: Text(
                      sheetTitle ?? 'Export events',
                      style: const TextStyle(
                        fontSize:   13,
                        fontWeight: FontWeight.w600,
                        color:      Colors.black45,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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