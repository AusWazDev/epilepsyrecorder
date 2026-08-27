import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/event_wizard_screen.dart';

/// Backing out of the wizard must not rewrite `detailsCompleted`.
///
/// ## The defect
///
/// `_build` set `detailsCompleted: false` unconditionally, and `_onWillPop`
/// captures whenever there is any input — which an existing record always has.
/// So merely OPENING a legacy record and leaving flipped its flag from NULL to
/// false, on a record the user had only looked at.
///
/// **NULL and false are different claims.** NULL means the record predates the
/// wizard: neither complete nor incomplete, because the concept did not exist
/// when it was written. False means someone started the flow and abandoned it.
/// Converting the first into the second is a quiet claim about history, and it
/// applied to all 69 records on the device that predate the wizard.
///
/// ## Why it was worth fixing despite changing nothing visible
///
/// Routing is unaffected (`isIncomplete` already sends these to the wizard),
/// the field is not exported, and no screen renders it. The reason to fix it is
/// that it is a stored value being rewritten by a tap that changed nothing —
/// exactly the class this project has refused six times over.

EventRecord legacy({bool? completed}) => EventRecord(
      id: 'legacy',
      timestamp: DateTime(2026, 8, 25, 22, 3),
      // The 10:03 PM record on the tablet: a real capture with a coerced type
      // and severity, missing only its duration.
      duration: null,
      durationSeconds: null,
      eventType: 'seizure',
      severity: EventSeverity.mild,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: false,
      notes: '',
      detailsCompleted: completed,
    );

void main() {
  setUp(Vocabularies.debugReset);
  tearDown(Vocabularies.debugReset);

  /// Pushes the wizard, backs out with the system gesture, and returns
  /// whatever the route yielded.
  ///
  /// Driven through a real Navigator rather than by calling `_build`, because
  /// the defect was in the interaction between the capture rule and the exit
  /// path — testing the builder alone would have missed which one fires.
  Future<EventRecord?> backOutOf(WidgetTester tester, EventRecord? existing) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    EventRecord? result;
    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return const Scaffold(body: Text('home'));
      }),
    ));

    unawaited(Navigator.of(ctx)
        .push<EventRecord>(MaterialPageRoute(
          builder: (_) => EventWizardScreen(existing: existing),
        ))
        .then((r) => result = r));
    await tester.pumpAndSettle();

    // The AppBar arrow — the exit path a user actually takes. It is a custom
    // IconButton, not a BackButton, and it only EXITS from step 0; on any
    // later step it walks back one. A legacy record with no duration opens at
    // step 0, so one tap leaves.
    expect(find.text('How long did it last?'), findsOneWidget,
        reason: 'precondition: on step 0, where the arrow exits');
    await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_back));
    await tester.pumpAndSettle();
    return result;
  }

  group('BACKING OUT PRESERVES THE FLAG', () {
    testWidgets('1. a LEGACY record keeps NULL', (tester) async {
      // THE DEFECT. Before the fix this returned `false`.
      final out = await backOutOf(tester, legacy());
      expect(out, isNotNull, reason: 'the draft is still returned');
      expect(out!.detailsCompleted, isNull,
          reason: 'it predates the wizard and still does');
    });

    testWidgets('2. NEGATIVE CONTROL: false is what the old rule produced',
        (tester) async {
      // Test 1 is a null result and would pass against a wizard that returned
      // nothing at all. This shows the record really did come back, carrying
      // its other values, so the NULL is a preserved flag rather than an
      // absent record.
      final out = await backOutOf(tester, legacy());
      expect(out!.id, 'legacy');
      expect(out.eventType, 'seizure');
      expect(out.severity, EventSeverity.mild);
      expect(out.detailsCompleted, isNot(false),
          reason: 'the value the unconditional rule wrote');
    });

    testWidgets('3. a PARTIAL stays false', (tester) async {
      final out = await backOutOf(tester, legacy(completed: false));
      expect(out!.detailsCompleted, isFalse);
    });

    testWidgets('4. a COMPLETED record is NOT downgraded', (tester) async {
      // Deliberate. The flag records whether the flow was ever completed, and
      // it was. If a field has since been emptied, `isIncomplete` catches that
      // by reading the fields — which it does better than a flag can.
      final out = await backOutOf(tester, legacy(completed: true));
      expect(out!.detailsCompleted, isTrue);
    });

    testWidgets('5. a NEW record captures as a partial', (tester) async {
      // The one case that must still write false: there is no prior value, and
      // a wizard-created record genuinely IS a fresh partial. Quick-record
      // writes false for the same reason.
      //
      // Something must be entered, or `_hasAnyInput` is false and the wizard
      // pops without a draft at all.
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      EventRecord? result;
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (c) {
          ctx = c;
          return const Scaffold(body: Text('home'));
        }),
      ));
      unawaited(Navigator.of(ctx)
          .push<EventRecord>(MaterialPageRoute(
            builder: (_) => const EventWizardScreen(),
          ))
          .then((r) => result = r));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).first, '2');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithIcon(IconButton, Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.detailsCompleted, isFalse,
          reason: 'a new wizard record IS a partial');
      expect(result!.durationSeconds, 120,
          reason: 'positive control: the entry was captured');
    });
  });

  group('SAVING STILL COMPLETES', () {
    testWidgets('6. Save sets true, whatever it started as', (tester) async {
      // The other half of the rule. Only `_finish` asserts completion, and the
      // fix must not have touched it.
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      EventRecord? result;
      late BuildContext ctx;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (c) {
          ctx = c;
          return const Scaffold(body: Text('home'));
        }),
      ));
      unawaited(Navigator.of(ctx)
          .push<EventRecord>(MaterialPageRoute(
            builder: (_) => EventWizardScreen(existing: legacy()),
          ))
          .then((r) => result = r));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip to end'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(result!.detailsCompleted, isTrue,
          reason: 'walking to the end and saving IS completing it');
    });
  });
}

/// Local `unawaited`, so the file does not depend on dart:async for one line.
void unawaited(Future<void> f) {}
