// Brief 197 Part A — do the app and the migration hide the SAME records?
//
// ⛔ WHY THIS EXISTS. The migration skips a record whose timestamp will not
// parse, and its survival check counts only the records that DID parse. That is
// harmless ONLY IF the app hides exactly the same records — so nothing the user
// could see is dropped. The claim rests on a comment in storage_migration.dart:
// "Identical to EventRecord._parseTimestamp, deliberately." A comment is not
// the code. This test drives BOTH paths over ONE table and asserts they agree.
//
// ⭐ RECORD LEVEL, NOT EXPRESSION LEVEL. `_parseTimestamp` is private, and
// agreement of the parse expression alone would not be the claim: what matters
// is whether the two paths ACCEPT THE SAME RECORDS. So the entry points driven
// are the ones each path actually uses on a legacy map — `EventRecord.fromMap`
// (the app's `_load`) and `rawMapToRow` (the migration). Each is given the same
// minimal map; only `timestamp` varies.
//
// For every row the two must agree on accept/reject, and where both accept, on
// the INSTANT and on the string the value round-trips to.

import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/storage_migration.dart';

/// One row: a label, and the `timestamp` value under test. [absent] means the
/// key is left out of the map entirely, which is not the same as null.
class _Row {
  const _Row(this.label, this.value, {this.absent = false});
  final String label;
  final Object? value;
  final bool absent;
}

const List<_Row> _table = <_Row>[
  // The three stored shapes (Brief 196).
  _Row('shape 1  Dart naive local, microseconds', '2026-08-22T18:18:35.180820'),
  _Row('shape 2  Swift true UTC, Z', '2026-08-22T06:45:09.000Z'),
  _Row('shape 3  Swift-origin normalised, naive', '2026-08-24T03:07:06.000'),
  // The brief's named edge cases.
  _Row('empty string', ''),
  _Row('whitespace only', '   '),
  _Row('null', null),
  _Row('non-string: int epoch', 1755843909),
  _Row('non-string: bool', true),
  _Row('date with no time', '2026-08-22'),
  _Row('two-digit year', '26-08-22T10:00:00'),
  _Row('bare time', '18:18:35'),
  _Row('trailing space', '2026-08-22T18:18:35 '),
  // Beyond the brief, same question.
  _Row('key absent', null, absent: true),
  _Row('leading space', ' 2026-08-22T18:18:35'),
  _Row('explicit offset +10:00', '2026-08-22T16:45:09+10:00'),
];

Map<String, dynamic> _mapFor(_Row r) => <String, dynamic>{
      'id': 'agree-${r.label.hashCode}',
      if (!r.absent) 'timestamp': r.value,
    };

void main() {
  test('the app and the migration accept and reject the SAME records, with the same instant', () {
    var accepted = 0;
    var rejected = 0;
    final disagreements = <String>[];

    for (final r in _table) {
      final app = EventRecord.fromMap(_mapFor(r));
      final row = rawMapToRow(_mapFor(r), 0, <String, int>{});

      final appAccepts = app != null;
      final migAccepts = row != null;
      if (appAccepts != migAccepts) {
        disagreements.add('${r.label}: app ${appAccepts ? "ACCEPTS" : "rejects"}, '
            'migration ${migAccepts ? "ACCEPTS" : "rejects"}');
        continue;
      }
      // ignore: avoid_print
      print('   ${appAccepts ? "ACCEPT" : "reject"}  ${r.label}'
          '${appAccepts ? "  -> ${app!.timestamp.toIso8601String()}" : ""}');
      if (!appAccepts) {
        rejected++;
        continue;
      }
      accepted++;

      // The migration stores TEXT; the SQLite reader parses it back. Compare the
      // INSTANT each path lands on, and the string each would carry forward.
      final migrated = DateTime.parse(row!['logged_at']! as String);
      if (!migrated.isAtSameMomentAs(app!.timestamp)) {
        disagreements.add('${r.label}: instant differs — app ${app.timestamp.toUtc()}, '
            'migration ${migrated.toUtc()}');
      }
      if (row['logged_at'] != app.timestamp.toIso8601String()) {
        disagreements.add('${r.label}: stored string differs — app '
            '"${app.timestamp.toIso8601String()}", migration "${row['logged_at']}"');
      }
    }

    // ignore: avoid_print
    print('   PARSE AGREEMENT (unit=inputs): ${_table.length} driven, '
        '$accepted accepted by both, $rejected rejected by both, '
        '${disagreements.length} disagreements');
    for (final d in disagreements) {
      // ignore: avoid_print
      print('   DISAGREE  $d');
    }

    expect(accepted + rejected + disagreements.length, greaterThanOrEqualTo(_table.length),
        reason: 'every row must land in exactly one bucket');
    expect(disagreements, isEmpty,
        reason: 'the migration would drop a record the app shows, or show one it drops');
  });

  test('POSITIVE CONTROL: the three stored shapes are all ACCEPTED by the app path', () {
    // Without this, a table the app rejected wholesale would "agree" perfectly.
    for (final r in _table.take(3)) {
      expect(EventRecord.fromMap(_mapFor(r)), isNotNull, reason: r.label);
    }
  });
}
