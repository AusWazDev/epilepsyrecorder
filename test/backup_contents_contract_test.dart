import 'dart:convert';
import 'dart:io';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/condition.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/event_store_sqlite.dart';
import 'package:medical_event_recorder/models/medication_note.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/vocabulary.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/services/backup_service.dart';

/// Contract #26 (behaviour half) — a backup taken through `backUpFromDevice`
/// CONTAINS the medication notes, conditions and type assignments that exist.
///
/// The scan half (`backup_entry_points_contract_test`) proves every backup
/// entry point goes through `backUpFromDevice`. This proves what that produces:
/// the real sheet, the real Save-to-device row, a real file on disk, read back.
///
/// ⛔ **THE DEFECT:** Home's reminder produced backups with none of the three,
/// on every device, from 28 August 2026 (Brief 192).
///
/// Harness notes, each measured on this project: the no-isolate database
/// factory (HomeScreen-style I/O on the fake clock), a REAL file for the fake
/// picker to name, and a real-clock yield for file I/O. One test in this file.

class _SaveTo extends FileSelectorPlatform {
  _SaveTo(this.path);
  final String path;
  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    SaveDialogOptions options = const SaveDialogOptions(),
  }) async =>
      FileSaveLocation(path);
}

Future<void> settleReal(WidgetTester tester) async {
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

  // ⛔ REAL GLYPH WIDTHS. The test font is one em per glyph, which wraps the
  // backup sheet's subtitles further than any device and overflowed it by
  // 61 px at phone size (MER CLAUDE.md: a widget test's text widths are not
  // real text widths). Roboto from the SDK cache, the pattern
  // backup_banner_copy_measure_test established.
  setUpAll(() async {
    final path = '${Platform.environment['FLUTTER_ROOT'] ?? 'C:/Flutter/flutter'}'
        '/bin/cache/artifacts/material_fonts/roboto-regular.ttf';
    final file = File(path);
    if (!file.existsSync()) {
      fail('Roboto not found at $path, cannot render the sheet at real widths.');
    }
    final loader = FontLoader('Roboto')
      ..addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
    await loader.load();
  });

  Database? db;
  Directory? tmp;
  FileSelectorPlatform? originalPicker;
  late String target;

  setUp(() async {
    Vocabularies.debugReset();
    db = await databaseFactory.openDatabase(inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: kSqliteSchemaVersion,
          onCreate: (d, v) async => createSchema(d),
        ));
    // inMemoryDatabasePath is one database per process: clear what matters.
    await db!.delete('event');
    await db!.delete(kMedicationNoteTable);
    await db!.delete(kConditionTable);

    await insertMedicationNote(
        db!,
        MedicationNote(
          id: 'note-1',
          occurredAt: DateTime(2026, 9, 20, 8),
          loggedAt: DateTime(2026, 9, 20, 9),
          kind: MedicationDeviation.missed,
        ));
    final epilepsy = await addCondition(db!, 'Epilepsy');
    final seizure = (await loadVocabulary(db!, kEventTypeTable))
        .firstWhere((e) => e.value == 'seizure');
    await setConditionFor(db!, kEventTypeTable, seizure, epilepsy!.id);

    StorageBoot.debugSet(store: SqliteEventStore(db!), db: db);
    await Vocabularies.load(db);

    tmp = await Directory.systemTemp.createTemp('mer_backup_contents_');
    target = '${tmp!.path}${Platform.pathSeparator}backup.json';
    originalPicker = FileSelectorPlatform.instance;
    FileSelectorPlatform.instance = _SaveTo(target);
  });

  tearDown(() async {
    if (originalPicker != null) FileSelectorPlatform.instance = originalPicker!;
    StorageBoot.debugSet();
    await db?.close();
    Vocabularies.debugReset();
    try {
      await tmp?.delete(recursive: true);
    } catch (_) {/* Windows can hold the file briefly; the OS cleans temp */}
  });

  testWidgets(
      '#26 a backup through backUpFromDevice contains notes, conditions and '
      'type assignments', (tester) async {
    final records = <EventRecord>[
      EventRecord(
        id: 'r-1',
        timestamp: DateTime(2026, 9, 20, 10),
        duration: DurationCategory.lt1,
        eventType: 'seizure',
        feelings: const <String>[],
        referralRequired: false,
        notes: '',
      ),
    ];

    // A phone-sized view, as the other screen tests use. The default 800x600
    // test surface is shorter than any phone and overflows the sheet by 65 px,
    // which is a harness artefact, not the sheet's layout.
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(375 * 3, 812 * 3);
    tester.view.devicePixelRatio = 3.0;

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: ElevatedButton(
              onPressed: () => backUpFromDevice(ctx, records),
              child: const Text('back up'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('back up'));
    final saveRow = find.text(kSaveToDeviceTitle);
    for (var i = 0; i < 20 && saveRow.evaluate().isEmpty; i++) {
      await settleReal(tester);
    }
    expect(saveRow, findsOneWidget,
        reason: 'CONTROL: the backup sheet did not open, so nothing below is '
            'reading a backup');

    await tester.tap(saveRow);
    // ⛔ WAIT FOR THE SAVE'S OWN COMPLETION SIGNAL, NOT FOR THE FILE TO EXIST.
    // Measured 26 September 2026: polling `existsSync` read the file after it
    // was created and before it was written, and failed on a FormatException,
    // a red for the wrong reason. The "Backup saved" snackbar is shown only
    // after `writeAsString(..., flush: true)` has returned.
    final saved = find.text('Backup saved');
    for (var i = 0; i < 40 && saved.evaluate().isEmpty; i++) {
      await settleReal(tester);
    }
    expect(saved, findsOneWidget,
        reason: 'CONTROL: the save did not report completion');
    final file = File(target);
    expect(file.existsSync(), isTrue,
        reason: 'CONTROL: no file was written to the chosen location');

    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    expect((json['records'] as List).length, 1,
        reason: 'CONTROL: the record itself is in the file');

    // Each asserted separately, so a missing one names itself.
    final problems = <String>[];
    final notes = json['medicationNotes'];
    if (notes is! List || notes.isEmpty) {
      problems.add('MEDICATION NOTES MISSING: $notes');
    }
    final conditions = json['conditions'];
    if (conditions is! List ||
        !conditions.any((c) => c is Map && c['name'] == 'Epilepsy')) {
      problems.add('CONDITIONS MISSING: $conditions');
    }
    final types = json['eventTypeConditions'];
    if (types is! Map || types['seizure'] != 'Epilepsy') {
      problems.add('TYPE ASSIGNMENTS MISSING: $types');
    }
    expect(problems, isEmpty, reason: '\n  ${problems.join('\n  ')}\n');
  }, timeout: const Timeout(Duration(seconds: 45)));
}
