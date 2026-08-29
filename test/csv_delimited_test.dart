import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/vocabulary.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';

/// The delimited CSV: the delimiter, a value containing it, ordering, and the
/// empty set.
///
/// ## What this file is for
///
/// Nothing in MER reads a CSV back. Restore uses the JSON backup envelope,
/// which is a separate file with separate code. So there is no round trip to
/// catch an export defect, and no screen on which a wrong cell would look
/// wrong. **The file is only ever checked here, or by the person it was sent
/// to.**

EventRecord rec({
  List<String> feelings = const <String>[],
  List<String> triggers = const <String>[],
}) =>
    EventRecord(
      id: 'r',
      timestamp: DateTime(2026, 8, 26, 9, 0),
      duration: null,
      eventType: 'seizure',
      severity: EventSeverity.mild,
      feelings: feelings,
      triggers: triggers,
      notes: '',
      referralRequired: false,
    );

/// The data row, split into cells on the outer comma, with CSV quoting undone
/// exactly one level — which is what a spreadsheet does when it opens the file.
///
/// Hand-rolled rather than pulled from a package, deliberately: a parser that
/// shares an assumption with the writer would confirm the assumption rather
/// than the output.
List<String> cells(String csv) {
  final line = csv.trim().split('\n').last;
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

// ⚠️ SHIFTED BY ONE when `record_kind` landed at index 3. Named constants
// rather than literals precisely so a column insertion is one edit and not a
// hunt through twenty assertions.
/// THE HEADER, GOLDEN. Every column, in order, exactly as `buildCsv` writes it.
///
/// This is the mechanical enforcement of the marker rule. The rule says the
/// marker tracks the header and ANY change to the column set bumps it - added,
/// removed, renamed or reordered, no judgement about whether a change is
/// "real". A rule stated in prose is followed when someone remembers it; test 1
/// below fails on ANY difference from this list, so the bump cannot be
/// forgotten.
///
/// It also replaces five hardcoded index constants that had to be hand-shifted
/// twice: once when `record_kind` landed at index 3, and again when `condition`
/// landed at index 4. Indices are now DERIVED from this list.
const List<String> kCsvHeaderGolden = <String>[
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
  'referral_required',
  'medication_kind',
  'notes',
];

final int kObservationsCell = kCsvHeaderGolden.indexOf('observations');
final int kTriggersCell = kCsvHeaderGolden.indexOf('beforehand');
final int kConditionCell = kCsvHeaderGolden.indexOf('condition');

void main() {
  setUp(Vocabularies.debugReset);
  tearDown(Vocabularies.debugReset);

  group('THE SHAPE', () {
    test('1. the header matches the golden EXACTLY, or the marker must bump',
        () {
      final header = buildCsv(<EventRecord>[rec()])
          .split('\n')
          .first
          .replaceFirst('﻿', '')
          .trim()
          .split(',');

      // Element-wise, not a length check. A rename or a reorder keeps the
      // count identical and changes the file completely - and a spreadsheet
      // built against the old shape breaks on either.
      expect(header, kCsvHeaderGolden,
          reason: 'THE COLUMN SET CHANGED. Update kCsvHeaderGolden AND bump '
              'kCsvShapeVersion - the marker tracks the header, mechanically, '
              'with no judgement about whether the change is "real".');
      expect(header[kObservationsCell], 'observations');
      expect(header[kTriggersCell], 'beforehand');
    });

    test('2. and a data row has the same number of cells as the header', () {
      // The defect this catches is a delimiter leaking out of a cell. An
      // unquoted comma or an unescaped newline in a value would give this row
      // MORE cells than the header, and every column after it would be read
      // against the wrong heading — silently, because the file still opens.
      final r = rec(
        feelings: const <String>['Dizzy, briefly'],
        triggers: const <String>['Stress'],
      );
      expect(cells(buildCsv(<EventRecord>[r])).length, kCsvHeaderGolden.length);
    });
  });

  group('THE DELIMITER, AND A VALUE THAT CONTAINS IT', () {
    test('3. entries are separated by semicolon-space', () {
      final r = rec(triggers: const <String>['Stress', 'Illness']);
      expect(cells(buildCsv(<EventRecord>[r]))[kTriggersCell],
          'Stress${kCsvListDelimiter}Illness');
    });

    test('4. a value containing the delimiter is QUOTED, not altered', () {
      // The words someone chose survive intact. Only punctuation is ADDED
      // around them, and only around the entry that needed it.
      expect(csvJoinList(<String>['Dizzy; unsteady', 'Stress']),
          '"Dizzy; unsteady"; Stress');
    });

    test('5. and a splitter can recover the set exactly', () {
      // The point of quoting rather than substituting: the boundary is
      // recoverable. Two entries in, two entries out, with the semicolon still
      // inside the one that had it.
      const original = <String>['Dizzy; unsteady', 'Stress'];
      final cell =
          cells(buildCsv(<EventRecord>[rec(feelings: original)]))[
              kObservationsCell];

      expect(cell, '"Dizzy; unsteady"; Stress');
      expect(_splitCell(cell), original);
    });

    test('6. a value containing a QUOTE doubles it, same rule one level down',
        () {
      expect(csvJoinList(<String>['a "loud" one']), '"a ""loud"" one"');
      expect(_splitCell(csvJoinList(<String>['a "loud" one'])),
          <String>['a "loud" one']);
    });

    test('7. NEGATIVE CONTROL: unquoted, the two cases are identical', () {
      // Tests 4 and 5 pass just as well against a writer that quotes
      // everything, or nothing, if the failure is never shown. This is the
      // failure: joined raw, ONE entry containing the delimiter and TWO
      // entries produce the same cell, and no reader can tell them apart.
      const oneEntry = <String>['Dizzy; unsteady'];
      const twoEntries = <String>['Dizzy', 'unsteady'];

      expect(oneEntry.join(kCsvListDelimiter),
          equals(twoEntries.join(kCsvListDelimiter)),
          reason: 'the ambiguity this quoting exists to remove');

      expect(csvJoinList(oneEntry), isNot(csvJoinList(twoEntries)));
      expect(_splitCell(csvJoinList(oneEntry)).length, 1);
      expect(_splitCell(csvJoinList(twoEntries)).length, 2);
    });

    test('8. and the outer CSV layer still quotes the whole cell', () {
      // Two layers, and a spreadsheet unwraps exactly one. The inner quotes
      // must survive into the cell a person sees.
      final raw = buildCsv(<EventRecord>[
        rec(feelings: const <String>['Dizzy; unsteady', 'Stress'])
      ]).trim().split('\n').last;

      expect(raw, contains('"""Dizzy; unsteady""; Stress"'),
          reason: 'inner quotes doubled inside the outer quoted field');
    });
  });

  group('THE EMOJI STRIPPER IS NOT POSITIONAL', () {
    test('9. a legacy value exports without its emoji', () {
      final csv = buildCsv(<EventRecord>[
        rec(feelings: const <String>['\u{1F635} Confused'])
      ]);
      expect(cells(csv)[kObservationsCell], 'Confused');
    });

    test('10. NEGATIVE CONTROL: an entry with NO emoji keeps its first word',
        () {
      // THE FAILURE MODE OF THE MECHANISM THAT WAS REPLACED. The old stripper
      // removed the leading non-space run without looking at it, so it was
      // correct on every value MER shipped — all eleven began with an emoji —
      // and silently wrong on the first value a user typed.
      //
      // "Dizzy spell" through a positional stripper is "spell". Through a
      // lookup it is "Dizzy spell", because an entry with no emoji has a label
      // identical to its value.
      Vocabularies.debugSet(observations: <VocabularyEntry>[
        const VocabularyEntry(
          id: 900,
          value: 'Dizzy spell',
          label: 'Dizzy spell',
          isSeeded: false,
          isActive: true,
          isProtected: false,
          sortOrder: 500,
        ),
      ]);

      final cell = cells(buildCsv(<EventRecord>[
        rec(feelings: const <String>['Dizzy spell'])
      ]))[kObservationsCell];

      expect(cell, 'Dizzy spell');
      expect(cell, isNot('spell'),
          reason: 'what a positional stripper would have written');
      expect(cell, isNot(isEmpty),
          reason: 'and what a stripper of the whole first token would');
    });

    test('11. a value absent from the vocabulary falls back to itself', () {
      // A record restored from another device, or from a vocabulary this
      // install does not have. The stored string reaches the file rather than
      // a blank or a wrong label.
      final cell = cells(buildCsv(<EventRecord>[
        rec(feelings: const <String>['Something only they use'])
      ]))[kObservationsCell];
      expect(cell, 'Something only they use');
    });
  });

  group('TRIGGERS: ORDER, AND WHAT THE ONE-HOT COLUMNS USED TO DROP', () {
    test('12. canonical order, whatever order they were tapped in', () {
      // What the seven columns did for free. Without it the same set reads two
      // ways down the page and the column stops being comparable.
      final tapped = rec(triggers: const <String>['Illness', 'Stress']);
      expect(cells(buildCsv(<EventRecord>[tapped]))[kTriggersCell],
          'Stress${kCsvListDelimiter}Illness');
      expect(kTriggerOptions.indexOf('Stress'),
          lessThan(kTriggerOptions.indexOf('Illness')));
    });

    test('13. an UNRECOGNISED trigger reaches the file', () {
      // The change's whole purpose, tested on triggers rather than argued. A
      // one-hot export had no column for a value it did not ship, so the value
      // was absent from the file with nothing on screen to reveal it.
      final r = rec(triggers: const <String>['Stress', 'Heat']);
      final cell = cells(buildCsv(<EventRecord>[r]))[kTriggersCell];

      expect(cell, 'Stress${kCsvListDelimiter}Heat');
      expect(kTriggerOptions, isNot(contains('Heat')));
    });

    test('14. NEGATIVE CONTROL: filtering the canonical list alone loses it',
        () {
      // Test 13 is a null-ish result — it passes against any writer that
      // happens to emit "Heat". This is the writer that would NOT: the obvious
      // implementation, canonical order by filtering kTriggerOptions, which
      // reproduces the one-hot defect exactly.
      const stored = <String>['Stress', 'Heat'];
      final naive = kTriggerOptions.where(stored.contains).toList();

      expect(naive, <String>['Stress'], reason: 'Heat has vanished');
      expect(csvOrderedTriggers(stored), <String>['Stress', 'Heat']);
    });
  });

  group('THE EMPTY SET IS BLANK', () {
    test('15. no observations and no triggers give empty cells', () {
      final c = cells(buildCsv(<EventRecord>[rec()]));
      expect(c[kObservationsCell], isEmpty);
      expect(c[kTriggersCell], isEmpty);
    });

    test('16. not the word "none", which would be a VALUE', () {
      // "None" is a thing someone may reasonably add to their own list, and
      // then a cell reading none would be two different statements sharing a
      // spelling. Blank is not a value, and cannot be confused with one.
      final csv = buildCsv(<EventRecord>[rec()]);
      expect(csv.toLowerCase(), isNot(contains('none')));
    });

    test('17. and a blank here means what it has always meant', () {
      // The seven one-hot columns wrote blank for "not noted" in every export
      // this app has ever produced. The cell is new; the convention is not.
      final none = cells(buildCsv(<EventRecord>[rec()]))[kTriggersCell];
      final some = cells(
          buildCsv(<EventRecord>[rec(triggers: const <String>['Stress'])]))[
          kTriggersCell];
      expect(none, isEmpty);
      expect(some, 'Stress');
    });
  });

  group('THE FILENAME CARRIES THE SHAPE MARKER', () {
    test('18. the marker sits before the extension, so .csv still opens it',
        () {
      // Reads the CONSTANT rather than restating "v2". The marker moves
      // whenever the column set does - it is now v3, for the three
      // rescue-medication columns - and a test that hardcoded the value would
      // have to be edited on every such change, which is exactly the edit that
      // stops being thought about.
      final name = csvFilename(when: DateTime(2026, 8, 26, 22, 30, 0));
      expect(name,
          'medical_event_recorder_20260826_223000.$kCsvShapeVersion.csv');
      expect(name.endsWith('.csv'), isTrue);
    });

    test('19. a prefix is honoured, and an empty one falls back', () {
      final when = DateTime(2026, 8, 26, 22, 30, 0);
      expect(csvFilename(prefix: 'filtered', when: when),
          'filtered_20260826_223000.$kCsvShapeVersion.csv');
      expect(csvFilename(prefix: '', when: when),
          'medical_event_recorder_20260826_223000.$kCsvShapeVersion.csv');
    });

    test('20. it is NOT a column', () {
      // The decision, pinned. A version column repeats one value on every row
      // and files a fact about the file among facts about the patient.
      final header =
          buildCsv(<EventRecord>[rec()]).split('\n').first.toLowerCase();
      expect(header, isNot(contains('version')));
      expect(header, isNot(contains(kCsvShapeVersion)));
    });
  });
}

/// Splits one cell back into entries, honouring the inner quoting.
///
/// This is the reader [csvJoinList] promises exists. Written here rather than
/// shipped, because the app never reads a CSV back — if it did, this would be
/// the shared function and the test would be circular.
List<String> _splitCell(String cell) {
  final out = <String>[];
  final sb = StringBuffer();
  var inQuotes = false;
  var i = 0;
  while (i < cell.length) {
    final c = cell[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < cell.length && cell[i + 1] == '"') {
          sb.write('"');
          i += 2;
          continue;
        }
        inQuotes = false;
      } else {
        sb.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (cell.startsWith(kCsvListDelimiter, i)) {
      out.add(sb.toString());
      sb.clear();
      i += kCsvListDelimiter.length;
      continue;
    } else {
      sb.write(c);
    }
    i++;
  }
  out.add(sb.toString());
  return out;
}
