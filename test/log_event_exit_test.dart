import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/vocabulary.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/log_event_screen.dart';

/// Leaving `LogEventScreen` with unsaved edits must not discard them silently.
///
/// AUDIT.md section 13(a). `_cancel` was a bare `Navigator.pop` with no
/// confirmation, and there was NO `PopScope` on the route at all — so the OS
/// back gesture and the Android hardware back did not even reach `_cancel`.
/// The only confirmation on the screen fired on SAVE: it protected against
/// saving, not against losing.
///
/// ## The shape being pinned
///
///   not dirty  -> both button exits leave immediately, NO prompt
///   dirty      -> prompt first, on every exit including the OS pop
///   Save       -> `confirmOnSave` untouched
///
/// ⭐ The CLEAN-EXIT half is load-bearing and is tested first. This is the fast
/// edit path; the common action is opening a record, reading it, leaving. A
/// confirmation on a departure that changed nothing would tax the more common
/// action, so tests 1 and 2 exist to fail if a prompt ever appears there.
///
/// No `SharedPreferences` in this file, so the one-state-per-process rule does
/// not apply. `Vocabularies.debugReset` is the only shared state.

EventRecord editable() => EventRecord(
      id: 'exit-1',
      timestamp: DateTime(2026, 8, 20, 9, 0),
      duration: DurationCategory.oneToFive,
      durationSeconds: 90,
      eventType: 'seizure',
      severity: EventSeverity.mild,
      feelings: const <String>[],
      triggers: const <String>[],
      rescueMedGiven: false,
      referralRequired: false,
      notes: '',
      detailsCompleted: true,
    );

/// Pumps the screen inside a real Navigator so a pop can be observed, and
/// records whether anything was returned to the caller.
///
/// `popped` distinguishes "left the screen" from "still on it"; `result`
/// carries whatever the screen handed back, which must be null on every exit
/// except Save.
class Harness {
  bool popped = false;
  Object? result;
  bool sentinelVisible = false;
}

Future<Harness> pumpScreen(WidgetTester tester,
    {bool confirmOnSave = true}) async {
  final h = Harness();
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: ElevatedButton(
            child: const Text('OPEN'),
            onPressed: () async {
              final r = await Navigator.of(context).push<EventRecord>(
                MaterialPageRoute(
                  builder: (_) => LogEventScreen(
                    existing: editable(),
                    confirmOnSave: confirmOnSave,
                  ),
                ),
              );
              h.popped = true;
              h.result = r;
            },
          ),
        ),
      ),
    ),
  ));
  await tester.tap(find.text('OPEN'));
  await tester.pumpAndSettle();
  return h;
}

/// Makes the screen dirty by a single tap on a field that is unambiguous on
/// this record: severity mild -> severe.
Future<void> makeDirty(WidgetTester tester) async {
  final severe = find.text(severityLabel(EventSeverity.severe));
  await tester.ensureVisible(severe);
  await tester.pumpAndSettle();
  await tester.tap(severe);
  await tester.pumpAndSettle();
}

/// Fires a real system back, the way Android delivers it. This is NOT a
/// `Navigator.pop` — it goes through the platform channel and the widget tree's
/// `PopScope`, which is the path that previously bypassed `_cancel` entirely.
Future<void> systemBack(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMethodCodec().encodeMethodCall(
      const MethodCall('popRoute'),
    ),
    (_) {},
  );
  await tester.pumpAndSettle();
}

Future<void> tapBackArrow(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.arrow_back));
  await tester.pumpAndSettle();
}

Future<void> tapCancel(WidgetTester tester) async {
  final cancel = find.widgetWithText(OutlinedButton, 'Cancel');
  await tester.ensureVisible(cancel);
  await tester.pumpAndSettle();
  await tester.tap(cancel);
  await tester.pumpAndSettle();
}

void main() {
  setUp(Vocabularies.debugReset);
  tearDown(Vocabularies.debugReset);

  // ── 1 and 2: the clean exits ───────────────────────────────────────────────

  testWidgets('1. CLEAN exit via the back arrow leaves with NO prompt',
      (tester) async {
    final h = await pumpScreen(tester);
    await tapBackArrow(tester);

    expect(find.text('Discard your changes?'), findsNothing,
        reason: 'nothing changed, so reading a record must not be taxed');
    expect(h.popped, isTrue, reason: 'it must actually leave');
    expect(h.result, isNull, reason: 'and write nothing');
  });

  testWidgets('1b. CONTROL for test 1: the same exit WITH a change DOES prompt',
      (tester) async {
    // Without this, test 1 would pass if the prompt were broken entirely.
    final h = await pumpScreen(tester);
    await makeDirty(tester);
    await tapBackArrow(tester);

    expect(find.text('Discard your changes?'), findsOneWidget);
    expect(h.popped, isFalse, reason: 'the prompt must hold the screen open');
  });

  testWidgets('2. CLEAN exit via the Cancel button leaves with NO prompt',
      (tester) async {
    final h = await pumpScreen(tester);
    await tapCancel(tester);

    expect(find.text('Discard your changes?'), findsNothing);
    expect(h.popped, isTrue);
    expect(h.result, isNull);
  });

  testWidgets('2b. CONTROL for test 2: the same exit WITH a change DOES prompt',
      (tester) async {
    final h = await pumpScreen(tester);
    await makeDirty(tester);
    await tapCancel(tester);

    expect(find.text('Discard your changes?'), findsOneWidget);
    expect(h.popped, isFalse);
  });

  // ── 3 and 4: the dirty exits, both outcomes ───────────────────────────────

  testWidgets('3. DIRTY back arrow: Discard leaves and writes nothing',
      (tester) async {
    final h = await pumpScreen(tester);
    await makeDirty(tester);
    await tapBackArrow(tester);

    expect(find.text('Discard your changes?'), findsOneWidget);
    // the body names the change, so the user can see what they are losing
    expect(find.textContaining('These changes have not been saved'),
        findsOneWidget);
    expect(find.textContaining('Severity:'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Discard'));
    await tester.pumpAndSettle();

    expect(h.popped, isTrue);
    expect(h.result, isNull, reason: 'DISCARD must not write the record');
  });

  testWidgets('3b. DIRTY back arrow: Go back stays, with the edit intact',
      (tester) async {
    final h = await pumpScreen(tester);
    await makeDirty(tester);
    await tapBackArrow(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Go back'));
    await tester.pumpAndSettle();

    expect(h.popped, isFalse, reason: 'it must stay on the screen');
    expect(find.text('Discard your changes?'), findsNothing);
    // the edit survives: pressing Save now still offers to save it, which it
    // could not do if the tap had been reverted
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm changes'), findsOneWidget,
        reason: 'the change is still pending, so the save dialog opens');
    expect(find.text('No changes to save.'), findsNothing);
  });

  testWidgets('4. DIRTY Cancel button: Discard leaves, Go back stays',
      (tester) async {
    final h = await pumpScreen(tester);
    await makeDirty(tester);
    await tapCancel(tester);

    expect(find.text('Discard your changes?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Go back'));
    await tester.pumpAndSettle();
    expect(h.popped, isFalse);

    // and again, choosing Discard this time
    await tapCancel(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Discard'));
    await tester.pumpAndSettle();
    expect(h.popped, isTrue);
    expect(h.result, isNull);
  });

  // ── 5: the path that previously bypassed everything ──────────────────────

  testWidgets('5. OS BACK, dirty, prompts — the path that had no guard at all',
      (tester) async {
    // Exercised through the flutter/navigation platform channel's popRoute,
    // which is how Android delivers a hardware or gesture back. It reaches the
    // tree's PopScope. Before this fix there was no PopScope on the route and
    // this popped the screen without touching _cancel.
    final h = await pumpScreen(tester);
    await makeDirty(tester);
    await systemBack(tester);

    expect(find.text('Discard your changes?'), findsOneWidget,
        reason: 'the OS pop must be intercepted, not just the buttons');
    expect(h.popped, isFalse);

    await tester.tap(find.widgetWithText(TextButton, 'Discard'));
    await tester.pumpAndSettle();
    expect(h.popped, isTrue);
    expect(h.result, isNull);
  });

  testWidgets('5b. CONTROL for test 5: OS BACK when CLEAN leaves immediately',
      (tester) async {
    // Proves the interception is conditional. A PopScope that blocked every
    // pop would pass test 5 and trap the user here; this fails if it does.
    final h = await pumpScreen(tester);
    await systemBack(tester);

    expect(find.text('Discard your changes?'), findsNothing);
    expect(h.popped, isTrue, reason: 'canPop: false must not trap a clean exit');
    expect(h.result, isNull);
  });

  testWidgets('5c. CONTROL that the channel message is LIVE, not inert',
      (tester) async {
    // If handlePlatformMessage silently did nothing, tests 5 and 5b would both
    // pass vacuously — 5b because the screen never left, 5 because no dialog
    // appeared. This asserts the message alone moves the app, with no taps.
    final h = await pumpScreen(tester);
    expect(h.popped, isFalse);
    await systemBack(tester);
    expect(h.popped, isTrue,
        reason: 'popRoute must actually reach the Navigator');
  });

  // ── 6 and 7: storage, and confirmOnSave unchanged ────────────────────────

  testWidgets('6. NOTHING reaches storage on any exit except Save',
      (tester) async {
    // The screen returns the record to the caller and the CALLER persists it,
    // so "returned non-null" is the observable proxy for "reached storage".
    // Every non-Save exit must return null.
    for (final exit in <String>['arrow', 'cancel', 'os']) {
      final h = await pumpScreen(tester);
      await makeDirty(tester);
      switch (exit) {
        case 'arrow':
          await tapBackArrow(tester);
        case 'cancel':
          await tapCancel(tester);
        case 'os':
          await systemBack(tester);
      }
      await tester.tap(find.widgetWithText(TextButton, 'Discard'));
      await tester.pumpAndSettle();
      expect(h.popped, isTrue, reason: '$exit should have left');
      expect(h.result, isNull, reason: '$exit must not return a record');
    }

    // POSITIVE CONTROL: Save DOES return one, so the null checks above are
    // measuring the exit and not a harness that can never see a result.
    final h = await pumpScreen(tester);
    await makeDirty(tester);
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(h.popped, isTrue);
    expect(h.result, isA<EventRecord>(),
        reason: 'Save is the one exit that writes');
  });

  testWidgets('7. confirmOnSave is UNCHANGED: wording, buttons, and its '
      'no-op guard', (tester) async {
    final h = await pumpScreen(tester);

    // its no-op short-circuit still fires, and is NOT the discard dialog
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('No changes to save.'), findsOneWidget);
    expect(find.text('Confirm changes'), findsNothing);
    expect(find.text('Discard your changes?'), findsNothing);

    await makeDirty(tester);
    await tester.ensureVisible(find.text('Save changes'));
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm changes'), findsOneWidget);
    expect(find.text('Save the following changes?'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Keep editing'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Save'), findsOneWidget);

    // ⚠️ the two dialogs must stay DISTINCT: the save dialog must not have
    // acquired the discard wording, and vice versa
    expect(find.text('Go back'), findsNothing);
    expect(find.text('Discard'), findsNothing);

    // Keep editing still means stay
    await tester.tap(find.widgetWithText(TextButton, 'Keep editing'));
    await tester.pumpAndSettle();
    expect(h.popped, isFalse);
    expect(h.result, isNull);
  });

  testWidgets('8. dismissing the discard dialog behaves as Go back',
      (tester) async {
    // Matches how confirmOnSave treats null: the user stays, edits intact.
    final h = await pumpScreen(tester);
    await makeDirty(tester);
    await tapBackArrow(tester);
    expect(find.text('Discard your changes?'), findsOneWidget);

    // dismiss without choosing, by popping the dialog route itself
    await systemBack(tester);

    expect(find.text('Discard your changes?'), findsNothing,
        reason: 'the dialog closed');
    expect(h.popped, isFalse, reason: 'but the screen did NOT leave');
    expect(h.result, isNull);
  });
}
