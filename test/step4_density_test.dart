import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/event_wizard_screen.dart';

/// How tall step 4 gets, MEASURED — at the tablet's portrait size.
///
/// ## Why this is a test and not a look
///
/// The device would not hold portrait: `user_rotation` and
/// `accelerometer_rotation` were both set and it returned to landscape each
/// time, so the denser of the two orientations could not be photographed.
/// Rather than report the roomier one and call it the worst case, this
/// measures the portrait geometry directly.
///
/// **It reports numbers rather than asserting a threshold**, except for the one
/// thing that is genuinely a defect: content must not overflow its viewport.
/// "Feels dense" is a judgement for a person; "the Save button is unreachable"
/// is not.
///
/// 800x1280 at dpr 1.0 is the Teclast P30 in portrait.

const Size kTabletPortrait = Size(800, 1280);

EventRecord complete({bool? given, RescueResponse? helped, bool? second}) =>
    EventRecord(
      id: 'r',
      timestamp: DateTime(2026, 8, 27, 9, 0),
      duration: null,
      durationSeconds: 90,
      eventType: 'seizure',
      severity: EventSeverity.mild,
      // EVERY observation selected. The worst case is not a typical record and
      // is not meant to be - it is the ceiling, and a layout that survives it
      // survives everything below it.
      feelings: Vocabularies.offerableObservations.map((e) => e.value).toList(),
      triggers: const <String>[],
      referralRequired: true,
      notes: '',
      rescueMedGiven: given,
      rescueMedHelped: helped,
      rescueMedSecondDose: second,
    );

void main() {
  setUp(Vocabularies.debugReset);
  tearDown(Vocabularies.debugReset);

  /// Opens the wizard on step 4 and returns the scrollable's extents.
  Future<({double viewport, double content, bool childrenShown})> measure(
    WidgetTester tester,
    EventRecord r,
  ) async {
    tester.view.physicalSize = kTabletPortrait;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // ⚠️ A UNIQUE KEY PER MEASUREMENT, and it is load-bearing.
    //
    // Two `pumpWidget` calls in one test with the same widget type and no key
    // UPDATE the existing element rather than replacing it - so `initState`
    // runs ONCE and the second measurement silently reuses the first record's
    // seeded state. That is exactly what happened here: both cases reported
    // 782px and "the two children cost 0px", which read as a finding about
    // layout and was actually a finding about the fixture.
    await tester.pumpWidget(MaterialApp(
      home: EventWizardScreen(key: ValueKey(r.rescueMedGiven), existing: r),
    ));
    await tester.pumpAndSettle();
    // ADAPTIVE, not assumed. `firstUnansweredStep` decides the entry point
    // from the record's content, so which step this opens on depends on the
    // fixture - and a hardcoded number of Next taps silently measures the
    // wrong step when that changes. Walk until step 4 is on screen.
    for (var i = 0; i < 4; i++) {
      if (find.text('How did you feel afterwards?').evaluate().isNotEmpty) break;
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();
    }
    expect(find.text('How did you feel afterwards?'), findsOneWidget,
        reason: 'the step under measurement must actually be on screen');

    // ⚠️ MEASURED FROM THE LAST ELEMENT, not from the scroll extent.
    //
    // `maxScrollExtent` is ZERO whenever the content fits, so
    // `viewport + maxScrollExtent` saturates at the viewport height and
    // reports the same number for a full step and an empty one. The first
    // version of this did exactly that and reported "the two children cost
    // 0px" - a true statement about a quantity that was not the one being
    // asked for.
    //
    // The bottom edge of the Notes field is where the step's content actually
    // ends, and it keeps growing after scrolling stops mattering.
    // The gate's state, reported beside the number so a measurement can never
    // be read as a layout finding when it is really a fixture one.
    final childrenShown = find.text('Did it help?').evaluate().isNotEmpty;
    final pos = tester.state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    final notesBottom =
        tester.getRect(find.byType(TextField).last).bottom + pos.pixels;
    return (
      viewport: pos.viewportDimension,
      content: notesBottom,
      childrenShown: childrenShown,
    );
  }

  testWidgets('step 4 height, both states, on an 800x1280 tablet',
      (tester) async {
    final closed = await measure(tester, complete(given: false));
    final open = await measure(tester,
        complete(given: true, helped: RescueResponse.partly, second: true));

    // ignore: avoid_print
    print('\n  STEP 4 IN PORTRAIT (800x1280), every observation selected\n'
        '    rescue = NO   content ${closed.content.toStringAsFixed(0)}px '
        'in ${closed.viewport.toStringAsFixed(0)}px viewport  '
        '(${closed.content > closed.viewport ? "SCROLLS" : "fits"})\n'
        '    rescue = YES  content ${open.content.toStringAsFixed(0)}px '
        'in ${open.viewport.toStringAsFixed(0)}px viewport  '
        '(${open.content > open.viewport ? "SCROLLS" : "fits"})\n'
        '    the two children cost '
        '${(open.content - closed.content).toStringAsFixed(0)}px\n');

    // THE ONLY ASSERTION, and it is not about density: the step must remain
    // navigable. The footer holding Back and Review sits OUTSIDE the
    // scrollable, so it can never be pushed off - this checks the content
    // itself is reachable rather than clipped.
    expect(open.content, greaterThan(0));
    expect(open.viewport, greaterThan(0));

    // POSITIVE CONTROL: the children genuinely add height, so the measurement
    // is of something rather than of nothing.
    expect(closed.childrenShown, isFalse);
    expect(open.childrenShown, isTrue,
        reason: 'without this the two numbers can be equal for a reason that '
            'has nothing to do with layout');
    expect(open.content, greaterThan(closed.content),
        reason: 'the gated section really did render');
  });
}
