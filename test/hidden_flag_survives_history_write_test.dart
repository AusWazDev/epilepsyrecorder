import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/screens/history_screen.dart';

/// The second half of `hidden_survives_history_write_test.dart`, and it is in
/// its own FILE rather than its own `test()` for a mechanical reason.
///
/// ## ⛔ ONE serialise-DRIVING WIDGET TEST PER FILE
///
/// `EventStore.serialise` chains on a STATIC queue:
///
///     final result = _queue.then((_) => operation());
///     _queue = result.then((_) {}, onError: (_) {});
///
/// That `.then` registers its continuation in whatever zone is current. A
/// `persistEvents` driven from a widget callback runs inside that test's
/// FAKE-ASYNC zone, so when the test ends `_queue` terminates in a continuation
/// bound to a dead zone — and **the next `serialise` call anywhere in the
/// process waits on it forever.** Put this test in the sibling file and it
/// hangs at 04:55 with the first one already green, with no output naming a
/// cause.
///
/// ⭐ Same class as `CLAUDE.md`'s one-prefs-test-per-process rule: a static that
/// outlives the zone it was last touched from. The practical test is the same —
/// count the tests in the file that drive the store, and if it is more than
/// one, split the file.
///
/// ## WHAT THIS ADDS OVER THE SIBLING
///
/// The sibling asserts the hidden record's ROW survives a History write. ⛔ **A
/// row that came back VISIBLE would satisfy that and still be a loss**: the
/// user hid it and the write path forgot. This asserts the flag.
///
/// ⚠️ The row control HIDES rather than deletes as of 17 September 2026, so
/// the write under test is now a hide. The claim is unchanged.

EventRecord rec(String id, int minute, {bool hidden = false}) => EventRecord(
      id: id,
      timestamp: DateTime(2026, 8, 20, 9, minute),
      duration: DurationCategory.lt1,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: false,
      notes: 'note $id',
      eventType: 'seizure',
      severity: EventSeverity.mild,
      detailsCompleted: true,
      hidden: hidden,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  late Directory tmp;
  late Database db;
  late SqliteEventStore store;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('mer_seamflag_');
    db = await databaseFactoryFfi.openDatabase(
      '${tmp.path}/mer.db',
      options: OpenDatabaseOptions(
        version: kSqliteSchemaVersion,
        onCreate: (d, _) => createSchema(d),
        onUpgrade: upgradeSchema,
      ),
    );
    store = SqliteEventStore(db);
  });

  tearDown(() async {
    await db.close();
    if (tmp.existsSync()) await tmp.delete(recursive: true);
  });

  /// NOT `pumpAndSettle` — see `bulk_hide_test.dart:54`.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 150));
    });
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('a hidden record survives a History write with its FLAG intact',
      (tester) async {
    final seed = <EventRecord>[
      rec('visible-a', 1),
      rec('HIDDEN', 2, hidden: true),
    ];
    await tester.runAsync(() => store.save(seed));

    await tester.pumpWidget(MaterialApp(
      home: HistoryScreen(
        records: seed,
        // What home_screen.dart:893-894 does.
        onRecordsChanged: (updated) async => persistEvents(store, updated),
        onEdit: (_, {required confirmOnSave}) async {},
      ),
    ));
    await settle(tester);

    expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget,
        reason: 'positive control: ONE visible row. If this is 2 the fixture '
            'is not hidden and the test is vacuous');

    // One tap, no confirmation — see the sibling file.
    // ⛔ A HIDE IS NO LONGER ONE TAP — A2 restored the confirmation on
    // 18 September 2026, so the control opens a dialog and the act only
    // happens on the affirmative.
    await tester.tap(find.byIcon(Icons.visibility_off_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Hide'));
    await settle(tester);

    // ⛔ READ THE TABLE, NOT `store.load()`. A second `serialise` call after the
    // widget's own would chain onto the dead-zone continuation described above.
    // ⭐ Querying the table is also the stronger assertion: it reports what is
    // in STORAGE rather than what the store's own path returns.
    final rows = await tester.runAsync(
        () => db.query('event', columns: <String>['id', 'hidden']));

    // ⛔ BOTH ROWS, and BOTH now hidden: the pre-existing one, which must not
    // have been destroyed, and the one the user just hid.
    expect(rows, hasLength(2),
        reason: 'positive control: hiding removes nothing from storage');
    final byId = <String, Object?>{
      for (final r in rows!) r['id'] as String: r['hidden'],
    };
    expect(byId['HIDDEN'], 1,
        reason: 'surviving as a VISIBLE row is still a loss — the user hid it '
            'and the write path forgot');
    expect(byId['visible-a'], 1,
        reason: 'and the row the user just hid carries the flag, or the tap '
            'did nothing and this test is vacuous');
  });
}
