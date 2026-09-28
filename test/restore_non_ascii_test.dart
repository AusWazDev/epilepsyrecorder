// Brief 236, 28 September 2026: a restore must return non-ASCII text exactly.
//
// ⛔ THE PICKER SERVES BYTES, THE WAY ANDROID'S DOES. `file_selector_android`
// 0.5.2+4 returns `XFile.fromData(bytes)`, and `cross_file` 0.3.5+2's
// `readAsString` on such a file IGNORES its encoding and decodes Latin-1
// (`String.fromCharCodes`). Measured on the Teclast, Brief 234: 3 of 3 stored
// non-ASCII values came back double-encoded. The contract harness serves a
// PATH instead, which is the desktop and iOS shape and cannot see this.
//
// Drives the real `restoreFromBackup`; nothing here restates its read.

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/services/backup_service.dart';

/// Every kind of text a user or the catalogue puts in a backup.
const String kNotes = 'café, naïve, résumé — don’t “quote” 1–5 min · 発作 😵';
const String kSeededEmoji = '😵 Confused'; //       a seeded (retired) value
const String kSeededEmoji2 = '😢 Sad'; //           another
const String kAlreadyMangled = 'ð\u009f\u0098µ Confused'; // stored on real devices
const String kTrigger = 'Café’s strobe lights';
const String kType = 'Épisode d’absence';
const String kNoteText = 'Missed — dose at 8 o’clock, felt “off”';
const String kCondition = 'Epilepsy — focal ‘aware’';

class _BytesPicker extends FileSelectorPlatform {
  _BytesPicker(this.payload);
  final String payload;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async =>
      XFile.fromData(Uint8List.fromList(utf8.encode(payload)),
          name: 'backup.json', mimeType: 'application/json');
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
  testWidgets('a restore returns every non-ASCII value exactly as backed up',
      (tester) async {
    FileSelectorPlatform.instance = _BytesPicker(backupJson());
    RestoreOutcome? out;
    await tester.pumpWidget(_Host(onResult: (r) => out = r));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Restore 1 event and 1 medication note'));
    await tester.pumpAndSettle();

    expect(out, isNotNull, reason: 'CONTROL: the restore completed');
    final r = out!.merged.single;

    // ⭐ COLLECTED, NOT THROWN ONE AT A TIME, so a failing run names EVERY
    // field that broke. The first `expect` to throw would otherwise mask the
    // rest (CLAUDE.md: a control's failure must be attributable).
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
    expect(wrong, isEmpty,
        reason: 'every non-ASCII value must restore byte-identical:\n'
            '${wrong.join('\n')}');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
