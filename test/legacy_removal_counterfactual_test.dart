import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/vocabulary.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';

/// WHAT REMOVING THE LEGACY VOCABULARY ENTRIES WOULD DO.
///
/// Built as a fixture rather than argued, because the claim it tests is a
/// claim about a FALLBACK PATH — and a fallback is exactly the kind of thing
/// that is easy to reason about wrongly and cheap to measure.
///
/// The proposition under test: "nothing enumerates the stored strings, so a
/// record holding a legacy value renders it, search finds it and the CSV
/// exports it, all WITHOUT the entry existing."
///
/// The first half is true. The second half is what this measures.

/// The value three real records on the tablet actually hold. The glyph is
/// INSIDE the stored string — it is not decoration beside it.
const String kLegacyConfused = '\u{1F635} Confused';

EventRecord legacyRecord() => EventRecord(
      id: 'legacy',
      timestamp: DateTime(2026, 8, 22, 20, 38),
      duration: null,
      eventType: 'seizure',
      severity: EventSeverity.mild,
      feelings: const <String>[kLegacyConfused],
      referralRequired: false,
      notes: '',
    );

/// The observations cell of the single data row.
/// ⚠️ INDEX 8, not 7 — `record_kind` landed at index 3 when the export went
/// multi-stream, shifting everything after it by one.
String observationsCell(String csv) => csvCell(csv, 'observations');

void main() {
  setUp(Vocabularies.debugReset);
  tearDown(Vocabularies.debugReset);

  test('1. AS SHIPPED: the legacy entry resolves the value to a clean label',
      () {
    // The state on the device right now, and the state this test exists to
    // protect. Verified against a real export the same day: three records hold
    // this value and the column reads "Confused" with no character above
    // U+2000 anywhere in it.
    expect(observationsCell(buildCsv(<EventRecord>[legacyRecord()])),
        'Confused');
  });

  test('2. COUNTERFACTUAL: with the legacy entries gone, the GLYPH is exported',
      () {
    // The proposed change, applied. Only the retired entries are removed —
    // the revised set stays exactly as shipped, so this isolates the one
    // variable.
    Vocabularies.debugSet(
      observations: kSeedObservations
          .map((s) => VocabularyEntry(
                id: kSeedObservations.indexOf(s) + 1,
                value: s.value,
                label: s.label,
                isSeeded: true,
                isActive: s.isActive,
                isProtected: s.isProtected,
                sortOrder: kSeedObservations.indexOf(s),
                emoji: s.emoji,
              ))
          .toList(),
    );

    final cell = observationsCell(buildCsv(<EventRecord>[legacyRecord()]));

    // NOT "Confused". `labelForValue` falls back to the raw stored value when
    // no entry matches, and the raw stored value carries the emoji.
    expect(cell, kLegacyConfused);
    expect(cell, isNot('Confused'));
    expect(cell.runes.any((r) => r > 0x2000), isTrue,
        reason: 'an emoji is now in the CSV, which DATA-MODEL.md section 6 '
            'forbids and which the revision existed to prevent');
  });

  test('3. and the SCREEN gets the raw string too, not a glyph-less chip', () {
    // The proposal expects a legacy chip to render "without a glyph", looking
    // "slightly different because it is legacy". The fallback does the
    // OPPOSITE: with no entry there is no `label` and no `emoji` field to
    // separate, so both the picker and the History row receive the whole
    // stored string with the glyph inline.
    //
    // That is the string that rendered as mojibake in History rows on the
    // tablet, which is what the label mechanism was introduced to fix.
    Vocabularies.debugSet(observations: const <VocabularyEntry>[]);

    expect(Vocabularies.labelFor(kObservationTable, kLegacyConfused),
        kLegacyConfused,
        reason: 'History row and CSV');
    expect(Vocabularies.displayFor(kObservationTable, kLegacyConfused),
        kLegacyConfused,
        reason: 'the picker chip');
  });

  test('4. POSITIVE CONTROL: the revised set is unaffected either way', () {
    // Without this, tests 2 and 3 would also pass against a vocabulary that
    // had simply stopped working. The values MER writes today are clean
    // strings, so they resolve identically with or without the legacy rows —
    // which is precisely why the loss is invisible unless you look at a record
    // that predates the revision.
    Vocabularies.debugReset();
    final shipped =
        observationsCell(buildCsv(<EventRecord>[_revised()]));

    Vocabularies.debugSet(observations: const <VocabularyEntry>[]);
    final stripped =
        observationsCell(buildCsv(<EventRecord>[_revised()]));

    expect(shipped, 'Tired');
    expect(stripped, 'Tired');
    expect(shipped, stripped,
        reason: 'the regression is confined to records written before the '
            'revision — 3 of 71 on this device');
  });
}

EventRecord _revised() => EventRecord(
      id: 'new',
      timestamp: DateTime(2026, 8, 27, 9, 0),
      duration: null,
      eventType: 'seizure',
      severity: EventSeverity.mild,
      feelings: const <String>['Tired'],
      referralRequired: false,
      notes: '',
    );

/// The value of a named column in the LAST data row, found by reading the
/// HEADER rather than counting.
///
/// **THIS WAS A HARDCODED INDEX AND IT BROKE TWICE.** It was `[7]` until
/// `record_kind` landed at index 3, and `[8]` until `condition` landed at
/// index 4 - each insert shifting every column after it. The comment
/// explaining the FIRST shift was still sitting there when the second one
/// happened.
///
/// The export's own rule is that the marker tracks the header, precisely
/// because inserted columns move everything after them. A test that counts
/// positions re-learns that on every insert; one that reads the header does
/// not.
String csvCell(String csv, String column) {
  final lines = csv.trim().split('\n');
  final header = lines.first.replaceFirst('﻿', '').split(',');
  final i = header.indexOf(column);
  if (i < 0) {
    throw StateError('no "$column" column in the export: $header');
  }
  return lines.last.split(',')[i];
}
