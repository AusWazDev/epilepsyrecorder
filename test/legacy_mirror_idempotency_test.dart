// Brief 75 Amendment 1 · B-0 — IS THE FOLD IDEMPOTENT?
//
// ⛔ THE WHOLE FIX RESTS ON THIS. "Do not retire on an incomplete read" means
// the reconciliation RE-RUNS next launch. That converts a terminal failure into
// a retried one, which is only an improvement if the retry is safe.
//
// ⭐ EVIDENCE, NOT AN ARGUMENT FROM THE `addedIds` NAMING. This runs the real
// function twice over the same mirror and counts what comes out.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/services/ios_capture_bridge.dart';

import 'legacy_mirror_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('folding the same mirror twice adds nothing the second time', () async {
    // A record only the mirror has, plus one both have where only the mirror
    // carries a real duration — the two things the fold can do.
    final onlyInMirror = mirrorRec(
        id: 'only-mirror', timestamp: DateTime(2026, 6, 1, 10, 0),
        duration: DurationCategory.oneToFive);
    final inBoth = mirrorRec(
        id: 'in-both', timestamp: DateTime(2026, 6, 2, 10, 0),
        duration: DurationCategory.oneToFive);
    final inBothNoDuration = mirrorRec(
        id: 'in-both', timestamp: DateTime(2026, 6, 2, 10, 0), duration: null);

    final spy = MirrorSpy(payloadOf([onlyInMirror, inBoth]));
    spy.install();
    addTearDown(spy.remove);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = EventStore();
    await store.save([inBothNoDuration]);

    // ── RUN 1 ────────────────────────────────────────────────────────────
    final first = await reconcileLegacySharedRecords(
      channel: kTestChannel, prefs: prefs, store: store,
      loaded: await store.load(),
    );

    expect(first.ran, isTrue,
        reason: 'CONTROL: run 1 must actually have run, or run 2 proves nothing.');
    expect(first.addedIds, contains('only-mirror'),
        reason: 'CONTROL: run 1 must ADD the mirror-only record, or there is no '
                'addition for run 2 to duplicate.');
    expect(first.durationsRecovered, contains('in-both'),
        reason: 'CONTROL: run 1 must RECOVER the duration, or there is no '
                'recovery for run 2 to double-count.');
    expect(first.wrote, isTrue, reason: 'CONTROL: run 1 must have persisted.');

    final afterFirst = await store.load();
    expect(afterFirst.length, 2,
        reason: 'CONTROL: the store should hold both records after run 1.');

    // ⚠️ Run 1 retired the mirror, so re-arm it: B-0 asks what happens when the
    // SAME mirror is read again, which is the state the fix deliberately
    // creates by NOT retiring.
    spy.payload = payloadOf([onlyInMirror, inBoth]);
    await prefs.setBool(kSharedRecordsReconciledKey, false);

    // ── RUN 2, over the same mirror ──────────────────────────────────────
    final second = await reconcileLegacySharedRecords(
      channel: kTestChannel, prefs: prefs, store: store,
      loaded: await store.load(),
    );

    expect(second.addedIds, isEmpty,
        reason: 'B-0: a second fold over the same mirror must add NOTHING. '
                'Anything here means not-retiring trades permanent loss for '
                'progressive duplication, which is a worse bargain.');
    expect(second.durationsRecovered, isEmpty,
        reason: 'B-0: the duration must not be recovered twice. The guard is '
                '`existing.duration == null || == lt1`, which stops holding '
                'once the first run has written the real value.');

    final afterSecond = await store.load();
    expect(afterSecond.length, afterFirst.length,
        reason: 'B-0: the record COUNT must not grow on a repeat fold. This is '
                'the assertion the whole retry design depends on.');
    expect(afterSecond.map((r) => r.id).toSet().length, afterSecond.length,
        reason: 'B-0: no duplicate ids.');
  });
}
