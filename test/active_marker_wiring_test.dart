// Brief 82 · the WIRING — that both call sites use the policy, and that the
// trade at `_handleEnd`'s comment is not reversed.
//
// ⛔ THIS IS THE HALF NO BEHAVIOURAL TEST ON THIS HOST CAN REACH, and saying so
// is the point. `endEvent` returns on Windows and `_handleEnd` is private, so
// this host cannot drive either call site. `active_marker_preserve_test` proves
// the POLICY is right; it cannot prove the call sites USE it. A future edit that
// restored an unconditional `prefs.remove(_activeEventKey)` would leave every
// assertion there green.
//
// ⭐ Source scan, exactly as contracts #19, #22 and #24 do it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String stripComments(String s) {
  final out = StringBuffer();
  var inBlock = false;
  for (final line in s.split('\n')) {
    var l = line;
    if (inBlock) {
      final e = l.indexOf('*/');
      if (e < 0) { out.writeln(); continue; }
      l = l.substring(e + 2); inBlock = false;
    }
    final b = l.indexOf('/*');
    if (b >= 0 && !l.substring(b).contains('*/')) { l = l.substring(0, b); inBlock = true; }
    final c = l.indexOf('//');
    if (c >= 0) l = l.substring(0, c);
    out.writeln(l);
  }
  return out.toString();
}

void main() {
  final raw = File('lib/services/notification_service.dart').readAsStringSync();
  final src = stripComments(raw);

  test('both call sites dispose of the marker through the one policy', () {
    // CONTROL: the reader must see the file, or every assertion is vacuous.
    expect(raw.contains('resolveActiveMarker'), isTrue,
        reason: 'CONTROL: the policy function was not found. Either it was '
                'removed or this scan is reading the wrong file.');

    expect(RegExp(r'await resolveActiveMarker\(').allMatches(src).length, 3,
        reason: 'Every disposal of the marker routes through the single policy: '
                '`_handleEnd`, `_clearIfTimedOut`\'s unreadable branch, and its '
                'timeout branch. Three sites, one shape — the point of the fix '
                'is that this file stops having two answers.');

    // ⛔ The defect itself: an unconditional removal of the marker.
    final removes = RegExp(r'prefs\.remove\(_activeEventKey\)').allMatches(src);
    expect(removes.length, 1,
        reason: '⛔ `prefs.remove(_activeEventKey)` may appear EXACTLY ONCE — '
                'inside `resolveActiveMarker`, after the readable check. A '
                'second occurrence is the defect returning: a removal a failure '
                'can reach, destroying the only copy of the start time.');

    // …and that one occurrence must be inside the policy function.
    // ⚠️ BRACE-MATCHED, not `indexOf('\n}')` — that found the first closing
    // brace at column 0 inside a nested block and put the policy's end BEFORE
    // its own body. Second time in this file a fixed/naive boundary produced a
    // confident wrong answer, which is why both are matched now.
    // ⚠️ AND THE BODY BRACE IS NOT THE FIRST BRACE. The signature's named
    // parameters open one — `(SharedPreferences prefs, {` — so `indexOf('{')`
    // matched the PARAMETER LIST and bounded the function at 156 characters.
    // Anchored on `) async {` instead.
    final policyStart = src.indexOf('Future<MarkerState> resolveActiveMarker');
    var d = 0, policyEnd = -1;
    for (var j = src.indexOf(') async {', policyStart) + 8; j < src.length; j++) {
      if (src[j] == '{') d++;
      if (src[j] == '}') { d--; if (d == 0) { policyEnd = j; break; } }
    }
    expect(policyEnd, greaterThan(policyStart),
        reason: 'CONTROL: could not bound resolveActiveMarker.');
    expect(removes.first.start > policyStart && removes.first.start < policyEnd,
        isTrue,
        reason: '⛔ The one removal must sit INSIDE `resolveActiveMarker`. '
                'Outside it, nothing guarantees a failure cannot reach it.');
  });

  test('the stuck-notification trade is not reversed', () {
    // ⚠️ `_handleEnd` continues past an unreadable marker DELIBERATELY: the
    // comment at its top records that a bare `DateTime.parse` used to throw
    // there and the active notification stuck. Only the deletion changed.
    // ⚠️ BOUNDED BY BRACE MATCHING, not by a character count. A fixed window
    // overran into the next function and made the assertion below report on
    // code that was not `_handleEnd` at all — caught on the first run.
    final start = src.indexOf('Future<void> _handleEnd()');
    var depth = 0, i = src.indexOf('{', start), end = -1;
    for (var j = i; j < src.length; j++) {
      if (src[j] == '{') depth++;
      if (src[j] == '}') { depth--; if (depth == 0) { end = j; break; } }
    }
    expect(end, greaterThan(start), reason: 'CONTROL: could not bound _handleEnd.');
    final body = src.substring(start, end);

    expect(body.contains('_showNormal()'), isTrue,
        reason: '⛔ `_handleEnd` must still restore the standing notification '
                'on EVERY path, including an unreadable marker. Reversing that '
                'would reinstate the stuck-notification bug the comment at '
                ':226 records as deliberately fixed. Only the DELETION changed.');

    // ⭐ THE REAL INVARIANT: the restore comes AFTER the disposal, so no branch
    // can dispose of the marker and skip restoring the notification.
    expect(body.indexOf('_showNormal()') > body.indexOf('resolveActiveMarker'),
        isTrue,
        reason: '⛔ The notification restore must follow the marker disposal. '
                'If disposal could return early, an unreadable marker would '
                'leave the active notification stuck — the exact bug the trade '
                'at :226 was made to fix.');
  });

  test('the quarantine keys are Dart-side and cannot collide with Swift', () {
    expect(src.contains("'mer_active_quarantine'"), isTrue,
        reason: 'CONTROL: the quarantine key must exist.');
    // ⭐ Same NAMES as the Swift side by design. They cannot collide because
    // shared_preferences cannot address a suite name — so this asserts the
    // absence of any attempt to, rather than the absence of the name.
    expect(src.contains('suiteName'), isFalse,
        reason: '⛔ Dart must never address the App Group suite. Doing so would '
                'make it a second writer of the keys a2df73c pinned on the '
                'Swift side. shared_preferences cannot do it today; this fails if '
                'anyone makes it possible.');
  });
}
