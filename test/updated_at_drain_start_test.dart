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

/// A drained START creates with updatedAt equal to timestamp.
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

    test('3b. a START creates with updatedAt EQUAL to timestamp',
        () async {
      // Rules 3 and 5 collided in the original: `applyInbox`'s start pass
      // CREATES records, which on iOS is the primary capture path, so a
      // drain-created record would have been born with updatedAt null while
      // creation was required to equal timestamp.
      final prefs = await SharedPreferences.getInstance();
      final store = EventStore();
      final tapped = DateTime(2026, 8, 22, 16, 29, 59);
      await writeStartInstruction(prefs, id: 'NEW', at: tapped);

      await drainInbox(
        transport: PrefsInboxTransport(prefs),
        store: store,
        loaded: const <EventRecord>[],
      );

      final raw = prefs.getString(kEventStorageKey)!;
      final made = EventRecord.fromMap(
          (jsonDecode(raw) as List<dynamic>).first as Map<String, dynamic>)!;

      expect(made.id, 'NEW', reason: 'positive control: it was created');
      expect(made.timestamp, tapped);
      expect(made.updatedAt, tapped,
          reason: 'a creation sets it equal to timestamp, and both are the '
              'instruction\'s at');
    });
  });
}
