import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/backup.dart';
import 'package:medical_event_recorder/models/condition.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/medication_note.dart';
import 'package:medical_event_recorder/models/vocabulary.dart';

/// Multi-condition pass 3: the attribution enters the backup envelope.
///
/// ## ⛔ THE DEFECT
///
/// Attribution is DERIVED from a record's event type, so nothing on a record
/// carries it. A restore onto a device with no conditions therefore produced 72
/// records reading `unknown` — and the user had no way to know, because the
/// mapping is something they set once and never see written down.
///
/// **Lost preference, not lost records** — restatable in one screen, which is
/// why this was pass 3 rather than urgent. But SILENT is the property that
/// matters, and it was silent. That is the argument that put medication notes
/// in the envelope, applied again.
///
/// ## ⛔ NO IDS TRAVEL, AND THAT DECIDES THE WHOLE SHAPE
///
/// `condition.id` is AUTOINCREMENT and therefore LOCAL. It means nothing on the
/// target, which mints its own. So conditions travel as NAMES and the mapping
/// keys on the name — which is also what makes merge natural, since
/// `addCondition` already matches case-insensitively by name.

Condition cond(int id, String name, {int sort = 0}) =>
    Condition(id: id, name: name, sortOrder: sort);

VocabularyEntry type(String value, {int? conditionId}) => VocabularyEntry(
      id: value.hashCode,
      value: value,
      label: value,
      isSeeded: true,
      isActive: true,
      isProtected: false,
      sortOrder: 0,
      conditionId: conditionId,
    );

EventRecord rec(String id, String? t) => EventRecord(
      id: id,
      timestamp: DateTime(2026, 8, 20, 9),
      duration: null,
      feelings: const <String>[],
      triggers: const <String>[],
      referralRequired: false,
      notes: '',
      eventType: t,
    );

/// The envelope EXACTLY as schema 2 wrote it — conditions absent entirely.
/// Written out rather than produced by flipping a flag: the fixture lesson,
/// eighth time in view.
String schema2Envelope(List<EventRecord> records) =>
    const JsonEncoder.withIndent('  ').convert({
      'format': kBackupFormatId,
      'schemaVersion': 2,
      'appVersion': '1.1.0+50',
      'exportedAt': DateTime(2026, 8, 29, 12).toIso8601String(),
      'recordCount': records.length,
      'records': records.map((e) => e.toMap()).toList(),
      'medicationNoteCount': 0,
      'medicationNotes': <Object?>[],
    });

void main() {
  group('THE ROUND TRIP', () {
    test('1. conditions and the mapping survive onto an EMPTY device', () {
      final conditions = <Condition>[cond(1, 'Epilepsy'), cond(2, 'Migraine')];
      final map = eventTypeConditionMap(
        <VocabularyEntry>[
          type('seizure', conditionId: 1),
          type('absence', conditionId: 1),
          type('aura', conditionId: 2),
          type('other'), // unassigned
        ],
        conditions,
      );

      final json = buildBackupJson(<EventRecord>[rec('a', 'seizure')],
          conditions: conditions, eventTypeConditions: map);
      final parsed = parseBackup(json);
      expect(parsed.isValid, isTrue, reason: parsed.message);

      expect(parsed.conditionNames, <String>['Epilepsy', 'Migraine']);
      expect(parsed.eventTypeConditions, <String, String>{
        'seizure': 'Epilepsy',
        'absence': 'Epilepsy',
        'aura': 'Migraine',
      });

      final plan = planRestore(const <EventRecord>[], parsed);
      expect(plan.conditionsToAdd, <String>['Epilepsy', 'Migraine']);
      expect(plan.typeAssignmentsToAdd.length, 3);
    });

    test('2. an UNASSIGNED type is absent from the map, not null in it', () {
      // Writing it as null would put "not said" in the file as though it were
      // said, and the reader cannot tell the two apart afterwards.
      final map = eventTypeConditionMap(
        <VocabularyEntry>[type('seizure', conditionId: 1), type('other')],
        <Condition>[cond(1, 'Epilepsy')],
      );
      expect(map.containsKey('other'), isFalse);
      expect(map, <String, String>{'seizure': 'Epilepsy'});
    });

    test('3. ⛔ NO IDS ARE WRITTEN — they are local and would be wrong', () {
      final json = buildBackupJson(
        const <EventRecord>[],
        conditions: <Condition>[cond(97, 'Epilepsy')],
        eventTypeConditions: const <String, String>{'seizure': 'Epilepsy'},
      );
      final map = jsonDecode(json) as Map<String, dynamic>;
      final written = (map['conditions'] as List).single as Map;

      expect(written.containsKey('id'), isFalse,
          reason: 'condition.id is AUTOINCREMENT and LOCAL. Carrying it would '
              'point at whatever row happens to hold that id on the target');
      expect(written['name'], 'Epilepsy');
      expect(json.contains('97'), isFalse,
          reason: 'the local id must not appear anywhere in the file');
    });
  });

  group('⛔ THE NEGATIVE CONTROL', () {
    test('4. the SCHEMA 2 envelope loses the mapping in the same round trip',
        () {
      // THE CONTROL THIS PASS NEEDS. The defect, reproduced: the exact envelope
      // that shipped yesterday, carrying the same records, through the same
      // restore path.
      final old = schema2Envelope(<EventRecord>[rec('a', 'seizure')]);
      expect(old.contains('eventTypeConditions'), isFalse,
          reason: 'precondition: this fixture really is the pre-fix shape');

      final parsedOld = parseBackup(old);
      final planOld = planRestore(const <EventRecord>[], parsedOld);

      expect(parsedOld.isValid, isTrue,
          reason: 'it parses fine — that is what made the loss silent');
      expect(planOld.inBackup, 1, reason: 'the RECORD restored, so nothing '
          'looked wrong; only the attribution was gone');
      expect(planOld.conditionsToAdd, isEmpty);
      expect(planOld.typeAssignmentsToAdd, isEmpty);

      // THE SAME DATA through the fixed path.
      final fixed = buildBackupJson(
        <EventRecord>[rec('a', 'seizure')],
        conditions: <Condition>[cond(1, 'Epilepsy')],
        eventTypeConditions: const <String, String>{'seizure': 'Epilepsy'},
      );
      final planNew = planRestore(const <EventRecord>[], parseBackup(fixed));

      expect(planNew.conditionsToAdd, <String>['Epilepsy']);
      expect(planNew.typeAssignmentsToAdd.length, 1);
      expect(planNew.conditionsToAdd.length,
          isNot(planOld.conditionsToAdd.length),
          reason: 'THE FIX IS INDISTINGUISHABLE FROM THE DEFECT — if these '
              'match, nothing was actually fixed');
    });
  });

  group('MERGE — EXISTING ALWAYS WINS', () {
    test('5. a condition the target already has is REUSED, not duplicated', () {
      final parsed = parseBackup(buildBackupJson(
        const <EventRecord>[],
        conditions: <Condition>[cond(1, 'Epilepsy'), cond(2, 'Migraine')],
      ));

      final plan = planRestore(const <EventRecord>[], parsed,
          existingConditions: <Condition>[cond(9, 'epilepsy')]);

      expect(plan.conditionsAlreadyPresent, 1,
          reason: 'matched CASE-INSENSITIVELY, the same comparison '
              'addCondition uses — "Epilepsy" must not become a second entry '
              'beside "epilepsy"');
      expect(plan.conditionsToAdd, <String>['Migraine']);
    });

    test('6. ⛔ a type already assigned to a DIFFERENT condition KEEPS its own',
        () {
      // The rule that matters most here. Re-attributing a type would silently
      // move every record carrying it to another condition — the migration
      // this whole design avoids, arriving through the restore path.
      final parsed = parseBackup(buildBackupJson(
        const <EventRecord>[],
        conditions: <Condition>[cond(1, 'Migraine')],
        eventTypeConditions: const <String, String>{'seizure': 'Migraine'},
      ));

      final plan = planRestore(const <EventRecord>[], parsed,
          existingConditions: <Condition>[cond(9, 'Epilepsy')],
          existingTypeConditions: const <String, String>{
            'seizure': 'Epilepsy'
          });

      expect(plan.typeAssignmentsAlreadySet, 1);
      expect(plan.typeAssignmentsToAdd, isEmpty,
          reason: 'RE-ATTRIBUTED. Every record carrying `seizure` would have '
              'silently moved from Epilepsy to Migraine');
    });

    test('7. restoring the same file twice is a no-op', () {
      final conditions = <Condition>[cond(1, 'Epilepsy')];
      const map = <String, String>{'seizure': 'Epilepsy'};
      final parsed = parseBackup(buildBackupJson(const <EventRecord>[],
          conditions: conditions, eventTypeConditions: map));

      final second = planRestore(const <EventRecord>[], parsed,
          existingConditions: conditions, existingTypeConditions: map);

      expect(second.conditionsToAdd, isEmpty);
      expect(second.typeAssignmentsToAdd, isEmpty);
    });
  });

  group('AN OLD BACKUP STILL RESTORES — ABSENCE IS ABSENCE', () {
    test('8. a schema 2 backup parses cleanly, with no conditions', () {
      final parsed = parseBackup(schema2Envelope(<EventRecord>[rec('a', 'seizure')]));

      expect(parsed.problem, isNull, reason: parsed.message);
      expect(parsed.schemaVersion, 2);
      expect(parsed.conditionNames, isEmpty);
      expect(parsed.eventTypeConditions, isEmpty);
      expect(parsed.records.length, 1, reason: 'the records still come through');
    });

    test('9. malformed condition keys degrade to empty, never to a refusal',
        () {
      final map = jsonDecode(schema2Envelope(<EventRecord>[rec('a', 'seizure')]))
          as Map<String, dynamic>;
      map['schemaVersion'] = 3;
      map['conditions'] = 'not a list';
      map['eventTypeConditions'] = <String, Object?>{'seizure': 42};

      final parsed = parseBackup(jsonEncode(map));
      expect(parsed.problem, isNull,
          reason: 'a damaged third stream must not cost the user their records');
      expect(parsed.conditionNames, isEmpty);
      expect(parsed.eventTypeConditions, isEmpty,
          reason: 'a non-string condition name is dropped, not coerced');
      expect(parsed.records.length, 1);
    });

    test('10. a condition with no usable name is SKIPPED', () {
      final map = jsonDecode(buildBackupJson(const <EventRecord>[],
          conditions: <Condition>[cond(1, 'Epilepsy')])) as Map<String, dynamic>;
      (map['conditions'] as List).addAll(<Object?>[
        <String, Object?>{'name': '   '},
        <String, Object?>{'name': null},
        'not even a map',
      ]);

      final parsed = parseBackup(jsonEncode(map));
      expect(parsed.conditionNames, <String>['Epilepsy'],
          reason: 'name is the ONLY thing that survives the id being local, so '
              'a nameless condition cannot be merged and must not be invented');
    });
  });

  group('THE SCHEMA GATE, AND THE EMPTY GATE', () {
    test('11. ⛔ an OLDER build REFUSES a schema 3 backup, cleanly', () {
      // Without the bump an old build would restore the records and drop the
      // attribution — 72 rows reading `unknown` and no way to know. The same
      // silent loss this pass fixes, moved one layer along.
      final map = jsonDecode(buildBackupJson(
        <EventRecord>[rec('a', 'seizure')],
        conditions: <Condition>[cond(1, 'Epilepsy')],
        eventTypeConditions: const <String, String>{'seizure': 'Epilepsy'},
      )) as Map<String, dynamic>;
      map['schemaVersion'] = kBackupSchemaVersion + 1;

      final parsed = parseBackup(jsonEncode(map));
      expect(parsed.problem, BackupProblem.unsupportedSchema);
      expect(parsed.message, contains('newer version'),
          reason: 'the EXISTING gate message, unchanged');
      expect(parsed.records, isEmpty,
          reason: 'a refusal restores nothing at all — not the records with '
              'the attribution quietly missing');
      expect(parsed.conditionNames, isEmpty);
    });

    test('12. conditions alone are correctly NOTHING TO RESTORE', () {
      // ⚠️ A DECISION, not an oversight. `addsNothing` deliberately has no
      // third term. A conditions-only backup is degenerate — conditions travel
      // WITH records in every backup a user would take, and this file could
      // only come from naming a condition and backing up before recording
      // anything.
      //
      // Restoring it would offer "Restore 0 events" on a button that does
      // something, and the snackbar has no noun for it. The refusal is
      // EXPLICIT, which is the property that matters: the loss this pass fixes
      // was silent, and this is not.
      final parsed = parseBackup(buildBackupJson(
        const <EventRecord>[],
        conditions: <Condition>[cond(1, 'Epilepsy')],
        eventTypeConditions: const <String, String>{'seizure': 'Epilepsy'},
      ));
      final plan = planRestore(const <EventRecord>[], parsed);

      expect(plan.conditionsToAdd, isNotEmpty,
          reason: 'the conditions ARE in the plan...');
      expect(plan.addsNothing, isTrue,
          reason: '...and it still adds nothing, because neither RECORD '
              'stream has anything new');
    });

    test('13. but conditions in a records-bearing backup restore normally', () {
      // The other half of 12, and without it that test is satisfied by a
      // build that ignores conditions entirely.
      final parsed = parseBackup(buildBackupJson(
        <EventRecord>[rec('a', 'seizure')],
        notes: <MedicationNote>[],
        conditions: <Condition>[cond(1, 'Epilepsy')],
        eventTypeConditions: const <String, String>{'seizure': 'Epilepsy'},
      ));
      final plan = planRestore(const <EventRecord>[], parsed);

      expect(plan.addsNothing, isFalse);
      expect(plan.conditionsToAdd, <String>['Epilepsy']);
      expect(plan.typeAssignmentsToAdd, <String, String>{
        'seizure': 'Epilepsy'
      });
    });
  });
}
