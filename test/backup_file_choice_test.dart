import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/backup.dart';
import 'package:medical_event_recorder/models/event_record.dart';

/// Choosing the right backup file.
///
/// From a real mis-restore: six backups, indistinguishable in the system
/// picker, and an older one restored over a device holding more. Nothing was
/// lost — merge-only saw to that — but nothing in the flow made the mistake
/// visible either.
///
/// The app cannot say a file is the WRONG one; it has no idea which device
/// wrote it, and deliberately records nothing that would say so. What it CAN
/// show is when the backup was taken — already in the envelope, previously
/// unread — which is what separates two files whose contents overlap.
///
/// A staleness caution was built and removed: see planRestore for why it needs
/// occurred_at and is deferred to the expansion.

EventRecord rec(String id, DateTime ts) => EventRecord(
      id: id,
      timestamp: ts,
      duration: DurationCategory.lt1,
      feelings: const <String>[],
      referralRequired: false,
      notes: '',
      eventType: kTypeSeizure,
      severity: EventSeverity.mild,
      triggers: const <String>[],
    );

/// A backup envelope, built the way the app builds one.
String envelope(List<EventRecord> records, DateTime exportedAt) =>
    buildBackupJson(records, exportedAt: exportedAt);

void main() {
  final older = DateTime(2026, 8, 20, 9, 0);

  group('the envelope is read, not extended', () {
    test('1. exportedAt reaches the plan', () {
      final stamp = DateTime(2026, 8, 25, 14, 22, 2);
      final parsed = parseBackup(envelope([rec('a', older)], stamp));

      final plan = planRestore(const <EventRecord>[], parsed);

      expect(plan.exportedAt, stamp,
          reason: 'the signal the picker cannot show');
    });

    test('2. no key was added to the envelope', () {
      final map = jsonDecode(envelope([rec('a', older)], older))
          as Map<String, dynamic>;

      expect(map.keys.toSet(), {
        'format',
        'schemaVersion',
        'appVersion',
        'exportedAt',
        'recordCount',
        'records',
        // ⛔ ADDED AT SCHEMA 2, and the exact-set assertion is KEPT rather than
        // loosened to "contains" — it is what catches an accidental addition,
        // and loosening it to accommodate a deliberate one would retire the
        // check on its first real outing.
        //
        // THE RULE, restated because the list alone stopped carrying it: this
        // file holds the USER'S OWN health data and nothing about their DEVICE.
        // Medication notes are the former. A device identifier, an install id,
        // a location or a diagnostic field is the latter and still may not go
        // in — these files get emailed around.
        'medicationNoteCount',
        'medicationNotes',
        // ADDED AT SCHEMA 3. Conditions and the type mapping. Still the user's
        // own data: what they track, and which of their event types belong to
        // it. Nothing about the DEVICE — and note there are no condition IDS
        // here, because those are AUTOINCREMENT and local, so they would be
        // meaningless on the machine that reads this file.
        'conditionCount',
        'conditions',
        'eventTypeConditions',
      }, reason: 'the user data, and nothing about the device');
    });
  });

  group('old filenames still restore', () {
    test('3. a backup parses on content, whatever it is called', () {
      // The rename is cosmetic BY DESIGN. Restore filters by extension and
      // validates by the envelope's `format` field, so a file written under the
      // old long name parses identically — the name never reaches the parser.
      final json = envelope([rec('legacy', older)], older);

      final parsed = parseBackup(json);

      expect(parsed.problem, isNull, reason: parsed.message);
      expect(parsed.records.single.id, 'legacy');
    });

    test('4. positive control: a genuinely invalid envelope IS refused', () {
      // Proves test 3 is asserting something. If parseBackup accepted
      // everything, "the old format still restores" would be vacuous.
      final parsed = parseBackup('{"format":"not-a-mer-backup"}');

      expect(parsed.problem, isNotNull);
      expect(parsed.records, isEmpty);
    });
  });

  group('the restore path never matches on a filename', () {
    // The prefix was shortened from medical_event_recorder_backup_ to
    // mer_backup_ on the strength of this property. If anything ever starts
    // matching on the name, every file written under the old prefix stops
    // restoring — six exist across two devices — and it fails silently, at the
    // moment someone needs their history back.
    const restorePath = <String>[
      'lib/services/backup_service.dart',
      'lib/models/backup.dart',
    ];
    const nameMatchers = <String>[
      'medical_event_recorder_backup',
      '.startsWith(',
      'basename(',
    ];

    /// Code only: the filename GENERATOR and the doc comments around it name
    /// the file legitimately. Only matching is forbidden.
    List<String> codeLines(String src) => const LineSplitter()
        .convert(src)
        .where((l) => !l.trimLeft().startsWith('//'))
        .where((l) => !l.contains('_backupFilename'))
        .toList();

    test('5. no filename matching in the restore path', () {
      final offenders = <String>[];
      var scanned = 0;

      for (final rel in restorePath) {
        final f = File(rel);
        expect(f.existsSync(), isTrue, reason: '$rel is named here but absent');
        final code = codeLines(f.readAsStringSync()).join('\n');
        scanned++;
        for (final m in nameMatchers) {
          if (code.contains(m)) offenders.add('$rel: $m');
        }
      }

      expect(offenders, isEmpty,
          reason: 'restore must identify a backup by the envelope format '
              'field, never by its name. Scanned $scanned files.');
    });

    test('6. positive control: the scan reads the files and can match', () {
      // Without this, test 5 passes just as well when the scan is broken —
      // an empty read and a clean corpus produce the same empty result.
      final code =
          codeLines(File('lib/models/backup.dart').readAsStringSync()).join('\n');

      expect(code, contains('kBackupFormatId'),
          reason: 'the scan can read a file and find a token known to be in it');
      expect(code, isNot(contains('medical_event_recorder_backup')));
    });
  });
}
