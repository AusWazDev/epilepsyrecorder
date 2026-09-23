// Brief 146 · the strand watchdog — it must FIRE on a stranded save and stay
// SILENT on a normal one.
//
// ⛔ WHAT IT GUARDS. A save can stop without failing: every store operation ends
// in a platform-channel reply, and a channel has no timeout anywhere in its
// chain. A reply that never arrives is not an exception and not a `false`, so
// `persistEvents`' `catch` is never entered, `_persist`'s `ok` is never
// assigned and the unsaved-write banner never appears. Brief 144 measured that
// on both stores. The watchdog is the only thing that makes it visible.
//
// ⚠️ A CONTROL THAT CAN ONLY STAY QUIET IS NOT A CONTROL. Phases 1 and 2 differ
// ONLY in whether the save settles, so a watchdog that never fired would fail
// phase 1 and one that always fired would fail phase 2.
//
// ⚠️ ONE PREFS-DEPENDENT TEST PER PROCESS (CLAUDE.md): one
// setMockInitialValues, one getInstance, reused. The warning flag is read and
// written through that same instance, so the phases live INSIDE one test — the
// same shape `load_records_reentry_test.dart` uses and for the same reason.
// Every phase names itself in its `reason`, so a failure is still attributable.
// The source pin below touches no preferences and is therefore free to be its
// own test.

import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common/sqlite_api.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';

EventRecord rec(String id, int day) => EventRecord(
      id: id,
      timestamp: DateTime(2026, 9, day),
      duration: DurationCategory.lt1,
      durationSeconds: 40,
      eventType: 'seizure',
      severity: EventSeverity.mild,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: false,
      notes: '',
      detailsCompleted: true,
    );

/// A store whose save never settles until [release] is called.
///
/// ⭐ Models what Brief 144 established: a call whose reply never comes. It is a
/// real [EventStore] subtype, so `persistEvents` treats it as any other.
class StrandingStore extends EventStore {
  final Completer<void> _gate = Completer<void>();
  int saveCalls = 0;

  @override
  Future<void> save(List<EventRecord> records) {
    saveCalls++;
    return _gate.future;
  }

  void release() => _gate.complete();
}

/// Never settles, and nothing releases it.
class HangingDatabase implements Database {
  @override
  dynamic noSuchMethod(Invocation i) => Completer<Never>().future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  const short = Duration(milliseconds: 150);

  test('the strand watchdog fires, stays quiet, and never touches the save',
      () async {
    // ── PHASE 1 · IT FIRES on a save that never settles ────────────────────
    await clearFailedWriteWarning();
    expect(await hasFailedWrite(), isFalse,
        reason: 'PHASE 1 CONTROL: the flag must start clear, or "it was set" '
            'cannot be told from "it was already set".');

    final stranded = StrandingStore();
    final pending = persistEvents(stranded, [rec('a', 1)],
        from: LoadState.completed, strandAfter: short);

    await Future<void>.delayed(short * 3);

    expect(stranded.saveCalls, 1,
        reason: 'PHASE 1 CONTROL: the save must actually have been attempted.');
    expect(await hasFailedWrite(), isTrue,
        reason: '⛔ PHASE 1 — THE WATCHDOG. A save that neither returned nor '
            'threw is invisible without this: the catch is never entered, so '
            'nothing sets the warning and the banner never appears while the '
            'record sits on screen looking saved.');

    // ── PHASE 1b · OBSERVE ONLY — the save is STILL outstanding ────────────
    var settled = false;
    unawaited(pending.then((_) => settled = true));
    await Future<void>.delayed(short);
    expect(settled, isFalse,
        reason: '⛔ PHASE 1b — THE WATCHDOG MUST NOT TOUCH THE SAVE. If this is '
            'true it completed, cancelled or timed the save out, which is the '
            'one thing forbidden: a timed-out save that then proceeds can '
            'interleave with the stranded one.');

    // ── PHASE 2 · SELF-CORRECTING: the slow save finishes ──────────────────
    stranded.release();
    expect(await pending, isTrue,
        reason: 'PHASE 2: the save completed normally after being reported — '
            'the watchdog left it alone.');
    expect(await hasFailedWrite(), isFalse,
        reason: '⭐ PHASE 2 — SELF-CORRECTING BY CONSTRUCTION. The success path '
            'already calls clearFailedWriteWarning(), so a false positive '
            'costs one Sentry event and a banner that clears itself. That is '
            'what makes a 30 s threshold safe to ship rather than merely '
            'defensible.');

    // ── PHASE 3 · IT STAYS SILENT on a save that settles normally ──────────
    await clearFailedWriteWarning();
    final healthy = StrandingStore()..release();
    final ok = await persistEvents(healthy, [rec('b', 2)],
        from: LoadState.completed, strandAfter: short);
    expect(ok, isTrue,
        reason: 'PHASE 3 CONTROL: a normal save still returns true.');

    await Future<void>.delayed(short * 4);
    expect(await hasFailedWrite(), isFalse,
        reason: '⛔ PHASE 3 — THE OTHER HALF OF THE CONTROL. A watchdog that '
            'fired on a healthy save would raise the banner on every ordinary '
            'write. Phases 1 and 3 differ ONLY in whether the save settles.');

    // ── PHASE 4 · a REAL store over a database that never replies ──────────
    await clearFailedWriteWarning();
    unawaited(persistEvents(
        SqliteEventStore(HangingDatabase()), [rec('d', 4)],
        from: LoadState.completed, strandAfter: short));

    await Future<void>.delayed(short * 3);
    expect(await hasFailedWrite(), isTrue,
        reason: '⛔ PHASE 4: the watchdog is not specific to a test double. A '
            'real SqliteEventStore whose database never replies is reported '
            'the same way — the shape Brief 144 measured.');

    await clearFailedWriteWarning();
  }, timeout: const Timeout(Duration(seconds: 45)));

  test('⛔ SOURCE — the watchdog observes; it does not cancel, complete or time '
      'out the save', () {
    // ⭐ THE GUARD THE BEHAVIOURAL PHASES CANNOT BE. They show the save is still
    // outstanding at one moment. Only the source can show that no cancellation,
    // completion or timeout was written at all.
    final src = File('lib/models/event_record.dart').readAsStringSync();

    const banner = 'THE STRAND WATCHDOG';
    expect(src.contains(banner), isTrue,
        reason: 'CONTROL: the watchdog block was not found — either it was '
            'removed or this scan reads the wrong file.');

    // The block runs from its banner to the success return.
    final start = src.indexOf(banner);
    final end = src.indexOf('return true;', start);
    expect(end, greaterThan(start),
        reason: 'CONTROL: the block end marker was not found after the banner, '
            'so the window below would be meaningless.');
    final block = src.substring(start, end);

    // CONTROL: the window really does contain the watchdog, not just a comment.
    expect(block.contains('Timer('), isTrue,
        reason: 'CONTROL: no Timer in the scanned window — the window is wrong '
            'and every absence below would be vacuous.');
    expect(block.contains('await pending;'), isTrue,
        reason: 'CONTROL: the original await must still be in the window. It is '
            'the thing the watchdog runs ALONGSIDE, not instead of.');

    for (final forbidden in <String>[
      '.timeout(', // would complete the save with an error
      'pending.ignore(', // would discard it
      '_gate', // a test double must not leak into lib/
    ]) {
      expect(block.contains(forbidden), isFalse,
          reason: '⛔ `$forbidden` appears in the watchdog block. The watchdog '
              'is OBSERVE-ONLY: it may report, and it may cancel its own '
              'TIMER, and it may do nothing else to the save or the queue. A '
              'timed-out save that then proceeds can interleave with the '
              'stranded one — a new defect wearing a fix\'s clothes.');
    }

    // ⭐ The one cancel that IS allowed, asserted positively so the rule above
    // cannot be satisfied by simply deleting the timer.
    expect(block.contains('watchdog.cancel()'), isTrue,
        reason: 'the timer must be cancelled when the save settles — that is a '
            'cancel of the TIMER, never of the save.');
  });
}
