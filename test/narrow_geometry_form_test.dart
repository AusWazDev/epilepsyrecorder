import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/log_event_screen.dart';

import 'narrow_geometry.dart';

/// THE FORM (`LogEventScreen`) — flex-overflow geometry across width.
///
/// ⚠️ NO PREFS HERE, so the one-test-per-process rule does not apply — the
/// same note `rescue_change_list_test.dart` carries. `Vocabularies.debugReset`
/// is the only shared state.
///
/// ⭐ This is the screen §13(am) was about, and the one D2's minimum is being
/// chosen for.

EventRecord record() => EventRecord(
      id: 'form-1',
      timestamp: DateTime(2026, 8, 20, 9, 0),
      duration: DurationCategory.oneToFive,
      durationSeconds: 90,
      eventType: 'seizure',
      severity: EventSeverity.mild,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: false,
      notes: '',
      detailsCompleted: true,
    );

void main() {
  setUp(Vocabularies.debugReset);
  tearDown(Vocabularies.debugReset);

  testWidgets('FORM geometry sweep', (tester) async {
    addTearDown(tester.view.reset);
    Widget build() => MaterialApp(
          home: LogEventScreen(existing: record(), confirmOnSave: true),
        );

    for (final w in <double>[400, 94]) {
      final g = await measureAt(tester,
          platform: TargetPlatform.windows, dpr: 1.25,
          logicalW: w, logicalH: 546, build: build);
      // ignore: avoid_print
      print('  NAMED form w=${w.toStringAsFixed(0)} '
          'texts=${g.overflowingTexts} flexOverflows=${g.overflows.length}');
      for (final o in g.overflows.take(4)) {
        // ignore: avoid_print
        print('     $o');
      }
    }

    await sweep(tester,
        screen: 'form', platform: TargetPlatform.windows, dpr: 1.25,
        logicalH: 546, build: build);
    await sweep(tester,
        screen: 'form', platform: TargetPlatform.android, dpr: 1.25,
        logicalH: 546, build: build);
  });
}
