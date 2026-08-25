import 'dart:async';

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
      options.environment = 'production';
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
                fontSize:      28,
                fontWeight:    FontWeight.w800,
                color:         Colors.white,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),

            // ── APP NAME ──
            const Text(
              kAppName,
              style: TextStyle(
                fontSize:   16,
                fontWeight: FontWeight.w600,
                color:      Colors.white,
              ),
            ),
            const SizedBox(height: 4),

            // ── TAGLINE ──
            Text(
              'TRACK · RECORD · UNDERSTAND',
              style: TextStyle(
                fontSize:      10,
                color:         Colors.white.withOpacity(0.5),
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 48),

            // ── LOADING ──
            SizedBox(
              width:  24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color:       Colors.white.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 48),

            // ── VERSION ──
            Text(
              'Version ${AppInfo.versionLabel}',
              style: TextStyle(
                fontSize: 11,
                color:    Colors.white.withOpacity(0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}