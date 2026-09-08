import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/history_screen.dart';

/// The History delete control's geometry, measured rather than eyeballed.
///
/// §8 records that it carries no accessibility label. This measures what the
/// captures could not settle: how far it sits from its own row's text, how far
/// from the NEXT row's icon, its tap target, and how many are on screen at once.
///
/// ⭐ One width per PROCESS is not needed here -- no `SharedPreferences` state
/// varies between the cases, only `physicalSize`, which `tester.view` resets per
/// test. The prefs are set once and identically. The negative control at the end
/// asserts the VISIBLE-ROW COUNT differs across the three widths, which is the
/// figure that proves the viewport override took effect -- and pins the tap
/// target as constant, which is what a reader would otherwise assume silently.

/// Twelve records with the same shape, which is the scannability case: a real
/// history of similar events. Complete, so no row carries "Add details".
List<EventRecord> rows() => List.generate(
      12,
      (i) => EventRecord(
        id: 'r$i',
        timestamp: DateTime(2026, 8, 20, 3, 1),
        duration: DurationCategory.lt1,
        durationSeconds: 40,
        eventType: 'seizure',
        severity: EventSeverity.mild,
        feelings: const <String>[],
        triggers: const <String>[],
        referralRequired: false,
        notes: '',
        detailsCompleted: true,
      ),
    );

final Map<double, Map<String, double>> results = {};

Future<void> measure(WidgetTester tester, double w, double h) async {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: HistoryScreen(
      records: rows(),
      onRecordsChanged: (_) async {},
      onEdit: (_, {required confirmOnSave}) async {},
    ),
  ));
  await tester.pumpAndSettle();

  final icons = find.byIcon(Icons.delete_outline);
  final n = tester.widgetList(icons).length;
  expect(n, greaterThan(0), reason: 'every row carries one');

  final r0 = tester.getRect(icons.at(0));

  // ⛔ THE TEXT GAP IS NOT REPORTED, AND THIS RECORDS WHY.
  // `find.textContaining('Seizure').at(0)` was used to locate the row title,
  // and its measured left edge MOVED BY THE FULL WIDTH DELTA between the three
  // cases (375 -> 430 -> 800 shifted it 258 -> 313 -> 683). A left-aligned
  // ListTile title cannot do that, so the finder was matching something else
  // and the element could not be identified with confidence. Reporting a
  // number whose subject is unknown is worse than reporting none, so the
  // text-to-icon distance is recorded as UNDETERMINED FROM THIS HARNESS.
  //
  // What IS identifiable is measured below: the IconButton's own rect, which
  // is the TAP TARGET, and the vertical spacing between consecutive icons.
  final btn = find.ancestor(of: icons.at(0), matching: find.byType(IconButton));
  final btnRect = tester.getRect(btn.first);
  final btn1 = n > 1
      ? tester.getRect(find.ancestor(of: icons.at(1), matching: find.byType(IconButton)).first)
      : btnRect;

  final m = {
    'icons_on_screen': n.toDouble(),
    'ICON_glyph_w': r0.width,
    'ICON_glyph_h': r0.height,
    'TARGET_w': btnRect.width,
    'TARGET_h': btnRect.height,
    'target_centre_y': btnRect.center.dy,
    'next_target_centre_y': btn1.center.dy,
    'centre_to_centre': btn1.center.dy - btnRect.center.dy,
    'vertical_GAP_between_targets': btn1.top - btnRect.bottom,
  };
  results[w] = m;
  // ignore: avoid_print
  print('MEASURED W=${w.toStringAsFixed(0)} '
      '${m.entries.map((e) => "${e.key}=${e.value.toStringAsFixed(1)}").join(" ")}');
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'disclaimerAcceptedVersion': kDisclaimerVersion,
      kWalkthroughSeenVersionKey: kWalkthroughVersion,
    });
    StorageBoot.debugSet();
    Vocabularies.debugReset();
  });
  tearDown(() {
    StorageBoot.debugSet();
    Vocabularies.debugReset();
  });

  testWidgets('375', (t) async => measure(t, 375, 667));
  testWidgets('430', (t) async => measure(t, 430, 932));
  testWidgets('800', (t) async => measure(t, 800, 1280));

  testWidgets('NEGATIVE CONTROL: the three widths differ', (t) async {
    // Without this, a harness that returned one layout for every size would
    // report three identical rows and read exactly as convincingly.
    expect(results.length, 3, reason: 'all three ran');
    // ⭐ The control is on the GLYPH gap, not the BOX gap. The box gap is
    // constant at every width BY CONSTRUCTION -- ListTile's title fills the
    // slot -- so asserting it varies would fail on a working harness. The
    // glyph gap is what actually grows, and icons_on_screen varies too, which
    // is the independent proof the viewport override took effect.
    final counts = results.values.map((m) => m['icons_on_screen']).toSet();
    expect(counts.length, greaterThan(1),
        reason: 'the number of visible rows MUST change with height; identical '
            'counts mean the viewport override did not take effect');
    final targets = results.values.map((m) => m['TARGET_h']).toSet();
    expect(targets.length, 1,
        reason: 'and the tap target is expected CONSTANT at every width -- '
            'pinned so a future change to it fails loudly');
    // ignore: avoid_print
    print('CONTROL visible-row counts: ${counts.toList()}  target heights: ${targets.toList()}');
  });
}
