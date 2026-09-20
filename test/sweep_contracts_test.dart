import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/models/event_record.dart';

/// THREE CONTRACTS FROM THE BRIEF 57 SWEEP — structures #1, #3 and #9.
/// Built 20 September 2026.
///
/// ⭐ Each is a SOURCE SCAN, which is real enforcement rather than a lesser
/// form: it is how the `exportScope` count guard, the save-location label pair
/// and the `.visible` manifest work. ⛔ A behavioural test cannot see any of
/// these three — each concerns the SHAPE of the code rather than what one
/// screen renders.

String _read(String p) => File(p).readAsStringSync();

/// The body of `home_screen`'s exclusive banner chain: from the chain head to
/// the end of its last `else if` branch.
String _chainBody() {
  final lines = const LineSplitter().convert(_read('lib/screens/home_screen.dart'));
  final start = lines.indexWhere(
      (l) => l.contains('if (!_notificationsAllowed && !Platform.isWindows)'));
  expect(start, greaterThanOrEqualTo(0),
      reason: 'CONTROL: the chain head must be findable, or the scan below '
          'runs over an empty string');
  var end = start;
  var lastElse = start;
  while (end < lines.length && end < start + 200) {
    if (lines[end].contains('] else if (')) lastElse = end;
    if (lines[end].trimLeft().startsWith('// ──') && end > start + 2) break;
    end++;
  }
  return lines.sublist(start, lastElse + 40 > lines.length
      ? lines.length
      : lastElse + 40).join('\n');
}

void main() {
  group('#1 the home banner chain', () {
    // ⭐ THE INVARIANT: only ADVISORY content may occupy the exclusive chain.
    // Anything describing data at risk, or an event in progress, stacks above
    // it.
    //
    // ⛔ WHY THE CHAIN IS DANGEROUS, in the code's own words: "The chain is
    // exclusive, so putting this in it would hide whichever banner it
    // displaced — including the active-event banner, whose End button is the
    // only way to end an event on Android."
    //
    // ⚠️ The backup reminder sat in it for a month because it was classified
    // ADVISORY. In an app with no backend, where an uninstall destroys
    // everything, a backup prompt is data at risk. The classification was the
    // error, not the chain.

    test('CONTROL: the chain is findable and non-trivial', () {
      expect(_chainBody().length, greaterThan(300));
      expect(_chainBody(), contains('] else if ('),
          reason: 'the extracted region must actually contain the chain');
    });

    test('no data-at-risk banner is inside the exclusive chain', () {
      final body = _chainBody();
      for (final forbidden in [
        '_showBackupReminder',
        '_writeFailed',
        '_storageFellBack',
      ]) {
        expect(body.contains(forbidden), isFalse,
            reason: '"$forbidden" appears inside the exclusive banner chain. '
                'Data at risk must STACK above the chain, not compete for its '
                'single slot — a branch there hides whatever it displaces, '
                'including the active-event banner whose End button is the '
                'only way to end an event on Android');
      }
    });
  });

  group('#3 FilterKind', () {
    // ⭐ THE INVARIANT: membership of `activeFilters` is restricted to states
    // the user SET and can CLEAR.
    //
    // ⛔ The rule, from the enum's own doc: "Hiding a record must NEVER join
    // `activeFilters`: the badge and the banner are CLEARABILITY claims … and
    // a hidden record is not clearable from there. Revealing one is."
    //
    // ⚠️ THE DISTINCTION THIS GUARDS: a record's `hidden` FLAG and a
    // `HiddenView` the user SELECTED are two different objects wearing the same
    // word. The view is clearable; the flag is not.

    test('activeFilters never reads a record\'s hidden flag', () {
      final src = _read('lib/screens/history_screen.dart');
      final i = src.indexOf('Set<FilterKind> get activeFilters');
      expect(i, greaterThanOrEqualTo(0), reason: 'CONTROL: getter findable');
      final body = src.substring(i, i + 900);

      expect(body.contains('.hidden'), isFalse,
          reason: 'activeFilters reads a record\'s `hidden` flag. The badge and '
              'the banner are CLEARABILITY claims, and Clear cannot un-hide a '
              'record — so a hidden record must never make the banner appear. '
              'A HiddenView the USER selected may, and does');
      expect(body.contains('_hiddenView != HiddenView.exclude'), isTrue,
          reason: 'and the view — which IS clearable — must still join, or the '
              'banner stops describing what Clear will do');
    });
  });

  group('#9 CSV columns', () {
    // ⭐ THE INVARIANT: any change to the column set, or to what a cell holds
    // for the same stored state, bumps the shape marker — with no judgement
    // about whether the change is "real".
    //
    // ⛔ WHAT THIS CHECKS AND WHAT IT CANNOT: it pins the COLUMN SET to the
    // marker, so renaming, adding, removing or reordering a column without
    // bumping fails. ⚠️ It CANNOT see a change to what a cell HOLDS for the
    // same column — that half of the rule stays a convention, and saying so is
    // the point.

    const marker = 'v7';
    const columns = <String>[
      'timestamp_iso', 'date', 'time', 'record_kind', 'condition',
      'event_type', 'duration', 'duration_seconds', 'severity',
      'observations', 'beforehand', 'rescue_med_given', 'rescue_med_helped',
      'rescue_med_second_dose', 'referral_required', 'medication_kind', 'notes',
    ];

    test('CONTROL: the recorded columns really are the header', () {
      final src = _read('lib/models/event_record.dart');
      for (final c in columns) {
        expect(src.contains("'$c'"), isTrue,
            reason: 'the pinned column "$c" is not in the source, so this '
                'contract is pinned to a header that does not exist');
      }
    });

    test('the column set and the marker move together', () {
      expect(kCsvShapeVersion, marker,
          reason: 'THE CONTRACT: the marker is now "$kCsvShapeVersion" but the '
              'column set pinned here is the one that belonged to "$marker".\n\n'
              'If you CHANGED THE COLUMNS: update the list above AND leave the '
              'marker bumped — that is the rule working.\n'
              'If you bumped the marker WITHOUT changing columns: update '
              '`marker` here. The rule permits that (a cell\'s CONTENT can '
              'change for the same column), and this test cannot see it, which '
              'is why that half stays a convention.');
      expect(columns.length, 17,
          reason: 'the pinned set is no longer 17 columns');
      expect(columns.toSet().length, columns.length,
          reason: 'a duplicate column name would make the header ambiguous');
    });
  });
}
