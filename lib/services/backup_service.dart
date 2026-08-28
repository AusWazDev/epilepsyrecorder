import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants.dart';
import '../models/backup.dart';
import '../models/medication_note.dart';
import '../models/event_record.dart';

/// Backup and restore, driven entirely by the system file picker.
///
/// The user chooses where a backup goes and which file comes back. Nothing is
/// remembered between runs: no stored path, no security-scoped bookmark, no
/// cloud credential, no background write. Every backup is a deliberate action
/// the user took.

/// The one file-type filter every backup file picker uses.
///
/// All four platforms must be satisfied by this single group, and each reads a
/// different field of it. Verified against the plugin sources in pubspec.lock:
///
///  * iOS (`file_selector_ios` 0.5.3+5, `file_selector_ios.dart:63-75`) reads
///    ONLY `uniformTypeIdentifiers`. iOS filters by UTI, not by extension, so a
///    group that sets `extensions` and nothing else is neither "allow any" nor
///    translatable, and the plugin throws `ArgumentError` in Dart before the
///    platform channel is touched — no picker is ever created. That was the
///    defect behind "Restore from backup does nothing on iOS".
///  * macOS (`file_selector_macos` 0.9.5:180-193) accepts any one of
///    extensions / UTIs / mimeTypes, and unions those it is given.
///  * Windows (`file_selector_windows` 0.9.3+5:131-141) requires `extensions`
///    non-empty and ignores the rest.
///  * Android (`file_selector_android` 0.5.2+4:83-99) requires `extensions` or
///    `mimeTypes` non-empty and ignores UTIs.
///
/// `public.json` is the system UTI for the `.json` extension, which is what
/// [_backupFilename] always writes, so a file produced by this app's own backup
/// path is selectable rather than greyed out. It is a system-declared type — the
/// app does not need to declare it in Info.plist, and no Info.plist entry is
/// required to present a document picker.
///
/// Anything not covered by the filter is still handled: a file that gets past
/// it is validated by [parseBackup] and refused with an explanation, never
/// applied.
const kBackupTypeGroup = XTypeGroup(
  label: 'Backup files',
  extensions: ['json'],
  uniformTypeIdentifiers: ['public.json'],
);

/// Short on purpose. The system file picker truncates the middle of a long
/// name, and `medical_event_recorder_backup_20260825_142202.json` renders as
/// something like `medical_event_record...2.json` — which hides the entire
/// timestamp and makes two backups from the same day indistinguishable. That
/// is not hypothetical: it caused a real mis-restore.
///
/// NOTHING matches on this prefix. Restore filters by extension and validates
/// by the envelope's `format` field, so every file written under the old name
/// still restores — verified by test.
String _backupFilename() =>
    'mer_backup_'
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
  List<EventRecord> records, {
  List<MedicationNote> notes = const <MedicationNote>[],
}) async {
  // Resolved before any await so no BuildContext crosses an async gap.
  final messenger = ScaffoldMessenger.of(context);

  try {
    final json = buildBackupJson(records, notes: notes);
    final dir  = await getTemporaryDirectory();
    final file = File('${dir.path}/${_backupFilename()}');
    await file.writeAsString(json, flush: true);
    if (!context.mounted) return;

    // No `text` alongside `files`. iOS treats a text parameter as a second
    // shared item, so "Save to Files" wrote a stray companion file containing
    // only the text and nothing else — leaving the user two files with no way
    // to tell which one restores. `subject` is metadata (the mail subject line)
    // and does not become an item, so it stays.
    final result = await SharePlus.instance.share(
      ShareParams(
        subject: '$kAppName backup',
        files:   [XFile(file.path, mimeType: 'application/json')],
        sharePositionOrigin: shareOriginRect(context),
      ),
    );

    // Invoking the sheet is not evidence of a backup. A user who opens it and
    // cancels must keep their reminder, not be told they are covered.
    if (backupCountsAsTaken(result.status)) await markBackupTaken();
  } catch (e, st) {
    // markBackupTaken is inside the guard on purpose. If it is what failed, the
    // reminder keeps running — the safe direction for a safety feature, per
    // backupCountsAsTaken above.
    await reportUserFacingFailure(
      messenger,
      e,
      st,
      'Could not prepare the backup to share. Your events have not been '
      'changed.',
    );
  }
}

Future<void> backupSaveAs(
  BuildContext context,
  List<EventRecord> records, {
  List<MedicationNote> notes = const <MedicationNote>[],
}) async {
  final json     = buildBackupJson(records, notes: notes);
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
  // Resolved before any await so no BuildContext crosses an async gap.
  final messenger = ScaffoldMessenger.of(context);

  FileSaveLocation? location;
  try {
    location = await getSaveLocation(
      suggestedName: filename,
      acceptedTypeGroups: const [kBackupTypeGroup],
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

  try {
    await File(location.path).writeAsString(json, flush: true);
    await markBackupTaken();
  } catch (e, st) {
    // Nothing is marked as backed up unless the write actually succeeded, so a
    // failure here leaves the reminder running rather than claiming cover.
    await reportUserFacingFailure(
      messenger,
      e,
      st,
      'Could not write the backup file. Your events have not been changed.',
    );
    return;
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Backup saved')),
  );
}

/// "Back up now" entry point. Offers the same two destinations as the CSV
/// export so the two flows behave alike.
Future<void> showBackupOptions(
  BuildContext context,
  List<EventRecord> records, {
  List<MedicationNote> notes = const <MedicationNote>[],
}) async {
  if (records.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No events to back up.')),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
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
            // NOT "a file you choose": on iOS the save tile below is compiled
            // out and Share is the only option, so nothing here lets the user
            // choose a location. Share does reach Files, but that is the user
            // choosing where to put it afterwards, not a save dialog.
            child: Text(
              'Saves every event to a file you can share or store. Keep it '
              'somewhere off this device.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          // ── SAVE (non-iOS only) ──
          // file_selector ships no save-dialog implementation for iOS:
          // FileSelectorIOS implements openFile/openFiles only, so getSaveLocation
          // falls through to the platform-interface default, which delegates to
          // getSavePath and throws UnimplementedError. Offering an option that
          // throws is worse than not offering it, and it cannot be caught into
          // anything useful — there is no iOS save dialog to fall back to.
          // Share reaches Files on iOS, so the user can still put the backup
          // wherever they choose and nothing is lost.
          // Android has no save implementation either, but never reaches it:
          // backupSaveAs returns from its own Downloads branch first.
          // Same guard as showExportOptions in models/event_record.dart.
          if (!Platform.isIOS)
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: const Text('Save to a file'),
              onTap: () async {
                Navigator.pop(sheet);
                await backupSaveAs(context, records, notes: notes);
              },
            ),
          // Same wording as the export sheet for the same action. Two labels
          // for one thing read as two different features.
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: const Text('Share to apps'),
            subtitle: const Text('Email, cloud storage, spreadsheets'),
            onTap: () async {
              Navigator.pop(sheet);
              await backupShare(context, records, notes: notes);
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
/// What a completed restore produced, for the caller to write.
///
/// ⛔ **TWO STREAMS, TWO WRITERS, ONE RESULT.** Events are a list the caller
/// rewrites wholesale; notes are rows it INSERTS into a SQLite table. Returning
/// only the events is what let medication notes fall out of restore entirely,
/// so the type now makes the second stream impossible to forget: a caller that
/// ignores `notesToAdd` has to ignore a named field rather than simply not
/// know it exists.
class RestoreOutcome {
  const RestoreOutcome(this.merged, this.notesToAdd);

  /// The full event list to persist, existing plus additions.
  final List<EventRecord> merged;

  /// ONLY the notes not already present. Inserting the union would duplicate
  /// every note already on the device.
  final List<MedicationNote> notesToAdd;
}

Future<RestoreOutcome?> restoreFromBackup(
  BuildContext context,
  List<EventRecord> existing, {
  List<MedicationNote> existingNotes = const <MedicationNote>[],
}) async {
  // The picker call is guarded because a throw here is invisible otherwise.
  // restoreFromBackup is awaited from a PopupMenuButton onSelected callback,
  // whose Future the framework discards, so an escaping error becomes an
  // unhandled zone error: captured by Sentry's guarded zone and shown to the
  // user as nothing at all. That is exactly how the iOS type-group defect
  // presented — a menu item that did nothing on tap. Any future failure of the
  // picker on any platform now says so on screen instead of vanishing.
  // Resolved before any await so no BuildContext crosses an async gap.
  final messenger = ScaffoldMessenger.of(context);

  XFile? file;
  try {
    file = await openFile(acceptedTypeGroups: const [kBackupTypeGroup]);
  } catch (e, st) {
    // Reported, not swallowed: the diagnostic value of the exception is the
    // reason this defect was findable at all.
    await Sentry.captureException(e, stackTrace: st);
    if (!context.mounted) return null;
    await _refuse(
      context,
      'This device could not open the file picker, so no backup could be '
      'chosen.',
    );
    return null;
  }

  // Cancelling is not a failure and must stay silent.
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

  final plan = planRestore(existing, parsed, existingNotes: existingNotes);
  // The one remaining silent null, and deliberately so: the screen this was
  // started from is gone, so there is nobody looking at it to tell. Every other
  // null from this function either shows a _refuse dialog, shows a snackbar, or
  // is an explicit user cancellation.
  if (!context.mounted) return null;

  // ⛔ BOTH STREAMS, NOT JUST EVENTS.
  //
  // This condition was written when events were the only stream, and it
  // outlived that. `plan.inBackup == 0` refused a backup holding medication
  // notes but no events — telling a user who logs only deviations that their
  // file contains nothing, and losing every note in it. **That is the same
  // silent loss this change exists to fix, surviving inside the gate meant to
  // prevent it.**
  //
  // A backup is empty when NEITHER stream has anything, not when the events
  // stream is empty.
  if (plan.inBackup == 0 && plan.notesInBackup == 0) {
    final lostRecords = parsed.unreadableRecords;
    final lostNotes = parsed.unreadableNotes;
    final String reason;
    if (lostRecords > 0 && lostNotes == 0) {
      // The pre-existing wording, unchanged — this is still the only shape it
      // ever described, and there is no reason to churn it.
      reason = 'None of the $lostRecords records in this backup could be read.';
    } else if (lostNotes > 0 && lostRecords == 0) {
      reason = 'None of the $lostNotes medication '
          '${lostNotes == 1 ? "note" : "notes"} in this backup could be read.';
    } else if (lostRecords > 0) {
      reason = 'None of the entries in this backup could be read: '
          '$lostRecords ${lostRecords == 1 ? "record" : "records"} and '
          '$lostNotes medication ${lostNotes == 1 ? "note" : "notes"}.';
    } else {
      // "This backup contains no events" became wrong for exactly the reason
      // the condition did — it names one stream while describing both.
      reason = 'This backup contains no events or medication notes.';
    }
    await _refuse(context, '$reason Nothing has been changed.');
    return null;
  }

  final confirmed = await _confirmRestore(context, plan);

  // Cancel and dismissal are NOT the same thing, and the difference is already
  // available here — it was simply being discarded.
  //
  //   Cancel button  -> pops false
  //   Restore button -> pops true
  //   barrier tap or system back -> pops nothing, so showDialog resolves NULL
  //
  // `if (confirmed != true)` collapsed the last two into one silent return. On
  // an 800x1280 tablet a tap that lands on the barrier beside a small action
  // button is easy, and the result was indistinguishable from a completed
  // restore: dialog closed, nothing written, nothing said. It cost two
  // diagnostic passes to establish that, and a user would have concluded their
  // backup file was worthless.
  if (confirmed == false) {
    // An explicit cancellation is a decision, not a failure. Stays silent.
    return null;
  }
  if (confirmed == null) {
    // Dismissed without deciding. Not an error either, so not a _refuse
    // dialog — but it must not be silent, because the likeliest way to get
    // here is aiming for Restore and missing.
    if (messenger.mounted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Nothing was restored — the dialog was dismissed. '
              'Your events have not been changed.'),
        ),
      );
    }
    return null;
  }

  return RestoreOutcome(plan.merged, plan.notesToAdd);
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

  // ⚠️ The events line is omitted ONLY when there are no events and there ARE
  // notes — the case the widened empty gate now lets through. Every
  // events-bearing backup produces exactly the dialog it always did, and a
  // notes-only one is spared an opening line reading "contains 0 events"
  // followed by "It ALSO contains 3 medication notes".
  final eventsFirst = plan.inBackup > 0 || plan.notesInBackup == 0;
  final lines = <String>[
    if (eventsFirst)
      'This backup contains ${plan.inBackup} '
          '${plan.inBackup == 1 ? "event" : "events"}$range.',
  ];

  // WHEN the backup was taken, which is the signal the picker cannot show and
  // the one that distinguishes two files whose contents overlap.
  if (plan.exportedAt != null) {
    lines.add('Backed up '
        '${DateFormat('d MMM yyyy, h:mm a').format(plan.exportedAt!)}.');
  }

  if (plan.alreadyPresent > 0) {
    lines.add('${plan.alreadyPresent} '
        '${plan.alreadyPresent == 1 ? "is" : "are"} already on this device.');
  }
  if (plan.unreadable > 0) {
    lines.add('${plan.unreadable} '
        '${plan.unreadable == 1 ? "record" : "records"} could not be read and '
        'will be skipped.');
  }
  // ⚠️ EVERY NOTE LINE IS CONDITIONAL ON THERE BEING NOTES, so a schema 1
  // backup — which is every backup taken before this change — produces a
  // dialog byte-identical to the one it produced before.
  if (plan.notesInBackup > 0) {
    lines.add('${eventsFirst ? "It also contains" : "This backup contains"} '
        '${plan.notesInBackup} medication '
        '${plan.notesInBackup == 1 ? "note" : "notes"}'
        '${plan.notesAlreadyPresent > 0 ? ', ${plan.notesAlreadyPresent} '
            'already on this device' : ''}.');
  }
  if (plan.notesUnreadable > 0) {
    lines.add('${plan.notesUnreadable} medication '
        '${plan.notesUnreadable == 1 ? "note" : "notes"} could not be read and '
        'will be skipped.');
  }
  // toAdd is an int, and was interpolated with no noun — the dialog read
  // "Restore 5?" while every other count in it was pluralised correctly.
  //
  // ⛔ AND IT MUST NAME BOTH STREAMS. A backup whose only new content is
  // medication notes would otherwise offer "Restore 0 events" on a button that
  // does something — the events-only phrasing is kept EXACTLY when there are no
  // notes to add, so nothing existing reads differently.
  final noteCount = plan.notesToAdd.length;
  final labelParts = <String>[
    if (plan.toAdd > 0 || noteCount == 0)
      '${plan.toAdd} ${plan.toAdd == 1 ? "event" : "events"}',
    if (noteCount > 0)
      '$noteCount medication ${noteCount == 1 ? "note" : "notes"}',
  ];
  final toAddLabel = labelParts.join(' and ');
  lines.add(plan.addsNothing
      ? 'There is nothing new to restore.'
      : 'Restore $toAddLabel?');
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
            child: Text('Restore $toAddLabel'),
          ),
      ],
    ),
  );
}
