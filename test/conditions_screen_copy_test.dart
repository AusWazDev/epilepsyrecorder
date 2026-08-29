import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/models/condition.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/conditions_screen.dart';

/// The copy on "What you track", and the one claim it must not make.
///
/// ## ⛔ WHY THIS FILE EXISTS
///
/// The hint read **"Epilepsy, migraine, something else"** — naming two
/// diagnoses, one of which the Change Register has in the BLOCKED set while the
/// catalogue assessment of 29 Aug put it on the SUPPORTED side. Either way a
/// placeholder was asserting something the record contradicted, and **nothing
/// anywhere would have caught it**: no test touched this screen's copy.
///
/// The rule the app settled on is the same one the store listing is being
/// corrected to: **name the SHAPE, not a diagnosis.** Naming the shape is true;
/// naming a diagnosis is a claim about what MER serves.
///
/// ## ⚠️ AND WHY THE EMPTY STATE IS TESTED HERE RATHER THAN ON THE DEVICE
///
/// The blurb carrying the shape claim renders **only when no condition is
/// named**. The test device has one, so that branch is unreachable there — a
/// device pass can read the hint and cannot read the blurb. This file is the
/// only place the empty branch is exercised at all.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: kSqliteSchemaVersion,
        // THE REAL SCHEMA, not a hand-built fixture. This file only needs the
        // screen to open; a fixture here would be one more thing to drift.
        onCreate: (d, _) => createSchema(d),
        onUpgrade: upgradeSchema,
      ),
    );
    await Vocabularies.load(db);
  });

  tearDown(() async => db.close());

  /// Pump until the load finishes.
  ///
  /// NOT pumpAndSettle. The screen shows a CircularProgressIndicator while
  /// loading and the add field autofocuses a blinking cursor once open --
  /// both animate forever, so pumpAndSettle can never settle and times out.
  /// Pump to a CONDITION instead of to quiescence.
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: ConditionsScreen(store: ConditionStore(db)),
    ));
    // runAsync, because the screen's load does REAL sqflite-ffi I/O and a
    // widget test runs on a fake clock -- pumping alone advances time the
    // database never sees, so the future stays pending forever.
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(CircularProgressIndicator).evaluate().isEmpty) return;
    }
    fail('the screen never finished loading');
  }

  Future<void> openAddField(WidgetTester tester) async {
    await tester.tap(find.text('Name a condition'));
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (find.byType(TextField).evaluate().isNotEmpty) return;
    }
    fail('the add field never appeared');
  }

  testWidgets('the empty state names the SHAPE, not a diagnosis',
      (tester) async {
    await pump(tester);

    // The shape claim, on the surface that survives focus. A placeholder
    // vanishes the moment someone types; this does not.
    expect(
      find.textContaining('episodes — they start, they stop'),
      findsOneWidget,
      reason: 'the empty-state blurb must carry the shape claim',
    );

    // Kept from the original blurb and load-bearing: it stops a user thinking
    // they are expected to enumerate everything they have.
    expect(find.textContaining('only ever name one'), findsOneWidget);
  });

  testWidgets('the hint defers to the user and names nobody', (tester) async {
    await pump(tester);
    await openAddField(tester);

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration!.hintText, 'The name you use for it');
  });

  testWidgets('NO DIAGNOSIS APPEARS IN ANY USER-FACING STRING', (tester) async {
    // ⛔ THE DURABLE ASSERTION. The two above pin today's exact wording and
    // will need editing if the copy is reworded; this one states the RULE and
    // survives rewording. It is what would have caught the original hint.
    await pump(tester);
    await openAddField(tester);

    final shown = <String>[
      for (final w in tester.widgetList<Text>(find.byType(Text)))
        if (w.data != null) w.data!,
      for (final w in tester.widgetList<TextField>(find.byType(TextField)))
        if (w.decoration?.hintText != null) w.decoration!.hintText!,
    ];

    // Named because an exclusion that cannot say what it excluded cannot be
    // trusted: these are the diagnoses this screen has carried or could
    // plausibly acquire, spanning both the supported and blocked sets.
    const forbidden = <String>[
      'epilepsy',
      'migraine',
      'seizure',
      'panic',
      'vertigo',
      'syncope',
      'cataplexy',
    ];

    expect(shown, isNotEmpty, reason: 'positive control: copy was collected');
    expect(shown.any((s) => s.contains('The name you use for it')), isTrue,
        reason: 'positive control: the hint is inside the collected set');

    for (final s in shown) {
      final lower = s.toLowerCase();
      for (final d in forbidden) {
        expect(lower.contains(d), isFalse,
            reason: 'user-facing copy names a diagnosis ("$d"): "$s"');
      }
    }
  });
}
