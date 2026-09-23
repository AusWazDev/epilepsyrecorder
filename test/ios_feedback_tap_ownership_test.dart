import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Ownership of the active marker at the feedback-tap branch.
///
/// ⭐ THE RULE THIS PINS: AN OPERATION THAT CLEARS STATE ON BEHALF OF AN EVENT
/// MUST ESTABLISH THAT THE STATE BELONGS TO THAT EVENT.
///
/// ⛔ THE DEFECT IT WAS WRITTEN AGAINST. `didReceive`'s default-action branch
/// cleared the app-suite active marker UNCONDITIONALLY. A feedback notification
/// for event A, tapped after event B had started, therefore deleted B's marker.
/// B then lost its duration and every end surface with it:
/// clearStaleActiveStateIfEnded wants the mirror-image guard and does not fire,
/// restorePersistentNotification reads nil and tears down B's Live Activity and
/// notification while B is still running, endActiveEventFromApp writes no end
/// instruction, and the 30-minute timeout lives in the branch that is no longer
/// reachable.
///
/// ⚠️ IDENTITY IS NOT AVAILABLE AND THAT IS WHY THIS PINS OWNERSHIP INSTEAD.
/// Neither feedback notification carries an event id — `userInfo` appears
/// nowhere in ios/ — so A cannot be compared to B by name. Ownership is
/// established structurally: the App Group copy has ONE writer and FOUR
/// clearers, and all four clearers end or abandon the event, so its presence
/// means an event is live and its absence means the app-suite copy is residue.
/// Both halves of that are pinned below.
///
/// ⚠️ WHAT THIS FILE CANNOT ESTABLISH, stated here and not only in a report,
/// because a green run read in three months must not imply coverage it lacks:
///
///  * It is a TEXT SCAN. It establishes that the removal sits inside a block
///    opened by a condition that reads the App Group marker key. It does NOT
///    execute Swift and cannot establish that the guard evaluates as intended.
///  * It does NOT establish the runtime sequence that produced the defect. That
///    argument is from source and is not device-verified.
///  * It says nothing about the notification NEVER BEING REMOVED, which is a
///    separate defect recorded at showFeedbackNotification and not fixed.
String _posix(String p) => p.replaceAll(Platform.pathSeparator, '/');

/// The verdict this file exists to produce, for one piece of Swift source.
enum Ownership {
  /// The removal is inside a block whose condition reads the App Group marker.
  guarded,

  /// The removal runs unconditionally in the case body. THE DEFECT.
  unguarded,

  /// No removal of the app-suite marker in this branch at all.
  absent,
}

/// Reads the feedback-tap branch of `didReceive` and says whether the marker
/// removal in it is dominated by a read of the App Group copy.
///
/// ⭐ BRACE DEPTH, NOT PROXIMITY. An earlier form of this checked only that
/// `kSharedActiveKey` appeared somewhere above the removal, which a COMMENT
/// mentioning the key would satisfy — and this branch is mostly comment. Depth
/// is what distinguishes "inside the guard" from "after it".
Ownership classify(String source) {
  final lines = source.split('\n');

  var start = lines.indexWhere((l) =>
      l.contains('case UNNotificationDefaultActionIdentifier'));
  if (start == -1) return Ownership.absent;

  var depth = 0;
  final openers = <int, String>{};
  for (var i = start; i < lines.length; i++) {
    final raw = lines[i];
    final code = raw.trimLeft().startsWith('//') ? '' : raw;

    // The case ends at the next case label at depth 0.
    if (i > start &&
        depth == 0 &&
        RegExp(r'^\s*(case |default:)').hasMatch(code)) {
      break;
    }

    if (code.contains('removeObject(forKey:') &&
        code.contains('kActiveEventKey')) {
      if (depth == 0) return Ownership.unguarded;
      final opener = openers[depth];
      if (opener != null && opener.contains('kSharedActiveKey')) {
        return Ownership.guarded;
      }
      return Ownership.unguarded;
    }

    final opens = '{'.allMatches(code).length;
    final closes = '}'.allMatches(code).length;
    if (opens > closes) {
      // Carry the condition text of a multi-line `if let` down to its brace.
      var cond = code;
      for (var j = i - 1; j >= start && j > i - 6; j--) {
        final prev = lines[j];
        if (prev.trimLeft().startsWith('//')) continue;
        if (!prev.trimRight().endsWith(',')) break;
        cond = '$prev $cond';
      }
      depth += opens - closes;
      openers[depth] = cond;
    } else {
      depth += opens - closes;
      if (depth < 0) break;
    }
  }
  return Ownership.absent;
}

/// ⛔ THE NEGATIVE CONTROL, AND IT IS THE REAL PRE-FIX SOURCE, NOT A STUB.
///
/// ⚠️ A canary easier to detect than the real population proves nothing. This
/// is the branch exactly as it stood at bb2eaf8 — 46 lines, comment-dominated,
/// with `kActiveEventKey` and the surrounding prose intact — so the predicate
/// is exercised against the hardest real instance rather than a convenient one.
const String kPreFixBranch = r'''
    case UNNotificationDefaultActionIdentifier
         where notifId == kFeedbackId || notifId == "mer_feedback_intent":
      // The wholesale copy that used to be here is DELETED, not bypassed. It
      // read the App Group mirror and overwrote the whole record list with it,
      // ungated — no merge, no staleness check. Dart never wrote that mirror, so
      // it was stale by design: end an event natively, ignore this notification,
      // log five events in-app, tap it days later, and the five were destroyed.
      // Restore two hundred from a backup first and it was two hundred.
      //
      // Nothing replaces it. The duration the extension recorded arrives as an
      // `end` instruction in the inbox and is applied by the drain, which is the
      // only thing that writes the record list.
      //
      // ── NO PRESERVE HERE, AND WHY IT IS SAFE ──
      // Same invariant as clearStaleActiveStateIfEnded, and the same pin. This
      // deletes the app's standard copy after an end that already happened —
      // the feedback notification being tapped is what says so. On 17+ the
      // extension ended the event and cleared only the shared copy, preserving
      // first if it could not read it, so what is deleted here is a duplicate of
      // a value already adjudicated. This site can beat clearStaleActiveStateIfEnded
      // to that deletion, which is exactly why it is named and not left implicit.
      let standard = UserDefaults.standard
      standard.removeObject(forKey: kActiveEventKey)
      standard.synchronize()
      // BOTH, deliberately. The flag is durable; the channel call is immediate.
      // Whichever arrives first wins, and consumption is idempotent on the Dart
      // side, so both arriving does not open the edit screen twice.
      //
      // This used to be an either/or on channel availability — and **the branch
      // that worked was the one that assumed failure.** On 17+ the event ends in
      // the widget extension, so the app usually is not running, navChannel is
      // nil, the flag is written, and initState's post-frame read consumes it.
      // On 16.2-16.x the app serviced the END action itself, so it is alive,
      // navChannel is non-nil, and only the transient call was made — sent to an
      // engine still paused, because didReceive runs BEFORE
      // applicationDidBecomeActive. Nothing durable was left behind, and iOS had
      // no resume-time consumer, so the tap landed on the dashboard instead of
      // the event's edit screen.
      //
      // Same asymmetry as endLiveActivity(completion:): on 17+ the work happens
      // somewhere the system keeps alive, and on 16.2-16.x it happens in a window
      // the app is about to close.
      standard.set(true, forKey: kPendingOpenLatest)
      standard.synchronize()
      navChannel?.invokeMethod("openLatestEvent", arguments: nil)
      completionHandler()
''';

void main() {
  final appDelegate =
      File('ios/Runner/AppDelegate.swift').readAsStringSync();

  group('the control — the suite observes BOTH verdicts', () {
    // ⭐ A control that passes where its siblings all fail is reporting on
    // itself, not on the subject. These two run the SAME predicate over two
    // sources and must disagree. If they ever agree, the predicate has stopped
    // discriminating and every other test in this file is uninformative.
    test('the pre-fix source classifies as UNGUARDED', () {
      expect(classify(kPreFixBranch), Ownership.unguarded,
          reason: 'POSITIVE CONTROL ON THE DEFECT. This is the real branch as '
              'it stood at bb2eaf8. If it does not read as unguarded, the '
              'predicate cannot see the defect it was written for, and the '
              'green result on the live file below means nothing.');
    });

    test('the live source classifies as GUARDED', () {
      expect(classify(appDelegate), Ownership.guarded,
          reason: 'THE FIX. The removal of the app-suite marker in the '
              'feedback-tap branch must sit inside a block whose condition '
              'reads kSharedActiveKey. Unconditional deletion here destroys '
              'the marker of whatever event is running NOW, not the one this '
              'notification describes.');
    });

    test('the two verdicts are actually different', () {
      // Belt and braces: makes the discrimination itself an assertion rather
      // than something a reader has to infer from two tests passing.
      expect(classify(kPreFixBranch), isNot(classify(appDelegate)),
          reason: 'the predicate returned the same verdict for the defective '
              'and the fixed source. It is not measuring the guard.');
    });
  });

  group('the structural argument the guard rests on', () {
    // The guard is only sound if the App Group copy's presence really does
    // mean an event is live. That is a property of the WRITERS and CLEARERS of
    // that key, not of this branch, so it is pinned separately.
    final swiftFiles = Directory('ios')
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((f) => f.path.endsWith('.swift'))
        .where((f) => !_posix(f.path).contains('/Pods/'))
        .where((f) => !_posix(f.path).contains('/.symlinks/'))
        .toList();

    List<String> nonComment(File f) => f
        .readAsStringSync()
        .split('\n')
        .where((l) => !l.trimLeft().startsWith('//'))
        .toList();

    test('positive control: Swift files were actually scanned', () {
      expect(swiftFiles, isNotEmpty);
    });

    test('the App Group marker has exactly one writer', () {
      final writes = <String>[];
      for (final f in swiftFiles) {
        final lines = nonComment(f);
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].contains('.set(') &&
              lines[i].contains('forKey:') &&
              (lines[i].contains('kSharedActiveKey') ||
                  lines[i].contains('kSharedActive'))) {
            writes.add('${_posix(f.path)}: ${lines[i].trim()}');
          }
        }
      }
      expect(writes, hasLength(1),
          reason: 'the ownership guard reads "App Group copy present means an '
              'event is live". A second writer breaks that reading. '
              'Found:\n${writes.join('\n')}');
    });

    test('every clearer of the App Group marker ends or abandons the event',
        () {
      const known = <String>{
        'perform',                       // EndMEREventIntent — the 17+ end
        'restorePersistentNotification', // the 30-minute abandonment
        'handleQuickLogEnd',             // the sub-17 notification end
        'endActiveEventFromApp',         // the in-app End button
      };

      final offenders = <String>[];
      var clearers = 0;

      for (final f in swiftFiles) {
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
          if (!(line.contains('kSharedActiveKey') ||
              line.contains('kSharedActive'))) {
            continue;
          }
          clearers++;
          if (!known.contains(enclosing)) {
            offenders.add('${_posix(f.path)}:${i + 1} in $enclosing');
          }
        }
      }

      expect(clearers, greaterThan(0),
          reason: 'positive control: clearers were actually found');
      expect(offenders, isEmpty,
          reason: '⛔ THE GUARD BECOMES UNSOUND. A function not on this list '
              'clears the App Group marker. The feedback-tap guard reads its '
              'ABSENCE as "no event is live", which holds only while every '
              'clearer is an end or an abandonment. Scanned $clearers. '
              'Unlisted:\n${offenders.join('\n')}');
    });
  });

  group('the successful path is unchanged', () {
    test('the branch still sets the pending-open flag and calls the channel',
        () {
      // ⛔ The brief requires an end that reads cleanly to behave exactly as
      // today. The guard covers the marker removal ONLY; the navigation half of
      // this branch must be untouched.
      final lines = appDelegate.split('\n');
      final start = lines.indexWhere(
          (l) => l.contains('case UNNotificationDefaultActionIdentifier'));
      final end = lines.indexWhere(
          (l) => l.trimRight() == '    default:', start);
      expect(start, isNot(-1));
      expect(end, greaterThan(start));

      final body = lines.sublist(start, end).join('\n');
      expect(body, contains('standard.set(true, forKey: kPendingOpenLatest)'));
      expect(body, contains("navChannel?.invokeMethod(\"openLatestEvent\""));
      expect(body, contains('completionHandler()'));
    });
  });
}
