// Brief 82 · the active marker is preserved when it cannot be read.
//
// ⛔ WHAT THIS GUARDS. `_handleEnd` removed the marker UNCONDITIONALLY, outside
// its `if (active != null)`. An unreadable marker therefore wrote no end
// instruction, showed no feedback, and was deleted anyway — taking the only
// copy of the event's start time with it and making that event's duration
// permanently unrecoverable. Android-only: `endEvent` returns on Windows and
// `_endActiveEvent` routes iOS to the native channel before reaching it.
//
// ⭐ THE POLICY IS PLATFORM-FREE SO BOTH ROWS ARE BEHAVIOURAL ON THIS HOST.
// Windows cannot reach `_handleEnd`, so a test driving it would be host-bound by
// construction — the class Brief 68 exists for. `resolveActiveMarker` takes
// `prefs` and `onReport` as parameters and reads `Platform` nowhere.
//
// ⚠️ One prefs instance, obtained once and reused, per CLAUDE.md: a second
// `setMockInitialValues` in the same process is accepted and changes nothing.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/services/notification_service.dart';

const kMarker = 'mer_active_event';
const kQuar = 'mer_active_quarantine';
const kQuarCount = 'mer_active_quarantine_count';

const kGood = '{"id":"evt-1","startIso":"2026-09-21T10:00:00.000"}';
const kBad = '{"id":"evt-1","startIso":"not-a-date"';   // truncated JSON

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  setUp(debugResetUnreadableReport);

  test('readable · unreadable · absent', () async {
    // ── 1 · READABLE → removed ───────────────────────────────────────────
    await prefs.clear();
    await prefs.setString(kMarker, kGood);
    final reports1 = <Object>[];
    final s1 = await resolveActiveMarker(prefs,
        decodedOk: true, onReport: (e, _) => reports1.add(e));

    expect(s1, MarkerState.readable, reason: 'CASE 1: a parsed marker.');
    expect(prefs.getString(kMarker), isNull,
        reason: 'CASE 1: a readable marker IS removed — the normal end path '
                'must be unchanged by this fix.');
    expect(prefs.getString(kQuar), isNull,
        reason: 'CASE 1: nothing to quarantine when the read succeeded.');
    expect(reports1, isEmpty, reason: 'CASE 1: nothing to report.');

    // ── 2 · UNREADABLE → preserved, counted, reported, NOT removed ───────
    await prefs.clear();
    await prefs.setString(kMarker, kBad);
    final reports2 = <Object>[];
    final s2 = await resolveActiveMarker(prefs,
        decodedOk: false, onReport: (e, _) => reports2.add(e));

    expect(s2, MarkerState.unreadable, reason: 'CASE 2: could not be read.');
    expect(prefs.getString(kMarker), kBad,
        reason: 'CASE 2: ⛔ THE ASSERTION THE WHOLE BRIEF EXISTS FOR. The '
                'marker must still be there. Removing it destroys the only '
                'copy of the start time and the duration can never be '
                'recovered — there is no retry for a deleted value.');
    expect(prefs.getString(kQuar), kBad,
        reason: 'CASE 2: the value is PRESERVED, byte for byte.');
    expect(prefs.getInt(kQuarCount), 1,
        reason: 'CASE 2: the count is what tells a later reader it recurred.');
    expect(reports2, hasLength(1),
        reason: 'CASE 2: ⭐ Dart has Sentry where Swift had only an os_log, so '
                'this side can actually report. The quarantine is '
                'preservation; this is the report. Two things.');
    expect(reports2.first.toString(), contains('occurrence #1'),
        reason: 'CASE 2: the report carries the count — "the third time" is '
                'actionable, "something failed" is not.');

    // ⭐ THE COUNT RISES; THE REPORTS DO NOT. An unreadable marker is no longer
    // removed, so it persists and every later end-press re-reads it — the fix
    // itself creates the recurrence. The durable COUNT carries how often;
    // the Sentry event is bounded to one per process so one stuck value cannot
    // become a firehose. Same choice as `_incompleteReported` in
    // ios_capture_bridge.dart.
    await prefs.setString(kMarker, kBad);
    await resolveActiveMarker(prefs,
        decodedOk: false, onReport: (e, _) => reports2.add(e));
    expect(prefs.getInt(kQuarCount), 2,
        reason: 'CASE 2: a second occurrence increments rather than replacing.');
    expect(reports2, hasLength(1),
        reason: 'CASE 2: ⛔ the SECOND occurrence must NOT report again in the '
                'same process. Preserving the marker is what makes it recur, '
                'so an unbounded report would turn one stuck value into a '
                'Sentry firehose — a defect manufactured by the fix.');

    // ── 3 · ABSENT → nothing written ─────────────────────────────────────
    await prefs.clear();
    final reports3 = <Object>[];
    final s3 = await resolveActiveMarker(prefs,
        decodedOk: false, onReport: (e, _) => reports3.add(e));

    expect(s3, MarkerState.absent, reason: 'CASE 3: nothing was there.');
    expect(prefs.getString(kQuar), isNull,
        reason: 'CASE 3: ⛔ an absent marker must NOT be quarantined. An empty '
                'quarantine entry manufactures evidence of a loss that did not '
                'happen, and a later reader cannot tell it from a real one.');
    expect(prefs.getInt(kQuarCount), isNull, reason: 'CASE 3: no count.');
    expect(reports3, isEmpty,
        reason: 'CASE 3: nothing failed, so nothing is reported.');

    // ⭐ THE CONTROL: the suite must observe BOTH "removed" and "not removed".
    // A harness that can only see one is worthless however true its output.
    expect(s1, MarkerState.readable);
    expect(s2, MarkerState.unreadable);
    expect(s3, MarkerState.absent);
  });
}
