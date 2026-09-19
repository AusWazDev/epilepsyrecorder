import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/history_screen.dart';

/// *Show hidden*, the count pair, and the four scope statements.
///
/// ⛔ **NOTHING HERE SETS THE FLAG THROUGH THE UI, BECAUSE NOTHING CAN.** There
/// is no hide control yet — Decision 7's condition is that the reveal ships
/// BEFORE the control, so hiding stays settable only from a fixture. Every
/// hidden record below is constructed hidden.
///
/// ## ⭐ WHY THE BANNER AND THE SHEET MUST **NOT** AGREE
///
/// They answer different questions and each denominator belongs to a different
/// control:
///
/// | | denominator | because |
/// |---|---|---|
/// | banner | the population in scope | it is a CLEARABILITY claim — its numbers must describe what the clear control returns you to, and clearing never reaches the hidden set |
/// | sheet title + filename | the complete set | it is a COMPLETENESS claim about a file that leaves the app |
///
/// A reader who finds *Showing 3 of 15* above *Export 3 of 20 events* is
/// looking at two true statements about two different things.

EventRecord rec(
  String id,
  DateTime ts, {
  String? type,
  bool referral = false,
  String notes = '',
  bool hidden = false,
}) =>
    EventRecord(
      id: id,
      timestamp: ts,
      duration: null,
      durationSeconds: 90,
      severity: EventSeverity.mild,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: referral,
      notes: notes,
      eventType: type,
      hidden: hidden,
    );

void main() {
  final now = DateTime.now();

  /// Four records: three visible, one hidden. Exactly one carries the search
  /// term, so a search narrows to one and the arithmetic is unambiguous.
  List<EventRecord> corpus() => <EventRecord>[
        rec('a', now.subtract(const Duration(days: 1)), type: 'seizure'),
        rec('b', now.subtract(const Duration(days: 2)),
            type: 'absence', referral: true, notes: 'kangaroo'),
        rec('c', now.subtract(const Duration(days: 3)), type: 'seizure'),
        rec('HIDDEN', now.subtract(const Duration(days: 4)),
            type: 'seizure', hidden: true),
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

  Finder inSheet(Finder f) =>
      find.descendant(of: find.byType(BottomSheet), matching: f);

  Future<void> toggleShowHidden(WidgetTester tester) async {
    await openSheet(tester);
    // ⛔ RETARGETED 18 September 2026. The `Show hidden` SwitchListTile
    // became a three-way control (Hide / Include / Only), because a
    // switch could not express "show me ONLY what I have hidden" —
    // the recovery case. `Include` is the exact equivalent of the old
    // switch in its ON state, so every assertion below is unchanged.
    await tester.tap(inSheet(find.text('Include')).first);
    await tester.pumpAndSettle();
    await closeSheet(tester);
  }

  Future<void> applySearch(WidgetTester tester) async {
    await openSheet(tester);
    await tester.enterText(
        inSheet(find.byType(TextField)).first, 'kangaroo');
    await tester.pumpAndSettle();
    await closeSheet(tester);
  }

  String? badge(WidgetTester tester) {
    final f = find.descendant(
      of: find.byType(AppBar),
      matching: find.textContaining(RegExp(r'^\d+$')),
    );
    if (f.evaluate().isEmpty) return null;
    return (f.evaluate().first.widget as Text).data;
  }

  /// The live screen's own export scope — read, never restated.
  ExportScope scopeNow(WidgetTester tester) {
    final state = tester.state(find.byType(HistoryScreen)) as dynamic;
    return state.exportScope as ExportScope;
  }

  /// The applied-filters banner's sentence, as rendered.
  String? bannerText(WidgetTester tester) {
    final f = find.textContaining('Showing ');
    if (f.evaluate().isEmpty) return null;
    return (f.evaluate().first.widget as Text).data;
  }

  group('1. THE REASON STRING — all four combinations', () {
    // ⛔ THE SITE WHERE THE CATEGORY ERROR WOULD APPEAR. `activeFilters` is one
    // set answering "what can I clear"; this sentence answers "what did I do".
    // A widening toggle folded into the narrowing list would tell the user they
    // narrowed by something that widened.

    testWidgets('1a. no adjustments — the banner is ABSENT', (tester) async {
      await pump(tester);
      expect(bannerText(tester), isNull,
          reason: 'its PRESENCE is the signal; a permanent strip reading '
              '"no filters" is chrome, and chrome gets skimmed');
      expect(badge(tester), isNull);
    });

    testWidgets('1b. narrowing only — "filtered by search"', (tester) async {
      await pump(tester);
      await applySearch(tester);
      expect(bannerText(tester), 'Showing 1 of 3 — filtered by search');
    });

    testWidgets('1c. widening only — no "filtered by" clause at all',
        (tester) async {
      await pump(tester);
      await toggleShowHidden(tester);
      expect(bannerText(tester), 'Showing 4 of 4 — hidden shown');
      expect(bannerText(tester), isNot(contains('filtered by')),
          reason: 'the whole of Decision 8: a widening toggle must not be '
              'described as something the user filtered BY');
    });

    testWidgets('1d. both — the separator form', (tester) async {
      await pump(tester);
      await applySearch(tester);
      await toggleShowHidden(tester);
      expect(bannerText(tester),
          'Showing 1 of 4 — filtered by search · hidden shown');
    });
  });

  group('2. THE COUNT PAIR — filename and sheet title cannot disagree', () {
    // ⛔ ONE PAIR, TWO CONSUMERS. Until this change each derived the claim
    // separately — the title from a count comparison, the filename from
    // `activeFilters` — and they had a live divergence: with records hidden
    // and no filter set, the filename said `_all` over a file that omitted
    // them.
    //
    // Each case reads the SHIPPED mapping from the LIVE screen. Restating the
    // strings here would agree with the source by construction and pass
    // through the very change this is meant to catch.

    Future<void> expectAgreement(
      WidgetTester tester, {
      required String title,
      required String suffix,
    }) async {
      final scope = scopeNow(tester);
      await tester.tap(find.byTooltip('Export CSV'));
      await tester.pumpAndSettle();

      expect(find.text(title), findsOneWidget,
          reason: 'the sheet title states the completeness claim');
      expect(exportFilenamePrefix(scope), endsWith(suffix),
          reason: 'and the filename must make the SAME claim — it is the half '
              'that survives after the sheet is gone');

      tester.state<NavigatorState>(find.byType(Navigator).first).pop();
      await tester.pumpAndSettle();
    }

    testWidgets('2a. HIDDEN ONLY — incomplete, and this is the case that was '
        'wrong before', (tester) async {
      // No filter is set, so the old `activeFilters` derivation called this
      // complete and named the file `_all` while omitting a record.
      await pump(tester);
      expect(badge(tester), isNull, reason: 'precondition: no adjustment');
      await expectAgreement(tester,
          title: 'Export 3 of 4 events', suffix: '_filtered');
    });

    testWidgets('2b. FILTERS ONLY — incomplete', (tester) async {
      await pump(tester);
      await applySearch(tester);
      await expectAgreement(tester,
          title: 'Export 1 of 4 events', suffix: '_filtered');
    });

    testWidgets('2c. SHOW HIDDEN ONLY — COMPLETE, though an adjustment is on',
        (tester) async {
      // The other direction: `activeFilters` is non-empty, and the export IS
      // complete. A `narrowed` flag would have named this `_filtered`.
      await pump(tester);
      await toggleShowHidden(tester);
      await expectAgreement(tester,
          title: 'Export all 4 events', suffix: '_all');
    });

    testWidgets('2d. BOTH — incomplete', (tester) async {
      await pump(tester);
      await applySearch(tester);
      await toggleShowHidden(tester);
      await expectAgreement(tester,
          title: 'Export 1 of 4 events', suffix: '_filtered');
    });
  });

  group('2e. THE PAIR ITSELF — the two statements over the same input', () {
    // The widget tests above prove the screen's numbers are right. These two
    // prove the CONSOLIDATION: that there is one derivation rather than two
    // that currently agree.

    test('the filename, the title and the HEADER never disagree', () {
      // Exhaustive over a small grid rather than three chosen cases, so a
      // boundary cannot be the one that was not tried.
      var complete = 0, partial = 0;
      for (var total = 0; total <= 6; total++) {
        for (var willExport = 0; willExport <= total; willExport++) {
          final scope =
              ExportScope(willExport: willExport, total: total);
          final saysAll = exportSheetTitle(scope).startsWith('Export all');
          final namedAll = exportFilenamePrefix(scope).endsWith('_all');

          // ⛔ THE THIRD CONSUMER, ADDED 19 September 2026. The list header
          // joined this pair when it stopped reading `shown.length` alone, so
          // it joins the agreement too — otherwise the doc comment on
          // ExportScope claims three consumers cannot disagree while only two
          // are held to it, which is a compliance asserted and never achieved.
          //
          // ⭐ The header says "all" by saying ONLY the total — no "of" clause
          // — so completeness is the absence of the pair rather than a word.
          final headerAll = !listCountLabel(scope).contains(' of ');
          expect(headerAll, namedAll,
              reason: 'willExport=$willExport total=$total — the list header '
                  'and the filename made different claims about the same '
                  'population. The header is what the user reads before '
                  'deciding whether an export is worth taking');

          expect(saysAll, namedAll,
              reason: 'willExport=$willExport total=$total — the title and '
                  'the filename made different claims about the same file. '
                  'The filename is the half that survives after the sheet is '
                  'gone, so a disagreement is a false completeness claim on '
                  'the artefact that outlives the correction');
          if (saysAll) { complete++; } else { partial++; }
        }
      }
      // Positive controls on the grid: both branches were actually reached, or
      // the loop above proves nothing about the one that was not.
      expect(complete, greaterThan(0), reason: 'positive control: complete');
      expect(partial, greaterThan(0), reason: 'positive control: partial');
    });

    test('the screen feeds BOTH from ONE scope, read once', () {
      // ⛔ THE BEHAVIOURAL TESTS CANNOT SEE THIS. The export sheet does not
      // render the filename, so nothing in the widget tree can observe what
      // the call site passed. A second derivation at the call site would leave
      // every test above green.
      //
      // So this reads the source, the way this project's Swift-scan guards do.
      // Brittle to reformatting and worth it: the alternative is an invariant
      // with no assertion behind it.
      final src =
          File('lib/screens/history_screen.dart').readAsStringSync();

      expect(src, contains('final scope = exportScope;'),
          reason: 'positive control: the call site reads the pair once');
      expect(src, contains('filenamePrefix: exportFilenamePrefix(scope),'),
          reason: 'the filename must take THAT scope, not its own derivation');
      expect(src, contains('sheetTitle: exportSheetTitle(scope),'),
          reason: 'and so must the title');
      // ⛔ RAISED 2 -> 3, 19 September 2026, AND THE REASON MATTERS MORE THAN
      // THE NUMBER. This guard FIRED when the list header started reading the
      // pair, which is exactly what it is for — a new read site cannot appear
      // silently. It is raised because the third occurrence was ADJUDICATED as
      // a legitimate consumer, not because the assertion was inconvenient.
      //
      // ⭐ The three: the getter declaration, the export call site, and the
      // list header. Any FOURTH is a second derivation appearing and must be
      // adjudicated the same way rather than absorbed by bumping this again.
      expect('exportScope'.allMatches(src).length, 3,
          reason: 'the getter declaration, the export call site, and the list '
              'header. A fourth occurrence is a second derivation appearing');
      expect(src, contains('listCountLabel(exportScope)'),
          reason: 'and the header is the third consumer, reading the same pair '
              'rather than counting the visible list itself');
    });
  });

  group('3. CLEAR-ALL RESTORES THE DEFAULT', () {
    // ⛔ THE INERT-CONTROL DEFECT, GUARDED. The proposal this replaced would
    // have put HIDING into `activeFilters`, producing a Clear control that
    // offered to clear something it could not clear. Revealing is clearable —
    // but only if the reset actually resets it.

    testWidgets('3a. the banner Clear returns to hidden-hidden',
        (tester) async {
      await pump(tester);
      await applySearch(tester);
      await toggleShowHidden(tester);
      expect(badge(tester), '2', reason: 'precondition: two adjustments');
      expect(bannerText(tester), contains('hidden shown'));

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(badge(tester), isNull, reason: 'every adjustment cleared');
      expect(bannerText(tester), isNull, reason: 'and the banner with them');
      expect(scopeNow(tester).willExport, 3,
          reason: 'the DEFAULT is hidden-hidden: back to three of four. A '
              'reset that cleared the filters but left Show hidden on would '
              'leave this at 4 and the control would have lied');
    });

    testWidgets('3b. the SHEET\'s Clear all does the same reset',
        (tester) async {
      // Two reset sites, and they must not drift. The sheet's is an inline
      // block rather than a call to _clearFilters.
      await pump(tester);
      await toggleShowHidden(tester);
      expect(scopeNow(tester).willExport, 4, reason: 'precondition: revealed');

      await openSheet(tester);
      await tester.tap(inSheet(find.text('Clear all')).first);
      await tester.pumpAndSettle();
      await closeSheet(tester);

      expect(scopeNow(tester).willExport, 3,
          reason: 'the sheet reset must clear Show hidden too, or the two '
              'reset sites disagree about what the default is');
      expect(badge(tester), isNull);
    });
  });

  group('4. THE EMPTY STATE — all four branches', () {
    testWidgets('4a. no records at all — unchanged', (tester) async {
      await pump(tester, <EventRecord>[]);
      expect(find.textContaining('No events yet.'), findsOneWidget);
      expect(find.textContaining('hidden'), findsNothing,
          reason: 'nothing has been hidden, so nothing may claim it has');
    });

    testWidgets('4b. filters set, nothing matches — unchanged', (tester) async {
      // Every record visible, so the hidden clause must not appear.
      await pump(tester, <EventRecord>[
        rec('a', now.subtract(const Duration(days: 1)), type: 'seizure'),
      ]);
      await applySearch(tester);
      expect(find.textContaining('No events match your search'), findsOneWidget);
      expect(find.textContaining('hidden'), findsNothing);
    });

    testWidgets('4c. no filters, everything hidden — names the state',
        (tester) async {
      // ⛔ THE ROW THAT MATTERS. Without it this screen is indistinguishable
      // from a fresh install, which is the Help screen's Windows-section
      // failure exactly.
      await pump(tester, <EventRecord>[
        rec('h1', now.subtract(const Duration(days: 1)), hidden: true),
        rec('h2', now.subtract(const Duration(days: 2)), hidden: true),
      ]);
      expect(find.textContaining('No events to show.'), findsOneWidget);
      expect(find.textContaining('2 events hidden.'), findsOneWidget);
      expect(find.textContaining('No events yet.'), findsNothing,
          reason: 'a user with everything hidden must NOT see the '
              'fresh-install message — that is the whole finding');
    });

    testWidgets('4d. MIXED — the filters message wins, with the count appended',
        (tester) async {
      await pump(tester, <EventRecord>[
        rec('a', now.subtract(const Duration(days: 1)), type: 'seizure'),
        rec('h1', now.subtract(const Duration(days: 2)), hidden: true),
      ]);
      await applySearch(tester);

      expect(find.textContaining('No events match your search'), findsOneWidget,
          reason: 'filters are what the user SET and can CLEAR, so they lead');
      expect(find.textContaining('1 event hidden.'), findsOneWidget,
          reason: 'and the hidden count is appended, singular for one');
      expect(find.textContaining('No events to show.'), findsNothing,
          reason: 'the filters message WINS; it does not appear beside the '
              'no-filters one');
    });

    testWidgets('4e. Show hidden ON suppresses the hidden clause',
        (tester) async {
      // Records are still FLAGGED hidden, but nothing is being withheld, so
      // "1 event hidden" beside a visible row would be false.
      await pump(tester, <EventRecord>[
        rec('a', now.subtract(const Duration(days: 1)), type: 'seizure'),
        rec('h1', now.subtract(const Duration(days: 2)), hidden: true),
      ]);
      await toggleShowHidden(tester);
      await applySearch(tester);

      expect(find.textContaining('No events match your search'), findsOneWidget);
      expect(find.textContaining('hidden.'), findsNothing,
          reason: 'nothing is being withheld while the toggle is on');
    });
  });

  group('5. THE BADGE — what it actually renders', () {
    // Reported because the escape clause turns on how this READS, not on
    // whether it counts correctly.
    testWidgets('5a. Show hidden alone renders "1"', (tester) async {
      await pump(tester);
      await toggleShowHidden(tester);
      expect(badge(tester), '1',
          reason: 'the badge counts ADJUSTMENTS the user can clear, and this '
              'is one of them');
    });

    testWidgets('5b. and the banner beside it says what the 1 IS',
        (tester) async {
      // The badge is a bare number; the banner is where it is disambiguated.
      await pump(tester);
      await toggleShowHidden(tester);
      expect(badge(tester), '1');
      expect(bannerText(tester), 'Showing 4 of 4 — hidden shown',
          reason: 'the count and its cause are readable together, which is '
              'what keeps a bare "1" from meaning two things');
    });
  });
}
