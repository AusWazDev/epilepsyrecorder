import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/backup.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/history_screen.dart';

/// The hide control, its undo, and the confirmation that went with it.
///
/// ⛔ **DECISION 7's CONDITION IS WHAT MAKES THE DIALOG REMOVABLE.** The reveal
/// shipped at `a0cfc7f`, so hiding is reversible *in the product* and not only
/// in the database. Without *Show hidden* this would be deletion with a
/// four-second window, and a reversible-action argument applied to an
/// irreversible one is how a false safety claim reaches medical copy.
///
/// ## ⭐ WHY THE SNACKBAR IS NOT THE REVERSIBILITY GUARANTEE
///
/// It is the FAST path. The DURABLE one is *Show hidden*, which reaches the
/// record at any time from the filter sheet. That distinction is what keeps a
/// missed SnackBar from being data loss — and it is why the two mitigations
/// below are about the control not LYING rather than about the window being
/// long enough.
///
/// These assertions do not use the store: `onRecordsChanged` is captured and
/// inspected directly, so this file is free of the static-serialise-queue
/// constraint recorded in `hidden_survives_history_write_test`.

EventRecord rec(String id, int minute, {bool hidden = false}) => EventRecord(
      id: id,
      timestamp: DateTime(2026, 8, 20, 9, minute),
      duration: DurationCategory.lt1,
      durationSeconds: 90,
      feelings: const <String>['Tired'],
      triggers: const <String>['Stress'],
      referralRequired: true,
      notes: 'note $id',
      eventType: 'seizure',
      severity: EventSeverity.mild,
      detailsCompleted: true,
      rescueMedGiven: true,
      rescueMedHelped: RescueResponse.helped,
      rescueMedSecondDose: false,
      hidden: hidden,
    );

void main() {
  setUp(Vocabularies.debugReset);
  tearDown(Vocabularies.debugReset);

  /// The last list the screen handed out, which is the list that reaches
  /// `persistEvents` in the real app.
  late List<EventRecord> written;
  late int writeCount;

  Future<void> pump(WidgetTester tester, List<EventRecord> seed) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    written = List<EventRecord>.from(seed);
    writeCount = 0;

    await tester.pumpWidget(MaterialApp(
      home: HistoryScreen(
        records: seed,
        onRecordsChanged: (updated) async {
          written = List<EventRecord>.from(updated);
          writeCount++;
        },
        onEdit: (_, {required confirmOnSave}) async {},
      ),
    ));
    await tester.pumpAndSettle();
  }

  Finder hideButton() => find.byIcon(Icons.visibility_off_outlined);

  group('1. THE CONTROL — one tap, no dialog', () {
    testWidgets('1a. hiding shows NO dialog', (tester) async {
      await pump(tester, <EventRecord>[rec('a', 1), rec('b', 2)]);

      await tester.tap(hideButton().first);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing,
          reason: 'a reversible act does not earn a destructive dialog — C2\'s '
              'own test is whether the user came here to do this thing');
      expect(find.textContaining('cannot be undone'), findsNothing,
          reason: 'and that sentence is now FALSE, so it must not survive in '
              'any form');
    });

    testWidgets('1b. CONTROL: the apparatus would have seen a dialog',
        (tester) async {
      // ⛔ A NEGATIVE NEEDS A POSITIVE CONTROL. `findsNothing` above passes
      // just as well against a finder that can never match anything — a
      // renamed widget, a typo, a dialog rendered outside the tested tree.
      // This proves the same finder DOES see an AlertDialog in the same
      // harness, so 1a's silence is a fact about the app.
      await pump(tester, <EventRecord>[rec('a', 1)]);

      final ctx = tester.element(find.byType(HistoryScreen));
      showDialog<void>(
        context: ctx,
        builder: (_) => const AlertDialog(
          title: Text('Delete this event?'),
          content: Text('This action cannot be undone.'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget,
          reason: 'the finder is live');
      expect(find.textContaining('cannot be undone'), findsOneWidget,
          reason: 'and so is the text finder');
    });
  });

  group('2. HIDE WITHOUT UNDO', () {
    testWidgets('2a. the record leaves the VIEW and stays in the LIST',
        (tester) async {
      await pump(tester, <EventRecord>[rec('a', 1), rec('b', 2), rec('c', 3)]);
      expect(hideButton(), findsNWidgets(3), reason: 'precondition: three rows');

      await tester.tap(hideButton().first);
      await tester.pumpAndSettle();

      expect(hideButton(), findsNWidgets(2),
          reason: 'out of view: the derived view excludes it');

      // ⛔ AND STILL IN THE LIST THAT REACHES save(). A removal here is the
      // §13(cj) failure mode (a) shape — save is a full delete-and-reinsert,
      // so an omitted row is gone permanently and retention is FOREVER.
      expect(written, hasLength(3),
          reason: 'hiding removes nothing. If this is 2 the record was DELETED '
              'and the reversibility the confirmation was traded for does not '
              'exist');
      expect(written.where((r) => r.hidden).map((r) => r.id), <String>['a'],
          reason: 'exactly the one the user hid, and by flag rather than by '
              'absence');
    });

    testWidgets('2b. every other field survives the hide', (tester) async {
      // The hide rebuilds the record through `withHidden`, which lists every
      // field — the same hazard as the two drain paths. Whole-map comparison
      // minus the one key it exists to change.
      final before = rec('a', 1);
      await pump(tester, <EventRecord>[before, rec('b', 2)]);

      await tester.tap(hideButton().first);
      await tester.pumpAndSettle();

      final after = written.firstWhere((r) => r.id == 'a');
      expect(after.hidden, isTrue, reason: 'positive control: it was hidden');
      // ⚠️ TWO EXCLUSIONS AS OF v11, and the second is the rule rather than
      // an accommodation: hiding is a user action, so it STAMPS `updatedAt`.
      // A test that still demanded it unchanged would be demanding the field
      // not work.
      expect(after.updatedAt, isNotNull,
          reason: 'positive control: the hide stamped it, so excluding it below '
              'is excluding something that actually changed');
      final b = before.toMap()
        ..remove('hidden')
        ..remove('updatedAt');
      final a = after.toMap()
        ..remove('hidden')
        ..remove('updatedAt');
      expect(a, b,
          reason: 'withHidden destroyed a field it was not meant to touch');
    });
  });

  group('3. UNDO', () {
    testWidgets('3a. undo restores the record to its POSITION', (tester) async {
      // ⭐ `ordinal` is the list index at save time, so position survives only
      // if the record keeps its index. Replaced in place rather than removed
      // and re-appended — §13(ch)'s delete-then-reinsert shape is what this
      // avoids.
      await pump(tester, <EventRecord>[rec('a', 1), rec('b', 2), rec('c', 3)]);

      await tester.tap(hideButton().at(1)); // the MIDDLE row
      await tester.pumpAndSettle();
      expect(written.map((r) => r.id), <String>['a', 'b', 'c'],
          reason: 'precondition: index preserved by the hide itself');

      expect(find.text('Undo'), findsOneWidget,
          reason: 'positive control: the undo affordance is on screen');
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      expect(written.map((r) => r.id), <String>['a', 'b', 'c'],
          reason: 'ORDER is the assertion. An undo that appended would give '
              'a, c, b — and ordinal is the list index, so the record would '
              'come back in the wrong place for good');
      expect(written.where((r) => r.hidden), isEmpty,
          reason: 'and nothing is left hidden');
    });

    testWidgets('3b. undo restores every field, not just the flag',
        (tester) async {
      final before = rec('b', 2);
      await pump(tester, <EventRecord>[rec('a', 1), before, rec('c', 3)]);

      await tester.tap(hideButton().at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();

      final after = written.firstWhere((r) => r.id == 'b');
      expect(after.toMap(), before.toMap(),
          reason: 'undo restores the ORIGINAL OBJECT captured before the hide, '
              'so nothing is rebuilt on the way back');
    });
  });

  group('4. THE SNACKBAR — the escape-clause conditions', () {
    testWidgets('4a. a second hide REPLACES the first bar, never queues',
        (tester) async {
      // ⛔ QUEUED BARS WOULD MAKE UNDO AMBIGUOUS. Two identical "Event hidden"
      // bars in sequence, and the first one's Undo refers to a record the user
      // can no longer tell from the second. Only the most recent action is
      // undoable, and only one bar says so.
      await pump(tester, <EventRecord>[rec('a', 1), rec('b', 2), rec('c', 3)]);

      await tester.tap(hideButton().first);
      await tester.pump();
      await tester.tap(hideButton().first);
      await tester.pump();

      expect(find.byType(SnackBar), findsOneWidget,
          reason: 'two bars on screen means the user is choosing between two '
              'identical Undos');
      expect(find.text('Undo'), findsOneWidget);
    });

    testWidgets('4b. leaving History takes the bar with it', (tester) async {
      // ⛔ ScaffoldMessenger sits ABOVE the Navigator, so without the dispose
      // clear this bar SURVIVES a pop and sits over Home with an Undo whose
      // closure targets a disposed State. That is worse than a missed undo:
      // a live control that silently does nothing.
      await pump(tester, <EventRecord>[rec('a', 1), rec('b', 2)]);

      // Push History over a host so there is something to pop back to.
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.of(ctx).push(MaterialPageRoute<void>(
                builder: (_) => HistoryScreen(
                  records: <EventRecord>[rec('a', 1), rec('b', 2)],
                  onRecordsChanged: (updated) async {
                    written = List<EventRecord>.from(updated);
                  },
                  onEdit: (_, {required confirmOnSave}) async {},
                ),
              )),
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(hideButton().first);
      await tester.pumpAndSettle();
      expect(find.text('Undo'), findsOneWidget,
          reason: 'positive control: the bar is up before the pop');

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Undo'), findsNothing,
          reason: 'a dead Undo must not outlive the screen that offered it');
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('5. THE INTEGRITY SITES, after a real hide', () {
    testWidgets('5a. export-all and backup both carry the hidden record',
        (tester) async {
      // Home passes `_records` — the complete list — to both. This asserts the
      // list the screen hands out, which is the one home assigns and persists,
      // still carries the record after a hide through the UI.
      await pump(tester, <EventRecord>[rec('a', 1), rec('b', 2)]);
      await tester.tap(hideButton().first);
      await tester.pumpAndSettle();

      expect(written, hasLength(2),
          reason: 'positive control: nothing was removed');

      final csv = buildCsv(written);
      expect(csv, contains('note a'),
          reason: 'export-all must be complete. There is one export named '
              '"all events" and it means it');
      expect(csv, contains('note b'), reason: 'positive control');

      final parsed = parseBackup(buildBackupJson(written));
      expect(parsed.records.map((r) => r.id), containsAll(<String>['a', 'b']),
          reason: 'a hidden record absent from a backup is destroyed by an '
              'uninstall, and retention is FOREVER');
      expect(parsed.records.firstWhere((r) => r.id == 'a').hidden, isTrue,
          reason: 'and the flag travels, or a restore unhides everything');
    });
  });
}
