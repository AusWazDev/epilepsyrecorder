// THE NO-ID FALLBACK — what a notification tap does when it cannot say which
// event it is about.
//
// ⭐ THE DECISION, 23 September 2026: NO ID → HISTORY. Never `.first`, in any
// branch, on any platform, under any optimisation.
//
// ⛔ WHAT WAS THERE BEFORE. Three live sites opened `_records.first` on a
// notification tap: the iOS funnel (`getPendingOpenLatest` returns a BOOL and
// carries no id) and BOTH Android legacy-boolean branches. `.first` is wrong
// whenever the list order changed between the notification firing and the tap —
// a record created in between is enough, hidden or not — and it is wrong
// SILENTLY, writing a carer's note onto a different event with no signal.
//
// ⚠️ THE COST IS REAL AND IT LANDS ON EVERY TAP, not only the failing ones.
// An Android tap that lands correctly today lands on History instead. Taken
// anyway: it converts a silent wrong-write into a visible extra tap, and a
// misrouted clinical detail with no signal is worse than one more tap.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/screens/home_screen.dart';

/// Source with `//` and `///` lines removed.
///
/// ⛔ COMMENTS MUST BE STRIPPED. This file's own subject is quoted in the
/// comments it asserts about — every pin below would match its own rationale.
/// `notification_routing_test.dart` failed on its first run for exactly that.
List<String> liveLines(String path) => File(path)
    .readAsLinesSync()
    .map((l) => l.trimLeft().startsWith('//') ? '' : l)
    .toList();


EventRecord rec(String id, DateTime when) => EventRecord(
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
    );

void main() {
  final older = rec('A', DateTime(2026, 9, 18, 10));
  final newer = rec('B', DateTime(2026, 9, 20, 10));
  final list  = [newer, older]; // newest first, as the screen holds it

  group('the routing decision', () {
    test('an id that resolves opens THAT record', () {
      final out = resolveNotificationRouting(list, 'A');
      expect(out.landing, NotificationLanding.record);
      expect(out.record?.id, 'A');
      expect(out.record?.id, isNot(list.first.id),
          reason: 'and this is only a real test while the target is NOT the '
              'first element \u2014 otherwise it passes against a .first '
              'implementation');
    });

    test('an id that resolves to nothing REPORTS, and never substitutes', () {
      final out = resolveNotificationRouting(list, 'GONE');
      expect(out.landing, NotificationLanding.notFound);
      expect(out.record, isNull,
          reason: 'the user asked for a specific event. Opening a different '
              'one with no signal is the defect the id path exists to remove');
      expect(out.landing, isNot(NotificationLanding.history),
          reason: 'a named-but-missing event is NOT the same as an unnamed '
              'one, and they get different messages. Collapsing them would '
              'tell a user to "choose it from the list" when it is not there');
    });

    test('\u2b50 NO ID ROUTES TO HISTORY, NOT TO .first', () {
      // \u2b50 THE CONTROL THIS FILE EXISTS FOR. Before 23 September 2026 this
      // case ran `_openDetails(_records.first)` \u2014 it opened `newer` and the
      // user added details to an event the notification never named.
      for (final id in <String?>[null, '']) {
        final out = resolveNotificationRouting(list, id);

        expect(out.landing, NotificationLanding.history,
            reason: '\u26d4 id=$id carries no event. History, always \u2014 never '
                '`.first`, on any platform, under any optimisation');
        expect(out.record, isNull,
            reason: '\u26d4 and NOTHING is carried back for a caller to open. A '
                'record here would be `.first` by another name');

        // \u26a0\ufe0f ANTI-VACUITY. "record is null" is worthless unless a `.first`
        // implementation would have had something to return \u2014 on an empty
        // list this test would pass against the very code it rejects.
        expect(list, isNotEmpty,
            reason: 'positive control: there IS a newest record');
        expect(list.first.id, 'B',
            reason: 'positive control AND the counterfactual: `.first` would '
                'have opened B. The routing decision returns nothing instead');
      }
    });

    test('an EMPTY list with no id still routes to History', () {
      // Previously this did nothing at all \u2014 `_records.isEmpty` short-circuited
      // and the tap produced no response, which reads as a broken app.
      final out = resolveNotificationRouting(const <EventRecord>[], null);
      expect(out.landing, NotificationLanding.history);
      expect(out.record, isNull);
    });
  });

  group('the upgrade boundary', () {
    test('a pending flag written by the CURRENT shipping build reaches History',
        () {
      // \u26d4 THE SEQUENCE, stated as the thing it is: the shipping build writes
      // `mer_open_latest_event = true` and NOTHING else \u2014 no id key, and its
      // feedback notification carries no `userInfo` at all. The new build
      // drains the flag, reads null for the id, and must land on History.
      //
      // \u26a0\ufe0f AND THIS BRANCH MAY NEVER EXPIRE ON iOS. Nothing ever removes a
      // feedback notification, so a pre-upgrade one can sit in Notification
      // Center indefinitely and be tapped long after the upgrade. Android's
      // equivalent shim is marked removable "after one release has fully
      // rolled"; on iOS that moment may not arrive, so the no-id branch is
      // PERMANENT, not transitional.
      const String? idFromPreUpgradeFlag = null;

      final out = resolveNotificationRouting(list, idFromPreUpgradeFlag);
      expect(out.landing, NotificationLanding.history,
          reason: '\u26d4 ESCAPE CLAUSE 3. If this ever reports `record`, a no-id '
              'path reaches a RECORD and the defect is back');
      expect(out.record, isNull);
    });
  });

  group('the copy the user is shown', () {
    test('History says WHY it opened, and the two messages are distinct', () {
      expect(kNotificationNoIdMessage,
          "That notification didn't identify an event. Choose it from the list.",
          reason: 'copy is the author\'s, not the implementation\'s. If it no '
              'longer fits its position, that is a decision to be redone, not '
              'a string to be shortened');
      expect(kNotificationMissingRecordMessage, 'That event could not be found.');
      expect(kNotificationNoIdMessage, isNot(kNotificationMissingRecordMessage),
          reason: 'the two landings must not read alike \u2014 one means "it is '
              'not there", the other means "I do not know which one"');
    });
  });

  group('position-as-identity survives in exactly one place', () {
    test('_openDetails(_records.first) is the LAST EVENT card and nothing else',
        () {
      final lines = liveLines('lib/screens/home_screen.dart');
      final hits = <int>[];
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('_openDetails(_records.first)')) hits.add(i);
      }

      // Positive control AND the denominator. If this is zero the scan is
      // broken, not the code — the card below is a permanent, deliberate site.
      expect(hits, isNotEmpty,
          reason: 'positive control: the scan finds the form at all');

      expect(hits, hasLength(1),
          reason: '⛔ NO ID → HISTORY. A notification tap that cannot name its '
              'event must open History, never the newest record. The only '
              'permitted `_openDetails(_records.first)` is the LAST EVENT '
              'card, which is a button the user pressed while looking at the '
              'record it names — not a routing decision made on their behalf.\n'
              'found at lines: ${hits.map((i) => i + 1).join(', ')}');

      // And it is genuinely the card, not some other survivor that happens to
      // be alone.
      final window = lines.sublist(hits.first - 6, hits.first + 3).join('\n');
      expect(window, contains('_LastEventCard'),
          reason: 'the surviving site must be the LAST EVENT card. It is at '
              'line ${hits.first + 1} and its neighbourhood does not name '
              '_LastEventCard, so position-as-identity has moved somewhere '
              'this pin no longer describes.');
    });
  });

  group('the iOS carrier exists on the Swift side', () {
    String src(String p) => File(p).readAsStringSync();

    test('both feedback notifications attach the event id to userInfo', () {
      final app = src('ios/Runner/AppDelegate.swift');
      final intent = src('ios/MERWidget/EndMEREventIntent.swift');

      expect(app, contains('content.title'),
          reason: 'positive control: AppDelegate builds notification content');
      expect(intent, contains('feedback.title'),
          reason: 'positive control: the intent builds notification content');

      expect(app, contains('kNotificationEventIdKey'),
          reason: '⛔ showFeedbackNotification must attach the event id so the '
              'tap can name its event. Without it the tap reaches History and '
              'the user must find the event themselves — every time.');
      expect(intent, contains('mer_event_id'),
          reason: '⛔ the mirrored copy in EndMEREventIntent must attach it '
              'too. On iOS 17+ the extension is the ONLY poster — the app is '
              'usually not running — so leaving it out disables the carrier on '
              'the path that carries most taps.');
    });

    test('the tap writes the id beside the flag, and CLEARS it when absent', () {
      final app = src('ios/Runner/AppDelegate.swift');

      expect(app, contains('standard.set(true, forKey: kPendingOpenLatest)'),
          reason: 'positive control AND a guard: kPendingOpenLatest keeps its '
              'name, meaning and type. It is not repurposed.');
      expect(app, contains('kPendingOpenEventId'),
          reason: 'the persisted path needs its own key for the id');
      expect(app, contains('standard.removeObject(forKey: kPendingOpenEventId)'),
          reason: '⛔ A TAP THAT CARRIES NO ID MUST CLEAR THE KEY. Otherwise an '
              'id left by an earlier tap is read as this tap\'s id, and the '
              'no-id case opens a RECORD — the exact defect this work removes, '
              'restored by omission.');
    });

    test('the live channel call carries the id in arguments', () {
      final app = src('ios/Runner/AppDelegate.swift');
      expect(app.contains('navChannel?.invokeMethod("openLatestEvent", arguments: nil)'),
          isFalse,
          reason: '⛔ arguments: nil is the defect. The live path and the '
              'persisted path must BOTH carry the id — whichever arrives first '
              'wins, so a carrier on only one of them is a carrier that works '
              'intermittently.');
    });
  });
}
