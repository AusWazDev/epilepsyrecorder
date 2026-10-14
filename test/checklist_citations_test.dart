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

/// The marker that declares ONE occurrence of a citation to be a real thing on
/// the build host, not in this repository. It goes immediately after the
/// closing backtick, with no space.
const String _hostMarker = '[host]';

/// The closed list of citations that may carry [_hostMarker] (Brief CIT-1,
/// 14 Oct 2026). **Every entry needs a reason.**
///
/// ⛔ Two locks, and the second is the point. The marker excuses only the
/// occurrence it sits on, so the same token cited UNMARKED anywhere else must
/// still resolve. And a marked token that is NOT in this map fails, so a new
/// unresolvable citation can pass only if a person marks it AND names it here.
/// A skip keyed on "does not resolve" would define the population by the pass
/// condition, and could never fail; this is keyed on a deliberate act instead.
const Map<String, String> _hostCitations = {
  'dSYMs/': 'a directory inside an Xcode archive, which is build output',
  'c05df5d0-3e4a-463d-98dc-4017e8f5e739': 'a provisioning profile UUID on the Mac',
  '46ab2a99…': 'a removed provisioning profile, quoted truncated',
  '/Applications/OneDrive.app': 'a macOS application path',
  '/Applications/OneDrive.localized/OneDrive.app': 'a macOS application path',
  'xcodebuild': 'Apple command-line tool',
  'willQuit': 'an event name in Claude desktop\'s log on the Mac',
  '~/.claude/CLAUDE.md': 'the Mac\'s global Claude Code rules file',
  'mds_stores': 'the macOS Spotlight indexing process',
  'ProvisionedDevices': 'a key inside a provisioning profile',
  'memory_pressure': 'macOS command-line tool',
  'uptime': 'Unix command-line tool',
  '~/.sentryclirc': 'sentry-cli credentials file on the Mac, never in the repo',
  '.p8': 'App Store Connect API key file type, Mac-only by design',
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
  _Citation(this.token, this.section, this.line, {this.host = false});
  final String token;
  final String section;
  final int line;

  /// True when this occurrence carries [_hostMarker].
  final bool host;
  @override
  String toString() =>
      '`$token`${host ? _hostMarker : ''}  (§$section, checklist line $line)';
}

/// The unmarked symbol rule: present as an identifier in the corpus, or a bare
/// filename at the repository root.
bool _symbolResolves(String root, String corpus, String token) =>
    _presentAsIdentifier(corpus, token) ||
    File('$root/$token').existsSync() ||
    Directory('$root/$token').existsSync();

/// The unmarked path rule: a file or directory under the repository root.
bool _pathResolves(String root, String token) {
  final p = token.endsWith('/') ? token.substring(0, token.length - 1) : token;
  return File('$root/$p').existsSync() || Directory('$root/$p').existsSync();
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
      final host = line.startsWith(_hostMarker, m.end);
      final c = _Citation(t, section, i + 1, host: host);
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
        // A marked occurrence is held to the closed list instead, in the
        // 'host citations' group below. Unmarked ones of the same token are not.
        if (c.host) continue;
        if (_notOurSymbols.containsKey(c.token)) continue;
        if (_notASymbolShape.hasMatch(c.token)) continue;
        checked++;
        // A bare filename is a path citation without a slash — STATUS.md, and
        // anything else at the repository root.
        if (_symbolResolves(root, corpus, c.token)) continue;
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
        if (c.host) continue; // see the symbol test
        if (_notOurPaths.containsKey(c.token)) continue;
        if (c.token.startsWith('http')) continue;
        checked++;
        if (!_pathResolves(root, c.token)) missing.add(c);
      }

      expect(checked, greaterThanOrEqualTo(10),
          reason: 'only $checked paths were checked — the extraction is '
              'probably broken');

      expect(missing, isEmpty,
          reason: 'the checklist cites paths that do not resolve:\n'
              '${missing.map((m) => '  $m').join('\n')}');
    });
  });

  group('host citations', () {
    final marked = [...extracted.symbols, ...extracted.paths]
        .where((c) => c.host)
        .toList();

    test('every [host] citation is in the closed list', () {
      final unlisted =
          marked.where((c) => !_hostCitations.containsKey(c.token)).toList();
      expect(unlisted, isEmpty,
          reason: 'these are marked $_hostMarker but are not in _hostCitations. '
              'The marker alone excuses nothing: name each one, with a reason, '
              'or cite something in the repository:\n'
              '${unlisted.map((m) => '  $m').join('\n')}');
    });

    test('a [host] citation does not resolve in the repository', () {
      // A marker on something the repo HAS would hide a later rename of it.
      final wronglyMarked = marked.where((c) => c.token.contains('/')
          ? _pathResolves(root, c.token)
          : _symbolResolves(root, corpus, c.token)).toList();
      expect(wronglyMarked, isEmpty,
          reason: 'marked $_hostMarker but present in the repository; remove '
              'the marker so the citation is checked:\n'
              '${wronglyMarked.map((m) => '  $m').join('\n')}');
    });

    test('every closed-list entry is still marked somewhere', () {
      final used = marked.map((c) => c.token).toSet();
      final stale = _hostCitations.keys.where((k) => !used.contains(k)).toList();
      expect(stale, isEmpty,
          reason: 'in _hostCitations but no longer cited with $_hostMarker; '
              'remove the entry so the list stays closed: $stale');
    });

    test('the closed list is small, and every entry has a reason', () {
      expect(_hostCitations.length, lessThan(25),
          reason: 'the host list has grown into a place to hide failures');
      for (final entry in _hostCitations.entries) {
        expect(entry.value.trim(), isNotEmpty,
            reason: '${entry.key} is listed without a stated reason');
      }
    });

    test('the marker is read per occurrence — control', () {
      final x = _extract('## s\n`a/b`$_hostMarker and `a/b` and `c` $_hostMarker\n');
      expect(x.paths.map((c) => c.host).toList(), [true, false],
          reason: 'the same token must be marked at one occurrence only');
      expect(x.symbols.single.host, isFalse,
          reason: 'a marker after a space is not attached to the span');
      expect(marked, isNotEmpty,
          reason: 'no $_hostMarker citations found: the marker reader is broken '
              'or the checklist lost its markings');
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
