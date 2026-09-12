import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/home_screen.dart';
import 'package:medical_event_recorder/theme/mer_theme.dart';

/// AUDIT.md §13(j)'s last standing site — home's "This month" statistic counts
/// events by WHEN THEY HAPPENED, not by when they were typed.
///
/// ⛔ THE FIXTURE IS THE TEST. Both records are LOGGED NOW, so both are in this
/// month by `timestamp`; they differ only in `occurredAt`. Under the rule this
/// replaced the figure read 2. If either record's `timestamp` ever stopped
/// falling in the current month the test would pass while measuring nothing,
/// so that is asserted as a precondition rather than assumed.
///
/// ⚠️ One prefs-dependent test per process, per CLAUDE.md's harness rule: this
/// file holds exactly one.

/// The last day of the month before this one, at midday — comfortably clear of
/// both month boundaries whatever day the suite runs on.
DateTime lastMonthDay(DateTime now) {
  final firstOfThisMonth = DateTime(now.year, now.month, 1);
  final lastOfLastMonth = firstOfThisMonth.subtract(const Duration(days: 1));
  return DateTime(lastOfLastMonth.year, lastOfLastMonth.month,
      lastOfLastMonth.day, 12);
}

/// Reads the number above a stat label. `_StatCell` is a Column of
/// `Text(value)` then `Text(label)`, so the first descendant Text is the value.
String statValue(WidgetTester tester, String label) {
  final cell =
      find.ancestor(of: find.text(label), matching: find.byType(Column)).first;
  final value = find
      .descendant(of: cell, matching: find.byType(Text))
      .evaluate()
      .first
      .widget as Text;
  return value.data!;
}

void main() {
  final now = DateTime.now();

  /// Backdated: it HAPPENED last month and was typed today.
  final backdated = EventRecord(
    id: 'backdated',
    timestamp: now,
    occurredAt: lastMonthDay(now),
    duration: null,
    feelings: const <String>[],
    triggers: const <String>[],
    referralRequired: false,
    notes: '',
    detailsCompleted: true,
  );

  /// Ordinary: it happened when it was typed.
  final today = EventRecord(
    id: 'today',
    timestamp: now,
    duration: null,
    feelings: const <String>[],
    triggers: const <String>[],
    referralRequired: false,
    notes: '',
    detailsCompleted: true,
  );

  setUpAll(() {
    SharedPreferences.setMockInitialValues({
      'disclaimerAcceptedVersion': kDisclaimerVersion,
      kWalkthroughSeenVersionKey: kWalkthroughVersion,
      kEventStorageKey:
          jsonEncode(<Map<String, dynamic>>[backdated.toMap(), today.toMap()]),
    });
    StorageBoot.debugSet();
    Vocabularies.debugReset();
  });
  tearDownAll(() {
    StorageBoot.debugSet();
    Vocabularies.debugReset();
  });

  testWidgets('"This month" counts occurrence, not logging time',
      (tester) async {
    // ⛔ PRECONDITION, not decoration: both records must be LOGGED this month,
    // or the fixture cannot discriminate between the two rules.
    final start = DateTime(now.year, now.month, 1);
    expect(backdated.timestamp.isAfter(start), isTrue,
        reason: 'the backdated record must be TYPED this month');
    expect(today.timestamp.isAfter(start), isTrue);
    expect(backdated.whenHappened.isAfter(start), isFalse,
        reason: 'and must have HAPPENED before it');

    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
        MaterialApp(theme: MERTheme.light, home: const HomeScreen()));
    await tester.pumpAndSettle();

    // Positive control: the fixture reached the screen at all.
    expect(statValue(tester, 'Total saved'), '2',
        reason: 'both records must be loaded, or the count below is vacuous');

    // ⛔ 1, not 2. Reading `timestamp` here gave 2 until 12 Sep 2026.
    expect(statValue(tester, 'This month'), '1',
        reason: 'a seizure backdated to last month belongs in last month');
  });
}
