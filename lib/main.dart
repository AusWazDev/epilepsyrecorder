import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'constants.dart';
import 'theme/mer_theme.dart';
import 'screens/disclaimer_screen.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'widgets/mer_icon_widget.dart';

void main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = 'https://48b157764abd294968a63ff25dfb1a49@o4511281612849152.ingest.us.sentry.io/4511284989394944';
      options.tracesSampleRate = 0.1;
      options.sendDefaultPii = false;
    },
    appRunner: () async {
      WidgetsFlutterBinding.ensureInitialized();
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
            Container(
              width:  100,
              height: 100,
              decoration: BoxDecoration(
                color:        Colors.white.withOpacity(0.12),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.22),
                  width: 1.5,
                ),
              ),
              child: const Center(
                child: MERIconWidget(size: 62),
              ),
            ),
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
              'Version $kAppVersion',
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