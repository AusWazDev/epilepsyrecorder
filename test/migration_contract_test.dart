import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_store_sqlite.dart';

/// THE MIGRATION CONTRACT — structure #11 of the Brief 57 sweep.
///
/// ## ⭐ THE INVARIANT
///
/// **Every migration step is additive, non-destructive, and independently
/// guarded, so a database at ANY version walks forward correctly in one open.**
///
/// ⛔ **IT IS NOT "EVERY GUARD HAS THE SAME SHAPE", and encoding that would be
/// wrong.** Three shapes are legitimate and all three are in use:
///
///     if (from < N && to >= N)                          one-sided
///     if (from >= M && from < N && to >= N)             two-sided
///     if (from < N && to >= N && !await hasColumn(...)) derived
///
/// ⚠️ **The two-sided form is LOAD-BEARING, not stylistic.** `createVocabularySql`
/// always emits the CURRENT column list, so the v3 step creates those tables
/// already carrying `emoji`; a one-sided `from < 4` therefore threw
/// `duplicate column name: emoji` for any database walking 1 -> 4 in a single
/// open — which was every device upgrading from a release before v3. ⭐ A
/// contract that demanded one shape would have forbidden the fix.
///
/// ## ⛔ WHAT IS CHECKED, AND WHAT IS NOT
///
/// Checked by source scan: that no step is chained, that nothing destructive
/// appears in the upgrade path, and that every version has a step.
/// ⚠️ **NOT checked: that a given step is CORRECT.** Correctness is what
/// `sqlite_upgrade_v2_test`'s v1 -> current fixture is for, and that fixture
/// exists precisely because one built at the current version cannot fail.

const _kPath = 'lib/models/event_store_sqlite.dart';

/// The body of `upgradeSchema`, from its signature to the first line that ends
/// the function at column 0.
String _upgradeBody() {
  final lines = File(_kPath).readAsLinesSync();
  final start = lines.indexWhere((l) => l.contains('upgradeSchema('));
  expect(start, greaterThanOrEqualTo(0),
      reason: 'CONTROL: upgradeSchema must be findable, or every scan below '
          'runs over an empty string and passes vacuously');
  var end = start + 1;
  while (end < lines.length && !lines[end].startsWith('}')) {
    end++;
  }
  return lines.sublist(start, end).join('\n');
}

void main() {
  test('CONTROL: the scanned body is non-trivial and contains a step', () {
    final body = _upgradeBody();
    expect(body.length, greaterThan(500),
        reason: 'a short body means the extraction failed');
    expect(body, contains('to >= 2'),
        reason: 'and it must contain a known step, or the extraction found '
            'the wrong region');
  });

  test('no step is chained — steps are `if`, not `else if`', () {
    // ⛔ THE LOAD-BEARING ONE. Chaining makes a step conditional on the
    // previous step NOT running, so a v1 database walking 1 -> 11 in one open
    // would execute one step and stop. Every step must stand alone.
    final body = _upgradeBody();
    expect(body.contains('else if'), isFalse,
        reason: 'an `else if` in the upgrade path makes one step suppress '
            'another, so a database several versions behind would walk only '
            'partway forward in a single open and arrive silently wrong');
  });

  test('nothing in the upgrade path is destructive', () {
    // ⭐ "Each step is additive and non-destructive: no row is rewritten and
    // no value is derived. Every existing row gets NULL in every new column,
    // which is the honest answer for a record captured before the concept
    // existed."
    final body = _upgradeBody();
    for (final verb in ['DROP ', 'DELETE ', 'TRUNCATE', ' RENAME ']) {
      expect(body.toUpperCase().contains(verb), isFalse,
          reason: 'found "$verb" in the upgrade path. A migration that '
              'rewrites or removes stored data cannot be replayed and cannot '
              'be reasoned about from the schema version alone — and on this '
              'app the stored data is the only copy that exists');
    }
  });

  test('every version from 2 to the current one has a step', () {
    // ⚠️ A GAP IS NOT A STYLE ISSUE. `onUpgrade` is called once with the whole
    // span, so a version with no step is a version whose change never lands
    // for anyone upgrading across it.
    final body = _upgradeBody();
    final missing = <int>[];
    for (var v = 2; v <= kSqliteSchemaVersion; v++) {
      if (!body.contains('to >= $v')) missing.add(v);
    }
    expect(missing, isEmpty,
        reason: 'no migration step guards version(s) $missing. Current schema '
            'is v$kSqliteSchemaVersion. Either the step is absent, or its '
            'guard does not use the `to >= N` form this scan reads — in which '
            'case this test needs widening, deliberately, not silencing');
  });
}
