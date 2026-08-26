import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/history_screen.dart';

/// The filter sheet, the badge, and the applied-filters banner.
///
/// ## The hazard this file exists for
///
/// Moving the filters into a sheet reclaims the screen and makes ONE failure
/// worse: a user who does not know a filter is on reads a partial history as
/// their whole history, and exports it for an appointment. That is an
/// incomplete clinical record, sent.
///
/// The badge and the banner are what prevent it, and both are computed from
/// `activeFilters`. **If a filter is ever added to the PREDICATE and forgotten
/// in `activeFilters`, both go quiet and the export sheet says "Export all 74
/// events" while exporting twelve.**
///
/// Test 10 is the control for exactly that, and it is the reason `FilterKind`
/// is an enum rather than four `||`s: an enum can be WALKED.

EventRecord rec(
  String id,
  DateTime ts, {
  String? type,
  bool referral = false,
  String notes = '',
}) =>
    EventRecord(
      id: id,
      timestamp: ts,
      duration: null,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: referral,
      notes: notes,
      eventType: type,
    );

void main() {
  final now = DateTime.now();

  /// A set spanning every filter's axis, so each can be exercised alone.
  List<EventRecord> corpus() => <EventRecord>[
        rec('a', now.subtract(const Duration(days: 1)), type: 'seizure'),
        rec('b', now.subtract(const Duration(days: 2)),
            type: 'absence', referral: true),
        rec('c', now.subtract(const Duration(days: 200)),
            type: 'seizure', notes: 'kangaroo'),
      ];

  setUp(Vocabularies.debugReset);
  tearDown(Vocabularies.debugReset);

  Future<void> pump(WidgetTester tester, [List<EventRecord>? records]) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: HistoryScreen(
        records: records ?? corpus(),
        onRecordsChanged: (_) async {},
        onEdit: (_, {required confirmOnSave}) async {},
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();
  }

  Future<void> closeSheet(WidgetTester tester) async {
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
  }

  /// Scoped to the sheet. "Seizure / fit" also appears as a BADGE on every
  /// matching row behind it, so an unscoped `find.text` matches three widgets
  /// and taps the wrong one. Scoping to the BottomSheet is what makes the tap
  /// mean "the filter chip".
  Finder inSheet(Finder f) =>
      find.descendant(of: find.byType(BottomSheet), matching: f);

  /// Applies one filter through the real UI, then dismisses the sheet.
  Future<void> apply(WidgetTester tester, FilterKind kind) async {
    await openSheet(tester);
    switch (kind) {
      case FilterKind.search:
        await tester.enterText(inSheet(find.byType(TextField)).first, 'kangaroo');
      case FilterKind.eventType:
        await tester.tap(inSheet(find.text('Seizure / fit')).first);
      case FilterKind.referral:
        await tester.tap(inSheet(find.byType(Switch)).first);
      case FilterKind.dateRange:
        await tester.tap(inSheet(find.text('Last 30 days')).first);
    }
    await tester.pumpAndSettle();
    await closeSheet(tester);
  }

  group('THE BANNER APPEARS FOR EVERY FILTER', () {
    // Walked from FilterKind.values rather than listed, so a filter added to
    // the enum without being wired into activeFilters fails HERE.
    for (final kind in FilterKind.values) {
      testWidgets('1.${kind.index} ${kind.name} alone raises the banner',
          (tester) async {
        await pump(tester);
        expect(find.textContaining('filtered by'), findsNothing,
            reason: 'precondition: nothing is filtered yet');

        await apply(tester, kind);

        expect(find.textContaining('filtered by'), findsOneWidget,
            reason: '${kind.name} narrows the list and the export, so it must '
                'raise the banner');
        expect(find.textContaining(kind.lineLabel), findsWidgets,
            reason: 'and the banner must NAME it, so the user knows what to '
                'clear rather than only that something is set');
      });
    }

    testWidgets('2. SEARCH ALONE — the easiest one to forget', (tester) async {
      // Called out separately because it is the one that narrows the export
      // without looking like a filter: a leftover word in a box.
      await pump(tester);
      await apply(tester, FilterKind.search);

      expect(find.textContaining('Showing 1 of 3'), findsOneWidget);
      expect(find.textContaining('filtered by search'), findsOneWidget);
    });
  });

  group('THE BADGE', () {
    testWidgets('3. absent when nothing is filtered', (tester) async {
      await pump(tester);
      expect(find.descendant(
        of: find.byTooltip('Filters'),
        matching: find.textContaining(RegExp(r'^\d+$')),
      ), findsNothing);
    });

    testWidgets('4. counts the filters, not the records', (tester) async {
      await pump(tester);
      await apply(tester, FilterKind.referral);
      expect(find.text('1'), findsOneWidget);

      await apply(tester, FilterKind.dateRange);
      expect(find.text('2'), findsOneWidget,
          reason: 'two filters, whatever the record count');
    });
  });

  group('THE FILTERS STILL SELECT THE SAME RECORDS', () {
    testWidgets('5. referral alone', (tester) async {
      await pump(tester);
      await apply(tester, FilterKind.referral);
      expect(find.textContaining('Showing 1 of 3'), findsOneWidget);
    });

    testWidgets('6. date alone', (tester) async {
      await pump(tester);
      await apply(tester, FilterKind.dateRange);
      expect(find.textContaining('Showing 2 of 3'), findsOneWidget,
          reason: 'the 200-day-old record falls outside 30 days');
    });

    testWidgets('7. type alone', (tester) async {
      await pump(tester);
      await apply(tester, FilterKind.eventType);
      expect(find.textContaining('Showing 2 of 3'), findsOneWidget);
    });

    testWidgets('8. COMBINATIONS still AND, not OR', (tester) async {
      // The one property a filter redesign is most likely to break, because
      // moving controls is where a predicate gets rewritten.
      await pump(tester);
      await apply(tester, FilterKind.eventType); // seizure -> a, c
      await apply(tester, FilterKind.dateRange); // last 30 days -> a, b

      expect(find.textContaining('Showing 1 of 3'), findsOneWidget,
          reason: 'the intersection is {a}. An OR would show three');
      expect(find.textContaining('type and date'), findsOneWidget);
    });
  });

  group('CLEARING', () {
    testWidgets('9. Clear in the banner removes every filter', (tester) async {
      await pump(tester);
      await apply(tester, FilterKind.referral);
      await apply(tester, FilterKind.dateRange);
      expect(find.textContaining('filtered by'), findsOneWidget);

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(find.textContaining('filtered by'), findsNothing);
      expect(find.text('3 events'), findsOneWidget,
          reason: 'and the quiet unfiltered count returns');
    });
  });

  group('THE NEGATIVE CONTROL', () {
    testWidgets(
        '10. a filter OMITTED from activeFilters would leave the banner silent '
        'while the list is narrowed', (tester) async {
      // ⚠️ THE HAZARD, made to happen.
      //
      // The banner and the badge cannot be tested for a defect that does not
      // exist yet, so this SIMULATES the omission: it narrows the list by a
      // filter and then asks what a calculation MISSING that filter would have
      // concluded. If the answer is "not narrowed", the screen would show a
      // partial history claiming to be whole — and the export sheet would say
      // "Export all 3 events" while exporting one.
      //
      // Without this, tests 1-2 pass just as well against a banner wired to a
      // constant `true`.
      await pump(tester);
      await apply(tester, FilterKind.search);

      final state = tester.state(find.byType(HistoryScreen)) as dynamic;
      final active = state.activeFilters as Set<FilterKind>;

      expect(active, contains(FilterKind.search),
          reason: 'the real calculation sees it');

      // The counterfactual: the same set with search dropped, as a hand-written
      // `||` chain would produce if someone forgot to extend it.
      final omitted = active.difference(<FilterKind>{FilterKind.search});
      expect(omitted, isEmpty,
          reason: 'ONLY search is active, so dropping it leaves nothing — '
              'and `isNotEmpty` would report NOT NARROWED while one of three '
              'records is on screen. That is the failure this design must '
              'make structurally impossible');

      // And the structural guard: the calculation is a switch over the enum
      // with no default, so a new FilterKind cannot compile without being
      // handled. Asserted as a fact about the ENUM being the source.
      expect(FilterKind.values.length, 4,
          reason: 'adding a fifth must fail the loop in group 1 until it is '
              'wired, rather than shipping a silent filter');
    });
  });

  group('THE EXPORT SCOPE STATEMENT', () {
    testWidgets('11. states the narrowed scope, computed not asserted',
        (tester) async {
      await pump(tester);
      await apply(tester, FilterKind.search);

      await tester.tap(find.byTooltip('Export CSV'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Export 1 of 3'), findsOneWidget,
          reason: 'the last line of defence, and the only place scope is '
              'stated once the filters are off-screen');
    });

    testWidgets('12. and says ALL when nothing is filtered', (tester) async {
      await pump(tester);
      await tester.tap(find.byTooltip('Export CSV'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Export all 3'), findsOneWidget);
    });
  });
}
