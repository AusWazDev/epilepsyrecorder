import 'dart:async';
import 'dart:io' show FileSystemException, PathAccessException, PathExistsException, PathNotFoundException;

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app_info.dart';
import 'constants.dart';
import 'theme/mer_theme.dart';
import 'screens/disclaimer_screen.dart';
import 'screens/home_screen.dart';
import 'models/event_store_sqlite.dart';
import 'models/storage_boot.dart';
import 'models/storage_migration.dart';
import 'services/notification_service.dart';
import 'widgets/mer_icon_widget.dart';
import 'theme/mer_type.dart';

void main() async {
  // Binding only — this is local setup, not a platform-channel round trip, and
  // NotificationService.init() needs it. Nothing here waits on IO.
  WidgetsFlutterBinding.ensureInitialized();

  // Started, deliberately NOT awaited. On Android a cold start from a
  // notification action is the capture path, and it must not queue behind a
  // platform channel. The release is stamped at send time instead (below).
  unawaited(AppInfo.load());

  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://48b157764abd294968a63ff25dfb1a49@o4511281612849152.ingest.us.sentry.io/4511284989394944';
      // options.release is NOT set here: it is not known yet, and Sentry only
      // needs it when an event is sent, not when it is configured. beforeSend
      // resolves AppInfo first, so every event that leaves the device carries
      // the correct release — including one thrown before startup finished.
      options.beforeSend = (event, hint) async {
        await AppInfo.load();
        if (AppInfo.isLoaded) event.release = AppInfo.sentryRelease;
        return sanitiseEventValues(event);
      };
      // ⛔ A DEV BUILD REPORTED AS 'production' AND SENTRY COULD NOT SEPARATE A
      // DEVELOPER'S CRASH FROM A USER'S — the instrument the release is read
      // through. kReleaseMode is the compiler's own answer, needs no plumbing,
      // and cannot drift from how the binary was actually built.
      //
      // ⭐ NOT a --dart-define, deliberately: a define can be OMITTED on a build
      // and silently reverts to the wrong label, which is the same failure class
      // as the hardcode it replaces. A compiler constant cannot be forgotten.
      //
      // ⚠️ `kReleaseMode` needs `package:flutter/foundation.dart` EXPLICITLY.
      // `material.dart` does NOT re-export it — assumed here at first, and the
      // analyzer said `Undefined name 'kReleaseMode'`. Recorded because the
      // assumption is the natural one to make twice.
      //
      // ⚠️ THE SPLIT BEGINS AT THE FIRST BUILD CARRYING THIS. Events recorded
      // before it keep the label they were given — 22 events as at 23 September
      // 2026, every one `production` — so a Sentry query spanning the boundary
      // mixes the two schemes. Nothing separates them retroactively.
      options.environment = kReleaseMode ? 'production' : 'development';
      options.tracesSampleRate = 0.1;
      options.sendDefaultPii = false;
    },
    appRunner: () async {
      // Storage is selected BEFORE anything renders. On first launch after the
      // SQLite build this runs the one-shot migration; where verification fails
      // it falls back to shared_preferences and the app is otherwise unchanged.
      // It never throws.
      final storage = await StorageBoot.init();
      if (!storage.succeeded) {
        await Sentry.captureMessage(
          'Storage migration did not complete; running on shared_preferences',
          level: SentryLevel.error,
          // ⛔ COUNTS REMOVED. `sourceEntries`, `loadable` and `insertedCount`
          // are counts of the user's medical records, and this site fires on
          // EVERY LAUNCH while the device stays unverified — so they left
          // continuously, not once. What remains is categorical: which failure
          // mode, and the sanitised error.
          withScope: (scope) => scope.setContexts('storage', {
            'state': storage.state.name,
            'error': sanitisedErrorText(storage.error),
          }),
        );
      } else if (storage.state == MigrationState.migrated) {
        await Sentry.captureMessage(
          'Storage migrated to SQLite',
          level: SentryLevel.info,
          // ⛔ EVERY FIELD HERE WAS A COUNT, so the context goes entirely.
          // `absent` was a per-key map of how many of the user's records
          // lacked a field — record-derived in the same way. What is left is
          // the fact that a migration completed, which is the adoption signal;
          // the diagnosis was never in these numbers.
        );
      }
      await NotificationService.instance.init();
      runApp(const AppBootstrap());
    },
  );
}

/* ===========================
   BOOTSTRAP
   =========================== */

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  bool _ready    = false;
  bool _accepted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs           = await SharedPreferences.getInstance();
      final acceptedVersion = prefs.getString('disclaimerAcceptedVersion') ?? '';
      if (!mounted) return;
      setState(() {
        _accepted = acceptedVersion == kDisclaimerVersion;
        _ready    = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:                      kAppName,
      theme:                      MERTheme.light,
      debugShowCheckedModeBanner: false,
      home: !_ready
          ? const _SplashLoadingScreen()
          : (_accepted
              ? const HomeScreen()
              : const DisclaimerScreen()),
    );
  }
}

/* ===========================
   SPLASH LOADING SCREEN
   =========================== */

class _SplashLoadingScreen extends StatelessWidget {
  const _SplashLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MERColours.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            // ── ICON ──
            const MERIconWidget(size: 140, style: MERIconStyle.mark),
            const SizedBox(height: 24),

            // ── MER ──
            const Text(
              'MER',
              style: TextStyle(
                fontSize:      MERType.display,
                fontWeight:    FontWeight.w800,
                color:         MERColours.onPrimary,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),

            // ── APP NAME ──
            const Text(
              kAppName,
              style: MERType.displayOnPrimary,
            ),
            const SizedBox(height: 4),

            // ── TAGLINE ──
            Text(
              'TRACK · RECORD · UNDERSTAND',
              style: MERType.captionOnPrimaryMuted.copyWith(letterSpacing: 1.8),
            ),
            const SizedBox(height: 48),

            // ── LOADING ──
            // ⭐ `const` BECAME AVAILABLE WITH THE TOKEN. The old
            // `Colors.white.withOpacity(0.5)` is a runtime call, so neither
            // widget could be const; `MERColours.onPrimaryMuted` is a
            // compile-time constant and both now can be. The analyzer said so
            // the moment the literal went.
            const SizedBox(
              width:  24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                // ⛔ RESOLVED TO A TOKEN, 20 September 2026. This read
                // `Colors.white.withOpacity(0.5)` and was the first — and so
                // far only — violation found by `colour_literal_scan_test`.
                //
                // ⭐ IT WAS NOT A NECESSARY EXCEPTION. `[read]`: this widget
                // renders INSIDE `MaterialApp(theme: MERTheme.light)`, and
                // its own Scaffold one line above already uses
                // `MERColours.primary`. The theme was available the whole
                // time; the literal was an oversight, not a constraint.
                //
                // ⚠️ CONTRAST, MEASURED, because being a permitted token and
                // being compliant are two different questions and only the
                // first was being asked. A loading indicator is a non-text UI
                // component under 1.4.11, which needs 3.0:1 against its
                // background:
                //
                //   before  white@50% over primary = #86A7C0   3.38:1
                //   now     onPrimaryMuted #B7CBDA             5.11:1
                //
                // ⭐ The old value PASSED, by 0.38. The token passes by 2.11
                // and keeps the muted intent the 50% opacity was reaching for.
                color:       MERColours.onPrimaryMuted,
              ),
            ),
            const SizedBox(height: 48),

            // ── VERSION ──
            Text(
              'Version ${AppInfo.versionLabel}',
              style: MERType.captionOnPrimaryMuted,
            ),
          ],
        ),
      ),
    );
  }
}
/* ===========================
   SENTRY VALUE SANITISATION
   =========================== */

/// Replaces an exception's RENDERED value with a categorical one, for the
/// exception types whose `toString()` embeds user-entered text.
///
/// ⛔ **THE RULE, AND IT IS THE ONE THE DISCLOSURE IS WRITTEN AGAINST:
/// categorical and boolean facts about the OPERATION may be sent; values
/// derived from the USER'S RECORDS may not.** `disclaimer_screen.dart` tells
/// the user these reports "contain no event data".
///
/// ⭐ **KEYED ON THE OBJECT, NEVER ON THE TYPE STRING.** `SentryEvent.throwable`
/// carries the original throwable, so this is a real `is` test.
/// `SentryException.type` is `throwable.runtimeType.toString()`, and the SDK's
/// own source warns that under `--obfuscate` that name "won't be human
/// readable" — so a string-keyed rule would fail silently in exactly the builds
/// that ship, and NO TEST WOULD CATCH IT, because tests are not obfuscated.
///
/// ⚠️ **AN UNRECOGNISED TYPE IS LEFT ALONE.** This is a whitelist, not a
/// scrubber: it cannot know what an arbitrary exception's rendering contains,
/// and inventing a redaction for one would be a matcher by another name.
SentryEvent sanitiseEventValues(SentryEvent event) {
  final replacement = _categoricalValueFor(event.throwable);
  if (replacement == null) return event;

  final exceptions = event.exceptions;
  if (exceptions == null || exceptions.isEmpty) return event;

  // Every entry, not a chosen one. MER's captures carry a single exception,
  // and where they did not, over-removing is the safe direction for a privacy
  // control — the same bias the workspace rules require of a resolution
  // instrument, pointed the other way.
  for (final e in exceptions) {
    e.value = replacement;
  }
  return event;
}

/// The same rule, applied to an error captured as a STRING rather than thrown.
///
/// ⭐ `MigrationOutcome.error` holds an `Object?` that was caught and stored,
/// so it never reaches `beforeSend` as a throwable — it is stringified into a
/// context. Without this it would bypass the sanitisation entirely, which is
/// the gap a rule applied in only one place always has.
String? sanitisedErrorText(Object? error) {
  if (error == null) return null;
  return _categoricalValueFor(error) ?? error.toString();
}

/// The categorical rendering for a recognised throwable, or null to leave it.
///
/// ## ⛔ THIS IS A BLOCKLIST, AND THAT IS A DECISION — 24 September 2026
///
/// **An unrecognised type passes through UNSANITISED.** The alternative is an
/// allowlist: strip every exception value by default and re-admit types one at
/// a time. That would be safer and was rejected, because it would cost the
/// diagnostic text of every exception in the app — including the ones whose
/// rendering is the only reason a defect was ever found. The trade is stated
/// rather than left implicit.
///
/// **THE RESIDUAL RISK, NAMED:** a type not listed here whose `toString()`
/// embeds user-entered text will send it. Nothing detects that; it would be
/// found the way these four were, by reading the type's source.
///
/// ⚠️ **THIS IS AN ABSENCE CLAIM IN DISGUISE — "these are the types that can
/// carry user text, AS AT 24 September 2026" — AND IT WILL ROT.** A package
/// upgrade can change a rendering, and a new dependency can add a type, with
/// no test failing either time. The four listed were each confirmed by reading
/// the type's own source, and re-confirming is the only way to renew the
/// claim. ⛔ A green suite is not evidence that the list is still complete.
///
/// ⭐ **AND "EXPORTED" IS NOT "REACHABLE".** `DatabaseException` exports the
/// abstract type but not `message`, which is declared on a subclass that is
/// not exported — so the obvious implementation could not be written. Confirm
/// what a type actually exposes before adding it; do not assume from its name.
///
/// **Listed as at that date:** `DatabaseException` (bound arguments, via the
/// storage layer), `FormatException` (`source`), `FileSystemException`
/// (`path`), `PlatformException` (`message`, `details`).
String? _categoricalValueFor(Object? throwable) {
  // ⛔ DELEGATED, NOT DUPLICATED. `DatabaseException` is the storage layer's
  // type and only the storage layer may import sqflite — an invariant held by
  // `sqlite_single_writer_test`, which caught this file importing it directly.
  final db = categoricalDatabaseErrorText(throwable);
  if (db != null) return db;
  if (throwable is FormatException) {
    // ⭐ `message` and `offset` are public and carry no user text; `source`
    // does. Dart's own `FormatException.toString()` renders up to ~78
    // characters of `source`, which for MER is the legacy JSON payload — the
    // path that existed in 1.0.2, before SQLite (Brief 173b).
    return 'FormatException(message: ${throwable.message}, '
        'offset: ${throwable.offset})';
  }
  if (throwable is FileSystemException) {
    // ⛔ `path` IS A FIELD, and it is the user's chosen filename. Confirmed
    // from the SDK rather than assumed: `final String? path` on
    // `FileSystemException`, rendered by its `_toStringHelper`. This is the
    // shape `backup_service.dart`'s picker failure arrives in.
    //
    // ⭐ `osError.errorCode` is an `int` on `OSError` and carries no path, so
    // the OS's own classification survives while the filename does not.
    // `message` is dropped: its docstring promises only that it excludes the
    // OS detail, not that it excludes the path.
    //
    // ⚠️ THE SUBCLASS IS TESTED BY `is`, NOT BY `runtimeType.toString()`.
    // `PathAccessException` / `PathExistsException` / `PathNotFoundException`
    // are the useful distinction, and a rendered type name is meaningless
    // under `--obfuscate` — the same reason the rule keys on the object.
    final kind = throwable is PathAccessException
        ? 'pathAccess'
        : throwable is PathExistsException
            ? 'pathExists'
            : throwable is PathNotFoundException
                ? 'pathNotFound'
                : 'fileSystem';
    return 'FileSystemException(kind: $kind, '
        'osErrorCode: ${throwable.osError?.errorCode})';
  }
  if (throwable is PlatformException) {
    // ⭐ `code` is the channel's own error identifier — categorical, set by
    // the plugin, never user text. `message` and `details` are free-form and
    // are dropped: a picker or a file plugin routinely puts a path in one.
    return 'PlatformException(code: ${throwable.code})';
  }
  return null;
}
