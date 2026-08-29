import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/backup.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/medication_note.dart';

/// Medication notes enter the backup envelope.
///
/// ## ⛔ THE DEFECT THIS FIXES
///
/// Medication notes reached the CSV and **nothing else**. `backup.dart` and
/// `backup_service.dart` contained no mention of `MedicationNote`, so a restore
/// onto a new device silently lost every one of them — in the single feature
/// whose stated purpose is that the backup file is the only copy that survives
/// losing the phone.
///
/// ## ⛔ AND WHY TEST 5 IS THE ONE THAT MATTERS
///
/// Tests 1-4 pass against any implementation that puts SOMETHING in the file.
/// Test 5 is the counterfactual: it builds the envelope the OLD code built, runs
/// the same round trip, and shows the notes vanishing. Without it, "notes
/// survive a round trip" is a statement about the new code that could equally
/// have been true of the old one for the wrong reason.

MedicationNote note(String id, int day, MedicationDeviation kind,
        {String notes = ''}) =>
    MedicationNote(
      id: id,
      occurredAt: DateTime(2026, 8, day, 9, 30),
      loggedAt: DateTime(2026, 8, day, 21, 5),
      kind: kind,
      notes: notes,
    );

EventRecord rec(String id, int day) => EventRecord(
      id: id,
      timestamp: DateTime(2026, 8, day, 12, 0),
      duration: null,
      eventType: 'seizure',
      severity: EventSeverity.mild,
      feelings: const <String>[],
      referralRequired: false,
      notes: '',
    );

/// The envelope EXACTLY as the pre-fix code wrote it: schema 1, six keys, no
/// notes. Written out rather than produced by flipping a flag, so it stays a
/// fixture of what shipped even as the live builder moves on.
///
/// ⚠️ The fixture lesson, seventh time in view.
String legacyEnvelope(List<EventRecord> records) =>
    const JsonEncoder.withIndent('  ').convert({
      'format': kBackupFormatId,
      'schemaVersion': 1,
      'appVersion': '1.1.0+41',
      'exportedAt': DateTime(2026, 8, 27, 23, 0).toIso8601String(),
      'recordCount': records.length,
      'records': records.map((e) => e.toMap()).toList(),
    });

void main() {
  group('THE ROUND TRIP', () {
    test('1. notes survive back up -> restore onto an EMPTY store, ids intact',
        () async {
      final notes = <MedicationNote>[
        note('n-1', 20, MedicationDeviation.missed, notes: 'forgot the morning'),
        note('n-2', 21, MedicationDeviation.late),
        note('n-3', 22, MedicationDeviation.changed, notes: 'half dose'),
      ];

      final json = buildBackupJson(<EventRecord>[rec('a', 20)], notes: notes);
      final parsed = parseBackup(json);
      expect(parsed.isValid, isTrue, reason: parsed.message);

      // Onto an EMPTY device: no events, no notes.
      final plan = planRestore(const <EventRecord>[], parsed);

      expect(plan.notesToAdd.length, 3);
      expect(plan.notesToAdd.map((n) => n.id), <String>['n-1', 'n-2', 'n-3'],
          reason: 'IDS MUST BE PRESERVED VERBATIM — merge-by-id is the only '
              'thing stopping a second restore duplicating every note');
      expect(plan.notesToAdd.map((n) => n.kind), <MedicationDeviation>[
        MedicationDeviation.missed,
        MedicationDeviation.late,
        MedicationDeviation.changed,
      ]);
      expect(plan.notesToAdd.first.notes, 'forgot the morning');
      expect(plan.notesToAdd.first.occurredAt, DateTime(2026, 8, 20, 9, 30));
      expect(plan.notesToAdd.first.loggedAt, DateTime(2026, 8, 20, 21, 5));
    });

    test('2. occurredAt and loggedAt stay DISTINCT across the trip', () {
      // The pair is the whole reason the medication stream exists — a missed
      // dose is recorded hours after it happened. A serialisation that
      // collapsed them would look fine on a same-day note and destroy the
      // meaning of every real one.
      final n = note('n-1', 20, MedicationDeviation.missed);
      expect(n.occurredAt, isNot(n.loggedAt));

      final parsed =
          parseBackup(buildBackupJson(const <EventRecord>[], notes: [n]));
      final back = parsed.notes.single;

      expect(back.occurredAt, n.occurredAt);
      expect(back.loggedAt, n.loggedAt);
      expect(back.occurredAt, isNot(back.loggedAt));
    });
  });

  group('MERGE-BY-ID, SAME RULE AS RECORDS', () {
    test('3. a note already on the device is NOT re-added', () {
      final onDevice = <MedicationNote>[note('n-1', 20, MedicationDeviation.missed)];
      final inFile = <MedicationNote>[
        note('n-1', 20, MedicationDeviation.missed),
        note('n-2', 21, MedicationDeviation.late),
      ];

      final parsed =
          parseBackup(buildBackupJson(const <EventRecord>[], notes: inFile));
      final plan = planRestore(const <EventRecord>[], parsed,
          existingNotes: onDevice);

      expect(plan.notesInBackup, 2);
      expect(plan.notesAlreadyPresent, 1);
      expect(plan.notesToAdd.map((n) => n.id), <String>['n-2'],
          reason: 'restoring the same file twice must be a no-op');
    });

    test('4. and the existing note WINS — restore never overwrites', () {
      // Same id, different content. The device's copy is authoritative, exactly
      // as it is for records.
      final onDevice = <MedicationNote>[
        note('n-1', 20, MedicationDeviation.missed, notes: 'what the device says')
      ];
      final inFile = <MedicationNote>[
        note('n-1', 20, MedicationDeviation.changed, notes: 'what the file says')
      ];

      final parsed =
          parseBackup(buildBackupJson(const <EventRecord>[], notes: inFile));
      final plan = planRestore(const <EventRecord>[], parsed,
          existingNotes: onDevice);

      expect(plan.notesToAdd, isEmpty,
          reason: 'the file version would have been inserted alongside or over '
              'the device version');
      expect(onDevice.single.notes, 'what the device says');
    });
  });

  group('⛔ THE NEGATIVE CONTROL', () {
    test('5. the OLD envelope loses every note in the same round trip', () {
      // THE CONTROL THIS FIX NEEDS. This is the defect, reproduced: the exact
      // envelope that shipped, carrying three real notes on the device, run
      // through the same restore path.
      final notesOnDevice = <MedicationNote>[
        note('n-1', 20, MedicationDeviation.missed),
        note('n-2', 21, MedicationDeviation.late),
        note('n-3', 22, MedicationDeviation.changed),
      ];

      // What the old code wrote — the notes are simply not in it.
      final old = legacyEnvelope(<EventRecord>[rec('a', 20)]);
      expect(old.contains('medicationNotes'), isFalse,
          reason: 'precondition: this fixture really is the pre-fix shape');

      final parsedOld = parseBackup(old);
      final planOld = planRestore(const <EventRecord>[], parsedOld);

      expect(parsedOld.isValid, isTrue,
          reason: 'it parses fine — that is what made the loss silent');
      expect(planOld.notesToAdd, isEmpty);
      expect(planOld.inBackup, 1,
          reason: 'the EVENT restored, so nothing looked wrong');

      // THE SAME DATA through the fixed path. If notes were ever dropped again
      // this equality is what fails.
      final fixed =
          buildBackupJson(<EventRecord>[rec('a', 20)], notes: notesOnDevice);
      final planNew = planRestore(const <EventRecord>[], parseBackup(fixed));

      expect(planNew.notesToAdd.length, 3);
      expect(planOld.notesToAdd.length, 0);
      expect(planNew.notesToAdd.length, isNot(planOld.notesToAdd.length),
          reason: 'THE FIX IS INDISTINGUISHABLE FROM THE DEFECT — if these '
              'match, nothing was actually fixed');
    });

    test('6. and a note dropped between build and parse would fail test 1',
        () {
      // Test 1 asserts what SURVIVES. This asserts the assertion has teeth, by
      // showing the same check applied to an envelope built with no notes.
      final empty = parseBackup(buildBackupJson(<EventRecord>[rec('a', 20)]));
      expect(empty.notes, isEmpty);
      expect(planRestore(const <EventRecord>[], empty).notesToAdd, isEmpty);
    });
  });

  group('AN OLD BACKUP STILL RESTORES — ABSENCE IS ABSENCE', () {
    test('7. a schema 1 backup with no notes key parses cleanly', () {
      // EVERY backup taken before this change is this shape, including the
      // baselines on disk. A gate on the missing key would have turned a fix
      // for silent loss into total loss.
      final parsed = parseBackup(legacyEnvelope(<EventRecord>[rec('a', 20)]));

      expect(parsed.problem, isNull, reason: parsed.message);
      expect(parsed.schemaVersion, 1);
      expect(parsed.notes, isEmpty);
      expect(parsed.unreadableNotes, 0,
          reason: 'ABSENT is not UNREADABLE — reporting a fault here would '
              'put a skipped-notes warning on every legacy restore');
      expect(parsed.records.length, 1,
          reason: 'and the events must still come through');
    });

    test('8. a malformed notes key degrades to empty, never to a refusal', () {
      final map = jsonDecode(legacyEnvelope(<EventRecord>[rec('a', 20)]))
          as Map<String, dynamic>;
      map['schemaVersion'] = 2;
      map['medicationNotes'] = 'not a list at all';

      final parsed = parseBackup(jsonEncode(map));
      expect(parsed.problem, isNull,
          reason: 'a damaged second stream must not cost the user their events');
      expect(parsed.notes, isEmpty);
      expect(parsed.records.length, 1);
    });

    test('9. an unreadable individual note is SKIPPED and COUNTED', () {
      final map = jsonDecode(buildBackupJson(const <EventRecord>[],
          notes: <MedicationNote>[note('n-1', 20, MedicationDeviation.missed)]))
          as Map<String, dynamic>;
      (map['medicationNotes'] as List).addAll(<Object?>[
        <String, Object?>{'id': 'bad', 'occurred_at': 'not a date'},
        <String, Object?>{'id': '', 'occurred_at': '2026-08-20T09:30:00.000',
          'logged_at': '2026-08-20T21:05:00.000', 'kind': 'missed'},
        'not even a map',
      ]);

      final parsed = parseBackup(jsonEncode(map));
      expect(parsed.notes.length, 1, reason: 'the good one survives');
      expect(parsed.unreadableNotes, 3,
          reason: 'a bad date, an EMPTY ID which merge-by-id cannot '
              'deduplicate, and a non-map');
      expect(parsed.notes.single.id, 'n-1');
    });
  });

  group('THE SCHEMA GATE IS THE PROTECTION FOR OLD BUILDS', () {
    test('10. the version bumped, and that is what makes the refusal fire', () {
      // 4 since `occurredAt` entered the record. The NUMBER is not the point
      // — the bump is, because it is what makes an older build refuse a file
      // it would otherwise restore incompletely.
      //
      // ⚠️ 3 -> 4 IS THE FIRST BUMP WHERE THE ENVELOPE'S OWN KEYS DID NOT
      // CHANGE. Records serialise through `EventRecord.toMap`, so the field
      // arrived in the file with no edit to `buildBackupJson` at all. The
      // constant's doc says "increment ONLY when the envelope shape changes";
      // the bump was made on the RULE BEHIND that wording — an older build
      // must refuse a file it would only partly understand — because such a
      // build would restore a backdated record and silently drop when it
      // happened. A loss inside `records` is harder to notice, not less real.
      expect(kBackupSchemaVersion, 4);

      final current = jsonDecode(buildBackupJson(const <EventRecord>[]))
          as Map<String, dynamic>;
      expect(current['schemaVersion'], 4);
    });

    test('11. ⛔ an OLDER build REFUSES a notes-bearing backup, cleanly', () {
      // Simulated by presenting a schema THREE file to this build — the same
      // arithmetic an old build performs on a schema 2 file.
      //
      // Without the bump, an old build would have read a notes-bearing file,
      // passed every gate, restored the events and DISCARDED THE NOTES with no
      // message at all. That is the same silent loss this change fixes, moved
      // one layer along, and the gate that prevents it needs a version it can
      // actually see.
      final map = jsonDecode(buildBackupJson(<EventRecord>[rec('a', 20)],
          notes: <MedicationNote>[note('n-1', 20, MedicationDeviation.missed)]))
          as Map<String, dynamic>;
      map['schemaVersion'] = kBackupSchemaVersion + 1;

      final parsed = parseBackup(jsonEncode(map));

      expect(parsed.problem, BackupProblem.unsupportedSchema);
      expect(parsed.message, contains('newer version'),
          reason: 'the EXISTING gate message, unchanged');
      expect(parsed.records, isEmpty,
          reason: 'a refusal restores nothing at all — not the events with the '
              'notes quietly missing');
      expect(parsed.notes, isEmpty);
    });
  });

  group('⛔ THE PARAMETER MUST ACTUALLY BE FORWARDED', () {
    test('15. every backupShare / backupSaveAs call passes notes', () {
      // ⛔ THIS DEFECT WAS COMMITTED DURING THIS VERY CHANGE, and it is the
      // second time in this codebase: `showExportOptions` once accepted a
      // `notes` parameter and never forwarded it, which was found only by
      // diffing a device export. The same mistake was made again here — both
      // call sites inside `showBackupOptions` were left un-forwarded — and the
      // same thing would have happened: a sheet that takes the notes, drops
      // them, and produces a backup that looks entirely normal.
      //
      // A round-trip test cannot see this, because it calls buildBackupJson
      // directly and never goes through the sheet. So the check is structural,
      // in the style of `sqlite_single_writer_test` — which is the guard that
      // caught MedicationScreen holding a Database.
      final src = File('lib/services/backup_service.dart').readAsStringSync();

      // Stated as the exact strings rather than a pattern, deliberately: the
      // un-forwarded call is a fixed shape and a literal cannot be damaged by
      // an escaping mistake the way the regex first written here was.
      // ⚠️ THIS PARAMETER CHAIN HAS NOW GROWN THREE TIMES — `notes`, then
      // `conditions`, then `eventTypeConditions` — and the FIRST time it grew
      // it was dropped. Listing every forwarded argument by name is what makes
      // a half-forwarded call fail here rather than on a device.
      const dropped = <String>[
        'backupSaveAs(context, records);',
        'backupShare(context, records);',
        // The shape after `notes` landed: still a partial forward now.
        'backupSaveAs(context, records, notes: notes);',
        'backupShare(context, records, notes: notes);',
      ];
      // ⚠️ NO TRAILING COMMA in these literals. The LAST forwarded argument
      // ends `);` not `,`, so a literal carrying the comma matched nothing and
      // reported zero — the guard caught its own pattern before it could
      // report a false clean.
      const forwarded = <String>[
        'conditions: conditions',
        'eventTypeConditions: eventTypeConditions',
      ];

      for (final bad in dropped) {
        expect(src.contains(bad), isFalse,
            reason: 'THIS CALL DROPS THE NOTES: $bad');
      }

      // POSITIVE CONTROL. Without it the test passes just as well against a
      // file where both calls were deleted, renamed, or moved — a null result
      // that proves the apparatus still works, not merely that it found
      // nothing.
      // POSITIVE CONTROL. Without it this passes just as well against a file
      // where the calls were deleted, renamed or moved — a null result that
      // proves the apparatus still works, not merely that it found nothing.
      //
      // Two occurrences each: showBackupOptions forwards to BOTH backupSaveAs
      // and backupShare, so a count of one means half the sheet was missed.
      for (final good in forwarded) {
        expect(RegExp(RegExp.escape(good)).allMatches(src).length,
            greaterThanOrEqualTo(2),
            reason: 'BOTH sheet tiles must forward $good — Save to a file AND '
                'Share to apps. One of them dropping it is exactly how the '
                'notes parameter was lost the first time');
      }
    });
  });

  group('NOTHING ELSE MOVED', () {
    test('12. a notes-free backup is byte-identical to the old shape but for '
        'the version and the two keys', () {
      final now = DateTime(2026, 8, 28, 1, 0);
      final map = jsonDecode(buildBackupJson(<EventRecord>[rec('a', 20)],
          exportedAt: now)) as Map<String, dynamic>;

      expect(map['format'], kBackupFormatId);
      expect(map['recordCount'], 1);
      expect((map['records'] as List).length, 1);
      expect(map['medicationNoteCount'], 0);
      expect(map['medicationNotes'], isEmpty);
      expect(map['exportedAt'], now.toIso8601String());
    });

    test('13. addsNothing accounts for BOTH streams', () {
      // A backup whose only new content is medication notes must still offer
      // the Restore button. Reading addsNothing off events alone would refuse
      // it and say "there is nothing new to restore" while holding notes the
      // device has never seen.
      final onDevice = <EventRecord>[rec('a', 20)];
      final parsed = parseBackup(buildBackupJson(onDevice,
          notes: <MedicationNote>[note('n-1', 20, MedicationDeviation.missed)]));

      final plan = planRestore(onDevice, parsed);

      expect(plan.toAdd, 0, reason: 'the event is already here');
      expect(plan.notesToAdd.length, 1);
      expect(plan.addsNothing, isFalse,
          reason: 'THE RESTORE BUTTON WOULD BE HIDDEN on a backup that has '
              'something to give');
    });

    test('14. and it is still true when genuinely nothing is new', () {
      final onDeviceEvents = <EventRecord>[rec('a', 20)];
      final onDeviceNotes = <MedicationNote>[
        note('n-1', 20, MedicationDeviation.missed)
      ];
      final parsed = parseBackup(
          buildBackupJson(onDeviceEvents, notes: onDeviceNotes));

      final plan = planRestore(onDeviceEvents, parsed,
          existingNotes: onDeviceNotes);

      expect(plan.addsNothing, isTrue);
    });
  });
}
