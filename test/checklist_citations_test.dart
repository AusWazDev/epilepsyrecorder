/// Asserts that every symbol and path `docs/iOS Device Test Checklist.md` cites
/// actually exists.
///
/// ## Why this exists
///
/// The checklist is verified against the code by hand, and that verification
/// rotted three times in one week. The worst case was §3.5, which for months
/// instructed a tester to exercise `syncFromSharedIfNeeded` and "an
/// unconditional sync in didReceive" — the first had been renamed and no longer
/// reconciled record lists, the second had been deleted outright. A tester
/// following those steps was testing nothing, and the document read as though
/// they were.
///
/// `tool/verify_release_signing.sh` now guards the build artefact. Nothing
/// guarded the prose. This does.
///
/// ## What it can and cannot catch
///
/// It catches a **rename or deletion** of anything the checklist names — which
/// is the failure that actually happened, repeatedly. It cannot check that a
/// step's *reasoning* is still true; only that the things it points at exist.
/// A symbol that survives but changes meaning still needs a person.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Where cited names must be found. Source and build configuration only —
/// deliberately NOT `test/`, so that a stale name surviving in a test comment
/// cannot vouch for a citation.
const List<String> _corpusDirs = [
  'lib',
  'ios/Runner',
  'ios/MERWidget',
  'tool',
];

const List<String> _corpusFiles = [
  'pubspec.yaml',
  'ios/Podfile',
  'ios/Runner.xcodeproj/project.pbxproj',
];

const String _checklist = 'docs/iOS Device Test Checklist.md';

/// Backticked spans that are not names of things in this repository.
///
/// Kept short on purpose. **Every entry needs a reason**, because this map is
/// the one place a real citation failure could be hidden.
const Map<String, String> _notOurSymbols = {
  // Third-party classes and packages. Real names, but they live in the plugins,
  // not here, so requiring them in our corpus would be a false failure.
  'FileSelectorIOS': 'file_selector_ios plugin class',
  'file_selector': 'package name',
  'file_selector_ios': 'package name',
  'file_selector_android': 'package name',
  'share_plus': 'package name',
  'getSaveLocation': 'file_selector platform-interface method',
  'getSavePath': 'file_selector platform-interface method',
  'openFile': 'file_selector method',
  'openFiles': 'file_selector method',
  'XTypeGroup': 'file_selector type',
  'UnimplementedError': 'dart:core',
  'ArgumentError': 'dart:core',
  'ActivityContent': 'ActivityKit',
  'ActivityKit': 'Apple framework',
  'UNUserNotificationCenter.delegate': 'UserNotifications, property reference',
  'IntentAuthenticationPolicy': 'AppIntents',
  'LiveActivityIntent': 'AppIntents protocol',
  'ShareResultStatus.success': 'share_plus enum value',

  // Apple / OS identifiers, not code in this repo.
  '0xe80000be': 'iOS installation error code',
  'MinimumOSVersion': 'Info.plist key, set by the build not written by us',
  'IPHONEOS_DEPLOYMENT_TARGET': 'Xcode build setting name',

  // Team identifiers and commit hashes.
  '6AXX9KX39T': 'Apple team identifier of a second developer account',

  // Values the document quotes, not names it cites.
  'seizure': 'default event type value shown to the tester',
  'mild': 'default severity value shown to the tester',
  'Always': 'the value of the iOS Show Previews setting',
  'try': 'Dart/Swift keyword, quoted in prose',
  'catch': 'Dart/Swift keyword, quoted in prose',

  // Cited precisely BECAUSE it is absent. The checklist's point is that the
  // notification action does NOT carry it, so requiring it in our source would
  // invert the claim.
  '.authenticationRequired': 'UNNotificationActionOptions member, cited as absent',
};

/// Path-looking spans that are not paths in this repository.
const Map<String, String> _notOurPaths = {
  '/storage/emulated/0/Download': 'an Android device path',
  'ios/MERWidget/': 'a directory, checked as ios/MERWidget',
  // Cited as NOT existing: §9's table says there is no linux/ target here.
  'linux/': 'cited as absent — this repo has no linux target',
};

/// A commit hash, a version number, or a section reference — never a symbol.
final RegExp _notASymbolShape = RegExp(
  r'^('
  r'[0-9a-f]{7,40}'          // commit hash
  r'|0x[0-9a-fA-F]+'         // hex literal
  r'|[0-9]+(\.[0-9]+)*x?'    // 16.2, 26.6, 16.x, 35
  r'|v[0-9]+(\.[0-9]+)*'     // v1.1.0
  r'|§.*'                    // section reference
  r'|[0-9]+'                 // bare number
  r')$',
);

String _repoRoot() {
  var dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      throw StateError('could not find the package root from ${Directory.current.path}');
    }
    dir = parent;
  }
  return dir.path;
}

/// Reads the corpus once. `followLinks: false` and an explicit `.symlinks`
/// filter, because `listSync` follows symlinks and `ios/.symlinks/plugins`
/// would otherwise drag in every plugin's source — which once made three tests
/// silently scan other people's code.
String _readCorpus(String root) {
  final buf = StringBuffer();
  for (final d in _corpusDirs) {
    final dir = Directory('$root/$d');
    if (!dir.existsSync()) continue;
    for (final e in dir.listSync(recursive: true, followLinks: false)) {
      if (e is! File) continue;
      if (e.path.contains('/.symlinks/')) continue;
      if (e.path.contains('/Pods/')) continue;
      try {
        buf.writeln(e.readAsStringSync());
      } on FileSystemException {
        // Binary asset. Nothing cited lives in one.
      }
    }
  }
  for (final f in _corpusFiles) {
    final file = File('$root/$f');
    if (file.existsSync()) buf.writeln(file.readAsStringSync());
  }
  return buf.toString();
}

/// True when [token] appears in [corpus] as a whole identifier.
///
/// **Substring matching is not good enough, and this was caught by the
/// demonstration rather than by reasoning.** Renaming
/// `registerNativeNotificationCategories` to
/// `registerNativeNotificationCategoriesRENAMED` left the old name as a prefix
/// of the new one, so `corpus.contains` still found it and the test passed on a
/// citation that had genuinely broken. Any rename that appends — a suffix, a
/// version marker, `Legacy`, `Old` — would have slipped through.
bool _presentAsIdentifier(String corpus, String token) {
  final re = RegExp('(?<![A-Za-z0-9_])${RegExp.escape(token)}(?![A-Za-z0-9_])');
  return re.hasMatch(corpus);
}

class _Citation {
  _Citation(this.token, this.section, this.line);
  final String token;
  final String section;
  final int line;
  @override
  String toString() => '`$token`  (§$section, checklist line $line)';
}

/// Extracts backticked spans, remembering which section each came from, and
/// skipping fenced code blocks — a shell command is not a citation.
({List<_Citation> symbols, List<_Citation> paths}) _extract(String md) {
  final symbols = <_Citation>[];
  final paths = <_Citation>[];
  final span = RegExp(r'`([^`\n]+)`');
  var section = '(front matter)';
  var inFence = false;

  final lines = md.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trimLeft().startsWith('```')) {
      inFence = !inFence;
      continue;
    }
    if (inFence) continue;

    final heading = RegExp(r'^#{2,3}\s+(.+)$').firstMatch(line);
    if (heading != null) section = heading.group(1)!.trim();

    for (final m in span.allMatches(line)) {
      var t = m.group(1)!.trim();
      if (t.isEmpty) continue;
      // Prose in backticks, not a name.
      if (t.contains(RegExp(r'\s'))) continue;
      t = t.replaceAll(RegExp(r'\(\)$'), '');
      t = t.replaceAll(RegExp(r'[.,;:]+$'), '');
      if (t.isEmpty) continue;
      final c = _Citation(t, section, i + 1);
      if (t.contains('/')) {
        paths.add(c);
      } else {
        symbols.add(c);
      }
    }
  }
  return (symbols: symbols, paths: paths);
}

void main() {
  final root = _repoRoot();
  final md = File('$root/$_checklist').readAsStringSync();
  final corpus = _readCorpus(root);
  final extracted = _extract(md);

  group('the checklist cites things that exist', () {
    test('every cited symbol appears in the source or build configuration', () {
      final missing = <_Citation>[];
      var checked = 0;
      for (final c in extracted.symbols) {
        if (_notOurSymbols.containsKey(c.token)) continue;
        if (_notASymbolShape.hasMatch(c.token)) continue;
        checked++;
        if (_presentAsIdentifier(corpus, c.token)) continue;
        // A bare filename is a path citation without a slash — STATUS.md, and
        // anything else at the repository root.
        if (File('$root/${c.token}').existsSync() ||
            Directory('$root/${c.token}').existsSync()) {
          continue;
        }
        missing.add(c);
      }

      // Positive control: the extraction must actually be finding citations.
      // Without this the test passes trivially if the regex, the fence handling
      // or the file path ever breaks.
      expect(checked, greaterThanOrEqualTo(40),
          reason: 'only $checked symbols were checked — the extraction is '
              'probably broken, and a test that scans nothing passes for free');

      expect(missing, isEmpty,
          reason: 'the checklist names things that no longer exist. Either the '
              'code was renamed and the document was not updated, or the '
              'citation was wrong when written:\n'
              '${missing.map((m) => '  $m').join('\n')}');
    });

    test('every cited path resolves', () {
      final missing = <_Citation>[];
      var checked = 0;
      for (final c in extracted.paths) {
        if (_notOurPaths.containsKey(c.token)) continue;
        if (c.token.startsWith('http')) continue;
        checked++;
        final p = c.token.endsWith('/')
            ? c.token.substring(0, c.token.length - 1)
            : c.token;
        final exists = File('$root/$p').existsSync() ||
            Directory('$root/$p').existsSync();
        if (!exists) missing.add(c);
      }

      expect(checked, greaterThanOrEqualTo(10),
          reason: 'only $checked paths were checked — the extraction is '
              'probably broken');

      expect(missing, isEmpty,
          reason: 'the checklist cites paths that do not resolve:\n'
              '${missing.map((m) => '  $m').join('\n')}');
    });
  });

  group('controls', () {
    test('the corpus is real and non-trivial', () {
      expect(corpus.length, greaterThan(200000),
          reason: 'the corpus is too small to be the whole source tree — '
              'a truncated corpus makes every lookup pass');
      // A symbol from each half of the boundary the checklist is about.
      expect(_presentAsIdentifier(corpus, 'handleQuickLogEnd'), isTrue,
          reason: 'Swift side missing from the corpus');
      expect(_presentAsIdentifier(corpus, 'bucketFromSeconds'), isTrue,
          reason: 'Dart side missing from the corpus');
    });

    test('the lookup can return false — negative control', () {
      // If this ever passes, `corpus.contains` is not discriminating and every
      // assertion above is worthless.
      expect(_presentAsIdentifier(corpus, 'thisSymbolIsNotAnywhereInMER'), isFalse);
      // The exact hole the demonstration exposed: a name that survives only as
      // a PREFIX of a longer one must not count as present.
      expect(_presentAsIdentifier('void handleQuickLogEndRENAMED() {}',
          'handleQuickLogEnd'), isFalse,
          reason: 'substring matching is back — an appending rename will pass');
      expect(_presentAsIdentifier('void handleQuickLogEnd() {}',
          'handleQuickLogEnd'), isTrue);
    });

    test('the ignore lists are small enough to audit', () {
      // Not a style rule. These maps are the one place a genuine citation
      // failure could be buried, so their size is itself the risk.
      expect(_notOurSymbols.length, lessThan(40),
          reason: 'the ignore list has grown into a place to hide failures');
      expect(_notOurPaths.length, lessThan(10));
      for (final entry in _notOurSymbols.entries) {
        expect(entry.value.trim(), isNotEmpty,
            reason: '${entry.key} is ignored without a stated reason');
      }
    });

    test('the checklist still has the sections the register cites by number', () {
      // The Change Register references §3.3, §3.4, §5, §7 and §8 by number, and
      // §0 was numbered 0 rather than renumbering them. If a heading is
      // renumbered those references silently rot.
      for (final h in ['## 0.', '### 3.3', '### 3.4', '## 5.', '## 7.', '## 8.']) {
        expect(md.contains(h), isTrue,
            reason: 'the checklist no longer has a heading starting "$h" — '
                'the Change Register cites it by number');
      }
    });
  });
}
