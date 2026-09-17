import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/vocabulary.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/log_event_screen.dart';
import 'package:medical_event_recorder/theme/mer_theme.dart';

/// ⛔ V1 — THE ADD PILL MUST READ AS A DIFFERENT KIND OF THING FROM A VALUE
/// CHIP, IN BOTH SELECTION STATES.
///
/// `showCheckmark` already separates a SELECTED value chip from the pill, but
/// only once something is selected. ⚠️ **The unselected value chip against the
/// add pill was the open case** — after S3 both are the same Material chip,
/// differing only by icon and colour. Corner geometry answers it in both
/// states, and reads before any label does.
///
/// ## ⚠️ THIS FILE NEEDS A REAL DATABASE, AND THAT IS WHY IT IS ITS OWN FILE
///
/// The add pill is hidden when `Vocabularies.canPersist` is false, which is
/// every widget test without sqflite. So the pill cannot be measured on the
/// real screen without one. `CLAUDE.md` allows one database-dependent test per
/// file; this is it.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(version: 1, onCreate: (d, _) async {
      await createAndSeedVocabularies(d);
      await createAndSeedTriggers(d);
    }));
    await Vocabularies.load(db);
  });

  tearDown(() async => db.close());

  EventRecord blank() => EventRecord(
        id: 'v1',
        timestamp: DateTime(2026, 8, 1, 9),
        duration: DurationCategory.oneToFive,
        durationSeconds: 120,
        detailsCompleted: true,
        feelings: const <String>[],
        triggers: const <String>[],
        referralRequired: false,
        notes: '',
        eventType: kTypeSeizure,
        severity: EventSeverity.mild,
      );

  /// ⛔ THE RENDERED RADIUS, NOT THE DECLARED ONE. A radius larger than half
  /// the height CLAMPS, so the theme's `20` on a 34-tall chip renders as a
  /// stadium at 17. Comparing the declared numbers would report a gap of 12
  /// where the rendered gap is 17 against 8 — the declared figure is the one
  /// that misleads here.
  double renderedRadius(OutlinedBorder? shape, double height) {
    final half = height / 2;
    if (shape is StadiumBorder) return half;
    if (shape is RoundedRectangleBorder) {
      final r = (shape.borderRadius.resolve(TextDirection.ltr)).topLeft.x;
      return r > half ? half : r;
    }
    return half; // theme default resolves to the stadium case
  }

  testWidgets('the add pill and a value chip differ in corner geometry',
      (tester) async {
    for (final scale in <double>[1.0, 2.0]) {
      tester.view.physicalSize = const Size(375, 5000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: MERTheme.light,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: LogEventScreen(existing: blank(), confirmOnSave: false),
        ),
      ));
      await tester.pumpAndSettle();
      for (var e = tester.takeException(); e != null;
          e = tester.takeException()) {}

      // Precondition: the pill is actually on screen, or this measures nothing.
      expect(Vocabularies.canPersist, isTrue,
          reason: 'positive control: the database is live, so the add pill is '
              'offered and can be measured on the real screen');
      expect(find.byType(ActionChip), findsWidgets);

      // ⛔ THE PAINTED BOX, NOT THE CHIP WIDGET'S RECT. `getRect` on the chip
      // returns the PADDED TAP TARGET (48), and a stadium radius derived from
      // that reports 24 where the corner actually drawn is half of 34. The
      // first version of this test made exactly that error and reported the
      // two scales as identical, because the tap target is 48 at both.
      double paintedHeight(Finder chip) => tester
          .getRect(find.descendant(of: chip, matching: find.byType(InkWell))
              .first)
          .height;

      final valueFinder = find.byType(FilterChip).first;
      final addFinder = find.byType(ActionChip).first;
      final value = tester.widget<FilterChip>(valueFinder);
      final valueH = paintedHeight(valueFinder);
      final add = tester.widget<ActionChip>(addFinder);
      final addH = paintedHeight(addFinder);

      final vr = renderedRadius(value.shape, valueH);
      final ar = renderedRadius(add.shape, addH);

      // ignore: avoid_print
      print('V1 @${scale}x 375w\n'
          '  value chip  h=${valueH.toStringAsFixed(1)}  '
          'rendered radius=${vr.toStringAsFixed(1)}  (stadium)\n'
          '  add pill    h=${addH.toStringAsFixed(1)}  '
          'rendered radius=${ar.toStringAsFixed(1)}\n'
          '  ratio       ${(ar / vr).toStringAsFixed(2)} of the value chip');

      expect(add.shape, isA<RoundedRectangleBorder>(),
          reason: 'V1: the add pill carries its own corner geometry');
      expect(value.shape, isNull,
          reason: 'positive control: the value chip does NOT set a shape, so '
              'the difference comes from the pill rather than from both being '
              'set to the same thing');
      expect(ar, lessThan(vr),
          reason: 'the pill must be VISIBLY squarer, not merely different');
    }
  });
}
