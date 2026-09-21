// Brief 74 Part D, Row 2 — the enforcement.
//
// ⭐ THIS IS THE ROW'S WHOLE JUSTIFICATION. A contract row that restates the
// 12 September comment in a different file would be WORSE THAN NOTHING: it
// would look like enforcement while being the same prose that already failed.
// This scan either returns zero or NAMES the violation.
//
// ⛔ WHY A SOURCE SCAN AND NOT A BEHAVIOURAL TEST. The invariant is "there is
// exactly ONE place that assigns", which is a statement about the SOURCE. No
// amount of driving the app can prove a second assignment does not exist —
// it can only fail to find one, which is the absence claim this whole cluster
// is made of.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Writes to `_records` that are NOT the accessor pair: any assignment to the
/// backing field, or any in-place mutation of the list.
final _violation = RegExp(
  r'_recordsSorted\s*=' // assigning the backing field
  r'|_records\.(sort|add|addAll|insert|removeAt|removeWhere|remove|clear)\s*\(' // mutating
  r'|_records\[[^\]]*\]\s*=', // element assignment
);

/// Strips comments so a line QUOTING the old code is not read as the old code.
/// ⚠️ Added because the annotations written with this fix quote
/// `_records.insert(0, rec)` verbatim, and a naive scan flagged them.
String stripComments(String s) {
  final out = StringBuffer();
  var inBlock = false;
  for (final line in s.split('\n')) {
    var l = line;
    if (inBlock) {
      final e = l.indexOf('*/');
      if (e < 0) { out.writeln(); continue; }
      l = l.substring(e + 2);
      inBlock = false;
    }
    final b = l.indexOf('/*');
    if (b >= 0 && !l.substring(b).contains('*/')) { l = l.substring(0, b); inBlock = true; }
    final c = l.indexOf('//');
    if (c >= 0) l = l.substring(0, c);
    out.writeln(l);
  }
  return out.toString();
}

void main() {
  test('home\'s _records is assigned in exactly one place', () {
    final raw = File('lib/screens/home_screen.dart').readAsStringSync();
    final src = stripComments(raw);

    // CONTROL 1 — the reader must be able to see the file at all.
    expect(raw.contains('_recordsSorted'), isTrue,
        reason: 'CONTROL: the backing field was not found. Either the file '
                'moved or the single-assignment shape was removed, and either '
                'way this scan is no longer checking anything.');

    // CONTROL 2 — the accessor pair must still exist, or "zero violations" is
    // true for the wrong reason.
    expect(src.contains('List<EventRecord> get _records => _recordsSorted;'), isTrue,
        reason: 'CONTROL: the getter is gone. Zero violations below would then '
                'mean the invariant has no implementation, not that it holds.');
    expect(src.contains('set _records(List<EventRecord> value)'), isTrue,
        reason: 'CONTROL: the setter is gone.');

    // ⭐ The setter's own body is the ONE permitted assignment to the backing
    // field. Everything else is a violation.
    final lines = src.split('\n');
    final hits = <String>[];
    var inSetter = false;
    var depth = 0;
    for (var i = 0; i < lines.length; i++) {
      final l = lines[i];
      if (l.contains('set _records(List<EventRecord> value)')) {
        inSetter = true;
        depth = 0;
      }
      if (inSetter) {
        depth += '{'.allMatches(l).length - '}'.allMatches(l).length;
        if (depth <= 0 && l.contains('}')) inSetter = false;
        continue; // the setter body is permitted
      }
      // ⚠️ THE FIELD'S OWN DECLARATION IS NOT A VIOLATION, and it is excluded
      // BY SHAPE rather than by line number: a declaration carries its type.
      // Enumerated here rather than loosened out of the pattern, so the
      // exclusion stays visible to anyone who doubts the zero.
      if (l.contains('List<EventRecord> _recordsSorted =')) continue;
      if (_violation.hasMatch(l)) hits.add('  :${i + 1}  ${l.trim()}');
    }

    expect(hits, isEmpty,
        reason: 'Contract #24: every assignment to home\'s `_records` must go '
                'through the single setter, which sorts by `whenHappened` '
                'descending. Each line below either assigns the backing field '
                'directly or mutates the list in place, and so can leave it in '
                'an order no one chose:\n${hits.join('\n')}');
  });

  test('the setter sorts by whenHappened, not timestamp', () {
    final src = stripComments(
        File('lib/screens/home_screen.dart').readAsStringSync());
    final setterIdx = src.indexOf('set _records(List<EventRecord> value)');
    expect(setterIdx, greaterThan(-1), reason: 'CONTROL: setter not found.');
    final body = src.substring(setterIdx, setterIdx + 400);

    expect(body.contains('b.whenHappened.compareTo(a.whenHappened)'), isTrue,
        reason: 'Contract #24: the single assignment path must sort by '
                '`whenHappened` DESCENDING. Sorting by `timestamp` here '
                'reinstates the entire defect at one stroke, and every other '
                'test in this cluster would go red together — which is the '
                'behaviour wanted, but this names the cause.');
    expect(body.contains('b.timestamp.compareTo'), isFalse,
        reason: 'Contract #24: the write clock must not decide display order.');
  });
}
