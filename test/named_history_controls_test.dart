import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/history_screen.dart';

import 'semantics_names.dart';

/// AUDIT.md §13(z), controls 2 and 3 of 5 — history's clear-search and its
/// per-row delete announced nothing. Both are on one screen, so one file.
///
/// ⭐ "Delete this event" rather than medication's bare "Delete", because this
/// one repeats per row. Measured: the row's own content IS the semantics node
/// immediately BEFORE the button in traversal order, so forward navigation
/// supplies context — but control-only navigation skips it.
///
/// ⛔ AND IT IS DELIBERATELY NOT DYNAMIC. A tooltip is VISIBLE on hover and
/// long-press, so 'Delete ${time}' would surface record data into a
/// newly-visible element. §13(ad) also shows seven byte-identical rows, so a
/// timestamp would not disambiguate. Which-record identification stays UNSOLVED.

List<EventRecord> rows() => List.generate(
      3,
      (i) => EventRecord(
        id: 'r$i',
        timestamp: DateTime(2026, 8, 20, 3, 1 + i),
        duration: DurationCategory.lt1,
        durationSeconds: 40,
        eventType: 'seizure',
        severity: EventSeverity.mild,
        feelings: const <String>[],
        triggers: const <String>[],
        referralRequired: false,
        notes: '',
        detailsCompleted: true,
      ),
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'disclaimerAcceptedVersion': kDisclaimerVersion,
      kWalkthroughSeenVersionKey: kWalkthroughVersion,
    });
    StorageBoot.debugSet();
    Vocabularies.debugReset();
  });
  tearDown(() {
    StorageBoot.debugSet();
    Vocabularies.debugReset();
  });

  testWidgets('history delete and clear-search announce, and nothing moved',
      (tester) async {
    final handle = tester.ensureSemantics();
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(430, 1200);

    await tester.pumpWidget(MaterialApp(
      home: HistoryScreen(
        records: rows(),
        onRecordsChanged: (_) async {},
        onEdit: (_, {required confirmOnSave}) async {},
      ),
    ));
    await tester.pumpAndSettle();

    final deleteNamed = announcedNames(tester).contains('Delete this event');
    expect(deleteNamed, isTrue,
        reason: 'the per-row delete is the one irreversible control in the app '
            'and must announce a name');

    // ⛔ BASELINE FROM UNPATCHED CODE. Three rows, three delete icons.
    expect(
        iconRects(tester, const [Icons.delete_outline]),
        <String>[
          '356.0,152.0 24.0x24.0',
          '356.0,225.0 24.0x24.0',
          '356.0,298.0 24.0x24.0',
        ],
        reason: 'adding a tooltip must not move a delete icon');

    // ⛔ THE SEARCH FIELD IS INSIDE THE FILTER BOTTOM SHEET, not the app bar. A
    // first version typed into `find.byType(TextField)` on the bare screen and
    // found none, so the clear-search control was unreachable.
    expect(find.byTooltip('Filters'), findsOneWidget,
        reason: 'the filter sheet is opened from the Filters action');
    await tester.tap(find.byTooltip('Filters'));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsWidgets,
        reason: 'the filter sheet must carry the search field');
    await tester.enterText(find.byType(TextField).first, 'seiz');
    await tester.pumpAndSettle();

    final names = announcedNames(tester);
    // ⚠️ The delete result is the one captured BEFORE the sheet was opened.
    // Reading it here would report false, because the open sheet covers the
    // rows and their icons leave the tree — a misleading print, not a defect.
    // A first version did exactly that and printed "false" for a control whose
    // assertion had already passed.
    // ignore: avoid_print
    print('  history: "Delete this event"=$deleteNamed'
        '  "Clear search"=${names.contains('Clear search')}');
    expect(names, contains('Clear search'),
        reason: 'the clear-search button must announce what it clears');

    handle.dispose();
  });
}
