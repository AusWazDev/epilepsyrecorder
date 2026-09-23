// The composite-load re-entrancy guard, and the loss it prevents.
//
// ⭐ PROMOTED FROM A PROBE, 23 September 2026. This began as a throwaway that
// settled one question by EXECUTION rather than by argument, after five
// source-only arguments on this device went four-for-six. The probe found the
// loss; this is the same probe kept.
//
// ⛔ WHAT IT ESTABLISHED. `reconcileLegacySharedRecords` tests its one-shot
// flag SYNCHRONOUSLY and sets it only behind an await. Two overlapping calls
// therefore both pass the check, both read the App Group mirror, and both
// delete it — and the second then persists a record list loaded BEFORE the
// first's fold, over the top of it. A record that existed only in the mirror
// ends up in neither the store nor the mirror. On a device that is the
// once-per-device upgrade from 1.0.2, and there is no second chance.
//
// ⚠️ WHAT THIS FILE CANNOT ESTABLISH, stated here and not only in a report,
// because a green run read in three months must not imply coverage it lacks:
//
//  * It uses the PREFS-BACKED `EventStore`, not `SqliteEventStore`. Both go
//    through `EventStore.serialise` and the loss is at the composite level
//    above it, so the shape should hold — but SQLite was never run.
//  * It MODELS the drain as a `persistEvents` of whatever the reconcile
//    returned. That is what `drainInbox` does when it has drainable keys, but
//    `drainInbox` itself is not exercised here.
//  * It does NOT prove the two routes interleave on real hardware, and is not
//    trying to. The guard is warranted by the function not being re-entrant
//    safe, by five callers reaching it, and by one of them being invited by a
//    notification nothing ever removes. Whether the race is reproducible on a
//    handset does not change whether the guard belongs there — and the only
//    device available holds one real user's medical records.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/screens/home_screen.dart';
import 'package:medical_event_recorder/services/ios_capture_bridge.dart';

import 'legacy_mirror_harness.dart';

/// Counting spy. The shipped `MirrorSpy` carries a bool for `cleared`; the
/// question here is about COUNTS, so this one counts.
class CountingSpy {
  CountingSpy(this.payload);
  String? payload;
  int readCount = 0;
  int clearCount = 0;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kTestChannel, (call) async {
      switch (call.method) {
        case 'readLegacySharedRecords':
          readCount++;
          // ⭐ A real channel hop is not synchronous, and this yield is what
          // makes the probe faithful rather than optimistic: it reproduces the
          // await that the one-shot flag check sits in front of.
          await Future<void>.delayed(Duration.zero);
          return payload;
        case 'clearLegacySharedRecords':
          clearCount++;
          payload = null; // Swift's removeObject
          return null;
        default:
          return null;
      }
    });
  }

  void remove() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kTestChannel, null);
  }
}

/// One run of the composite, under [outcome] ids afterwards.
class Run {
  Run(this.reads, this.clears, this.stored);
  final int reads;
  final int clears;
  final List<String> stored;
}

void main() {
  // ⚠️ ONE PREFS-DEPENDENT TEST PER PROCESS (CLAUDE.md): one
  // setMockInitialValues, one getInstance, reused across phases. Each phase
  // resets only the flag it cares about, through that same instance. This is
  // ONE test for that reason, with the phases inside it.
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  final onDevice = mirrorRec(id: 'onDevice', timestamp: DateTime(2026, 6, 1, 10));
  final mirrorOnly =
      mirrorRec(id: 'mirrorOnly', timestamp: DateTime(2026, 6, 2, 10));

  /// `_loadRecords`' body, modelled at the granularity the hazard lives at:
  /// load → reconcile → persist what the reconcile returned.
  ///
  /// Faithful to `home_screen._loadRecordsInner`, which does `base = await
  /// _store.load()`, then `reconcileLegacySharedRecords(loaded: base)`, then
  /// `base = fold.records`, then hands that to `drainInbox`, which persists
  /// `plan.merged`. See the limits at the top for what is modelled.
  Future<void> inner(EventStore store) async {
    var base = await store.load();
    final fold = await reconcileLegacySharedRecords(
      channel: kTestChannel, prefs: prefs, store: store, loaded: base,
    );
    base = fold.records;
    await persistEvents(store, base, from: LoadState.completed);
  }

  /// Drives two composite loads and reports what happened.
  ///
  /// [gate] is what each call is wrapped in — the real [LoadSerialiser.run] for
  /// the guarded case, a pass-through for the unguarded one.
  Future<Run> twoLoads({
    required Future<void> Function(Future<void> Function()) gate,
    required bool serial,
  }) async {
    await prefs.setBool(kSharedRecordsReconciledKey, false);
    debugResetIncompleteReport();
    LoadSerialiser.resetForTest();

    final spy = CountingSpy(payloadOf([mirrorOnly]));
    spy.install();
    final store = EventStore();
    await store.save([onDevice]);

    if (serial) {
      await gate(() => inner(store));
      await gate(() => inner(store));
    } else {
      // Started without an await between them: what the two routes do when
      // _handleResume's load is suspended at an await and the queued channel
      // call is delivered.
      final a = gate(() => inner(store));
      final b = gate(() => inner(store));
      await Future.wait([a, b]);
    }

    final stored = (await store.load()).map((r) => r.id).toList()..sort();
    spy.remove();
    return Run(spy.readCount, spy.clearCount, stored);
  }

  Future<void> passThrough(Future<void> Function() op) => op();

  test('the composite load is serialised against itself', () async {
    final unguarded = await twoLoads(gate: passThrough, serial: false);
    final guarded = await twoLoads(gate: LoadSerialiser.run, serial: false);
    final serialControl = await twoLoads(gate: passThrough, serial: true);

    // ignore: avoid_print
    print('''
=== COMPOSITE LOAD RE-ENTRANCY ===
                         UNGUARDED   GUARDED   SERIAL (control)
mirror reads             ${unguarded.reads}           ${guarded.reads}         ${serialControl.reads}
clearLegacyShared calls  ${unguarded.clears}           ${guarded.clears}         ${serialControl.clears}
records in store         ${unguarded.stored}  ${guarded.stored}  ${serialControl.stored}
''');

    // ── THE LANDING CHECKS ────────────────────────────────────────────────
    // ⭐ A control that passes where its siblings all fail is reporting on
    // itself, not on the subject. The SERIAL column is the same probe, same
    // payload, same store, differing ONLY in one await. It must show no loss —
    // otherwise this apparatus cannot produce a "no loss" verdict at all and
    // the guarded column below means nothing.
    expect(serialControl.reads, 1,
        reason: 'LANDING CHECK: run serially, the second call must find the '
            'one-shot flag SET and return before reading the mirror. If this '
            'is not 1 the probe is not exercising the flag.');
    expect(serialControl.clears, 1,
        reason: 'LANDING CHECK: serially the mirror is retired exactly once.');
    expect(serialControl.stored, ['mirrorOnly', 'onDevice'],
        reason: 'LANDING CHECK: serially the fold survives. This is the "no '
            'loss" verdict the apparatus must be capable of producing.');

    // ── THE HAZARD IS REAL ────────────────────────────────────────────────
    // Without the guard, the exact shape the shipped code had before
    // 23 September 2026. Asserted rather than described, so that if the
    // underlying check-then-act is ever fixed at its own site this test says
    // so loudly instead of passing for the wrong reason.
    // ── REVISITED 23 September 2026 · Brief 135R-2 ───────────────────────
    // ⭐ THIS TEST ASKED TO BE REVISITED AND THEN WAS, BY ITS OWN TERMS. It
    // read, and is preserved here rather than silently replaced:
    //
    //     expect(unguarded.stored, ['onDevice'], reason: '⛔ THE HAZARD …
    //     If this now shows NO loss, the check-then-act in
    //     reconcileLegacySharedRecords has been fixed at its own site …'
    //
    // ⛔ IT NOW SHOWS NO LOSS — AND THE CAUSE IS NOT THE ONE THE NOTE
    // ANTICIPATED. `reconcileLegacySharedRecords` is untouched: the
    // check-then-act is still there and the race still runs, measured in the
    // two rows above this one. What changed is `save`, which stopped deleting
    // records a caller's list does not name (Brief 135R). ⭐ So the race no
    // longer has a mechanism through which to destroy anything.
    //
    // ⚠️ THE HAZARD ASSERTION THEREFORE MOVES OFF THE CONSEQUENCE AND ONTO
    // THE RACE, which is both more direct and still able to fail. The old
    // form could only ever have been evidence about `save`.
    expect(unguarded.reads, 2,
        reason: '⛔ THE HAZARD, STATED DIRECTLY. Unguarded, both callers pass '
            'the one-shot flag check and read the mirror — the check-then-act '
            'is unfixed at its own site. If this drops to 1 it HAS been fixed '
            'there, and the guard below is no longer being tested by this '
            'file.');
    expect(unguarded.clears, 2,
        reason: '⛔ AND THE IRREVERSIBLE HALF. `clearLegacySharedRecords` runs '
            'TWICE unguarded. It is irreversible, so this is a live hazard in '
            'its own right and is NOT addressed by the save fix — it is '
            'exactly what LoadSerialiser is for.');
    expect(unguarded.stored, ['mirrorOnly', 'onDevice'],
        reason: '⚠️ NO LONGER A DISCRIMINATOR, AND SAID SO RATHER THAN LEFT '
            'TO READ AS ONE. All three columns now agree because `save` is '
            'add-or-update, so the second persist can no longer overwrite the '
            'fold with a stale base. Kept as a regression pin on the save fix '
            'reached through a different route — NOT as evidence about the '
            'guard.');

    // ── THE FIX, collected not thrown ─────────────────────────────────────
    // ⛔ CLAUDE.md: at test granularity a control that fired and a control that
    // was MASKED have identical output, because the first expect to throw ends
    // the test. Three forms are reported here, so each must report separately.
    // On this probe's first run that exact masking hid two of three forms.
    final findings = <String>[];
    void check(String form, Object actual, Object expected, String meaning) {
      final ok = actual.toString() == expected.toString();
      findings.add('${ok ? "ok       " : "FAILED   "}  $form  '
          'expected $expected, got $actual  — $meaning');
    }

    check('F1/F2', guarded.reads, 1,
        'exactly one caller may pass the one-shot flag check and read the mirror');
    check('F3   ', guarded.clears, 1,
        'clearLegacySharedRecords must run exactly once — it is irreversible');
    // ⚠️ F4 NO LONGER DISCRIMINATES, 23 September 2026. It passes unguarded
    // too, because `save` stopped deleting what a list does not name. ⛔ Kept
    // and REPORTED AS NON-DISCRIMINATING rather than removed: a passing form
    // that cannot fail reads exactly like a discharged control, which is the
    // masking class CLAUDE.md records. F1/F2 and F3 are what test the guard.
    check('F4   ', guarded.stored, ['mirrorOnly', 'onDevice'],
        'the mirror-only record must survive — ⚠️ NON-DISCRIMINATING since the '
        'save fix: true unguarded as well, so it is evidence about `save`, '
        'not about LoadSerialiser');

    // ignore: avoid_print
    print('--- GUARDED ---\n${findings.join('\n')}\n');

    expect(findings.where((f) => f.startsWith('FAILED')), isEmpty,
        reason: 'the guard did not serialise the composite:\n'
            '${findings.join('\n')}');
  });

  group('the guard is actually wired in', () {
    // ⚠️ The behavioural test above proves LoadSerialiser WORKS. It cannot
    // prove _loadRecords USES it — that is a property of the screen's source,
    // and this is what goes red against the pre-fix file.

    test('_loadRecords routes through LoadSerialiser, and nothing bypasses it',
        () {
      final file =
          File('lib/screens/home_screen.dart').readAsStringSync();
      final lines = file.split('\n');

      final wrapper = lines.indexWhere((l) =>
          l.contains('Future<void> _loadRecords(') &&
          !l.trimLeft().startsWith('//'));
      expect(wrapper, isNot(-1),
          reason: 'positive control: _loadRecords was found');
      expect(lines[wrapper] + lines[wrapper + 1], contains('LoadSerialiser.run'),
          reason: '⛔ _loadRecords must route through the serialiser. '
              'Unguarded, two overlapping loads destroy records — see the '
              'behavioural test in this file.');

      // Every caller must go through the wrapper, not the body.
      final bypass = <String>[];
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        if (l.trimLeft().startsWith('//') || l.trimLeft().startsWith('///')) {
          continue;
        }
        if (!l.contains('_loadRecordsInner')) continue;
        if (l.contains('Future<void> _loadRecordsInner')) continue; // the body
        if (l.contains('LoadSerialiser.run')) continue; // the wrapper
        bypass.add('line ${i + 1}: ${l.trim()}');
      }
      expect(bypass, isEmpty,
          reason: '⛔ a caller reaches the composite body directly and so is '
              'not serialised. FIVE callers exist and only two were ever '
              'named: initState, _routeNotificationTap, _handleResume, and '
              'BOTH '
              'branches of _endActiveEvent.\n${bypass.join('\n')}');

      // The denominator, asserted rather than eyeballed.
      final callers = <String>[];
      for (var i = 0; i < lines.length; i++) {
        final l = lines[i];
        if (l.trimLeft().startsWith('//') || l.trimLeft().startsWith('///')) {
          continue;
        }
        if (!l.contains('_loadRecords(')) continue;
        if (l.contains('Future<void> _loadRecords(')) continue;
        callers.add('line ${i + 1}: ${l.trim()}');
      }
      expect(callers, hasLength(5),
          reason: 'positive control AND the denominator. Five callers were '
              'enumerated on 23 September 2026. A different count means the '
              'enumeration moved and the guard\'s coverage must be rechecked '
              '— two enumerations on this project have each missed one.\n'
              '${callers.join('\n')}');
    });
  });
}

