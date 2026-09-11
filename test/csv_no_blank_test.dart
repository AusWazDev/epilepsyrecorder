import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/medication_note.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';

/// AUDIT.md §13(cc): A CSV FIELD IS NEVER BLANK. Every cell is a positive
/// statement — a value, `Not Captured`, or `Not Applicable`.
///
/// ⛔ THE ACCEPTANCE TEST IS THE WHOLE RULE, NOT ITS INSTANCES. Test 1 does
/// not ask "is Not Captured written where it should be". It asks: CAN ANY
/// PATH STILL EMIT AN EMPTY CELL? It walks every cell of every row over a
/// fixture that reaches every branch — a quick-log, a complete record, a
/// rescue record with given=No, a backdated record, a medication note — and
/// fails on the first empty string. Against the unpatched v6 builder it
/// failed with 34 empty cells across 5 rows (measured 11 September 2026);
/// that is the control, and it is recorded here because a test that has
/// never failed proves nothing.
///
/// Tests 2 to 4 pin the three decisions §13(cd) records as the rule's edges:
/// `referral_required` is the ONE KNOWN EXCEPTION and keeps writing `No`
/// (non-nullable bool, no absent state, routed to the adviser — §13(bl));
/// a user's seeded `Unknown` in beforehand stays a user value, distinguishable
/// from `Not Captured`; and the two rescue children are CONDITIONAL on
/// `rescue_med_given`, Not Applicable when it is No and Not Captured otherwise.

const _nc = 'Not Captured';
const _na = 'Not Applicable';

/// Splits one CSV line into cells, undoing quoting exactly once — what a
/// spreadsheet does on open. Hand-rolled, not imported, so the reader shares
/// no assumption with the writer.
List<String> cells(String line) {
  final out = <String>[];
  final sb = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < line.length && line[i + 1] == '"') {
          sb.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        sb.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == ',') {
      out.add(sb.toString());
      sb.clear();
    } else {
      sb.write(c);
    }
  }
  out.add(sb.toString());
  return out;
}

/// Rows of the export, excluding the header; quoted newlines rejoined.
List<List<String>> rows(String csv) {
  final lines = <String>[];
  final sb = StringBuffer();
  var quotes = 0;
  for (final raw in csv.split('\n')) {
    sb.write(sb.isEmpty ? raw : '\n$raw');
    quotes += raw.split('"').length - 1;
    if (quotes.isEven) {
      lines.add(sb.toString());
      sb.clear();
      quotes = 0;
    }
  }
  return lines.where((l) => l.trim().isNotEmpty).skip(1).map(cells).toList();
}

List<String> header(String csv) =>
    cells(csv.split('\n').first.replaceFirst('﻿', ''));

final t0 = DateTime(2026, 9, 8, 14, 5, 30);

EventRecord quickLog() => EventRecord(
      id: 'q',
      timestamp: DateTime(2026, 8, 30, 16, 36, 41),
      duration: null,
      feelings: const <String>[],
      referralRequired: false,
      notes: '',
      detailsCompleted: false,
    );

EventRecord complete() => EventRecord(
      id: 'c',
      timestamp: t0,
      duration: null,
      durationSeconds: 200,
      eventType: 'seizure',
      severity: EventSeverity.severe,
      feelings: const <String>['Tired'],
      triggers: const <String>['Stress'],
      notes: 'Fell, hit head',
      referralRequired: true,
      rescueMedGiven: true,
      rescueMedHelped: RescueResponse.partly,
      rescueMedSecondDose: false,
      detailsCompleted: true,
    );

EventRecord rescueNo() => EventRecord(
      id: 'n',
      timestamp: DateTime(2026, 9, 2, 6, 45),
      duration: DurationCategory.oneToFive,
      eventType: 'seizure',
      severity: EventSeverity.mild,
      feelings: const <String>[],
      referralRequired: false,
      notes: '',
      rescueMedGiven: false,
      detailsCompleted: true,
    );

EventRecord backdated() => EventRecord(
      id: 'b',
      timestamp: DateTime(2026, 9, 9, 21, 30),
      occurredAt: DateTime(2026, 9, 7, 8, 0),
      duration: DurationCategory.gt5,
      eventType: 'seizure',
      severity: EventSeverity.moderate,
      feelings: const <String>[],
      referralRequired: false,
      notes: 'Two days late',
      detailsCompleted: true,
    );

MedicationNote note() => MedicationNote(
      id: 'm',
      occurredAt: DateTime(2026, 9, 5, 8, 0),
      loggedAt: DateTime(2026, 9, 5, 8, 2),
      kind: MedicationDeviation.missed,
      notes: '',
    );

String fixtureCsv() => buildCsv(
      <EventRecord>[backdated(), complete(), rescueNo(), quickLog()],
      notes: <MedicationNote>[note()],
    );

void main() {
  setUp(Vocabularies.debugReset);
  tearDown(Vocabularies.debugReset);

  test('1. ⛔ THE RULE: no path emits an empty cell', () {
    final csv = fixtureCsv();
    final h = header(csv);
    final rs = rows(csv);
    expect(rs, hasLength(5), reason: 'four events and one note');

    final empties = <String>[];
    for (var r = 0; r < rs.length; r++) {
      expect(rs[r], hasLength(h.length), reason: 'row $r has every column');
      for (var c = 0; c < h.length; c++) {
        if (rs[r][c].isEmpty) empties.add('row $r ${h[c]}');
      }
    }
    // Reported as a count so a regression names its size, not just itself.
    expect(empties, isEmpty,
        reason: '${empties.length} empty cell(s): ${empties.join(', ')}');
  });

  test('2. ⛔ THE ONE KNOWN EXCEPTION: referral_required still writes No '
      'on a record that was never asked', () {
    final csv = buildCsv(<EventRecord>[quickLog()]);
    final h = header(csv);
    final r = rows(csv).single;
    expect(r[h.indexOf('referral_required')], 'No',
        reason: 'a non-nullable bool has no absent state; routed to the '
            'adviser, not resolved here — §13(bl), §13(cd)');
    // and every OTHER unasked scalar on the same row says so
    for (final col in ['event_type', 'duration', 'severity']) {
      expect(r[h.indexOf(col)], _nc, reason: col);
    }
  });

  test('3. a user\'s seeded "Unknown" in beforehand is a value, not an '
      'absence', () {
    final csv = buildCsv(<EventRecord>[
      EventRecord(
        id: 'u',
        timestamp: t0,
        duration: DurationCategory.lt1,
        eventType: 'seizure',
        severity: EventSeverity.mild,
        feelings: const <String>[],
        triggers: const <String>['Unknown'],
        referralRequired: false,
        notes: '',
      ),
    ]);
    final h = header(csv);
    final r = rows(csv).single;
    expect(r[h.indexOf('beforehand')], 'Unknown');
    expect(r[h.indexOf('beforehand')], isNot(_nc));
    // and the empty set on the SAME record kind reads Not Captured
    expect(r[h.indexOf('observations')], _nc);
  });

  test('4. the rescue children are CONDITIONAL on rescue_med_given', () {
    final h = header(fixtureCsv());
    final helped = h.indexOf('rescue_med_helped');
    final second = h.indexOf('rescue_med_second_dose');

    final no = rows(buildCsv(<EventRecord>[rescueNo()])).single;
    expect(no[h.indexOf('rescue_med_given')], 'No');
    expect(no[helped], _na, reason: 'hidden on screen when given is No');
    expect(no[second], _na);

    final yesUnanswered = rows(buildCsv(<EventRecord>[
      EventRecord(
        id: 'y',
        timestamp: t0,
        duration: DurationCategory.lt1,
        eventType: 'seizure',
        severity: EventSeverity.mild,
        feelings: const <String>[],
        referralRequired: false,
        notes: '',
        rescueMedGiven: true,
      ),
    ])).single;
    expect(yesUnanswered[helped], _nc, reason: 'asked, not answered');
    expect(yesUnanswered[second], _nc);

    final notAsked = rows(buildCsv(<EventRecord>[quickLog()])).single;
    expect(notAsked[h.indexOf('rescue_med_given')], _nc);
    expect(notAsked[helped], _nc);
    expect(notAsked[second], _nc);
  });

  test('5. duration_seconds has three states, and the legacy range is '
      'Not Applicable', () {
    final h = header(fixtureCsv());
    final col = h.indexOf('duration_seconds');
    expect(rows(buildCsv(<EventRecord>[complete()])).single[col], '200');
    expect(rows(buildCsv(<EventRecord>[rescueNo()])).single[col], _na,
        reason: '"a legacy range, no number" — the number does not exist');
    expect(rows(buildCsv(<EventRecord>[quickLog()])).single[col], _nc);
  });

  test('7. ⛔ no cell in the file renders the literal `unknown` — with a '
      'control proving the search would find it', () {
    // After the condition decision of 11 Sep 2026 (§13(cd)), `unknown` left
    // the last scalar column. A fixture reaching every branch must contain
    // none. Case-sensitive: the seeded beforehand option is `Unknown`, a
    // user's value, and must stay findable as itself (test 3).
    final csv = fixtureCsv();
    final hits = <String>[];
    final h = header(csv);
    final rs = rows(csv);
    for (var r = 0; r < rs.length; r++) {
      for (var c = 0; c < h.length; c++) {
        if (rs[r][c] == 'unknown') hits.add('row $r ${h[c]}');
      }
    }
    expect(hits, isEmpty, reason: '${hits.length} cell(s): ${hits.join(', ')}');

    // POSITIVE CONTROL: a record whose NOTES are literally "unknown" puts the
    // word in a cell, and the same search finds it. Without this, the zero
    // above would also be produced by a search that could find nothing.
    final control = buildCsv(<EventRecord>[
      EventRecord(
        id: 'k',
        timestamp: t0,
        duration: DurationCategory.lt1,
        eventType: 'seizure',
        severity: EventSeverity.mild,
        feelings: const <String>[],
        referralRequired: false,
        notes: 'unknown',
      ),
    ]);
    final found = rows(control).single.where((v) => v == 'unknown').length;
    expect(found, 1, reason: 'the search apparatus can find the literal');
  });

  test('6. a medication row: event-only columns Not Applicable, condition '
      'Not Captured, empty notes Not Captured', () {
    final csv = buildCsv(const <EventRecord>[], notes: [note()]);
    final h = header(csv);
    final r = rows(csv).single;
    for (final col in [
      'event_type', 'duration', 'duration_seconds', 'severity',
      'observations', 'beforehand', 'rescue_med_given', 'rescue_med_helped',
      'rescue_med_second_dose', 'referral_required',
    ]) {
      expect(r[h.indexOf(col)], _na, reason: col);
    }
    expect(r[h.indexOf('condition')], _nc,
        reason: 'the column exists since v8 and nothing writes it');
    expect(r[h.indexOf('notes')], _nc);
    expect(r[h.indexOf('medication_kind')], 'Missed');
  });
}
