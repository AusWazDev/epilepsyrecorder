// Contract #22 — how a failure on `au.com.notiva.mer/navigation` is READ.
//
// ⛔ THE DEFECT THIS EXISTS FOR IS NOT A WRONG ANSWER. IT IS AN ABSENT ONE.
// Both channel calls in `home_screen` were wrapped in `catch (_) {}`, so
// Android, Windows and a BROKEN iOS produced byte-identical observable
// behaviour — no log, no Sentry event, no failing test. The fix is not a
// platform guard around the call: that would silence iOS too, on exactly the
// failure worth hearing about. It is a platform-aware reading of the failure.
//
//     platform          MissingPluginException      anything else
//     iOS               report                      report
//     Android, Windows  swallow (expected)          report
//
// ⭐ WHY `isIOS` IS A PARAMETER AND NOT A `Platform.isIOS` READ. A test host
// renders exactly one platform. Had the policy read the platform itself, this
// file could only ever have exercised the Windows row, and the iOS row would
// have passed by never running — which is the Brief 64 defect, rebuilt inside
// the test written to prevent it. The parameter is what makes BOTH rows
// behavioural on this host rather than one behavioural and one asserted.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/services/ios_capture_bridge.dart';

/// A stand-in for anything the Swift handler can throw that is NOT the channel
/// being absent — a handler that errored, a codec failure, a decode failure.
final _somethingElse = PlatformException(code: 'restore_failed');
final _missing       = MissingPluginException(
    'No implementation found for method restoreNotification on channel '
    'au.com.notiva.mer/navigation');

void main() {
  group('nav channel failure policy', () {
    // ── ROW 2 of the table ───────────────────────────────────────────────
    test('1. a non-MissingPluginException is REPORTED on every platform', () {
      expect(
        shouldReportNavChannelFailure(_somethingElse, isIOS: true),
        isTrue,
        reason: 'iOS: a PlatformException from the Swift handler is the '
                'restoreNotification failure this contract exists to surface. '
                'Swallowing it returns the app to the silent state.',
      );
      expect(
        shouldReportNavChannelFailure(_somethingElse, isIOS: false),
        isTrue,
        reason: 'Android/Windows: only MissingPluginException is expected off '
                'iOS. Anything else means something unforeseen happened on a '
                'channel that should simply be absent, and it must not be '
                'swallowed just because the platform has no handler.',
      );
    });

    // ── ROW 1 of the table, both halves ──────────────────────────────────
    test('2. MissingPluginException is REPORTED on iOS', () {
      expect(
        shouldReportNavChannelFailure(_missing, isIOS: true),
        isTrue,
        reason: 'A missing handler ON iOS is a channel or method rename on the '
                'Swift side. It has NO other detector: the call silently '
                'becomes a no-op and every other test stays green. This is the '
                'single assertion that makes a platform guard around the call '
                'the wrong fix.',
      );
    });

    test('3. MissingPluginException is SWALLOWED off iOS', () {
      expect(
        shouldReportNavChannelFailure(_missing, isIOS: false),
        isFalse,
        reason: 'The channel is registered only in AppDelegate.swift, so off '
                'iOS this fires on every cold start and every save. Reporting '
                'it would bury assertion 2 in noise — which is the same failure '
                'as the catch, one layer up.',
      );
    });

    // ⚠️ Tests 2 and 3 are SEPARATE tests, not two expects in one. The first
    // `expect` to throw ends a test, so a single test holding both would report
    // red while leaving the second assertion unproven and unnamed — the
    // attributable-control rule in CLAUDE.md, applied here rather than learned
    // here again.

    test('4. the policy is not a constant — it discriminates on BOTH axes', () {
      // ⛔ A policy returning `true` always, or `false` always, satisfies some
      // of the assertions above and is worthless. This pins that the answer
      // actually moves with each input independently.
      final byPlatform = shouldReportNavChannelFailure(_missing, isIOS: true) !=
                         shouldReportNavChannelFailure(_missing, isIOS: false);
      final byError    = shouldReportNavChannelFailure(_missing,       isIOS: false) !=
                         shouldReportNavChannelFailure(_somethingElse, isIOS: false);
      expect(byPlatform, isTrue,
          reason: 'holding the error fixed, the platform must change the answer');
      expect(byError, isTrue,
          reason: 'holding the platform fixed, the error type must change the answer');
    });

    // ── The host-bound half, named rather than hidden ────────────────────
    test('5. SOURCE SCAN — no bare `catch (_)` remains on a _navChannel call', () {
      // ⚠️ THIS IS THE HALF NO BEHAVIOURAL TEST ON THIS HOST CAN REACH.
      // Tests 1-4 prove the POLICY is right. They cannot prove the two call
      // sites USE it — a future edit restoring `catch (_) {}` at either site
      // leaves every one of them passing. That is the host-bound class this
      // whole sweep is about, so it is checked by reading the source.
      final src = File('lib/screens/home_screen.dart').readAsStringSync();

      // Positive control: the thing being searched for must be findable.
      expect(src.contains('_navChannel.invokeMethod'), isTrue,
          reason: 'CONTROL: if the channel calls cannot be found at all, the '
                  'assertions below are vacuous and would pass over an empty '
                  'file. A null needs a control.');

      final calls = RegExp(r'_navChannel\.invokeMethod').allMatches(src).length;
      expect(calls, greaterThanOrEqualTo(4),
          reason: 'CONTROL, denominator: getPendingOpenLatest, '
                  'getShowPreviewsSetting, endActiveEvent and restoreNotification '
                  'are the four known calls. A count below 4 means the scan is '
                  'reading something other than this file.');

      // ⛔ SCOPED TO CHANNEL CALLS, NOT TO THE FILE. A blanket ban on
      // `catch (_)` here would also condemn the jsonDecode guard at the
      // mer_active_event read, which is unrelated and correct — and a check
      // that is wrong about a legitimate line gets deleted by the first person
      // it inconveniences. ⭐ THE EXCLUSION IS ENUMERATED, not asserted to be
      // narrow: this prints every bare catch it chose not to flag.
      final bare = RegExp(r'catch \(_\)').allMatches(src).toList();
      final flagged = <String>[];
      final excluded = <String>[];
      for (final m in bare) {
        final before = src.substring((m.start - 400).clamp(0, m.start), m.start);
        // The nearest preceding channel call with no intervening catch binding
        // means this bare catch is the handler for that call.
        final onChannel = before.contains('_navChannel.invokeMethod') &&
            !before.split('_navChannel.invokeMethod').last.contains('catch (');
        final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
        final snippet = src.substring(m.start, (m.start + 60).clamp(0, src.length))
            .split('\n')
            .first;
        (onChannel ? flagged : excluded).add(':$line  $snippet');
      }
      expect(flagged, isEmpty,
          reason: 'A bare `catch (_)` on a _navChannel call is the exact shape '
                  'contract #22 replaced: it makes a permanently dead call and '
                  'a working one indistinguishable. Route it through '
                  'reportNavChannelFailure instead.\n'
                  'EXCLUDED as not on a channel call (enumerated so the '
                  'exclusion stays auditable): ${excluded.isEmpty ? "none" : excluded}');

      expect(
        'reportNavChannelFailure'.allMatches(src).length,
        greaterThanOrEqualTo(2),
        reason: 'Both channel call sites — _drainPendingOpenLatest and '
                '_openLogScreen — must read their failure through the one '
                'policy. A second reporting path is what this replaced.',
      );
    });
  });
}

extension on String {
  Iterable<Match> allMatches(String input) => RegExp(this).allMatches(input);
}
