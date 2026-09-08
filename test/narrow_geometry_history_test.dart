import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/history_screen.dart';

import 'narrow_geometry.dart';

/// HISTORY — flex-overflow geometry across width.
///
/// ⚠️ HISTORY IS ONE OF THE NINE UNCAPPED SCREENS per §13(aa), where home is
/// one of the three capped at 520. So it may degrade at a different width, and
/// D2's minimum has to clear whichever is higher.
///
/// Record shape and harness copied from `history_delete_geometry_test.dart`,
/// which is the working precedent for pumping this screen.

List<EventRecord> rows() => List.generate(
      12,
      (i) => EventRecord(
        id: 'r$i',
        timestamp: DateTime(2026, 8, 20, 3, 1),
        duration: DurationCategory.lt1,
        durationSeconds: 40,
        eventType: 'seizure',
        severity: EventSeverity.mild,
        feelings: const <String>[],
        triggers: const <String>[],
        referralRequired: false,
        notes: '',
        detailsCompleted: true,
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'disclaimerAcceptedVersion': kDisclaimerVersion,
      kWalkthroughSeenVersionKey: kWalkthroughVersion,
    });
    StorageBoot.debugSet();
    Vocabularies.debugReset();
  });
  tearDown(() {
    StorageBoot.debugSet();
    Vocabularies.debugReset();
  });

  testWidgets('HISTORY geometry sweep', (tester) async {
    addTearDown(tester.view.reset);
    Widget build() => MaterialApp(
          home: HistoryScreen(
            records: rows(),
            onRecordsChanged: (_) async {},
            onEdit: (_, {required confirmOnSave}) async {},
          ),
        );

    for (final w in <double>[400, 94]) {
      final g = await measureAt(tester,
          platform: TargetPlatform.windows, dpr: 1.25,
          logicalW: w, logicalH: 546, build: build);
      // ignore: avoid_print
      print('  NAMED history w=${w.toStringAsFixed(0)} '
          'texts=${g.overflowingTexts} flexOverflows=${g.overflows.length}');
      for (final o in g.overflows.take(4)) {
        // ignore: avoid_print
        print('     $o');
      }
    }

    await sweep(tester,
        screen: 'history', platform: TargetPlatform.windows, dpr: 1.25,
        logicalH: 546, build: build);
    await sweep(tester,
        screen: 'history', platform: TargetPlatform.android, dpr: 1.25,
        logicalH: 546, build: build);

    expect(true, isTrue, reason: 'diagnostic; the print output is the result');
  });
}
