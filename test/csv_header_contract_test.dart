import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';

/// BRIEF 63 — the CSV header row, asserted whole and in order.
///
/// ⛔ **THE EXISTING PINS WERE PARTIAL AND THAT IS WHY THIS EXISTS.**
/// `sweep_contracts_test` pins the column SET against the shape marker;
/// `rescue_medication_test` pins ONE index; `your_data_copy_test` and
/// `csv_delimited_test` each pin a list. **None asserted the whole row, in
/// order, with this column's position, in one place.** A header assertion
/// spread across four files is four things to keep in step.
///
/// ⚠️ **AND THE POSITION IS THE HALF THAT MATTERS MOST TO A CONSUMER.** A
/// spreadsheet that matches on column ORDER breaks silently when a column
/// moves and loudly when one is renamed; a spreadsheet that matches on NAME
/// does the opposite. **Both are pinned here.**


/// ⛔ **THE COLUMN SET, PINNED TO THE MARKER BY HASH. Brief 63 C-4.**
///
/// 🔴 **CONTRACTS #9 STATES A RULE IT COULD NOT ENFORCE, AND THIS RELEASE
/// PROVED IT.** #9 says *"any change to the column set … bumps the shape
/// marker"* — added, removed, **renamed** or reordered. `sweep_contracts_test`
/// compares the pinned list against the SOURCE, so a rename that updates both
/// in one commit is invisible to it. **Measured during Brief 63 Part B:**
///
///     pin left at the old name          -> red
///     pin updated as the brief directs  -> GREEN, with no marker bump
///
/// ⚠️ **So the column set moved and nothing objected.** Amendment 1 predicted
/// that test would go red and it did not; the prediction reasoned by analogy
/// with v7→v8, which was a change to the column SET rather than a rename.
///
/// ⭐ **THIS CLOSES IT BY KEYING THE HASH ON THE MARKER**, so both directions
/// fail:
///
///     set changes, marker does not   -> the v8 hash no longer matches
///     marker bumps, map not updated  -> no entry for the new marker
///
/// ⚠️ **THE ESCAPE IN C-4 WAS EVALUATED AND DID NOT FIRE.** A pin that cries
/// wolf is worse than the convention it replaces, so stability was measured
/// before this was written, not assumed:
///
///     same header hashed 5x        identical
///     values changed               hash UNMOVED
///     row count changed            hash UNMOVED
///     one column renamed           hash MOVED
///
/// The header is a constant list of literals — no locale, no clock, no
/// platform and no record content reaches it.
String _fnv1a64(String s) {
  var h = BigInt.parse('14695981039346656037');
  final mask = BigInt.parse('18446744073709551615');
  final prime = BigInt.parse('1099511628211');
  for (final c in s.codeUnits) {
    h = (h ^ BigInt.from(c)) & mask;
    h = (h * prime) & mask;
  }
  return h.toRadixString(16).padLeft(16, '0');
}

/// Marker -> hash of the header row it describes.
///
/// ⛔ **ADD AN ENTRY, NEVER EDIT ONE.** A past marker's hash is a record of what
/// that marker meant; changing it in place makes the record agree with whatever
/// the code now does, which is the one thing a pin must not do.
const Map<String, String> kHeaderHashForMarker = <String, String>{
  // v8 — the value convention (Brief 62) AND the `referral_required` ->
  // `further_attention` rename (Brief 63). Both folded into one bump because
  // v8 was unreleased when the rename landed.
  'v8': 'ec0cf721277795ac',
};

void main() {
  EventRecord rec({bool? referral}) => EventRecord(
        id: 'h',
        timestamp: DateTime(2026, 9, 20, 9, 0),
        duration: null,
        feelings: const <String>[],
        referralRequired: referral,
        notes: '',
      );

  List<String> header() => buildCsv([rec()]).split('\n').first.split(',');

  test('1. the header is these 17 columns, in this order', () {
    const expected = <String>[
      'timestamp_iso',
      'date',
      'time',
      'record_kind',
      'condition',
      'event_type',
      'duration',
      'duration_seconds',
      'severity',
      'observations',
      'beforehand',
      'rescue_med_given',
      'rescue_med_helped',
      'rescue_med_second_dose',
      'further_attention', // <- renamed Brief 63; position unchanged
      'medication_kind',
      'notes',
    ];
    final got = header();
    // ⛔ The BOM rides on column 1 and is not part of the name.
    got[0] = got[0].replaceFirst('﻿', '');
    expect(got, expected,
        reason: 'the whole row, in order. A rename, a reorder, an addition or '
            'a removal all fail here, and the diff names which');
    expect(got, hasLength(17),
        reason: 'COVERAGE: 17 columns. A clean pass over an unstated '
            'denominator says nothing');
  });

  test('2. `further_attention` is at index 14, column 15', () {
    final got = header();
    expect(got.indexOf('further_attention'), 14,
        reason: 'POSITION IS PART OF THE CONTRACT. Brief 63 renamed this '
            'column and required the position to be unchanged — measured at '
            '15 of 17 before the rename and asserted at 15 after');
    expect(got[14], 'further_attention');
  });

  test('3. ⛔ the RETIRED name is gone from the header', () {
    final got = header();
    expect(got.contains('referral_required'), isFalse,
        reason: 'the export must not carry the retired name. The capture '
            'surfaces stopped asking about a referral; the header followed');

    // ⭐ CONTROL ON THE ABSENCE. A `contains` returning false proves nothing
    // unless the same comparison can return true — a header list that had
    // been emptied, or a typo in the string, would both read as "absent".
    expect(got.contains('further_attention'), isTrue,
        reason: 'CONTROL: the same comparison, on the same list, finds the '
            'replacement. So the absence above is a real absence and not a '
            'dead search');
    expect(got.contains('rescue_med_given'), isTrue,
        reason: 'CONTROL: and an UNRELATED column is present too, so the list '
            'is fully populated rather than truncated before index 14');
  });

  test('4. the three written values, quoted from the code not from a brief',
      () {
    // ⭐ Brief 63: "Values: unchanged ... Quote the two written values from the
    // code rather than from me." There are THREE states, not two — the third
    // arrived with Brief 62's nullable field, and naming only two would
    // re-describe the column as it was before that change.
    String cell(bool? v) {
      final rows = buildCsv([rec(referral: v)]).split('\n');
      final h = rows.first.replaceFirst('﻿', '').split(',');
      return rows[1].split(',')[h.indexOf('further_attention')];
    }

    expect(cell(true), 'Yes');
    expect(cell(false), 'No');
    expect(cell(null), 'Not Captured',
        reason: 'the not-asked state from Brief 62, which v8 was taken for. '
            'The rename does not touch it');

    // The source of those strings, pinned so the values cannot drift from the
    // writer that produces them:
    //   String yesNoCsv(bool? v) =>
    //       v == null ? kCsvNotCaptured : (v ? 'Yes' : 'No');
    expect(yesNoCsv(true), 'Yes');
    expect(yesNoCsv(false), 'No');
    expect(yesNoCsv(null), kCsvNotCaptured);
  });

  test('5. the shape marker is v8 and did NOT move for this rename', () {
    expect(kCsvShapeVersion, 'v8',
        reason: 'Brief 63 folded the rename into the bump already taken this '
            'cycle for the value convention. v8 is UNRELEASED, so one marker '
            'change reaches users instead of two.\n\n'
            'If you are changing the header and wondering whether to bump: '
            'the answer is yes ONCE v8 has shipped, and no while it has not');
  });

  test('6. ⛔ the column SET is pinned to the MARKER, by hash', () {
    final raw = buildCsv([rec()]).split('\n').first.replaceFirst('\uFEFF', '');
    final actual = _fnv1a64(raw);
    final expected = kHeaderHashForMarker[kCsvShapeVersion];

    expect(expected, isNotNull,
        reason: 'THE MARKER MOVED AND THIS MAP DID NOT.\n\n'
            'kCsvShapeVersion is now "$kCsvShapeVersion" and no entry exists '
            'for it. ADD one — do not edit an existing entry, because a past '
            "marker's hash records what that marker meant.\n\n"
            'The header this run produced hashes to:\n  $actual');

    expect(actual, expected,
        reason: 'THE COLUMN SET CHANGED WITHOUT THE MARKER BEING BUMPED.\n\n'
            'kCsvShapeVersion is "$kCsvShapeVersion", whose pinned header hash '
            'is $expected, but the header now hashes to $actual.\n\n'
            'The header this run produced:\n  $raw\n\n'
            'REPAIR — both halves, together:\n'
            '  1. bump kCsvShapeVersion, because a consumer has no other '
            'signal that the file changed shape;\n'
            '  2. add the new marker and this hash to kHeaderHashForMarker.\n\n'
            'If the marker deliberately is NOT bumping — because it has already '
            'moved this cycle and has not shipped — update the hash against the '
            'EXISTING marker and say so in the commit. That is the only case '
            'where editing an entry is correct, and it is why this message '
            'names it rather than forbidding it outright.');
  });

  test('7. CONTROL: the hash moves for a SET change and not for a VALUE change',
      () {
    // ⭐ Without this, a hash that never moved would pass test 6 for ever.
    final base = buildCsv([rec()]).split('\n').first.replaceFirst('\uFEFF', '');

    final valuesDiffer =
        buildCsv([rec(referral: true)]).split('\n').first.replaceFirst('\uFEFF', '');
    expect(_fnv1a64(valuesDiffer), _fnv1a64(base),
        reason: 'a VALUE change must not move the header hash, or the pin '
            'fires on edits that change no shape — the cry-wolf failure C-4 '
            "names as worse than the convention it replaces");

    final setDiffers = base.replaceFirst('further_attention', 'renamed_column');
    expect(_fnv1a64(setDiffers), isNot(_fnv1a64(base)),
        reason: 'and a SET change MUST move it, or test 6 is asserting against '
            'a hash that cannot change and proves nothing');
  });
}
