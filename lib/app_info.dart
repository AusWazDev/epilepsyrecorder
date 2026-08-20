import 'package:package_info_plus/package_info_plus.dart';

/// Single source of truth for the app's identity and version at runtime.
///
/// Every value here is read from the platform's own packaged metadata, which
/// Flutter populates from pubspec.yaml at build time (Android versionName /
/// versionCode, iOS CFBundleShortVersionString / CFBundleVersion, the Windows
/// executable's version resource). Nothing is written down a second time, so
/// there is no copy that can drift from pubspec and no generator anyone has to
/// remember to run.
///
/// Populated once by [load] before the app runs. Do not hardcode a version
/// anywhere else.
class AppInfo {
  AppInfo._();

  static String packageName = '';
  static String version     = '';
  static String buildNumber = '';

  static bool _loaded = false;
  static bool get isLoaded => _loaded;

  static Future<void>? _pending;

  /// Version for display while startup may still be in flight. Never blocks.
  static String get versionLabel => _loaded ? version : '…';

  /// Sentry release identifier, e.g.
  /// `au.com.notiva.medicaleventrecorder@1.1.0+5`.
  ///
  /// Format is package@version+build, unchanged from the string this replaced,
  /// so release history is not split across two naming conventions.
  static String get sentryRelease => '$packageName@$version+$buildNumber';

  /// Reads the platform package metadata. Requires the Flutter binding to be
  /// initialised.
  ///
  /// Safe to call repeatedly and concurrently: the first call owns the
  /// platform-channel round trip and every other caller awaits the same
  /// future. Never throws — a failure leaves [isLoaded] false and clears the
  /// pending future so a later caller can retry.
  ///
  /// This is deliberately NOT awaited during startup. On Android a cold start
  /// from a notification action is the capture path, and nothing on that path
  /// may wait on a platform channel.
  static Future<void> load() {
    if (_loaded) return Future<void>.value();
    return _pending ??= _load();
  }

  static Future<void> _load() async {
    try {
      final info  = await PackageInfo.fromPlatform();
      packageName = info.packageName;
      version     = info.version;
      buildNumber = info.buildNumber;
      _loaded     = true;
    } catch (_) {
      _pending = null; // allow a later attempt
    }
  }
}
