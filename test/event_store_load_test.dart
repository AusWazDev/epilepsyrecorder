import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_record.dart';

/// Regression test for the total-data-loss defect: every record lives in one
/// JSON string under one key, so an exception while parsing any single record
/// previously made the entire history unreachable.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Map<String, dynamic> goodRecord(String id, String iso) => {
        'id': id,
        'timestamp': iso,
        'duration': 'lt1',
        'feelings': <String>[],
        'referralRequired': false,
        'notes': 'note $id',
        'eventType': 'seizure',
        'severity': 'mild',
        'triggers': <String>[],
      };

  test('one unparseable record does not cost the user the whole history',
      () async {
    final payload = <dynamic>[
      goodRecord('good-1', '2026-08-01T09:15:00.000'),
      // unparseable timestamp
      {...goodRecord('bad-unparseable', ''), 'timestamp': 'not-a-date'},
      goodRecord('good-2', '2026-08-02T14:30:00.000'),
      // timestamp key absent entirely
      Map<String, dynamic>.from(goodRecord('bad-missing', ''))
        ..remove('timestamp'),
      // timestamp present but wrong type
      {...goodRecord('bad-typed', ''), 'timestamp': 12345},
      // not a map at all
      'this is not a record',
    ];

    SharedPreferences.setMockInitialValues({
      kEventStorageKey: jsonEncode(payload),
    });

    final records = await EventStore().load();

    expect(records.length, 2, reason: 'both good records must survive');
    expect(
      records.map((r) => r.id).toList(),
      ['good-2', 'good-1'],
      reason: 'survivors are returned newest-first',
    );
    expect(records.first.notes, 'note good-2');
  });

  test('fromMap returns null rather than defaulting a bad timestamp',
      () async {
    expect(EventRecord.fromMap(goodRecord('ok', '2026-08-01T09:15:00.000')),
        isNotNull);
    expect(
        EventRecord.fromMap(
            {...goodRecord('x', ''), 'timestamp': 'not-a-date'}),
        isNull);
    expect(
        EventRecord.fromMap(
            Map<String, dynamic>.from(goodRecord('x', ''))..remove('timestamp')),
        isNull);
  });

  test('a wholly valid payload is unaffected', () async {
    SharedPreferences.setMockInitialValues({
      kEventStorageKey: jsonEncode(<dynamic>[
        goodRecord('a', '2026-08-01T09:15:00.000'),
        goodRecord('b', '2026-08-03T11:00:00.000'),
      ]),
    });
    final records = await EventStore().load();
    expect(records.map((r) => r.id).toList(), ['b', 'a']);
  });
}
