import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/capture_inbox.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/capture_instruction.dart';

/// ⛔ THE REBUILD PATHS MUST NOT DESTROY FIELDS THEY DO NOT KNOW ABOUT.
///
/// Two places construct a NEW `EventRecord` from an existing one to change one
/// value: `capture_inbox.dart` (an end instruction supplying a duration) and
/// `ios_capture_bridge.dart` (recovering a duration). `ios_capture_bridge`
/// states the hazard in its own comment — *"every field it does not set is a
/// field it destroys"* — and both were nonetheless incomplete.
///
/// ## 🔴 WHAT THIS FOUND, AND IT PREDATES THE PASS THAT ADDED THE FILE
///
/// `216bef7` added `rescueMedGiven`, `rescueMedHelped` and
/// `rescueMedSecondDose` to `EventRecord` **and updated neither rebuild path**.
/// Nothing tested it. So a user who walked the wizard and recorded a rescue
/// dose, whose end instruction then drained afterwards — the exact ordering
/// `capture_inbox`'s own comment describes as expected — had all three fields
/// silently reset to null.
///
/// ## ⭐ WHY THIS COMPARES MAPS RATHER THAN LISTING FIELDS
///
/// A test that asserts `rescueMedGiven` survives would have to be extended by
/// hand for every future field, which is the failure that caused this. Comparing
/// the whole `toMap()` and excluding only the keys the path is MEANT to change
/// means **a field added tomorrow is covered by this test the day it lands**,
/// without anyone remembering. The exclusion is named and small; everything else
/// must be identical.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Every nullable field populated, so an omission shows up as a difference
  /// rather than as null-equals-null.
  EventRecord full(String id) => EventRecord(
        id: id,
        timestamp: DateTime(2026, 8, 22, 18, 30),
        occurredAt: DateTime(2026, 8, 20, 9, 15),
        duration: DurationCategory.lt1,
        durationSeconds: null,
        detailsCompleted: true,
        feelings: const <String>['Tired'],
        triggers: const <String>['Stress'],
        referralRequired: true,
        notes: 'a note',
        eventType: 'seizure',
        severity: EventSeverity.moderate,
        rescueMedGiven: true,
        rescueMedHelped: RescueResponse.helped,
        rescueMedSecondDose: false,
        // NON-DEFAULT ON PURPOSE -- see the header: a field left at its
        // default compares equal to a rebuild that destroyed it.
        hidden: true,
      );

  setUp(() => SharedPreferences.setMockInitialValues(<String, Object>{}));

  test('1. a drained END instruction changes ONLY the duration', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = EventStore();
    final before = full('x');
    await store.save(<EventRecord>[before]);

    await writeEndInstruction(prefs,
        id: 'x', at: DateTime(2026, 8, 22, 18, 30), seconds: 187);

    final outcome = await drainInbox(
      transport: PrefsInboxTransport(prefs),
      store: store,
      loaded: await store.load(),
    );
    expect(outcome.wrote, isTrue);

    final raw = prefs.getString(kEventStorageKey)!;
    final after = EventRecord.fromMap(
        (jsonDecode(raw) as List<dynamic>).first as Map<String, dynamic>)!;

    // The one field this path exists to set.
    expect(after.durationSeconds, 187);

    // ⛔ EVERYTHING ELSE, compared as a whole. TWO exclusions as of v11, both
    // named here rather than being items on a list nobody maintains.
    //
    // ⚠️ `updatedAt` JOINED THE EXCLUSIONS BECAUSE THE DRAIN IS SUPPOSED TO
    // CHANGE IT. An end instruction is a user action — somebody tapped End on
    // a notification, a Live Activity, or the in-app banner — and the rule is
    // that it stamps the INSTRUCTION'S `at`. Demanding it unchanged here would
    // be demanding the field not work.
    //
    // ⭐ That it is stamped from the instruction and not from `now` has its own
    // control, in `updated_at_drain_end_test.dart`.
    expect(after.updatedAt, isNotNull,
        reason: 'positive control: the drain stamped it, so excluding it below '
            'excludes something that actually changed');
    final b = before.toMap()
      ..remove('durationSeconds')
      ..remove('updatedAt');
    final a = after.toMap()
      ..remove('durationSeconds')
      ..remove('updatedAt');
    expect(a, b,
        reason: 'the rebuild destroyed a field it was not meant to touch');
  });

  test('2. NAMED EXPLICITLY: the fields that were actually being lost',
      () async {
    // Test 1 is the durable guard. This one states what was broken, so a
    // reader of the history knows this file is not hypothetical.
    final prefs = await SharedPreferences.getInstance();
    final store = EventStore();
    await store.save(<EventRecord>[full('y')]);
    await writeEndInstruction(prefs,
        id: 'y', at: DateTime(2026, 8, 22, 18, 30), seconds: 90);

    await drainInbox(
      transport: PrefsInboxTransport(prefs),
      store: store,
      loaded: await store.load(),
    );

    final raw = prefs.getString(kEventStorageKey)!;
    final after = EventRecord.fromMap(
        (jsonDecode(raw) as List<dynamic>).first as Map<String, dynamic>)!;

    expect(after.rescueMedGiven, isTrue,
        reason: 'lost since 216bef7 — a rescue dose the user recorded');
    expect(after.rescueMedHelped, RescueResponse.helped,
        reason: 'lost since 216bef7');
    expect(after.rescueMedSecondDose, isFalse, reason: 'lost since 216bef7');
    expect(after.occurredAt, DateTime(2026, 8, 20, 9, 15),
        reason: 'would have been the fourth field lost the same way');
  });

  /// ⛔ THE SAME HAZARD ONE STEP EARLIER: a field that is not destroyed on the
  /// way through, but arrives WRONG on the way in.
  ///
  /// Two independent statements of "what this field is when nobody said" exist
  /// for every optional field — the constructor's default parameter value, and
  /// `fromMap`'s own fallback for an absent key. Nothing makes them agree.
  ///
  /// ## ⚠️ WHY AN ABSENT KEY IS REACHABLE AT ALL
  ///
  /// `toMap` writes every key, including nulls, deliberately — so a payload
  /// this app wrote never exercises a fallback. **The legacy App Group mirror
  /// is the exception**: `reconcileLegacySharedRecords` parses records written
  /// by an older build, and a key that build did not have is simply absent.
  /// That read takes `fromMap`'s fallback, not the constructor's default, and
  /// a divergence between the two would appear on that path ONLY.
  ///
  /// ## ⭐ WHY THIS COMPARES WHOLE MAPS RATHER THAN LISTING FIELDS
  ///
  /// Same reason as test 1. The six REQUIRED constructor parameters have no
  /// default to disagree with, so they are supplied identically on both sides
  /// and thereby pinned out of the comparison; everything left is exactly the
  /// optional set. A new optional field is compared the day it lands, and a
  /// new required one breaks this file's compilation rather than passing
  /// silently.
  test('3. fromMap\'s absent-key fallback equals the constructor default, '
      'for every field', () {
    final t = DateTime(2026, 8, 22, 18, 30);

    // The required six, and nothing else. Values are arbitrary and identical
    // on both sides — they exist to pin, not to assert.
    final viaConstructor = EventRecord(
      id: 'x',
      timestamp: t,
      duration: DurationCategory.lt1,
      feelings: const <String>[],
      referralRequired: false,
      notes: '',
    );

    // ⛔ EVERY OPTIONAL KEY OMITTED, which is the whole point: supplying one as
    // an explicit null would test the parse, not the fallback.
    final viaFromMap = EventRecord.fromMap(<String, dynamic>{
      'id': 'x',
      'timestamp': t.toIso8601String(),
      'duration': DurationCategory.lt1.name,
      'feelings': const <String>[],
      'referralRequired': false,
      'notes': '',
    });

    expect(viaFromMap, isNotNull,
        reason: 'positive control: the map must parse at all, or the '
            'comparison below never happens');

    expect(viaFromMap!.toMap(), viaConstructor.toMap(),
        reason: 'an absent key takes fromMap\'s fallback while a fresh record '
            'takes the constructor default — they must not disagree, or the '
            'same record means two things depending on which door it came '
            'through');
  });
}
