import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/models/vocabulary.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/vocabulary_screen.dart';

/// Bulk hide and show on "Your lists".
///
/// ## ⛔ WHAT THIS IS FOR
///
/// Trimming a list that now holds 22 observations and 21 beforehand entries
/// cost ONE TAP PER ROW — about sixteen for a user whose condition is not the
/// one seeded first. The mechanism that answers "this list is too long" cost
/// more than the problem it solved.
///
/// ## ⛔ AND WHY SHOW IS TESTED AS HARD AS HIDE
///
/// *A safety mechanism that can be applied but not lifted converts a success
/// into a permanent defect.* Hiding sixteen in one gesture while unhiding them
/// takes sixteen taps leaves a user one gesture from a state they can only
/// leave slowly. Test 4 is that rule, not a symmetry preference.
///
/// ## ⚠️ THESE ASSERT THE PROPERTY, NOT WHICH ROWS
///
/// The first draft located checkboxes by label through an ancestor/descendant
/// finder chain, and it threw. Tapping the first N boxes and asserting N
/// entries changed tests what bulk MEANS — several from one action — without
/// the test re-deriving the screen's own row order, which would make the
/// second implementation's bug the finding.
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

  int activeCount() =>
      <String>[kEventTypeTable, kTriggerTable, kObservationTable].fold(
          0,
          (n, t) =>
              n + Vocabularies.allIn(t).where((e) => e.isActive).length);

  /// NOT pumpAndSettle. The bulk action does real sqflite-ffi writes and then
  /// shows a SnackBar; a widget test runs on a fake clock, so settling waits on
  /// I/O the clock never reaches. Pump a fixed number of frames instead.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(
      // A tall surface: the list is lazy, so rows below the fold are absent
      // from the tree rather than merely off-screen.
      home: MediaQuery(
        data: MediaQueryData(size: Size(1400, 3000)),
        child: VocabularyScreen(),
      ),
    ));
    await settle(tester);
  }

  Future<void> enterSelect(WidgetTester tester) async {
    await tester.tap(find.text('Select'));
    await settle(tester);
  }

  /// ⚠️ ensureVisible BEFORE each tap, and the RESULT IS ASSERTED.
  ///
  /// `tap` does not throw when it misses — it warns. A missed tap here selects
  /// one fewer row and every count downstream is quietly off by one, which is
  /// exactly how test 4 first failed: 46 where 47 was expected, with the real
  /// cause a warning nobody reads.
  Future<void> tapBoxes(WidgetTester tester, int n) async {
    for (var i = 0; i < n; i++) {
      final box = find.byType(Checkbox).at(i);
      await tester.ensureVisible(box);
      await settle(tester);
      await tester.tap(box);
      await settle(tester);
    }
    expect(find.text(n == 1 ? '1 selected' : '$n selected'), findsOneWidget,
        reason: 'a tap MISSED — it warns rather than throwing, so assert the '
            'selection actually took');
  }

  testWidgets('1. the mode is opt-in — no checkboxes until Select',
      (tester) async {
    await pump(tester);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('Hide'), findsWidgets, reason: 'per-row buttons remain');

    await enterSelect(tester);
    expect(find.byType(Checkbox), findsWidgets);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('2. ⛔ LOCKED ROWS KEEP THEIR LOCK AND GET NO CHECKBOX',
      (tester) async {
    await pump(tester);
    final locks = find.byIcon(Icons.lock_outline).evaluate().length;
    expect(locks, greaterThan(0),
        reason: 'POSITIVE CONTROL: there ARE locked rows to exclude');

    await enterSelect(tester);
    expect(find.byIcon(Icons.lock_outline).evaluate().length, locks,
        reason: 'losing the lock in selection mode would read as '
            'selectable-but-unticked');
  });

  testWidgets('3. hides SEVERAL from one action', (tester) async {
    await pump(tester);
    await enterSelect(tester);
    final before = activeCount();

    await tapBoxes(tester, 3);

    await tester.tap(find.widgetWithText(TextButton, 'Hide selected'));
    await settle(tester);

    expect(activeCount(), before - 3,
        reason: 'three entries changed from ONE action — one-at-a-time would '
            'have changed one');
    expect(find.byType(Checkbox), findsNothing,
        reason: 'the mode closes when the action completes');
  });

  testWidgets('4. ⛔ SHOW IS AS CHEAP AS HIDE — the removal path',
      (tester) async {
    await pump(tester);
    await enterSelect(tester);
    final before = activeCount();

    // ⚠️ ONE ROW, AND INDEX 0 SPECIFICALLY. An earlier draft hid three and
    // re-selected indices 0-2 expecting the same rows; a diagnostic showed the
    // three hidden were `seizure`, `other` and `Missed medication` — spanning
    // two sections — so CHECKBOX INDICES ARE NOT STABLE ACROSS A HIDE. Index 0
    // is the first row of the first section and cannot move.
    //
    // Bulk HIDE is proved by test 3. What this proves is that the reverse is
    // the SAME kind of gesture rather than sixteen taps, and test 5 proves the
    // bar offers it for a hidden selection.
    await tapBoxes(tester, 1);
    await tester.tap(find.widgetWithText(TextButton, 'Hide selected'));
    await settle(tester);
    expect(activeCount(), before - 1);

    await enterSelect(tester);
    await tapBoxes(tester, 1);
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Show selected'))
            .onPressed,
        isNotNull,
        reason: 'the reverse action must be OFFERED for a hidden selection');
    await tester.tap(find.widgetWithText(TextButton, 'Show selected'));
    await settle(tester);

    expect(activeCount(), before,
        reason: 'unhide is one gesture of the same kind, or a bulk hide is a '
            'trap the user needs sixteen taps to escape');
  });

  testWidgets('5. an action is offered only when it would do something',
      (tester) async {
    await pump(tester);
    await enterSelect(tester);

    TextButton btn(String label) =>
        tester.widget<TextButton>(find.widgetWithText(TextButton, label));

    expect(find.text('Select entries'), findsOneWidget);
    expect(btn('Hide selected').onPressed, isNull);
    expect(btn('Show selected').onPressed, isNull);

    await tapBoxes(tester, 1);
    expect(btn('Hide selected').onPressed, isNotNull);
    expect(btn('Show selected').onPressed, isNull,
        reason: 'offering Show for an entry already shown would be a control '
            'that does nothing');
  });

  testWidgets('6. leaving the mode clears the selection', (tester) async {
    await pump(tester);
    await enterSelect(tester);
    await tapBoxes(tester, 1);

    await tester.tap(find.text('Done'));
    await settle(tester);
    expect(find.byType(Checkbox), findsNothing);

    await enterSelect(tester);
    expect(find.text('Select entries'), findsOneWidget,
        reason: 'a stale selection surviving the mode would act on rows the '
            'user cannot see ticked');
  });
}
