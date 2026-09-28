import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// The files Reset deletes, and ONLY those. Brief 208 Part B, 28 September 2026.
///
/// ## ⛔ NAMED FILES IN APP-OWNED DIRECTORIES. NEVER A DIRECTORY, NEVER A
/// ## USER-CHOSEN LOCATION
///
/// Two kinds of file, each matched by NAME inside a directory the app itself
/// writes to:
///
///   * **Share intermediates**, in the temporary directory and in the
///     `share_plus` folder under it (on Android the plugin copies each shared
///     file there: `Share.kt`, `copyToShareCacheFolder`). The CSV has been
///     `medical_event_recorder…csv` in every build that shipped. The backup was
///     `medical_event_recorder_backup_…json` until `cd53b28` and `mer_backup_…json`
///     since. Nothing reads any of them back; they sat there until the OS purged
///     them.
///   * **The pre-migration backup**, `mer_pre_sqlite_backup_…json`: the whole
///     pre-SQLite history in plaintext. Nothing reads it (Brief 206 §2.2), and it
///     is not part of migration recovery, which re-runs from the legacy prefs
///     payload. Swept from Application Support, plus the one path `schema_meta`
///     recorded. That recorded path is the only way to reach a copy written to
///     DOCUMENTS before `9eed24f` moved the writer, 24 September 2026.
///
/// ⛔ **User-saved exports are EXEMPT, and nothing here can reach them.**
/// Android's Save writes to `/storage/emulated/0/Download`; desktop Save writes
/// wherever the user chose; iOS Save goes through Files. None of those
/// directories is swept. ⚠️ The one gap, stated: a desktop user who picks the
/// temporary directory or Application Support as a save location has put a
/// file where Reset sweeps, and a file with a matching name there is deleted.
/// The app cannot tell that file from its own.
///
/// ⚠️ **On Windows the temporary directory can be the user's shared `%TEMP%`**
/// (it is package-private only under MSIX). That is why the match is on the
/// app's own filename prefixes and never on an extension alone.
///
/// ⭐ BEST-EFFORT PER FILE. A file that will not delete (locked, already gone)
/// must not stop Reset. Returns how many were deleted, for tests.
final RegExp kShareIntermediateName = RegExp(
    r'^(medical_event_recorder[^/\\]*\.(csv|json)|mer_backup_[^/\\]*\.json)$');
final RegExp kPreMigrationBackupName =
    RegExp(r'^mer_pre_sqlite_backup_[^/\\]*\.json$');

Future<int> deleteResetFiles({String? recordedBackupPath}) async {
  var deleted = 0;
  final temp = await _dirOrNull(getTemporaryDirectory);
  if (temp != null) {
    deleted += await _sweep(temp, kShareIntermediateName);
    deleted += await _sweep(
        Directory('${temp.path}${Platform.pathSeparator}share_plus'),
        kShareIntermediateName);
  }
  final support = await _dirOrNull(getApplicationSupportDirectory);
  if (support != null) {
    deleted += await _sweep(support, kPreMigrationBackupName);
  }
  // ⛔ The recorded path is honoured ONLY if its file name is the backup's own.
  // A meta value is data; it is never allowed to aim a delete at anything else.
  if (recordedBackupPath != null && recordedBackupPath.isNotEmpty) {
    final f = File(recordedBackupPath);
    if (kPreMigrationBackupName.hasMatch(_name(f)) && await _delete(f)) {
      deleted++;
    }
  }
  return deleted;
}

Future<Directory?> _dirOrNull(Future<Directory> Function() get) async {
  try {
    return await get();
  } catch (_) {
    return null;
  }
}

String _name(FileSystemEntity e) => e.uri.pathSegments.lastWhere(
    (s) => s.isNotEmpty,
    orElse: () => '');

/// Files directly in [dir] whose name matches. Not recursive, and never a
/// directory.
Future<int> _sweep(Directory dir, RegExp name) async {
  var deleted = 0;
  try {
    if (!await dir.exists()) return 0;
    await for (final e in dir.list(followLinks: false)) {
      if (e is File && name.hasMatch(_name(e)) && await _delete(e)) deleted++;
    }
  } catch (_) {
    // A directory that cannot be listed must not stop Reset.
  }
  return deleted;
}

Future<bool> _delete(File f) async {
  try {
    if (!await f.exists()) return false;
    await f.delete();
    return true;
  } catch (_) {
    return false;
  }
}
