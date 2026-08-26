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
  /// ⚠️ ANCHORED ON THE DAY HEADER, NOT ON `ListTile`.
  ///
  /// The referral toggle is a `Card > SwitchListTile` — so it IS a ListTile,
  /// and it sits ABOVE the list. `find.byType(ListTile).first` returned its
  /// position, and every figure this file reported was the toggle's, not an
  /// event's. The numbers were quoted in two design reads and drove a
  /// recommendation that the filter row needed no restructuring. It did.
  ///
  /// The assertions still PASSED throughout, because the toggle's position
  /// satisfies them. A check that runs, reports clean, and measures something
  /// adjacent to the question.
  Future<double> firstRowTop(WidgetTester tester) async {
    final header = find.textContaining('AUG 2026');
    expect(header, findsWidgets,
        reason: 'the day header is the first thing in the list proper');
    return tester.getTopLeft(header.first).dy;
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

  testWidgets(
      '2a. THE PROPERTY THE REDESIGN BOUGHT: the list start is INDEPENDENT of '
      'the type count', (tester) async {
    // The whole argument for moving the filters into a sheet. Before, the type
    // chips were a Wrap on the screen and every added type pushed the list
    // down without bound — 364px at four, 472px at fifteen, and on a phone
    // 487px rising to 847px, which left ZERO events visible.
    //
    // Asserting EQUALITY rather than a bound is the point: a bound would still
    // pass if growth resumed slowly.
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await pumpHistory(tester);
    final atFour = await firstRowTop(tester);

    Vocabularies.debugSet(eventTypes: fifteenTypes());
    await pumpHistory(tester);
    final atFifteen = await firstRowTop(tester);

    expect(atFifteen, atFour,
        reason: 'a sheet scrolls where a wrapping row could only grow');
  });

  testWidgets('2b. and the same holds on a PHONE, where it was 92%',
      (tester) async {
    // The worst case in the measurement, and the one that made the redesign
    // unarguable: at fifteen types the filters filled 791px of 859px and no
    // event row fitted at all.
    tester.view.physicalSize = const Size(411, 915);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Vocabularies.debugSet(eventTypes: fifteenTypes());
    await pumpHistory(tester);
    final top = await firstRowTop(tester);
    // ignore: avoid_print
    print('  PHONE, fifteen types: first row at ${top.toStringAsFixed(0)}px');

    expect(top, lessThan(200),
        reason: 'was 847px of a 915px screen');
  });

  testWidgets('3. every type is still REACHABLE, none clipped', (tester) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    Vocabularies.debugSet(eventTypes: fifteenTypes());
    await pumpHistory(tester);
    // The chips live in the FILTER SHEET now. That is the change this file's
    // measurement argued for: a sheet SCROLLS where a wrapping row could only
    // grow, so fifteen types no longer push the list off the screen.
    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();

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
    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();

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
