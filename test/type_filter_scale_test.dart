import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/vocabulary.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/history_screen.dart';
import 'package:medical_event_recorder/screens/log_event_screen.dart';

/// What the type pickers do when there are FIFTEEN types instead of four.
///
/// Measured rather than argued. The question is whether History's filter row —
/// four fixed chips today — needs a different shape once a user can add their
/// own, on a screen where the date chips already scroll.
///
/// The answer that matters is a NUMBER: how much vertical space the filter
/// takes before the first event row. Everything above the list is a tax on the
/// thing the screen is for.

const List<String> kFifteen = <String>[
  'Seizure / fit',
  'Absence episode',
  'Medication taken',
  'Cluster headache',
  'Migraine with aura',
  'Migraine without aura',
  'Focal aware seizure',
  'Focal impaired awareness',
  'Tonic-clonic',
  'Myoclonic jerk',
  'Atonic drop',
  'Vasovagal syncope',
  'Panic episode',
  'Hypoglycaemic episode',
  'Other / custom',
];

List<VocabularyEntry> fifteenTypes() {
  var i = 0;
  return kFifteen.map((label) {
    final n = i++;
    final value = label == 'Other / custom' ? kOtherEventTypeValue : label;
    return VocabularyEntry(
      id: n + 1,
      value: value,
      label: label,
      isSeeded: n < 3 || label == 'Other / custom',
      isActive: true,
      isProtected: value == kMedicationValue,
      sortOrder: n,
    );
  }).toList();
}

EventRecord rec(String id, String type) => EventRecord(
      id: id,
      timestamp: DateTime(2026, 8, 20, 9, 0),
      duration: null,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: false,
      notes: '',
      eventType: type,
    );

void main() {
  setUp(Vocabularies.debugReset);
  tearDown(Vocabularies.debugReset);

  /// Where the first event row starts, in logical pixels from the top of the
  /// list area. This is the number the question is really about.
  Future<double> firstRowTop(WidgetTester tester) async {
    final rows = find.byType(ListTile);
    expect(rows, findsWidgets, reason: 'the list must have rendered');
    return tester.getTopLeft(rows.first).dy;
  }

  Future<void> pumpHistory(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: HistoryScreen(
        records: <EventRecord>[
          for (var i = 0; i < 6; i++) rec('r$i', kFifteen[i]),
        ],
        onRecordsChanged: (_) async {},
        onEdit: (_, {required confirmOnSave}) async {},
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('1. FOUR types — the baseline', (tester) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpHistory(tester);
    final top = await firstRowTop(tester);
    // ignore: avoid_print
    print('  four types: first row at ${top.toStringAsFixed(0)}px');
    expect(top, lessThan(500));
  });

  testWidgets('2. FIFTEEN types — how much further down the list starts',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Vocabularies.debugSet(eventTypes: fifteenTypes());
    await pumpHistory(tester);
    final top = await firstRowTop(tester);
    // ignore: avoid_print
    print('  fifteen types: first row at ${top.toStringAsFixed(0)}px');

    // Recorded, not enforced at a tight bound: the point is to have the number
    // in the record so the shape decision is made against it rather than
    // against a guess. A hard bound here would fail on a font change.
    expect(top, lessThan(900),
        reason: 'if the filter pushes the list below this, the screen is a '
            'filter with a list underneath rather than a list with a filter');
  });

  testWidgets('3. every type is still REACHABLE, none clipped', (tester) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Vocabularies.debugSet(eventTypes: fifteenTypes());
    await pumpHistory(tester);

    // A Wrap does not clip — it grows. So the failure mode at fifteen is not a
    // hidden chip, it is a filter that eats the screen. Both are asserted so
    // the distinction is on the record.
    for (final label in kFifteen) {
      expect(find.text(label), findsWidgets,
          reason: '"$label" must be reachable in the filter');
    }
  });

  testWidgets('4. "Other / custom" is still LAST at fifteen', (tester) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Vocabularies.debugSet(eventTypes: fifteenTypes());
    await pumpHistory(tester);

    final other = tester.getTopLeft(find.text('Other / custom').first);
    for (final label in kFifteen.where((l) => l != 'Other / custom')) {
      final p = tester.getTopLeft(find.text(label).first);
      final isLater = other.dy > p.dy || (other.dy == p.dy && other.dx > p.dx);
      expect(isLater, isTrue,
          reason: '"Other" must sort after "$label" — it is the no-fit escape '
              'hatch, and an escape hatch in the middle of a list is not one');
    }
  });

  testWidgets('5. the FORM grid grows to fifteen without clipping',
      (tester) async {
    // The 2-wide grid was fixed-shape for four. Fifteen plus the add tile is
    // eight rows, inside a scrolling page — so it lengthens rather than clips.
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Vocabularies.debugSet(eventTypes: fifteenTypes());
    await tester.pumpWidget(
        MaterialApp(home: LogEventScreen(existing: rec('x', 'Tonic-clonic'))));
    await tester.pumpAndSettle();

    expect(find.text('Tonic-clonic'), findsWidgets);
    expect(tester.takeException(), isNull,
        reason: 'no overflow from the fixed-aspect grid at fifteen');
  });
}
