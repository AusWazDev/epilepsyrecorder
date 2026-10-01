// Brief 321 · a save must land even when the screen that started it is gone.
//
// ⛔ THIS HARNESS CONSTRUCTS A STATE THE APP DOES NOT CURRENTLY PRODUCE.
// As at 1 October 2026, nothing in `lib/` removes Home (or History) from the
// Navigator while a screen pushed above it survives. Brief 319's sweep is the
// basis for that claim: the only route removals in `lib/` are
// `pushAndRemoveUntil` in `_confirmResetDisclaimer` (reached from About, which
// cannot run with these screens open) and two `pushReplacement` calls on the
// splash and disclaimer screens. A whole-tree teardown does not reach these
// sites either: the pushed route's future never completes, so the code after
// the `await` never runs (Brief 319, probe 1).
//
// ⭐ WHY IT EXISTS ANYWAY. Each site awaits a pushed screen and then writes.
// If a future change removes the screen below while the one above survives,
// the write must still land. This holds that line, for four sites:
//
//     onRestore        Home, Your data's restore callback
//     _openLogScreen   Home, "Edit details" on the Last Event card
//     _openWizard      Home, "Record with details"
//     _editRecord      History, a row tap
//
// ⛔ THE ASSERTION IS ON STORAGE ONLY. In Brief 318 and Brief 319's probe 2 the
// setState-after-dispose throw was reported by the framework as an async error
// and `tester.takeException()` returned null, so a throw assertion here would
// be coverage that can never fail. What must hold is that the record is in the
// database.
//
// ⚠️ The pushed screen is completed with `Navigator.pop(context, record)`,
// which is exactly what LogEventScreen's save and the wizard's finish do
// (`log_event_screen.dart` and `event_wizard_screen.dart`, by that call). The
// form itself is not driven: what is under test is the CALLER's handling of
// the result, not the form.
//
// ⛔ ONE PREFS-DEPENDENT TEST PER PROCESS, so one site per file.

import 'dart:convert';
import 'dart:io';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/event_wizard_screen.dart';
import 'package:medical_event_recorder/screens/history_screen.dart';
import 'package:medical_event_recorder/screens/home_screen.dart';
import 'package:medical_event_recorder/screens/log_event_screen.dart';

import 'restore_vocabulary_contract.dart' show FakeFileSelector, settleReal;

enum WriteSite { onRestore, openLogScreen, openWizard, historyEditRecord }

const kEditedNotes = 'Edited after the screen below was removed (Brief 321)';

/// A COMPLETE record, so `wantsWizard` is false and an edit opens the form.
EventRecord completeRec(String id, int day, {String notes = ''}) => EventRecord(
      id: id,
      timestamp: DateTime(2026, 9, day, 9),
      duration: DurationCategory.lt1,
      durationSeconds: 40,
      eventType: 'seizure',
      severity: EventSeverity.mild,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: false,
      notes: notes,
      detailsCompleted: true,
    );

void registerRouteRemovedWriteCase(WriteSite site) {
  sqfliteFfiInit();
  // In-process: HomeScreen's own database I/O runs inside the pump.
  databaseFactory = databaseFactoryFfiNoIsolate;

  Database? db;
  FileSelectorPlatform? originalPicker;
  Directory? tmp;
  final device = completeRec('device-1', 10);
  final restored = completeRec('restored-1', 20);

  setUp(() async {
    Vocabularies.debugReset();
    db = await databaseFactory.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: kSqliteSchemaVersion,
          onCreate: (d, v) async => createSchema(d),
        ));
    await db!.delete('event'); // shared per process
    await SqliteEventStore(db!).save([device]);
    StorageBoot.debugSet(store: SqliteEventStore(db!), db: db);
    await Vocabularies.load(db);
    if (site == WriteSite.onRestore) {
      originalPicker = FileSelectorPlatform.instance;
      tmp = await Directory.systemTemp.createTemp('mer_b321_');
      final backup = File('${tmp!.path}${Platform.pathSeparator}backup.json');
      await backup.writeAsString(jsonEncode({
        'format': kBackupFormatId,
        'schemaVersion': 1,
        'appVersion': '1.1.0+41',
        'exportedAt': DateTime(2026, 8, 27, 23).toIso8601String(),
        'recordCount': 1,
        'records': [restored.toMap()],
      }));
      FileSelectorPlatform.instance = FakeFileSelector(backup.path);
    }
  });

  tearDown(() async {
    if (originalPicker != null) FileSelectorPlatform.instance = originalPicker!;
    StorageBoot.debugSet();
    await db?.close();
    db = null;
    Vocabularies.debugReset();
    try {
      await tmp?.delete(recursive: true);
    } catch (_) {/* Windows can hold the file briefly; the OS cleans temp */}
    tmp = null;
  });

  testWidgets('[${site.name}] the write lands after the screen below is removed',
      (tester) async {
    void mark(String step) => debugPrint('    >>> [${site.name}] $step');
    mark('START');
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(375 * 3, 1600 * 3);
    tester.view.devicePixelRatio = 3.0;

    NavigatorState nav() => tester.state<NavigatorState>(find.byType(Navigator).first);

    /// Removes the route that hosts [screen], and proves it is gone.
    Future<void> removeRouteOf(Type screen) async {
      final el = tester.element(find.byType(screen, skipOffstage: false));
      nav().removeRoute(ModalRoute.of(el)!);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(screen, skipOffstage: false), findsNothing,
          reason: 'CONTROL: $screen was not removed, so this is the ordinary '
              'path, not the one under test.');
    }

    /// Completes the topmost pushed screen of type [screen] with [result],
    /// the same call its own save makes.
    void completeWith(Type screen, EventRecord result) {
      expect(find.byType(screen), findsOneWidget,
          reason: 'CONTROL: $screen is not on top, so there is nothing to '
              'complete.');
      Navigator.of(tester.element(find.byType(screen))).pop(result);
    }

    Future<void> settle() async {
      for (var i = 0; i < 60; i++) {
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump();
      }
    }

    Future<Map<String, EventRecord>> stored() async => {
          for (final row in await db!.query('event'))
            if (eventFromRow(row) case final r?) r.id: r,
        };

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();
    await settleReal(tester);
    mark('1 Home pumped');
    expect((await stored()).keys.toSet(), {'device-1'},
        reason: 'CONTROL: the device must start with exactly its seed.');

    late String wantId;
    String? wantNotes;

    switch (site) {
      case WriteSite.onRestore:
        await tester.tap(find.byTooltip('Open navigation menu'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Your data'));
        await tester.pumpAndSettle();
        final restore = find.text('Restore from a backup');
        await tester.ensureVisible(restore);
        await tester.tap(restore);
        await tester.pumpAndSettle();
        final confirm = find.byWidgetPredicate((w) =>
            w is FilledButton &&
            w.child is Text &&
            ((w.child as Text).data ?? '').startsWith('Restore '));
        for (var i = 0; i < 20 && confirm.evaluate().isEmpty; i++) {
          await settleReal(tester);
        }
        expect(confirm, findsOneWidget,
            reason: 'CONTROL: the restore confirm dialog did not appear.');
        mark('2 confirm dialog up; removing Home');
        await removeRouteOf(HomeScreen);
        expect(confirm, findsOneWidget,
            reason: 'CONTROL: the dialog went with Home.');
        await tester.tap(confirm);
        await tester.pump();
        wantId = restored.id;

      case WriteSite.openLogScreen:
        final edit = find.text('Edit details');
        await tester.ensureVisible(edit);
        await tester.tap(edit);
        await tester.pumpAndSettle();
        mark('2 log screen open; removing Home');
        await removeRouteOf(HomeScreen);
        completeWith(LogEventScreen, completeRec('device-1', 10, notes: kEditedNotes));
        wantId = 'device-1';
        wantNotes = kEditedNotes;

      case WriteSite.openWizard:
        final details = find.text('Record with details');
        await tester.ensureVisible(details);
        await tester.tap(details);
        await tester.pumpAndSettle();
        mark('2 wizard open; removing Home');
        await removeRouteOf(HomeScreen);
        completeWith(EventWizardScreen, completeRec('wizard-new', 25, notes: kEditedNotes));
        wantId = 'wizard-new';
        wantNotes = kEditedNotes;

      case WriteSite.historyEditRecord:
        final allHistory = find.text('All history');
        await tester.ensureVisible(allHistory);
        await tester.tap(allHistory);
        await tester.pumpAndSettle();
        final row = find.byWidgetPredicate(
            (w) => w.runtimeType.toString() == '_EventListTile');
        expect(row, findsOneWidget,
            reason: 'CONTROL: History does not show the one seeded record.');
        await tester.tap(row);
        await tester.pumpAndSettle();
        mark('2 log screen open over History; removing History');
        await removeRouteOf(HistoryScreen);
        expect(find.byType(HomeScreen, skipOffstage: false), findsOneWidget,
            reason: 'CONTROL: Home must survive, so its own callback is not '
                'what is being tested.');
        completeWith(LogEventScreen, completeRec('device-1', 10, notes: kEditedNotes));
        wantId = 'device-1';
        wantNotes = kEditedNotes;
    }

    mark('3 result delivered; settling the write');
    await settle();
    final after = await stored();
    mark('4 ids in storage: ${after.keys.toSet()}');
    expect(after.containsKey(wantId), isTrue,
        reason: '⛔ THE LOST WRITE. `$wantId` is not in STORAGE. The caller '
            'awaited the pushed screen, the screen below it was gone, and the '
            'write after the await never happened.');
    if (wantNotes != null) {
      expect(after[wantId]!.notes, wantNotes,
          reason: '⛔ THE LOST WRITE. `$wantId` is in storage but without the '
              'change the pushed screen returned.');
    }
    mark('5 DONE');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
