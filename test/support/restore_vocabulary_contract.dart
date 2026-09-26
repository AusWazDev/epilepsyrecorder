// Tier A · step 2 · THE FAILING TEST, written BEFORE the fix (26 September 2026).
//
// ⛔ WHAT THIS DRIVES: THE REAL `onRestore`. `HomeScreen` is pumped against a
// real SQLite schema, the drawer opens "Your data", "Restore from a backup" is
// tapped, the file picker is served a backup through `FileSelectorPlatform`,
// and the confirm dialog's own Restore button is tapped. Nothing in `lib/` is
// called directly and no state is poked.
//
// ⭐ WHY AT THE CALL SITE AND NOT AT A HELPER. `restore_vocabulary_state_test`
// drives `parseBackup`, `planRestore` and `SqliteEventStore.save`, and says in
// its own header that it does NOT drive `onRestore`. The fix lands in
// `onRestore`'s loop, after `_persist()` and before the conditions guard — so a
// helper-level test would pass against the fixed code and the broken code
// alike. See CLAUDE.md, "DRIVE THE COMPOSITION, NOT THE UNIT".
//
// ⛔ WHY THIS IS A SUPPORT FILE AND NOT ONE FILE WITH TWO TESTS. Both cases
// depend on SharedPreferences, and the standing rule is ONE prefs-dependent
// TEST per PROCESS. Same shape as `history_clobber_contract.dart`, whose
// harness this copies: no-isolate factory, real I/O in `setUp`, storage reads
// through `tester.runAsync`.
//
// ⛔ SOFT ASSERTIONS FOR THE FINDINGS. The first `expect` to throw ends a test,
// which would mask every finding after it (CLAUDE.md, "A CONTROL PROVES AN
// APPARATUS IS LIVE ONLY IF THE FAILURE IT PRODUCES IS ATTRIBUTABLE"). So the
// findings are collected and reported together, each by name.

import 'dart:io';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/vocabulary.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/home_screen.dart';

const customType = 'Staring spell (my own word for it)';
const customObservation = 'Metallic taste before it starts';
const customTrigger = 'Strobe lights at the gym';

/// A value on a record ALREADY ON THE DEVICE that has no list entry — the
/// damage an earlier restore left behind. D-1: `merged` must repair it.
const orphanObservation = 'Left behind by an earlier restore';

/// D-2: stored with surrounding whitespace. `addUserEntry` would trim it and
/// create an entry the record can never resolve to.
const untrimmedObservation = '  Padded on both sides  ';

/// D-3: a value MER retired. Its row is DELETED from the fixture to stand in
/// for a boot seed that failed, so only a guard inside the loop can refuse it.
final String shippedHiddenObservation =
    kLegacyObservations.firstWhere((s) => s.label == 'Confused').value;

EventRecord rec(
  String id,
  int day, {
  String? eventType,
  List<String> feelings = const <String>[],
  List<String> triggers = const <String>[],
}) =>
    EventRecord(
      id: id,
      timestamp: DateTime(2026, 9, day, 9),
      duration: DurationCategory.lt1,
      eventType: eventType,
      feelings: feelings,
      triggers: triggers,
      referralRequired: false,
      notes: '',
    );

/// Called ONCE per process, before anything touches SharedPreferences.
void seedPrefs() {
  SharedPreferences.setMockInitialValues({
    'disclaimerAcceptedVersion': kDisclaimerVersion,
    kWalkthroughSeenVersionKey: kWalkthroughVersion,

  });
}

/// Serves one backup file, from a REAL FILE ON DISK. `extends`, as the
/// platform interface requires.
///
/// ⛔ NOT `XFile.fromData`, AND THE REASON IS A MEASURED CORRUPTION. In
/// `cross_file` 0.3.5+2, `XFile.fromData(...).readAsString()` IGNORES its
/// `encoding` argument and returns `String.fromCharCodes(bytes)` — a Latin-1
/// decode of UTF-8 bytes. Measured 26 September 2026: a restored `😵 Confused`
/// arrived in storage as U+00F0 U+009F U+0098 U+00B5 + " Confused", the exact
/// mis-decode the mangled-twin seeds exist for. A path-backed `XFile` decodes
/// with the encoding it is given, which is the shape a real picker returns.
/// ⚠️ `restore_outcomes_test`'s fake uses `fromData` and never meets this only
/// because every fixture it serves is ASCII.
class FakeFileSelector extends FileSelectorPlatform {
  FakeFileSelector(this.path);
  final String path;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async =>
      XFile(path, name: 'backup.json', mimeType: 'application/json');
}

/// Null when [table] has no row with EXACTLY this value; otherwise the row.
Future<VocabularyEntry?> rowFor(Database db, String table, String value) async {
  for (final e in await loadVocabulary(db, table)) {
    if (e.value == value) return e;
  }
  return null;
}

/// One restore scenario.
class RestoreCase {
  const RestoreCase({
    required this.name,
    required this.backupJson,
    required this.deviceRecords,
    required this.check,
  });

  final String name;
  final String Function() backupJson;
  final List<EventRecord> deviceRecords;

  /// Runs after the restore, on the REAL clock. Returns the findings: an empty
  /// list means the case passed.
  final Future<List<String>> Function(Database db) check;
}

/// Lends the REAL clock for one short interval, then settles the fake one.
///
/// ⛔ WITHOUT THIS, HOMESCREEN'S INITIAL LOAD NEVER COMPLETES. Measured
/// 26 September 2026 by bisection: a save started after the first
/// `pumpAndSettle` stayed PENDING through ten 200 ms pumps — the static store
/// queue was blocked behind the unfinished load — and with the load
/// unfinished `_loadState` never reached `completed`, so `onRestore`'s
/// `_persist()` was WITHHELD. The restore then reported success with the
/// failed-write banner up and the restored record absent from storage.
/// One real-clock yield after the pump and the same save COMPLETED.
///
/// ⚠️ `history_clobber_contract.dart` never meets this only because its first
/// assertion happens to be a `tester.runAsync` read straight after the pump.
/// That yield is load-bearing there and says so nowhere. WHAT in the load
/// needs the real clock was NOT identified; this lends it rather than
/// guessing.
Future<void> settleReal(WidgetTester tester) async {
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
}

bool failedWriteBannerShowing() => find
    .byWidgetPredicate((w) => w.runtimeType.toString() == '_FailedWriteBanner')
    .evaluate()
    .isNotEmpty;

void registerRestoreVocabularyCase(RestoreCase c) {
  sqfliteFfiInit();
  // ⛔ NO-ISOLATE ON PURPOSE: `HomeScreen`'s own database I/O runs inside the
  // pump, on the fake clock, and only the in-process factory completes there.
  databaseFactory = databaseFactoryFfiNoIsolate;

  Database? db;
  FileSelectorPlatform? originalPicker;
  Directory? tmp;

  group('[${c.name}]', () {
    // ── REAL CLOCK. Every piece of real I/O in the fixture lives here. ────
    setUp(() async {
      Vocabularies.debugReset();
      db = await databaseFactory.openDatabase(inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            version: kSqliteSchemaVersion,
            onCreate: (d, v) async => createSchema(d),
          ));
      // inMemoryDatabasePath is ONE database per process — clear what matters.
      await db!.delete('event');
      await db!.delete(kObservationTable,
          where: 'value = ?', whereArgs: <Object?>[shippedHiddenObservation]);
      await SqliteEventStore(db!).save(c.deviceRecords);

      // ── CONTROL 0 · the fixture is what it claims. Here, on the real
      // clock, so no fixture read happens inside the test body.
      expect(await rowFor(db!, kObservationTable, shippedHiddenObservation),
          isNull,
          reason: 'CONTROL: the retired row was meant to be deleted from the '
              'fixture, so the D-3 assertion would test nothing.');
      expect(await rowFor(db!, kEventTypeTable, customType), isNull,
          reason: 'CONTROL: the new device already has the custom type, so '
              'the finding cannot fail.');
      expect((await db!.query('event')).length, c.deviceRecords.length,
          reason: 'CONTROL: the device does not start with the records the '
              'case declares.');

      StorageBoot.debugSet(store: SqliteEventStore(db!), db: db);
      // What boot does. Without it the pickers' cache holds the shipped seeds
      // rather than this database, which is not the state a device is in.
      await Vocabularies.load(db);
      originalPicker = FileSelectorPlatform.instance;
      tmp = await Directory.systemTemp.createTemp('mer_tierA_');
      final backup = File('${tmp!.path}${Platform.pathSeparator}backup.json');
      await backup.writeAsString(c.backupJson()); // UTF-8, the default
      FileSelectorPlatform.instance = FakeFileSelector(backup.path);
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

    testWidgets(
        'a restore through the real onRestore recreates the list entries its '
        'records use', (tester) async {
      void mark(String step) => debugPrint('    >>> [${c.name}] $step');

      mark('START');
      addTearDown(tester.view.reset);
      tester.view.physicalSize = const Size(375 * 3, 1600 * 3);
      tester.view.devicePixelRatio = 3.0;

      // ── 1 · HomeScreen, the drawer, Your data ────────────────────────
      mark('1 pumping HomeScreen');
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();
      await settleReal(tester);
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Your data'));
      await tester.pumpAndSettle();

      // ── 2 · Restore, through the real button and the real dialog ─────
      mark('2 tapping Restore from a backup');
      final restore = find.text('Restore from a backup');
      await tester.ensureVisible(restore);
      await tester.tap(restore);
      await tester.pumpAndSettle();

      final confirm = find.byWidgetPredicate((w) =>
          w is FilledButton &&
          w.child is Text &&
          ((w.child as Text).data ?? '').startsWith('Restore '));
      // The backup is a REAL file (see FakeFileSelector), and reading it is
      // real I/O the fake clock cannot complete — so lend the real clock until
      // the dialog is up. Bounded: an absent dialog fails the control below.
      for (var i = 0; i < 20 && confirm.evaluate().isEmpty; i++) {
        await settleReal(tester);
      }
      expect(confirm, findsOneWidget,
          reason: 'CONTROL: the confirm dialog did not appear, so the restore '
              'never reached onRestore\'s write path.');
      mark('3 confirming');
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      await settleReal(tester);

      expect(find.textContaining('Restored '), findsOneWidget,
          reason: 'CONTROL: onRestore did not reach its completion snackbar, '
              'so its loop may not have run at all.');

      // ⭐ CONTROL: the persist LANDED. Without this, a withheld `_persist()`
      // — which is exactly what the harness first produced — reads as a
      // restore that ran and simply created no entries: the finding would be
      // red for the wrong reason. `_FailedWriteBanner` is private, so it is
      // matched by its type NAME; a rename makes this control fail loudly.
      Navigator.of(tester.element(find.text('Restore from a backup'))).pop();
      await tester.pumpAndSettle();
      expect(find.byTooltip('Open navigation menu'), findsOneWidget,
          reason: 'CONTROL: not back on HomeScreen, so the banner check below '
              'would look at the wrong screen.');
      expect(failedWriteBannerShowing(), isFalse,
          reason: 'CONTROL: the failed-write banner is up, so onRestore\'s '
              '_persist() did not land and this run cannot speak to the '
              'vocabulary.');

      // ── 3 · What is in STORAGE, read on the fake clock ──────────────
      // The no-isolate factory completes through microtasks, which the fake
      // clock flushes, so this needs no runAsync — and a runAsync read here
      // was measured to deadlock while the queue was blocked.
      mark('4 reading storage');
      final problems = await c.check(db!);
      mark('5 DONE, ${problems.length} finding(s)');
      expect(problems, isEmpty,
          reason: '\n  ${problems.join('\n  ')}\n');
    }, timeout: const Timeout(Duration(seconds: 45)));
  });
}

/// Records still verbatim in storage: the property that must NOT change.
///
/// ⛔ READ BY DIRECT QUERY, NOT `SqliteEventStore.load()`. `load` chains onto
/// `EventStore.serialise`, the STATIC queue, whose tail was last extended by
/// `onRestore`'s `_persist()` INSIDE THE FAKE CLOCK. Awaiting it from
/// `tester.runAsync` deadlocks: measured 26 September 2026, both cases hung
/// at the storage read for the full 45 seconds with every driving step
/// already complete. `eventFromRow` is the store's own decoder, so the
/// comparison still sees exactly what the store would return.
Future<List<String>> recordsVerbatim(
    Database db, Map<String, EventRecord> expected) async {
  final out = <String>[];
  final stored = <String, EventRecord>{
    for (final row in await db.query('event'))
      if (eventFromRow(row) case final r?) r.id: r,
  };
  expected.forEach((id, want) {
    final got = stored[id];
    if (got == null) {
      out.add('CONTROL FAILED: record $id is not in storage.');
      return;
    }
    // Per field, BEFORE and AFTER, with code points — a count or a bare
    // "changed" says a rule fired, never what it did, and a terminal that
    // mis-renders a glyph makes two different strings look identical.
    String cp(String s) => s.runes
        .map((r) => r < 0x80 ? String.fromCharCode(r) : '<U+${r.toRadixString(16).toUpperCase()}>')
        .join();
    void field(String name, List<String> w, List<String> g) {
      if (w.join('\u0000') == g.join('\u0000')) return;
      out.add('RECORD CHANGED: $id.$name\n'
          '      before ${w.map(cp).toList()}\n'
          '      after  ${g.map(cp).toList()}');
    }
    field('eventType', [want.eventType ?? '<null>'], [got.eventType ?? '<null>']);
    field('feelings', want.feelings, got.feelings);
    field('triggers', want.triggers, got.triggers);
  });
  return out;
}

/// A finding when no row exists, or the row is not ACTIVE.
Future<String?> needsActiveRow(Database db, String table, String value) async {
  final row = await rowFor(db, table, value);
  if (row == null) return 'MISSING: no $table row for "$value"';
  if (!row.isActive) return 'INACTIVE: the $table row for "$value" is hidden';
  return null;
}
