import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Path with platform separators normalised to forward slashes.
///
/// Duplicated from `ios_handoff_test.dart` rather than shared, for the reason
/// that file records: on Windows `Directory.listSync` returns `ios\MERWidget\…`
/// and every `contains('/Foo/')` predicate silently misses, which made that
/// file's guard unfalsifiable on one of the two machines that runs it.
String _posix(String p) => p.replaceAll(Platform.pathSeparator, '/');

/// The active-marker preservation rule, and the invariant two sites lean on.
///
/// ⭐ THE RULE: NO SITE DELETES AN ACTIVE MARKER WITHOUT FIRST PRESERVING WHAT
/// IT COULD NOT READ. It is satisfied at three sites by a CALL, and at two more
/// by an INVARIANT — both marker copies are written in one place from one value,
/// so those two can only ever delete a byte-identical duplicate of something
/// another site already adjudicated.
///
/// ⛔ A SCAN CANNOT SEE AN INVARIANT, so the invariant is PINNED and the pin is
/// what this file checks. If `the pin` goes red, `clearStaleActiveStateIfEnded`
/// and the feedback-tap branch become lossy with nothing else going red to say
/// so.
///
/// ⭐ SECOND INSTANCE OF A PATTERN, and worth recording as such. The
/// `whenHappened` cluster, the same day, did not make six write sites remember a
/// convention — it reduced assignment to one place and scanned for exactly one.
/// This is that shape in Swift: five deletion sites are not made to remember a
/// preserve; the WRITE is pinned to one site and the redundancy of two deletions
/// follows from it.
///
/// ⚠️ WHAT THIS FILE CANNOT ESTABLISH, stated here rather than only in a report,
/// because a green run read in three months must not imply coverage it does not
/// have:
///
///  * It establishes that a preserve call EXISTS in the same function and
///    TEXTUALLY PRECEDES the removal.
///  * It does NOT establish that the call sits on the failure branch rather than
///    the success branch, and it does NOT establish that it ever runs. Verifying
///    either needs Swift control flow, which a text scan does not have.
///  * ⛔ THE PRESERVE CAPTURES THE APP-SUITE COPY ONLY, AND THIS LIST DID NOT
///    SAY SO UNTIL 21 SEPTEMBER 2026. `preserveUnreadableMarker` reads
///    `UserDefaults.standard`, so what lands in the quarantine is
///    `kActiveEventKey`. The App Group removals that follow it —
///    `AppDelegate.swift`'s `kSharedActiveKey` clears in `handleQuickLogEnd`
///    and `endActiveEventFromApp` — are NOT preserved by that call. They are
///    safe because the single-write invariant makes the two copies
///    byte-identical, so the preserved bytes are the same bytes. ⭐ THEIR
///    SAFETY RESTS ON THE INVARIANT, NOT ON THE PRESERVE. Break the invariant
///    and *the preserve — present at the three call sites* below still passes
///    while those two removals become lossy.
///
///    ⚠️ The group *every marker removal is preceded by a preserve* now covers
///    them, having been added because the original helper stopped at the FIRST
///    removal matching its token and never examined the line after it. A file
///    that lists its limits implies the list is complete, which is why this was
///    worse than an unlisted limit in a file that lists none.
///  * The conditions that PRODUCE an unreadable marker are cold-and-locked.
///    `ARCHITECTURE.md` §5 records that `didReceive` is not entered cold,
///    measured on hardware. No simulator reproduces that, so this file is the
///    logic half only; the other half is an argument about a cable.
///
/// ⚠️ AND WHAT THE QUARANTINE IS. Preservation, on the asymmetry that bytes are
/// cheap and deleting an unparseable marker is irreversible. NOTHING IN THE
/// FIELD READS IT. The `os_log` beside each preserve is a development reader —
/// Console.app over a cable, not durable across a reboot.
void main() {
  late List<File> swiftFiles;

  String appDelegate() => File('ios/Runner/AppDelegate.swift').readAsStringSync();
  String endIntent()   => File('ios/MERWidget/EndMEREventIntent.swift').readAsStringSync();

  setUp(() {
    // Pods and .symlinks are excluded for the reason ios_handoff_test.dart
    // records: following them turns this into a scan of every plugin's example
    // app, where a coincidental hit is a spurious failure and a real one is
    // buried.
    swiftFiles = Directory('ios')
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((f) => f.path.endsWith('.swift'))
        .where((f) => !_posix(f.path).contains('/Pods/'))
        .where((f) => !_posix(f.path).contains('/.symlinks/'))
        .toList();
  });

  // ── Lines that WRITE one of the two marker keys ───────────────────────────
  List<String> markerWrites(List<File> files, List<String> keyTokens) {
    final hits = <String>[];
    for (final f in files) {
      final lines = f.readAsStringSync().split('\n');
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//') ||
            line.trimLeft().startsWith('///')) {
          continue;
        }
        final isWrite = line.contains('.set(') || line.contains('.setValue(');
        if (!isWrite) continue;
        if (!line.contains('forKey:')) continue;
        if (keyTokens.any(line.contains)) {
          hits.add('${_posix(f.path)}:${i + 1}: ${line.trim()}');
        }
      }
    }
    return hits;
  }

  group('the pin — one write site per marker key', () {
    test('exactly one Swift site writes the app-suite active marker', () {
      expect(swiftFiles, isNotEmpty,
          reason: 'positive control: Swift files were actually scanned');

      final writes = markerWrites(swiftFiles, ['kActiveEventKey']);

      expect(writes, hasLength(1),
          reason: 'THE LOAD-BEARING INVARIANT. clearStaleActiveStateIfEnded and '
              'the feedback-tap branch delete this key without preserving it, '
              'and that is safe ONLY because it is written in one place, '
              'together with the App Group copy, from one value. A second '
              'writer makes both of those sites lossy and nothing else goes '
              'red. Found:\n${writes.join('\n')}');
    });

    test('exactly one Swift site writes the App Group active marker', () {
      final writes =
          markerWrites(swiftFiles, ['kSharedActiveKey', 'kSharedActive']);

      expect(writes, hasLength(1),
          reason: 'same invariant, other copy. Found:\n${writes.join('\n')}');
    });

    test('both marker writes are adjacent and share one value', () {
      final src   = appDelegate();
      final lines = src.split('\n');

      final iStd = lines.indexWhere((l) =>
          l.contains('.set(') && l.contains('forKey: kActiveEventKey'));
      final iShr = lines.indexWhere((l) =>
          l.contains('.set(') && l.contains('forKey: kSharedActiveKey'));

      expect(iStd, isNot(-1), reason: 'positive control: the app-suite write was found');
      expect(iShr, isNot(-1), reason: 'positive control: the App Group write was found');

      expect((iShr - iStd).abs(), lessThanOrEqualTo(1),
          reason: 'the two copies must be written together. Separating them is '
              'how they start to diverge, and divergence is what makes the two '
              'no-preserve sites lossy');

      // Same source value, so the two copies are byte-identical by construction.
      final valStd = RegExp(r'\.set\((\w+),').firstMatch(lines[iStd])?.group(1);
      final valShr = RegExp(r'\.set\((\w+),').firstMatch(lines[iShr])?.group(1);

      expect(valStd, isNotNull, reason: 'positive control: a value name was parsed');
      expect(valStd, equals(valShr),
          reason: 'both marker copies must come from ONE value. '
              'app-suite writes "$valStd", App Group writes "$valShr"');
    });
  });

  group('the pin — the Dart half', () {
    // The app-suite key is "flutter.mer_active_event", which is what
    // shared_preferences produces when Dart writes "mer_active_event". So Dart
    // is a potential SECOND writer of one copy and not the other — exactly the
    // divergence the invariant forbids. It is unreachable on iOS today, and
    // this is what holds that true.
    test('Dart cannot write the marker on iOS', () {
      final svc = File('lib/services/notification_service.dart').readAsStringSync();
      final lines = svc.split('\n');

      final writers = <int>[];
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('setString(_activeEventKey')) writers.add(i + 1);
      }
      expect(writers, hasLength(1),
          reason: 'positive control: Dart has exactly one writer of the marker, '
              'inside _handleStart. Found at lines $writers');

      final callers = <int>[];
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('_handleStart()') &&
            !lines[i].contains('Future<void> _handleStart')) {
          callers.add(i + 1);
        }
      }
      expect(callers, hasLength(1),
          reason: 'more than one caller of _handleStart means this guard no '
              'longer covers every path to the Dart write. Found at $callers');

      final guard  = lines.indexWhere((l) => l.contains('if (Platform.isIOS) return;'));
      final caller = callers.single - 1;

      expect(guard, isNot(-1),
          reason: 'onActionReceived must return early on iOS — the native '
              'handler owns that path');
      expect(guard, lessThan(caller),
          reason: 'the iOS guard must precede the only call to _handleStart. '
              'Without it Dart writes the app-suite copy ALONE, the two copies '
              'diverge, and the two no-preserve sites lose the only copy of a '
              'marker nobody preserved');
    });
  });

  group('the enumeration — every marker removal is accounted for', () {
    // Two enumerations on this project were wrong before this one, so this is
    // not a formality. A removal added to a function not on this list fails
    // here, which is the only thing standing between "five sites" and "five
    // sites plus one nobody noticed".
    const known = <String>{
      'clearStaleActiveStateIfEnded',  // invariant, no preserve — see its doc block
      'restorePersistentNotification', // parses before removing; checked 21 Sep 2026
      'userNotificationCenter',        // feedback-tap branch; invariant, no preserve
      'handleQuickLogEnd',             // preserves
      'endActiveEventFromApp',         // preserves
      'perform',                       // EndMEREventIntent; preserves
    };

    test('no marker removal lives in an unlisted function', () {
      final offenders = <String>[];
      var  removals   = 0;

      for (final f in swiftFiles.where((f) =>
          _posix(f.path).contains('/Runner/AppDelegate.swift') ||
          _posix(f.path).contains('/MERWidget/EndMEREventIntent.swift'))) {
        final lines = f.readAsStringSync().split('\n');
        var enclosing = '<file scope>';

        for (var i = 0; i < lines.length; i++) {
          final line = lines[i];
          final fn = RegExp(r'\bfunc\s+(\w+)').firstMatch(line);
          if (fn != null && !line.trimLeft().startsWith('//')) {
            enclosing = fn.group(1)!;
          }
          if (line.trimLeft().startsWith('//')) continue;
          if (!line.contains('removeObject(forKey:')) continue;
          if (!(line.contains('kActiveEventKey') ||
                line.contains('kSharedActiveKey') ||
                line.contains('kSharedActive'))) {
            continue;
          }
          removals++;
          if (!known.contains(enclosing)) {
            offenders.add('${_posix(f.path)}:${i + 1} in $enclosing');
          }
        }
      }

      expect(removals, greaterThan(0),
          reason: 'positive control: marker removals were actually found');
      expect(offenders, isEmpty,
          reason: 'a function not on the known list removes an active marker. '
              'Every removal must either preserve first, or carry a comment '
              'saying which invariant makes it safe and naming this pin. '
              'Scanned $removals removals. Unlisted:\n${offenders.join('\n')}');
    });
  });

  group('the preserve — present at the three call sites', () {
    // ⚠️ TEXTUAL PRECEDENCE ONLY. This shows a preserve exists in the function
    // and appears before the removal. It does NOT show the call is on the
    // failure branch, and it does NOT show it runs.
    void expectPreserveBeforeRemoval({
      required String source,
      required String function,
      required String removalToken,
    }) {
      final lines = source.split('\n');
      final start = lines.indexWhere((l) => l.contains('func $function'));
      expect(start, isNot(-1), reason: 'positive control: $function was found');

      var preserve = -1;
      var removal  = -1;
      for (var i = start; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;
        if (preserve == -1 &&
            (line.contains('preserveUnreadableMarker') ||
             line.contains('forKey: kQuarantineKey'))) {
          preserve = i;
        }
        if (line.contains('removeObject(forKey:') &&
            line.contains(removalToken)) {
          removal = i;
          break;
        }
      }

      expect(preserve, isNot(-1),
          reason: '$function removes an active marker with no preserve before '
              'it. An unreadable marker is the ONLY evidence the event was '
              'running, and deleting it is irreversible');
      expect(removal, isNot(-1),
          reason: 'positive control: the removal in $function was found');
      expect(preserve, lessThan(removal),
          reason: 'the preserve in $function must come BEFORE the removal. '
              'After it there is nothing left to read');
    }

    test('handleQuickLogEnd preserves before clearing', () {
      expectPreserveBeforeRemoval(
        source:       appDelegate(),
        function:     'handleQuickLogEnd',
        removalToken: 'kActiveEventKey',
      );
    });

    test('endActiveEventFromApp preserves before clearing', () {
      expectPreserveBeforeRemoval(
        source:       appDelegate(),
        function:     'endActiveEventFromApp',
        removalToken: 'kActiveEventKey',
      );
    });

    test('EndMEREventIntent preserves before clearing', () {
      expectPreserveBeforeRemoval(
        source:       endIntent(),
        function:     'perform',
        removalToken: 'kSharedActive',
      );
    });

    // ── the widening, 21 September 2026 ──────────────────────────────────
    //
    // ⛔ expectPreserveBeforeRemoval BREAKS AT THE FIRST REMOVAL matching its
    // token, so in handleQuickLogEnd it examined :955 and stopped, and the
    // App Group removal on :956 was never looked at. Same in
    // endActiveEventFromApp for :1062 / :1063.
    //
    // This checks EVERY marker removal in those functions, not the first.
    // It passes today — the preserve textually precedes both — but it is what
    // makes that a checked fact rather than an assumed one. See the limits
    // note at the top for what "preceded by a preserve" does and does not
    // buy for the App Group copy specifically.
    void expectPreserveBeforeEveryRemoval({
      required String source,
      required String function,
      required int expectedRemovals,
    }) {
      final lines = source.split('\n');
      final start = lines.indexWhere((l) => l.contains('func $function'));
      expect(start, isNot(-1), reason: 'positive control: $function was found');

      var preserve = -1;
      final unprotected = <String>[];
      var removals = 0;
      var depth = 0;
      var seenBody = false;

      for (var i = start; i < lines.length; i++) {
        final line = lines[i];
        if (line.trimLeft().startsWith('//')) continue;

        if (preserve == -1 &&
            (line.contains('preserveUnreadableMarker') ||
             line.contains('forKey: kQuarantineKey'))) {
          preserve = i;
        }

        // `kSharedActive` and not `kSharedActiveKey`: EndMEREventIntent spells
        // the constant without the suffix, being a separate target with its own
        // local copy. Matching only the suffixed form found ZERO removals there
        // — caught by the expectedRemovals control on its first run, which is
        // what that control is for.
        if (line.contains('removeObject(forKey:') &&
            (line.contains('kActiveEventKey') ||
             line.contains('kSharedActive'))) {
          removals++;
          if (preserve == -1 || preserve > i) {
            unprotected.add('line ${i + 1}: ${line.trim()}');
          }
        }

        depth += '{'.allMatches(line).length - '}'.allMatches(line).length;
        if (depth > 0) seenBody = true;
        if (seenBody && depth <= 0) break;
      }

      expect(removals, expectedRemovals,
          reason: 'positive control: $function must contain exactly '
              '$expectedRemovals marker removals. A different count means the '
              'function changed shape and this assertion is now measuring '
              'something else. Found $removals');
      expect(unprotected, isEmpty,
          reason: '⛔ a marker removal in $function is NOT preceded by a '
              'preserve. The original helper stopped at the first removal and '
              'could not see this. Unprotected:\n${unprotected.join('\n')}');
    }

    test('every marker removal in handleQuickLogEnd is preceded by a preserve',
        () {
      expectPreserveBeforeEveryRemoval(
        source:           appDelegate(),
        function:         'handleQuickLogEnd',
        expectedRemovals: 2,
      );
    });

    test('every marker removal in endActiveEventFromApp is preceded by a preserve',
        () {
      expectPreserveBeforeEveryRemoval(
        source:           appDelegate(),
        function:         'endActiveEventFromApp',
        expectedRemovals: 2,
      );
    });

    test('every marker removal in EndMEREventIntent is preceded by a preserve',
        () {
      expectPreserveBeforeEveryRemoval(
        source:           endIntent(),
        function:         'perform',
        expectedRemovals: 1,
      );
    });

    test('the preserve adds no blocking call to the capture path', () {
      // writeInboxInstruction records that synchronize() "can sit waiting on
      // cfprefsd while the window runs out". Sites 1 and 3 are on that path.
      final intent = endIntent();
      expect('synchronize()'.allMatches(intent).length, equals(1),
          reason: 'EndMEREventIntent had exactly one synchronize() before the '
              'preserve was added and must still have exactly one. It is the '
              'tightest window of the three sites');
    });
  });
}
