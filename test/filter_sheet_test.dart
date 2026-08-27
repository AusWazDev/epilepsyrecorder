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

/// [complete] controls whether the record satisfies [isIncomplete].
///
/// The corpus needs a MIX, or the "needs details" filter cannot be shown to
/// narrow anything — and a filter test where the filter excludes nothing
/// proves nothing.
EventRecord rec(
  String id,
  DateTime ts, {
  String? type,
  bool referral = false,
  String notes = '',
  bool complete = true,
}) =>
    EventRecord(
      id: id,
      timestamp: ts,
      duration: null,
      durationSeconds: complete ? 90 : null,
      severity: complete ? EventSeverity.mild : null,
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
        // The only INCOMPLETE one: no duration, no severity.
        rec('c', now.subtract(const Duration(days: 200)),
            type: 'seizure', notes: 'kangaroo', complete: false),
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

  /// The badge's text, or null when there is no badge.
  ///
  /// Scoped to the AppBar: a bare `find.text('1')` would also match a row's
  /// content. The badge is a SIBLING of the IconButton inside a Stack, not a
  /// descendant of it, so the tooltip cannot be the anchor.
  String? badge() {
    final f = find.descendant(
      of: find.byType(AppBar),
      matching: find.textContaining(RegExp(r'^\d+$')),
    );
    if (f.evaluate().isEmpty) return null;
    return (f.evaluate().first.widget as Text).data;
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
      case FilterKind.incomplete:
        await tester.tap(inSheet(find.text('Needs details')).first);
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

        // ⚠️ AND THE BADGE, for the SAME kind, in the same test.
        //
        // Two consumers of `activeFilters`, and the badge is the one a user
        // looks at FIRST — it is beside the export button they are about to
        // press. A filter counted by the banner but not the badge would leave
        // the AppBar reading "nothing is filtered" at the exact moment someone
        // exports a partial file.
        //
        // SEARCH is the case that makes this necessary rather than tidy: it is
        // the filter most easily left on by accident, and the one whose
        // inclusion in a "filter count" is most arguable. It is included.
        expect(badge(), '1',
            reason: 'the badge must count ${kind.name} too — one filter is on');
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
      expect(badge(), '2',
          reason: 'two filters, whatever the record count');

      // Three, INCLUDING SEARCH. The badge is what a user reads beside the
      // export button, so search being absent from it would be a hole at the
      // place they look first.
      await apply(tester, FilterKind.search);
      expect(badge(), '3');
    });

    testWidgets('4a. SEARCH ALONE raises the badge, not just the banner',
        (tester) async {
      await pump(tester);
      expect(badge(), isNull, reason: 'precondition');

      await apply(tester, FilterKind.search);

      expect(badge(), '1',
          reason: 'a leftover word in a search box narrows the EXPORT, so the '
              'AppBar must not read as unfiltered');
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

    testWidgets('6a. NEEDS DETAILS alone', (tester) async {
      await pump(tester);
      await apply(tester, FilterKind.incomplete);
      expect(find.textContaining('Showing 1 of 3'), findsOneWidget,
          reason: 'only c has a duration and a severity unset');
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
      // ⚠️ THIS NUMBER MOVED, and that is the assertion doing its job rather
      // than being brittle. A fifth kind — `incomplete` — was added, the
      // generated loop in group 1 grew a case, the `apply` switch below
      // stopped compiling until it was handled, and this line failed until it
      // was updated. Four separate places refused to stay silent.
      //
      // Update it when a kind is added. Do NOT relax it to `greaterThan`: the
      // point is that adding one is a deliberate act with a visible cost.
      expect(FilterKind.values.length, 5,
          reason: 'adding a sixth must fail the loop in group 1 until it is '
              'wired, rather than shipping a silent filter');
    });

    testWidgets(
        '10a. THE SAME OMISSION AT THE BADGE — the place a user looks FIRST',
        (tester) async {
      // The line's control asks what a calculation missing a filter would
      // CONCLUDE. This one asks what it would COUNT, because the badge is a
      // different consumer with a different failure: the banner going quiet
      // hides the reason, the badge going quiet hides that there is one at all
      // — and the badge sits beside the export button.
      //
      // SEARCH is the subject deliberately. It is the filter most easily left
      // on by accident and the one whose membership in a "filter count" is
      // most arguable, so it is the one an implementer would be most tempted
      // to leave out.
      await pump(tester);
      await apply(tester, FilterKind.search);

      expect(badge(), '1', reason: 'the real count includes search');
      expect(find.textContaining('Showing 1 of 3'), findsOneWidget,
          reason: 'and the list IS narrowed — one of three records');

      final state = tester.state(find.byType(HistoryScreen)) as dynamic;
      final active = state.activeFilters as Set<FilterKind>;

      // The counterfactual: the count a version that excluded search would
      // render. Zero is not "no badge with a zero in it" — the badge is hidden
      // when the count is zero, so the AppBar would read exactly as it does
      // with nothing filtered.
      final omitted = active.difference(<FilterKind>{FilterKind.search}).length;
      expect(omitted, 0,
          reason: 'a badge computed without search would show NOTHING beside '
              'the export button while a filtered set is what gets exported. '
              'That is the hazard §2 exists to prevent, at the place a user '
              'looks first');
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

    testWidgets('12a. the NOUN agrees with the total, not the shown count',
        (tester) async {
      // "Export 1 of 3 event" - the singular landed beside the plural number,
      // because the noun was computed from `shown` while both strings place it
      // after `total`.
      //
      // ⚠️ THE DISCRIMINATING CASE, chosen deliberately: shown == 1 while
      // total > 1 is the ONLY state where the two rules disagree. A test taken
      // at any other count passes against both and would have shipped the
      // defect. It is also not a rare state - the "Needs details" queue ENDS at
      // one as it is worked down, so the last export before it empties is the
      // broken reading.
      await pump(tester);
      await apply(tester, FilterKind.search);

      await tester.tap(find.byTooltip('Export CSV'));
      await tester.pumpAndSettle();

      expect(find.text('Export 1 of 3 events'), findsOneWidget);
      expect(find.text('Export 1 of 3 event'), findsNothing,
          reason: 'what agreeing with `shown` produced');
    });

    testWidgets('12b. POSITIVE CONTROL: the singular is still reachable',
        (tester) async {
      // 12a passes just as well against "always plural", which would be a
      // different defect wearing the same result. One record, unfiltered: the
      // noun must go back to the singular.
      await pump(tester, <EventRecord>[
        rec('solo', now.subtract(const Duration(days: 1)), type: 'seizure'),
      ]);

      await tester.tap(find.byTooltip('Export CSV'));
      await tester.pumpAndSettle();

      expect(find.text('Export all 1 event'), findsOneWidget);
      expect(find.textContaining('1 events'), findsNothing);
    });

    testWidgets('13. and the FILENAME agrees with it', (tester) async {
      // Tests 11 and 12 pin what the sheet SAYS. Nobody reads the sheet again
      // afterwards — the file outlives it, and once it is attached to an email
      // the filename is the only surviving statement of scope.
      //
      // So the two must not be able to disagree. A file called `_all_` holding
      // a filtered set is worse than no statement at all: it is a positive
      // assertion of completeness over an incomplete export, and it is the
      // exact failure the sheet header was added to prevent, displaced one
      // artefact downstream.
      //
      // ⚠️ NEWLY WORTH PINNING because the filename now carries the shape
      // marker too. Both halves are built by `csvFilename` from a prefix this
      // screen chooses, and the scope half had no test.
      //
      // The narrowed-ness is READ FROM THE LIVE SCREEN and fed to the SHIPPED
      // mapping. Restating the two strings here would agree with the source by
      // construction and pass through the very change this is meant to catch.
      await pump(tester);
      final unfiltered = exportFilenamePrefix(narrowed: narrowedNow(tester));
      expect(find.textContaining('Export all 3'), findsNothing,
          reason: 'precondition: the sheet is not open, so the screen state is '
              'what is being read');

      await apply(tester, FilterKind.search);
      final filtered = exportFilenamePrefix(narrowed: narrowedNow(tester));

      expect(find.textContaining('Showing 1 of 3'), findsOneWidget,
          reason: 'positive control: the list really is narrowed, so the two '
              'prefixes were taken from genuinely different states');

      expect(unfiltered, endsWith('_all'));
      expect(filtered, endsWith('_filtered'));
      expect(unfiltered, isNot(filtered),
          reason: 'the counterfactual: one prefix for both cases would name '
              'every file `_all_`, and the claim would be false exactly when '
              'it mattered');

      // And the name a user actually receives, end to end — scope and shape in
      // one string, from the two functions that build it.
      expect(
          csvFilename(prefix: filtered, when: DateTime(2026, 8, 26, 23, 9, 17)),
          'medical_event_recorder_filtered_20260826_230917.'
          '$kCsvShapeVersion.csv');
    });
  });
}

/// Whether the live History screen considers itself narrowed.
///
/// Reads `activeFilters` — the same set the screen's own `_isNarrowed` reads —
/// so the test observes the screen's state rather than deciding it.
bool narrowedNow(WidgetTester tester) {
  final state = tester.state(find.byType(HistoryScreen)) as dynamic;
  return (state.activeFilters as Set<FilterKind>).isNotEmpty;
}
