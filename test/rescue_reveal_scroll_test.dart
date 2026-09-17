import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/log_event_screen.dart';
import 'package:medical_event_recorder/theme/mer_theme.dart';

/// ⛔ V5 — ANSWERING A QUESTION MUST NOT GROW THE FORM SOMEWHERE THE USER
/// CANNOT SEE.
///
/// Tapping **Given** inserts two more questions BELOW the one just answered,
/// through a collection-if. ⚠️ **The measurement is what makes this a defect
/// rather than a tidiness note**: at 375x667 the rescue block already begins
/// **373.7 below the fold** at scale 1.0 and **972.7 below it at 200%**, so
/// the two new questions arrive off-screen and nothing says they exist.
///
/// ⭐ **Two problems, two assertions, and neither substitutes for the other.**
/// Scrolling helps someone who can see the screen and tells a screen-reader
/// user nothing; an announcement tells a screen-reader user and leaves the
/// sighted user's new questions off-screen.
void main() {
  setUp(Vocabularies.debugReset);
  tearDown(Vocabularies.debugReset);

  EventRecord blank() => EventRecord(
        id: 'v5',
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

  Future<void> pumpForm(WidgetTester tester) async {
    // The real phone geometry the fold figures were measured at.
    tester.view.physicalSize = const Size(375, 667);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: MERTheme.light,
      home: LogEventScreen(existing: blank(), confirmOnSave: false),
    ));
    await tester.pumpAndSettle();
    for (var e = tester.takeException(); e != null; e = tester.takeException()) {}
  }

  testWidgets('the parent question is pulled to the top of the viewport',
      (tester) async {
    await pumpForm(tester);

    final given = find.text('Given');
    await tester.scrollUntilVisible(given, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();

    // ⛔ PRECONDITION, ASSERTED RATHER THAN ASSUMED: the two children are NOT
    // in the tree yet. Without this the test passes on a form that was already
    // showing them, and proves nothing about the reveal.
    expect(find.text('DID IT HELP?'), findsNothing);
    expect(find.text('SECOND DOSE'), findsNothing);

    await tester.tap(given.first);
    await tester.pumpAndSettle();

    expect(find.text('DID IT HELP?'), findsOneWidget,
        reason: 'positive control: the reveal actually happened, so the '
            'scroll assertion below is about the revealed state');

    final viewportTop = tester.getRect(find.byType(Scrollable).first).top;
    final labelTop = tester.getRect(find.text('RESCUE MEDICATION')).top;

    // ignore: avoid_print
    print('V5 AFTER REVEAL\n'
        '  scroll viewport top : ${viewportTop.toStringAsFixed(1)}\n'
        '  RESCUE MEDICATION   : ${labelTop.toStringAsFixed(1)}\n'
        '  delta               : ${(labelTop - viewportTop).toStringAsFixed(1)}');

    // ⚠️ A TOLERANCE, NOT AN EQUALITY, and the reason is named: the question
    // sits inside the scroll view's own padding, so `alignment: 0.0` puts the
    // LABEL's leading edge at the viewport's leading edge only up to that
    // padding. A tight equality would encode this screen's padding into an
    // assertion about scrolling.
    expect(labelTop - viewportTop, lessThan(32.0),
        reason: 'the question the user just answered must still be in view, '
            'at the TOP, with the new questions in the space below it');
  });

  testWidgets('the insertion is ANNOUNCED, because scrolling is silent',
      (tester) async {
    // SemanticsService.announce goes out over the accessibility channel.
    final announced = <String>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      (dynamic message) async {
        final map = message as Map<dynamic, dynamic>;
        if (map['type'] == 'announce') {
          announced.add((map['data'] as Map<dynamic, dynamic>)['message']
              as String);
        }
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<dynamic>(
            SystemChannels.accessibility, null));

    final handle = tester.ensureSemantics();
    await pumpForm(tester);

    final given = find.text('Given');
    await tester.scrollUntilVisible(given, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();

    expect(announced, isEmpty,
        reason: 'nothing has been announced yet, so the assertion below is '
            'about the tap rather than about the screen opening');

    await tester.tap(given.first);
    await tester.pumpAndSettle();

    expect(announced, hasLength(1),
        reason: 'answering Given announces the insertion exactly once');
    expect(announced.single, contains('did it help'));
    expect(announced.single, contains('second dose'));
    handle.dispose();
  });

  testWidgets('answering it AGAIN does not re-announce', (tester) async {
    // ⛔ The trigger is `rescueChildrenVisible` going false -> true, NOT the
    // tap. Re-tapping Given while the children are already showing changes
    // nothing on screen, so announcing again would describe an event that did
    // not happen.
    final announced = <String>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(
      SystemChannels.accessibility,
      (dynamic message) async {
        final map = message as Map<dynamic, dynamic>;
        if (map['type'] == 'announce') announced.add('x');
        return null;
      },
    );
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockDecodedMessageHandler<dynamic>(
            SystemChannels.accessibility, null));

    final handle = tester.ensureSemantics();
    await pumpForm(tester);

    final given = find.text('Given');
    await tester.scrollUntilVisible(given, 200,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();

    await tester.tap(given.first);
    await tester.pumpAndSettle();
    expect(announced, hasLength(1), reason: 'the first tap reveals');

    await tester.tap(given.first);
    await tester.pumpAndSettle();
    expect(announced, hasLength(1),
        reason: 'the second tap reveals nothing, so it announces nothing');
    handle.dispose();
  });
}
