import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/history_screen.dart';

/// History search matches what a user can SEE, never an internal identifier.
///
/// ## Why this needs a test rather than a reading
///
/// The haystack is assembled from nine expressions, and whether any of them
/// leaks an identifier depends on what each helper returns in its FALLBACK
/// path — which is not visible at the call site. Reading it gives an opinion;
/// searching a real screen gives an answer.
///
/// ## The discriminating probe, and why the obvious ones prove nothing
///
/// Most identifiers in this app are SUBSTRINGS of their own labels, so a
/// search for them matches either way and settles nothing:
///
///     seizure   -> "Seizure / fit"      contains "seizure"
///     mild      -> "Mild"               contains "mild"
///     medication-> "Medication taken"   contains "medication"
///     other     -> "Other / custom"     contains "other"
///
/// Exactly two identifiers in the whole app do NOT appear in their label:
///
///     DurationCategory.lt1        -> "< 1 minute"
///     DurationCategory.oneToFive  -> "1-5 minutes"
///
/// So those two are the only probes that can tell a label-matching search from
/// a key-matching one, and they are what this file uses.

EventRecord rec(
  String id,
  DateTime ts, {
  DurationCategory? bucket,
  List<String> feelings = const <String>[],
  String notes = '',
}) =>
    EventRecord(
      id: id,
      timestamp: ts,
      duration: bucket,
      durationSeconds: null,
      eventType: 'seizure',
      severity: EventSeverity.mild,
      feelings: feelings,
      triggers: const <String>[],
      referralRequired: false,
      notes: notes,
    );

void main() {
  final now = DateTime.now();

  setUp(Vocabularies.debugReset);
  tearDown(Vocabularies.debugReset);

  List<EventRecord> corpus() => <EventRecord>[
        rec('a', now.subtract(const Duration(days: 1)),
            bucket: DurationCategory.lt1),
        rec('b', now.subtract(const Duration(days: 2)),
            bucket: DurationCategory.oneToFive),
        // A legacy observation: the glyph is INSIDE the stored value, and the
        // vocabulary resolves it to the plain label.
        rec('c', now.subtract(const Duration(days: 3)),
            feelings: const <String>['\u{1F635} Confused']),
        rec('d', now.subtract(const Duration(days: 4)),
            feelings: const <String>['Memory gap']),
      ];

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: HistoryScreen(
        records: corpus(),
        onRecordsChanged: (_) async {},
        onEdit: (_, {required confirmOnSave}) async {},
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// Runs a search and returns how many records survive it, READ FROM THE
  /// BANNER the user sees rather than from internal state.
  ///
  /// The banner is the screen's own statement of what it is showing, so a
  /// count taken from it cannot disagree with what is rendered - which is the
  /// property under test. Reaching into a private list would measure something
  /// adjacent to it.
  Future<int> search(WidgetTester tester, String q) async {
    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byType(BottomSheet), matching: find.byType(TextField)),
        q);
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();

    final banner = find.textContaining(RegExp(r'Showing \d+ of'));
    expect(banner, findsOneWidget,
        reason: 'a non-empty query always narrows, so the banner must be up');
    final text = (banner.evaluate().first.widget as Text).data!;
    return int.parse(
        RegExp(r'Showing (\d+) of').firstMatch(text)!.group(1)!);
  }

  group('SEARCH MATCHES LABELS, NOT KEYS', () {
    testWidgets('1. an enum key absent from its label finds NOTHING',
        (tester) async {
      // THE TEST THE BRIEF ASKS FOR. `lt1` is stored on record 'a' and is the
      // string a developer sees; the user only ever sees "< 1 minute".
      await pump(tester);
      expect(await search(tester, 'lt1'), 0);
    });

    testWidgets('2. and the other one', (tester) async {
      await pump(tester);
      expect(await search(tester, 'onetofive'), 0);
    });

    testWidgets('3. POSITIVE CONTROL: the LABEL for that same record matches',
        (tester) async {
      // Without this, tests 1 and 2 pass just as well against a search that is
      // simply broken. Same record, same field, the text a user can actually
      // read on screen.
      await pump(tester);
      expect(await search(tester, 'minute'), greaterThan(0),
          reason: 'the visible duration text must still find it');
    });

    testWidgets('4. an observation is found by its VISIBLE text',
        (tester) async {
      await pump(tester);
      expect(await search(tester, 'memory gap'), 1);
    });

    testWidgets('5. a LEGACY observation is found by its label, not its glyph',
        (tester) async {
      // The stored value is the glyph-bearing string; the label is plain. Both
      // are in the haystack deliberately - a user types a word, not a data
      // format - and the label is what they can see on the row.
      await pump(tester);
      expect(await search(tester, 'confused'), 1);
    });
  });
}
