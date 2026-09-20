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
}
