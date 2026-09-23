import 'dart:async';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app_info.dart';
import 'constants.dart';
import 'theme/mer_theme.dart';
import 'screens/disclaimer_screen.dart';
import 'screens/home_screen.dart';
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
        return event;
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
          withScope: (scope) => scope.setContexts('storage', {
            'state':         storage.state.name,
            'sourceEntries': storage.sourceEntries,
            'loadable':      storage.loadableCount,
            'inserted':      storage.insertedCount,
            'error':         storage.error?.toString(),
          }),
        );
      } else if (storage.state == MigrationState.migrated) {
        await Sentry.captureMessage(
          'Storage migrated to SQLite',
          level: SentryLevel.info,
          withScope: (scope) => scope.setContexts('storage', {
            'sourceEntries': storage.sourceEntries,
            'loadable':      storage.loadableCount,
            'inserted':      storage.insertedCount,
            'distinctIds':   storage.distinctIds,
            'skipped':       storage.skipped,
            'absent':        storage.absentCounts,
          }),
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