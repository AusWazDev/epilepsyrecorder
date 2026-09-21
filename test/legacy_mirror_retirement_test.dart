// Brief 75 · the seven retirement cases.
//
// ⛔ THIS PATH CONSUMES ITS ONLY CHANCE. Every iOS device upgrading from 1.0.2
// runs it once. If it misreads, the mirror is deleted and no later release can
// recover it, because there will be nothing left to read.
//
// ⭐ THE INVARIANT: the mirror is retired only when the read was COMPLETE —
// every element of the payload accounted for. Not when nothing changed.
// Completeness of the read, not absence of change, earns the right to delete.
//
// ⚠️ NOT a prefs-per-process case: `SharedPreferences.getInstance` is called
// once here and the instance is REUSED across cases, so the CLAUDE.md harness
// rule is satisfied by there being one prefs-dependent test. Each case resets
// only the one flag it cares about, through that same instance.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/services/ios_capture_bridge.dart';

import 'legacy_mirror_harness.dart';

/// One case: seed a payload, run the reconciliation, report what happened.
class Outcome {
  Outcome(this.retired, this.cleared, this.reports, this.stored);
  final bool retired;
  final bool cleared;
  final List<Object> reports;
  final List<EventRecord> stored;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<Outcome> run(String? payload, {List<EventRecord> seedStore = const []}) async {
    final spy = MirrorSpy(payload);
    spy.install();
    addTearDown(spy.remove);
    debugResetIncompleteReport();

    await prefs.setBool(kSharedRecordsReconciledKey, false);
    final store = EventStore();
    await store.save(seedStore);

    final reports = <Object>[];
    await reconcileLegacySharedRecords(
      channel: kTestChannel, prefs: prefs, store: store,
      loaded: await store.load(),
      onError: (e, _) => reports.add(e),
    );
    return Outcome(
      prefs.getBool(kSharedRecordsReconciledKey) ?? false,
      spy.cleared,
      reports,
      await store.load(),
    );
  }

  final good = mirrorRec(id: 'g1', timestamp: DateTime(2026, 6, 1, 10, 0));
  final also = mirrorRec(id: 'g2', timestamp: DateTime(2026, 6, 2, 10, 0));

  testWidgets('the seven retirement cases', (tester) async {
    // ── 1 · absent key → COMPLETE, retires ───────────────────────────────
    final absent = await run(null);
    expect(absent.retired, isTrue,
        reason: 'CASE 1: an absent mirror has nothing to account for, so it is '
                'COMPLETE and must retire. Failing to retire here would strand '
                'a mirror that does not exist and re-run forever.');

    // ── 2 · clean decode, nothing new → retires ──────────────────────────
    final nothingNew = await run(payloadOf([good]), seedStore: [good]);
    expect(nothingNew.retired, isTrue, reason: 'CASE 2: the two agreed.');
    expect(nothingNew.cleared, isTrue,
        reason: 'CASE 2: Swift must have been told to delete.');

    // ── 3 · clean decode, something new, wrote → retires ─────────────────
    final somethingNew = await run(payloadOf([good, also]), seedStore: [good]);
    expect(somethingNew.retired, isTrue, reason: 'CASE 3: complete fold.');
    expect(somethingNew.stored.length, 2,
        reason: 'CASE 3: ⛔ THE SUCCESSFUL PATH MUST BE UNCHANGED. A device '
                'whose mirror reads cleanly upgrades exactly as before.');

    // ── 4 · NOT a List → does NOT retire ─────────────────────────────────
    final notAList = await run('{"not":"a list"}');
    expect(notAList.retired, isFalse,
        reason: 'CASE 4: ⛔ the payload could not be read. Before 21 Sep 2026 '
                'this arrived at the same line as "the two agreed" and deleted '
                'the mirror. The flag must stay unset.');
    expect(notAList.cleared, isFalse,
        reason: 'CASE 4: ⛔ clearLegacySharedRecords must NOT have been called. '
                'This is the assertion the whole brief exists for — the flag '
                'can be re-set, the deleted App Group value cannot.');
    expect(notAList.reports, isNotEmpty, reason: 'CASE 4: must report.');

    // ── 5 · a List, ALL records dropped → does not retire ────────────────
    final allDropped = await run('[{"id":"x","timestamp":"not-a-date"}]');
    expect(allDropped.retired, isFalse, reason: 'CASE 5: nothing decoded.');
    expect(allDropped.cleared, isFalse, reason: 'CASE 5: no delete.');

    // ── 6 · SOME dropped, survivors folded AND WRITTEN → does not retire ─
    // ⭐ THE A-1 CASE, and the one nothing previously distinguished: `wrote`
    // was true, so the mirror was deleted along with the records it dropped.
    final partial = await run(partialPayload(also), seedStore: [good]);
    expect(partial.stored.length, 2,
        reason: 'CASE 6: ⭐ the survivor must STILL be folded and written. '
                'Partial recovery is better than none and that behaviour is '
                'unchanged by this fix.');
    expect(partial.retired, isFalse,
        reason: 'CASE 6: ⛔ THE ONE THIS AMENDMENT EXISTS FOR. `wrote` was '
                'true — the merged list persisted — but the merge was not built '
                'from everything that was there. Retiring here deletes the '
                'dropped records permanently, on the single run this device '
                'ever gets.');
    expect(partial.cleared, isFalse, reason: 'CASE 6: no delete.');
    expect(partial.reports, isNotEmpty,
        reason: 'CASE 6: must report, with counts.');
    expect(partial.reports.first.toString(), contains('of 2'),
        reason: 'CASE 6: the report must carry what it SAW versus what it '
                'KEPT. "1 of 2" is actionable; "something failed" is not.');

    // ── 7 · a throw → does not retire, and reports ───────────────────────
    final threw = await run('this is not json at all');
    expect(threw.retired, isFalse, reason: 'CASE 7: decode threw.');
    expect(threw.cleared, isFalse, reason: 'CASE 7: no delete.');
    expect(threw.reports, isNotEmpty,
        reason: 'CASE 7: ⚠️ this replaces a bare `catch (_)` that discarded '
                'the error entirely — Brief 70 classified it Tier 1, '
                'platform-unrendered.');

    // ⭐ THE CONTROL THAT MATTERS: the suite must be able to observe BOTH
    // verdicts. A harness that can only ever report one is worthless however
    // true its output, and this project has had two blind nulls already.
    final retiredSeen = [absent, nothingNew, somethingNew].map((o) => o.retired);
    final notRetiredSeen =
        [notAList, allDropped, partial, threw].map((o) => o.retired);
    expect(retiredSeen.every((r) => r), isTrue,
        reason: 'CONTROL: the harness must be able to observe RETIRED.');
    expect(notRetiredSeen.every((r) => !r), isTrue,
        reason: 'CONTROL: the harness must be able to observe DID NOT RETIRE. '
                'Both verdicts observed across the seven cases means neither '
                'result above is an artefact of a blind apparatus.');
  });
}
