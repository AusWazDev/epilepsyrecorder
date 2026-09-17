import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/backup.dart';
import 'package:medical_event_recorder/models/capture_instruction.dart';
import 'package:medical_event_recorder/models/capture_inbox.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/services/ios_capture_bridge.dart';

/// THE CONTROL THAT MATTERS: a drained END stamps the tap, not the drain.
///
/// ⛔ ITS OWN FILE, AND THE REASON IS MECHANICAL.
///
/// `SharedPreferences.setMockInitialValues` does NOT take effect once an
/// instance exists earlier in the same process, and a Dart test FILE is one
/// process. `CLAUDE.md`'s rule is ONE PREFS-DEPENDENT TEST PER FILE -- not
/// one state, one TEST -- because the second test gets whatever the first
/// left, and the sibling tests here write records into prefs.
///
/// ⚠️ AND `test`, NOT `testWidgets`. A `testWidgets` body runs on a FAKE
/// CLOCK, so a prefs or sqflite await inside one waits on a future the clock
/// never reaches -- the test hangs with no output rather than failing. The
/// first draft of this suite did exactly that, for six and a half minutes.
///
/// `updatedAt` — schema v11.
///
/// ⛔ **IT RECORDS WHEN THE USER ACTED, NOT WHEN THE APP WROTE**, and the
/// difference is not cosmetic. A drain runs whenever the app next comes to the
/// foreground; the user acted when they tapped. Stamping `DateTime.now()` in a
/// drain would let **a device that merely launched outrank a device where
/// somebody actually edited something.**
///
/// ## ⚠️ WHY "NOT SET BY A DRAIN" WOULD HAVE BEEN THE WRONG RULE
///
/// `_endActiveEvent` is a button tapped INSIDE the app, and it routes through
/// the inbox deliberately — to keep Dart's main isolate the single writer of
/// the record list. **Three end surfaces on two platforms all reach storage
/// through the drain.** Drain does not mean no user; it means the write is
/// deferred. What distinguishes the cases is whether a user action is
/// ATTRIBUTABLE, and an inbox instruction is itself the evidence of one — it
/// even carries the time.
///
/// ## The three "when"s
///
///     timestamp   when it was LOGGED
///     occurredAt  when it HAPPENED
///     updatedAt   when it was last CHANGED
///
/// ⛔ **None of them means "when the row was written."**
///
/// ⭐ INERT. Nothing reads it — no restore change, no conflict screen, no
/// existing-wins change. Exactly `hidden` at v10.

const _channelName = 'au.com.notiva.mer/navigation';

EventRecord full(String id, DateTime ts, {DateTime? updatedAt}) => EventRecord(
      id: id,
      timestamp: ts,
      occurredAt: DateTime(2026, 8, 20, 9, 15),
      duration: DurationCategory.lt1,
      durationSeconds: null,
      detailsCompleted: true,
      feelings: const <String>['Tired'],
      triggers: const <String>['Stress'],
      referralRequired: true,
      notes: 'a note',
      eventType: 'seizure',
      severity: EventSeverity.moderate,
      rescueMedGiven: true,
      rescueMedHelped: RescueResponse.helped,
      rescueMedSecondDose: false,
      updatedAt: updatedAt,
    );

class _FakeIosHost {
  String? legacyRecords;
  bool legacyCleared = false;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(_channelName),
            (MethodCall call) async {
      switch (call.method) {
        case 'readLegacySharedRecords':
          return legacyRecords;
        case 'clearLegacySharedRecords':
          legacyCleared = true;
          return null;
      }
      return null;
    });
  }

  void remove() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(_channelName), null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('3. A DRAINED INSTRUCTION USES THE INSTRUCTION\'S at', () {
    setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

    test('3a. THE CONTROL THAT MATTERS: an END stamps the tap, not now',
        () async {
      // ⛔ THE ORIGINAL RULE WOULD HAVE FAILED THIS TEST. "Not set by either
      // drain" would have left `updatedAt` untouched by a user ending an
      // event — three surfaces, two platforms. And `DateTime.now()` here would
      // record the FOREGROUND rather than the tap.
      final prefs = await SharedPreferences.getInstance();
      final store = EventStore();
      final logged = DateTime(2026, 8, 22, 18, 30);
      await store.save(<EventRecord>[full('x', logged, updatedAt: logged)]);

      // The user tapped End at a time firmly in the past, and the drain runs
      // NOW. If the implementation used `now`, these would differ.
      final tapped = DateTime(2026, 8, 22, 18, 37, 12);
      await writeEndInstruction(prefs, id: 'x', at: tapped, seconds: 432);

      final outcome = await drainInbox(
        transport: PrefsInboxTransport(prefs),
        store: store,
        loaded: await store.load(),
      );
      expect(outcome.wrote, isTrue, reason: 'positive control: it drained');

      final raw = prefs.getString(kEventStorageKey)!;
      final after = EventRecord.fromMap(
          (jsonDecode(raw) as List<dynamic>).first as Map<String, dynamic>)!;

      expect(after.durationSeconds, 432,
          reason: 'positive control: the end really was applied');
      expect(after.updatedAt, tapped,
          reason: 'the INSTRUCTION\'S at, not the drain\'s clock. A device that '
              'merely came to the foreground must not outrank a device where '
              'somebody actually edited something');
      expect(after.timestamp, logged,
          reason: 'and the log time still does not drift');

      // The distinguishing assertion, stated separately: `now` is far from
      // `tapped`, so an implementation using `now` cannot pass by coincidence.
      expect(DateTime.now().difference(tapped).inDays, greaterThan(1),
          reason: 'positive control on the FIXTURE: the two clocks are far '
              'enough apart that this test can tell them apart');
    });
  });
}
