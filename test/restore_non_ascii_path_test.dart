// Brief 248, 29 September 2026: the PATH-backed counterpart of
// restore_non_ascii_test.dart.
//
// ⛔ THE PICKER SERVES A REAL FILE PATH, THE WAY THE DESKTOP AND iOS PICKERS
// DO. Android's picker returns `XFile.fromData(bytes)`, and that is the case
// restore_non_ascii_test.dart pins. Brief 236 A2 recorded iOS, Windows and macOS
// as "believed unaffected" by the decoding defect, because they return a
// path-backed XFile, and `cross_file` decodes a path-backed file as UTF-8. That
// was READ FROM CODE and UNTESTED (28 September 2026). This converts it into a
// test: the same backup and the same non-ASCII values, written to a real file
// as UTF-8 and served by path through the real `restoreFromBackup`.
//
// ⚠️ WHAT THIS PINS AND WHAT IT DOES NOT. It pins the DART side: given a
// path-backed XFile, `restoreFromBackup` returns every value exactly. It runs in
// a harness on the host, so it says nothing about what a real iOS picker hands
// back. That the iOS picker returns a path is `file_selector_ios`'s behaviour,
// read, not observed here. Measured against the pre-fix code (38bd6a0^), see
// Brief 248 B3.
//
// Kept deliberately identical to restore_non_ascii_test.dart in its payload
// and its checks, so the only difference between the two files is how the
// file is served.

import 'dart:convert';
import 'dart:io';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/services/backup_service.dart';

/// Every kind of text a user or the catalogue puts in a backup. Identical to
/// restore_non_ascii_test.dart.
const String kNotes = 'café, naïve, résumé — don’t “quote” 1–5 min · 発作 😵';
const String kSeededEmoji = '😵 Confused'; //       a seeded (retired) value
const String kSeededEmoji2 = '😢 Sad'; //           another
const String kAlreadyMangled = 'ð\u009f\u0098µ Confused'; // stored on real devices
const String kTrigger = 'Café’s strobe lights';
const String kType = 'Épisode d’absence';
const String kNoteText = 'Missed — dose at 8 o’clock, felt “off”';
const String kCondition = 'Epilepsy — focal ‘aware’';

/// Serves a real file by PATH, the desktop and iOS shape.
class _PathPicker extends FileSelectorPlatform {
  _PathPicker(this.path);
  final String path;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async =>
      XFile(path, name: 'backup.json', mimeType: 'application/json');
}

String backupJson() => jsonEncode(<String, Object?>{
      'format': kBackupFormatId,
      'schemaVersion': kBackupSchemaVersion,
      'appVersion': '1.1.0+60',
      'exportedAt': DateTime(2026, 9, 20, 17, 19).toIso8601String(),
      'records': <Object?>[
        EventRecord(
          id: 'r1',
          timestamp: DateTime(2026, 8, 22, 17),
          duration: DurationCategory.lt1,
          eventType: kType,
          feelings: const <String>[kSeededEmoji, kSeededEmoji2, kAlreadyMangled],
          triggers: const <String>[kTrigger],
          referralRequired: false,
          notes: kNotes,
        ).toMap(),
      ],
      'medicationNotes': <Object?>[
        <String, Object?>{
          'id': 'm1',
          'occurred_at': DateTime(2026, 8, 27, 23, 21).toIso8601String(),
          'logged_at': DateTime(2026, 8, 27, 23, 25).toIso8601String(),
          'kind': 'missed',
          'notes': kNoteText,
        },
      ],
      'conditions': <Object?>[
        <String, Object?>{'name': kCondition, 'seededKey': null, 'isActive': true},
      ],
      'eventTypeConditions': <String, String>{kType: kCondition},
    });

class _Host extends StatelessWidget {
  const _Host({required this.onResult});
  final void Function(RestoreOutcome?) onResult;

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () async =>
                    onResult(await restoreFromBackup(ctx, const <EventRecord>[])),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
}

void main() {
  late Directory tmp;
  late File backup;
  late FileSelectorPlatform original;

  // ⛔ REAL I/O IN setUp, which runs on the real clock (CLAUDE.md, "A
  // testWidgets BODY RUNS ON A FAKE CLOCK").
  setUp(() async {
    original = FileSelectorPlatform.instance;
    tmp = await Directory.systemTemp.createTemp('mer_b248_');
    backup = File('${tmp.path}${Platform.pathSeparator}backup.json');
    await backup.writeAsBytes(utf8.encode(backupJson()), flush: true);
    FileSelectorPlatform.instance = _PathPicker(backup.path);
  });

  tearDown(() async {
    FileSelectorPlatform.instance = original;
    try {
      if (await tmp.exists()) await tmp.delete(recursive: true);
    } catch (_) {}
  });

  testWidgets('a PATH-served restore returns every non-ASCII value exactly',
      (tester) async {
    // CONTROL: the file really holds the multi-byte UTF-8 form, so the test can
    // only pass if the read decodes it as UTF-8.
    final onDisk = await tester.runAsync(() => backup.readAsBytes());
    expect(onDisk, utf8.encode(backupJson()),
        reason: 'CONTROL: the served file holds the backup as UTF-8 bytes');

    RestoreOutcome? out;
    await tester.pumpWidget(_Host(onResult: (r) => out = r));
    print('[b248] 1 tapping go');
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    // The read is real file I/O the fake clock cannot complete, so lend the
    // real clock until the confirm dialog is up. Bounded: if it never appears,
    // the control below fails and names it.
    final confirm =
        find.widgetWithText(FilledButton, 'Restore 1 event and 1 medication note');
    for (var i = 0; i < 20 && confirm.evaluate().isEmpty; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
    }
    print('[b248] 2 dialog up: ${confirm.evaluate().isNotEmpty}');
    expect(confirm, findsOneWidget,
        reason: 'CONTROL: the path-backed file was read and the confirm '
            'dialog came up');
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    print('[b248] 3 restore done: ${out != null}');

    expect(out, isNotNull, reason: 'CONTROL: the restore completed');
    final r = out!.merged.single;

    // ⭐ COLLECTED, NOT THROWN ONE AT A TIME, so a failing run names EVERY
    // field that broke. Identical checks to restore_non_ascii_test.dart.
    final wrong = <String>[];
    void check(String field, Object? got, Object? want) {
      if (jsonEncode(got) != jsonEncode(want)) {
        wrong.add('$field: got ${jsonEncode(got)}, want ${jsonEncode(want)}');
      }
    }

    check('NOTES (accents, curly quotes, dash, CJK, emoji)', r.notes, kNotes);
    check('OBSERVATIONS (seeded emoji; the mangled value stays as it was)',
        r.feelings, const <String>[kSeededEmoji, kSeededEmoji2, kAlreadyMangled]);
    check('TRIGGERS', r.triggers, const <String>[kTrigger]);
    check('EVENT TYPE', r.eventType, kType);
    check('MEDICATION NOTE', out!.notesToAdd.single.notes, kNoteText);
    check('CONDITION', out!.conditionsToAdd.single.name, kCondition);
    check('TYPE MAP (key and value)', out!.typeAssignmentsToAdd,
        <String, String>{kType: kCondition});
    print('[b248] 4 fields wrong: ${wrong.length}');
    expect(wrong, isEmpty,
        reason: 'every non-ASCII value must restore byte-identical:\n'
            '${wrong.join('\n')}');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
