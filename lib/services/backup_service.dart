import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../models/backup.dart';
import '../models/event_record.dart';

/// Backup and restore, driven entirely by the system file picker.
///
/// The user chooses where a backup goes and which file comes back. Nothing is
/// remembered between runs: no stored path, no security-scoped bookmark, no
/// cloud credential, no background write. Every backup is a deliberate action
/// the user took.

String _backupFilename() =>
    'medical_event_recorder_backup_'
    '${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';

/// Whether a share outcome counts as a backup actually taken.
///
/// Only an explicit success does. The reminder is a safety feature, so it must
/// fail in the safe direction: leaving the reminder running when a backup did
/// happen is a minor annoyance, whereas clearing it when one did not tells the
/// user they are protected when they are not, and they find out only after
/// losing everything.
///
/// Platform reality: iOS and Android report success or dismissed, so a
/// cancelled sheet is distinguishable there and is not counted. Windows, macOS
/// and Linux report `unavailable` — nothing is knowable, so nothing is counted
/// and the reminder simply keeps running. Desktop users still clear it via
/// Save to a file, where completion is known.
bool backupCountsAsTaken(ShareResultStatus status) =>
    status == ShareResultStatus.success;

/// Records that a backup was taken, so the reminder banner can count events
/// logged since. Called only where completion is actually knowable.
Future<void> markBackupTaken() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kLastBackupKey, DateTime.now().toIso8601String());
}

/// Number of events logged since the last backup, used by the reminder banner.
/// With no backup ever taken, every record counts.
Future<int> eventsSinceLastBackup(List<EventRecord> records) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString(kLastBackupKey);
  final last = raw == null ? null : DateTime.tryParse(raw);
  if (last == null) return records.length;
  return records.where((r) => r.timestamp.isAfter(last)).length;
}

/* ===========================
   BACKUP
   =========================== */

Future<void> backupShare(
  BuildContext context,
  List<EventRecord> records,
) async {
  final json = buildBackupJson(records);
  final dir  = await getTemporaryDirectory();
  final file = File('${dir.path}/${_backupFilename()}');
  await file.writeAsString(json, flush: true);
  if (!context.mounted) return;

  final result = await SharePlus.instance.share(
    ShareParams(
      subject: '$kAppName backup',
      text:    '$kAppName backup (JSON)',
      files:   [XFile(file.path, mimeType: 'application/json')],
      sharePositionOrigin: shareOriginRect(context),
    ),
  );

  // Invoking the sheet is not evidence of a backup. A user who opens it and
  // cancels must keep their reminder, not be told they are covered.
  if (backupCountsAsTaken(result.status)) await markBackupTaken();
}

Future<void> backupSaveAs(
  BuildContext context,
  List<EventRecord> records,
) async {
  final json     = buildBackupJson(records);
  final filename = _backupFilename();

  // ── ANDROID — save to Downloads ──
  if (Platform.isAndroid) {
    try {
      final dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) await dir.create(recursive: true);
      await File('${dir.path}/$filename').writeAsString(json, flush: true);
      await markBackupTaken();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup saved to Downloads/$filename')),
      );
    } catch (_) {
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
      XTypeGroup(label: 'Backup files', extensions: ['json']),
    ],
  );
  if (location == null) return;

  await File(location.path).writeAsString(json, flush: true);
  await markBackupTaken();
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Backup saved')),
  );
}

/// "Back up now" entry point. Offers the same two destinations as the CSV
/// export so the two flows behave alike.
Future<void> showBackupOptions(
  BuildContext context,
  List<EventRecord> records,
) async {
  if (records.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No events to back up.')),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 4),
            child: Text(
              'Back up now',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Text(
              'Saves every event to a file you choose. Keep it somewhere off '
              'this device.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.save_alt),
            title: const Text('Save to a file'),
            onTap: () async {
              Navigator.pop(sheet);
              await backupSaveAs(context, records);
            },
          ),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: const Text('Share'),
            onTap: () async {
              Navigator.pop(sheet);
              await backupShare(context, records);
            },
          ),
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('Cancel'),
            onTap: () => Navigator.pop(sheet),
          ),
        ],
      ),
    ),
  );
}

/* ===========================
   RESTORE
   =========================== */

/// Full restore flow: pick a file, validate it completely, show what would
/// happen, confirm, then write once.
///
/// Returns the merged list when a restore was applied, or null when nothing
/// was written — which covers cancelling, every refusal case, and a backup
/// that adds nothing. Existing data is never modified before the confirm.
Future<List<EventRecord>?> restoreFromBackup(
  BuildContext context,
  List<EventRecord> existing,
) async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(label: 'Backup files', extensions: ['json']),
    ],
  );
  if (file == null) return null;

  String raw;
  try {
    raw = await file.readAsString();
  } catch (_) {
    if (!context.mounted) return null;
    await _refuse(context, 'That file could not be opened.');
    return null;
  }

  final parsed = parseBackup(raw);
  if (!parsed.isValid) {
    if (!context.mounted) return null;
    await _refuse(context, parsed.message);
    return null;
  }

  final plan = planRestore(existing, parsed);
  if (!context.mounted) return null;

  if (plan.inBackup == 0) {
    await _refuse(
      context,
      parsed.unreadableRecords > 0
          ? 'None of the ${parsed.unreadableRecords} records in this backup '
              'could be read. Nothing has been changed.'
          : 'This backup contains no events. Nothing has been changed.',
    );
    return null;
  }

  final confirmed = await _confirmRestore(context, plan);
  if (confirmed != true) return null;

  return plan.merged;
}

Future<void> _refuse(BuildContext context, String message) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Cannot restore'),
      content: Text('$message\n\nYour existing events have not been changed.'),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}

Future<bool?> _confirmRestore(BuildContext context, RestorePlan plan) {
  final fmt = DateFormat('d MMM yyyy');
  final range = (plan.earliest != null && plan.latest != null)
      ? ' from ${fmt.format(plan.earliest!)} to ${fmt.format(plan.latest!)}'
      : '';

  final lines = <String>[
    'This backup contains ${plan.inBackup} '
        '${plan.inBackup == 1 ? "event" : "events"}$range.',
  ];
  if (plan.alreadyPresent > 0) {
    lines.add('${plan.alreadyPresent} '
        '${plan.alreadyPresent == 1 ? "is" : "are"} already on this device.');
  }
  if (plan.unreadable > 0) {
    lines.add('${plan.unreadable} '
        '${plan.unreadable == 1 ? "record" : "records"} could not be read and '
        'will be skipped.');
  }
  lines.add(plan.addsNothing
      ? 'There is nothing new to restore.'
      : 'Restore ${plan.toAdd}?');
  lines.add('Restoring only adds events. Nothing already on this device is '
      'changed or removed.');

  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Restore from backup'),
      content: Text(lines.join('\n\n')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        if (!plan.addsNothing)
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Restore ${plan.toAdd}'),
          ),
      ],
    ),
  );
}
