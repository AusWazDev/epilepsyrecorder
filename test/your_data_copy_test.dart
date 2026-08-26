import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/backup.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/services/backup_service.dart';

/// The claims the Your data screen makes about the two files.
///
/// This copy tells someone which file will bring their history back, so a wrong
/// sentence here is worse than no sentence. Each test corresponds to a statement
/// on the screen, so the copy cannot quietly drift from the code.

/// Returns a picker that always yields an in-memory file holding [contents].
///
/// Deliberately NOT a real file on disk. restoreFromBackup awaits
/// `readAsString`, and real file I/O never completes under the widget-test
/// binding's fake async — the test hangs instead of failing. XFile.fromData
/// reads from memory, so the await resolves.
class _FixedFileSelector extends FileSelectorPlatform {
  _FixedFileSelector(this.contents);

  final String contents;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async =>
      XFile.fromData(
        Uint8List.fromList(utf8.encode(contents)),
        mimeType: 'application/json',
        name: 'backup.json',
      );
}

EventRecord record(String id, DateTime when) => EventRecord(
      id: id,
      timestamp: when,
      duration: DurationCategory.lt1,
      feelings: const <String>[],
      referralRequired: false,
      notes: '',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final originalSelector = FileSelectorPlatform.instance;
  tearDown(() => FileSelectorPlatform.instance = originalSelector);

  group('"Every event, oldest first, one row each"', () {
    test('CSV rows ascend even though the list is newest-first', () {
      // EventStore.load sorts descending and History's filter preserves that,
      // so every caller hands buildCsv a newest-first list.
      final newestFirst = <EventRecord>[
        record('third', DateTime(2026, 8, 22, 18, 0)),
        record('second', DateTime(2026, 8, 21, 18, 0)),
        record('first', DateTime(2026, 8, 20, 18, 0)),
      ];

      final rows = buildCsv(newestFirst).trim().split('\n');
      final dates = rows.skip(1).map((r) => r.split(',')[1]).toList();

      expect(dates, <String>['2026-08-20', '2026-08-21', '2026-08-22'],
          reason: 'the screen states "oldest first"');
      expect(rows.length, 4, reason: 'one header plus one row each');
    });
  });

  group('"It cannot be read back into the app"', () {
    test('parseBackup refuses a CSV', () {
      final csv = buildCsv(<EventRecord>[
        record('a', DateTime(2026, 8, 22, 18, 0)),
      ]);

      final parsed = parseBackup(csv);

      expect(parsed.isValid, isFalse);
      expect(parsed.records, isEmpty);
      // The BOM alone stops it being JSON, so this is the unreadable gate.
      expect(parsed.problem, BackupProblem.unreadable);
    });

    test('parseBackup refuses a CSV even with the BOM stripped', () {
      final csv = buildCsv(<EventRecord>[
        record('a', DateTime(2026, 8, 22, 18, 0)),
      ]).replaceFirst('﻿', '');

      expect(parseBackup(csv).isValid, isFalse);
    });

    test('the restore picker does not accept .csv', () {
      // Second, independent barrier: on iOS the file is not even selectable.
      expect(kBackupTypeGroup.extensions, <String>['json']);
      expect(kBackupTypeGroup.extensions, isNot(contains('csv')));
      expect(kBackupTypeGroup.uniformTypeIdentifiers, <String>['public.json']);
    });
  });

  group('"A backup file holds everything"', () {
    test('the envelope carries every record and its fields', () {
      final records = <EventRecord>[
        record('a', DateTime(2026, 8, 22, 18, 0)),
        record('b', DateTime(2026, 8, 21, 18, 0)),
      ];

      final parsed = parseBackup(buildBackupJson(records));

      expect(parsed.isValid, isTrue, reason: parsed.message);
      expect(parsed.records.map((r) => r.id), <String>['a', 'b']);
      expect(parsed.records.first.toMap(), records.first.toMap());
      expect(parsed.schemaVersion, kBackupSchemaVersion);
    });
  });

  group('the restore dialog names what it is restoring', () {
    /// Writes a backup file and drives restoreFromBackup against it.
    Future<void> pumpRestore(
      WidgetTester tester,
      List<EventRecord> inBackup,
      List<EventRecord> onDevice,
    ) async {
      FileSelectorPlatform.instance =
          _FixedFileSelector(buildBackupJson(inBackup));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => restoreFromBackup(context, onDevice),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
    }

    testWidgets('plural when more than one event would be added',
        (tester) async {
      await pumpRestore(
        tester,
        <EventRecord>[
          record('a', DateTime(2026, 8, 22, 18, 0)),
          record('b', DateTime(2026, 8, 21, 18, 0)),
        ],
        <EventRecord>[],
      );

      // Was "Restore 2" — an int interpolated with no noun.
      expect(find.text('Restore 2 events'), findsOneWidget);
      expect(find.textContaining('Restore 2 events?'), findsOneWidget);
    });

    testWidgets('singular when exactly one would be added', (tester) async {
      await pumpRestore(
        tester,
        <EventRecord>[record('a', DateTime(2026, 8, 22, 18, 0))],
        <EventRecord>[],
      );

      expect(find.text('Restore 1 event'), findsOneWidget);
    });

    testWidgets('the merge-only promise is still shown', (tester) async {
      await pumpRestore(
        tester,
        <EventRecord>[record('a', DateTime(2026, 8, 22, 18, 0))],
        <EventRecord>[],
      );

      expect(
        find.textContaining('Restoring only adds events'),
        findsOneWidget,
      );
    });
  });

  group('every restore refusal message is intact', () {
    // The screen tells the user a backup "holds everything" and can be read
    // back. These are the twelve ways that can fail, and each must still say
    // what went wrong rather than failing blankly.
    test('unreadable, not-a-backup, schema and empty gates', () {
      expect(parseBackup('not json at all').message,
          'This file could not be read. It may be damaged or incomplete.');

      expect(parseBackup('[1,2,3]').message,
          'This is not a Medical Event Recorder backup file.');

      expect(parseBackup('{"format":"something-else"}').message,
          'This is not a Medical Event Recorder backup file.');

      expect(
        parseBackup('{"format":"$kBackupFormatId"}').message,
        'This backup is missing its version information and cannot be read.',
      );

      expect(
        parseBackup('{"format":"$kBackupFormatId","schemaVersion":999}')
            .message,
        'This backup was made by a newer version of Medical Event Recorder. '
        'Update the app, then try again.',
      );

      expect(
        parseBackup('{"format":"$kBackupFormatId","schemaVersion":1}').message,
        'This backup does not contain any event data.',
      );
    });

    test('a record with an unreadable timestamp is skipped, not fatal', () {
      final json = '{"format":"$kBackupFormatId","schemaVersion":1,'
          '"records":[{"id":"bad","timestamp":"not-a-date"},'
          '{"id":"good","timestamp":"2026-08-22T18:00:00.000"}]}';

      final parsed = parseBackup(json);

      expect(parsed.isValid, isTrue);
      expect(parsed.unreadableRecords, 1);
      expect(parsed.records.single.id, 'good');
    });
  });

  // ELEVEN COLUMNS, down from 27. The one-hot block is gone in both halves:
  // eleven observation columns collapsed when observations became
  // user-extensible, and seven trigger columns collapse here, completing
  // DATA-MODEL.md section 6.
  //
  // This test is the shape's only fixed point. Nothing in the app reads a CSV
  // back, so a column that moved, doubled or vanished would not fail anywhere
  // else - the file would simply be wrong, in the one artefact that leaves the
  // app and goes to a clinician.
  group('the CSV columns', () {
    test('header row, in order', () {
      final header = buildCsv(<EventRecord>[
        record('a', DateTime(2026, 8, 22, 18, 0)),
      ]).split('\n').first.replaceFirst('﻿', '').trim();

      expect(header.split(','), <String>[
        'timestamp_iso',
        'date',
        'time',
        'event_type',
        'duration',
        'duration_seconds',
        'severity',
        // The eleven one-hot feelings columns COLLAPSED to one delimited column,
        // and the change was FORCED rather than chosen: a one-hot export has no
        // column for a user-defined observation, so the moment someone adds
        // "Dizzy" the value vanishes from the file. Silent loss in the artefact a
        // clinician reads. DATA-MODEL.md §6 always required this; user-defined
        // vocabularies made it required NOW rather than at the final stage.
        'observations',
        // And triggers, in the same place the seven columns occupied, so the
        // reading order of the file is unchanged: when, what, how long, how
        // bad, what after, what before, referral, notes.
        'beforehand',
        'referral_required',
        'notes',
      ]);
    });

    test('no emoji reaches the header OR the values', () {
      // Was "stripped from the feelings headers only". There are no feelings
      // headers any more, and the rule moved to where it always belonged: the
      // VALUES. DATA-MODEL.md §6 requires emoji stripped from both, and the
      // legacy strings already render as mojibake in History rows on the tablet.
      //
      // The mechanism is no longer a regex. The CSV writes each observation's
      // LABEL, and a legacy entry's label is its value without the emoji.
      final legacy = EventRecord(
        id: 'e',
        timestamp: DateTime(2026, 8, 22, 18, 0),
          duration: null,
        feelings: const <String>['😵 Confused'],
        referralRequired: false,
        notes: '',
      );
      final csv = buildCsv(<EventRecord>[legacy]);

      for (final option in kFeelingsOptions) {
        expect(csv, isNot(contains(option)),
            reason: 'no raw emoji-bearing string may reach the file');
      }
      // POSITIVE CONTROL: the value IS exported, stripped - so the absence
      // above is a naming fact and not a dropped field.
      expect(csv, contains('Confused'));

      // Triggers carry no emoji and pass through untouched. Only the ones
      // this record HOLDS now - the seven names no longer appear as headers.
      expect(csv, isNot(contains('Poor sleep')),
          reason: 'a trigger this record does not hold has no column any more');
    });
  });
}
