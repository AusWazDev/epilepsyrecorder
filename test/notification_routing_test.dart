import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/screens/home_screen.dart';

/// THE NOTIFICATION ROUND TRIP — the path that had no coverage at all.
///
/// ⛔ **`7c5fae7` shipped id-based routing with NO TEST, on the one path where
/// a defect writes a carer's note onto a different event.** ⭐ The Brief 60
/// coverage read found it: nothing in 126 test files referenced
/// `mer_open_event_id`, `openLatest` or the resolution at all.
///
/// ## ⚠️ THE HONEST LIMIT, STATED RATHER THAN WORKED AROUND
///
/// ⛔ **The round trip cannot be driven END TO END from `flutter test` on this
/// machine.** Both call sites sit behind `Platform.isAndroid` — `dart:io`, not
/// `defaultTargetPlatform` — so on a Windows or macOS host they never execute,
/// and no override reaches them.
///
/// ⭐ **So the RESOLUTION is extracted and tested here, because that is the part
/// a defect corrupts.** The platform gate decides WHEN TO POLL; it has nothing
/// to do with WHICH RECORD OPENS.
///
/// **What would cover the rest:** an integration test on an Android device or
/// emulator, driving a real notification tap. ⛔ **That is not available from
/// this machine and the gap is recorded rather than implied.**
///
/// 🔴 **AND THE iOS LEG STAYS OPEN.** `_openLatestEvent` is still
/// position-based — the iOS native channel's `getPendingOpenLatest` returns a
/// BOOL with no id. ⚠️ **It does not become closed because the Android side
/// now is**; closing it needs a Swift change and a Mac.

EventRecord rec(String id, DateTime when, {bool hidden = false}) => EventRecord(
      id:               id,
      timestamp:        when,
      duration:         DurationCategory.lt1,
      durationSeconds:  30,
      detailsCompleted: true,
      feelings:         const <String>[],
      triggers:         const <String>[],
      referralRequired: false,
      notes:            '',
      eventType:        kTypeSeizure,
      severity:         EventSeverity.mild,
      hidden:           hidden,
    );

void main() {
  final older = rec('A', DateTime(2026, 9, 18, 10));
  final newer = rec('B', DateTime(2026, 9, 20, 10));

  test('1. the happy path lands on the RIGHT record', () {
    // ⭐ ASSERTS THE RECORD, not the SnackBar or any other report — the thing
    // reported ABOUT, never the thing that reports. A test on the message
    // would have passed against a build that opened the wrong event.
    final out = resolveNotificationTarget([newer, older], 'A');
    expect(out.hadId, isTrue);
    expect(out.record?.id, 'A');
  });

  test('2. the target is NOT the newest, and the original still opens', () {
    // 🔴 THE CASE `.first` GOT WRONG INDEPENDENTLY OF HIDING, and the reason
    // the id path exists. A record created between the notification firing and
    // the tap makes position-as-identity wrong on its own.
    final list = [newer, older]; // newest first, as the app holds it
    final out = resolveNotificationTarget(list, 'A');
    expect(out.record?.id, 'A',
        reason: 'the notification named A. B was recorded afterwards and is '
            'now first in the list — resolving by position would open B and '
            'the user would add details to the wrong event');
    expect(out.record?.id, isNot(list.first.id),
        reason: 'and this is only a real test while the target is NOT the '
            'first element — otherwise it passes against a .first '
            'implementation');
  });

  test('3. a HIDDEN target still opens — routing reads the complete set', () {
    final hiddenOne = rec('A', DateTime(2026, 9, 18, 10), hidden: true);
    final out = resolveNotificationTarget([newer, hiddenOne], 'A');
    expect(out.record?.id, 'A',
        reason: 'hiding is a VIEW concern. A notification about an event must '
            'open that event whatever the user has chosen to see');
    expect(out.record?.hidden, isTrue,
        reason: 'and it is genuinely the hidden one, not a lookalike');
  });

  test('4. an id that resolves to nothing reports, and never substitutes', () {
    final out = resolveNotificationTarget([newer, older], 'GONE');
    expect(out.hadId, isTrue,
        reason: 'the tap DID carry an id, so this is not the legacy path');
    expect(out.record, isNull,
        reason: 'and nothing is substituted. Opening the newest record instead '
            'is the defect the id path exists to remove — the user asked for a '
            'specific event and would get a different one with no signal');
  });

  test('5. no id at all falls through to the legacy path', () {
    for (final id in <String?>[null, '']) {
      final out = resolveNotificationTarget([newer, older], id);
      expect(out.hadId, isFalse,
          reason: 'id=$id must be distinguishable from an id that resolved to '
              'nothing — the caller runs the pre-id fallback on one and '
              'reports on the other');
      expect(out.record, isNull);
    }
  });

  group('the contract at the call site', () {
    String src(String p) => File(p).readAsStringSync();

    test('the legacy fallback still carries its removal condition', () {
      // ⛔ A compatibility shim without an expiry is how temporary becomes
      // architecture. The condition was recorded when the shim was added; this
      // asserts it has not been quietly dropped.
      final s = src('lib/services/notification_service.dart');
      expect(s, contains('mer_open_latest_event'),
          reason: 'CONTROL: the legacy key is still referenced, so the '
              'assertion below is about something');
      expect(s.contains('REMOVABLE once no pre-id notification'), isTrue,
          reason: 'the pre-id fallback must keep its stated removal condition '
              '— removable once no pre-id notification can still be in flight, '
              'i.e. after one release has fully rolled');
    });

    test('the missing-record message asserts no cause it cannot know', () {
      // ⚠️ THE CAUSE LIST, settled 20 September 2026: MER has NO DELETE PATH
      // for events — hiding is the only removal and routing reads the complete
      // set, so a hidden record still resolves. The realistic causes are that
      // the record was NEVER SAVED (`_persist()` is deliberately not awaited
      // and can fail) or that a restore replaced the list. ⛔ In the first case
      // "no longer on this device" is simply false.
      final s = src('lib/screens/home_screen.dart');

      // ⛔ COMMENTS STRIPPED. The correction's own comment QUOTES the retired
      // wording so the change stays legible, and a raw `contains` matched that
      // quote rather than any live string — this test failed on its first run
      // for exactly that reason. ⭐ A mention in a comment is not code.
      final live = s
          .split('\n')
          .where((l) {
            final t = l.trimLeft();
            return !t.startsWith('//') && !t.startsWith('///');
          })
          .join('\n');

      expect(s.contains('no longer on this device'), isTrue,
          reason: 'CONTROL: the retired wording IS still quoted in a comment, '
              'so the strip below is load-bearing rather than decoration. If '
              'this ever fails, the annotation recording the change has been '
              'deleted and the assertion below has become trivially true');
      expect(live.contains('no longer on this device'), isFalse,
          reason: 'that wording asserts the record WAS here and has gone. The '
              'commonest cause is a write that failed, where it was never here '
              'at all — and that is the case most needing the user to look');
      expect(live, contains('That event could not be found.'));
    });
  });
}
