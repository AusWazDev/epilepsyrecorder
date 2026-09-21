// Harness for `reconcileLegacySharedRecords`. NOT a test file.
//
// ⭐ THIS PATH IS ALREADY FULLY INJECTABLE, AND THAT IS WHY AN iOS FIX CAN BE A
// WINDOWS BRIEF. `reconcileLegacySharedRecords` takes its channel, prefs, store
// and loaded list as PARAMETERS and reads `Platform` nowhere. The only platform
// read is at the call site in `home_screen`, outside the function.
//
// The rationale for that shape is already written down at
// `walkthrough_screen.dart:361-366` and was applied again in Brief 68 Part C as
// `shouldReportNavChannelFailure`. Cited, not re-derived.

import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';

const kTestChannel = MethodChannel('au.com.notiva.mer/navigation');

/// What the mocked Swift side did, so a test can assert on deletion rather than
/// infer it from the flag.
class MirrorSpy {
  MirrorSpy(this.payload);

  /// The raw string `readLegacySharedRecords` returns. Null = key absent.
  String? payload;

  /// ⛔ THE ASSERTION THAT MATTERS: did Swift delete the mirror?
  bool cleared = false;
  int readCount = 0;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kTestChannel, (call) async {
      switch (call.method) {
        case 'readLegacySharedRecords':
          readCount++;
          return payload;
        case 'clearLegacySharedRecords':
          cleared = true;
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

EventRecord mirrorRec({
  required String id,
  required DateTime timestamp,
  DurationCategory? duration,
}) =>
    EventRecord(
      id: id,
      timestamp: timestamp,
      duration: duration,
      durationSeconds: duration == null ? null : 40,
      eventType: 'seizure',
      severity: EventSeverity.mild,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: false,
      notes: '',
      detailsCompleted: true,
    );

String payloadOf(List<EventRecord> rs) =>
    jsonEncode(rs.map((r) => r.toMap()).toList());

/// A payload that is a well-formed JSON List whose elements cannot all become
/// records — the PARTIAL case. The second element is a Map with no usable
/// timestamp, which `EventRecord.fromMap` returns null for.
String partialPayload(EventRecord good) => jsonEncode(<dynamic>[
      good.toMap(),
      <String, dynamic>{'id': 'undecodable', 'timestamp': 'not-a-date'},
    ]);
