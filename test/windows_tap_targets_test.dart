import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/history_screen.dart';
import 'package:medical_event_recorder/theme/mer_theme.dart';

/// ⭐ THE DESKTOP COLUMN §13(x) DOES NOT HAVE. AUDIT.md §13(y).
///
/// `theme_data.dart:400-407` selects `MaterialTapTargetSize.padded` for
/// android / fuchsia / iOS and `shrinkWrap` for linux / macOS / **windows**.
/// This app sets neither `materialTapTargetSize` nor `platform`, so the 48x48
/// floor that every mobile measurement rests on **does not apply on Windows**.
///
/// ⛔ MEASURED BY OVERRIDING THE PLATFORM, which is the exact condition
/// `ThemeData` branches on -- not by scraping a desktop window, where a target
/// cannot be measured at all. The negative control is the whole point: the SAME
/// widgets are measured under both platforms in one run, so a harness that
/// ignored the override would report identical numbers and fail loudly.

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

/// Every distinct interactive class on screen, with its measured target.
Map<String, String> measureTargets(WidgetTester tester) {
  final out = <String, String>{};
  void add(String label, Finder f) {
    if (!tester.any(f)) return;
    final r = tester.getRect(f.first);
    out[label] = '${r.width.toStringAsFixed(1)}x${r.height.toStringAsFixed(1)}';
  }

  add('IconButton', find.byType(IconButton));
  add('FilledButton', find.byType(FilledButton));
  add('OutlinedButton', find.byType(OutlinedButton));
  add('TextButton', find.byType(TextButton));
  add('ListTile', find.byType(ListTile));
  add('Checkbox', find.byType(Checkbox));
  add('SwitchListTile', find.byType(SwitchListTile));
  return out;
}

Future<Map<String, String>> pumpHistory(
    WidgetTester tester, TargetPlatform p, double w, double h) async {
  // ⛔ Reset INLINE at the end of each measurement, not via addTearDown: the
  // framework asserts on a changed foundation debug variable BEFORE tearDowns
  // run, so a tearDown reset is too late and the test fails with "The value of
  // a foundation debug variable was changed by the test."
  debugDefaultTargetPlatformOverride = p;
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    theme: MERTheme.light,
    home: HistoryScreen(
      records: rows(),
      onRecordsChanged: (_) async {},
      onEdit: (_, {required confirmOnSave}) async {},
    ),
  ));
  await tester.pumpAndSettle();

  final icons = find.byIcon(Icons.delete_outline);
  final n = tester.widgetList(icons).length;
  final btn0 = tester.getRect(
      find.ancestor(of: icons.at(0), matching: find.byType(IconButton)).first);
  final btn1 = tester.getRect(
      find.ancestor(of: icons.at(1), matching: find.byType(IconButton)).first);

  final m = measureTargets(tester);
  debugDefaultTargetPlatformOverride = null;
  m['delete_count'] = '$n';
  m['delete_gap'] = (btn1.top - btn0.bottom).toStringAsFixed(1);
  m['delete_centre_to_centre'] =
      (btn1.center.dy - btn0.center.dy).toStringAsFixed(1);
  // ignore: avoid_print
  print('TARGETS ${p.name} ${w.toStringAsFixed(0)}x${h.toStringAsFixed(0)} '
      '${m.entries.map((e) => "${e.key}=${e.value}").join(" ")}');
  return m;
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
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('History targets: WINDOWS vs ANDROID at the same size',
      (tester) async {
    final win = await pumpHistory(tester, TargetPlatform.windows, 1280, 720);
    final and = await pumpHistory(tester, TargetPlatform.android, 1280, 720);

    // ⛔ THE NEGATIVE CONTROL. If the platform override did nothing, these
    // would be identical and every number above would be meaningless.
    expect(win['IconButton'], isNot(equals(and['IconButton'])),
        reason: 'shrinkWrap must yield a SMALLER IconButton than padded; '
            'identical values mean the override did not take effect');
    // ignore: avoid_print
    print('CONTROL windows IconButton=${win['IconButton']}  '
        'android IconButton=${and['IconButton']}');

    // and the thresholds, reported not asserted
    for (final e in {'windows': win, 'android': and}.entries) {
      final t = e.value['IconButton']!;
      final h = double.parse(t.split('x')[1]);
      // ignore: avoid_print
      print('THRESHOLD ${e.key} IconButton h=$h '
          'meets24=${h >= 24} meets44=${h >= 44} meets48=${h >= 48}');
    }
  });

  testWidgets('the width cap at desktop widths', (tester) async {
    // history is UNCAPPED, so its content should fill the window.
    for (final w in [1280.0, 1920.0]) {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      tester.view.physicalSize = Size(w, 720);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(MaterialApp(
        theme: MERTheme.light,
        home: HistoryScreen(
          records: rows(),
          onRecordsChanged: (_) async {},
          onEdit: (_, {required confirmOnSave}) async {},
        ),
      ));
      await tester.pumpAndSettle();
      final tile = tester.getSize(find.byType(ListTile).first);
      final capped = find.byWidgetPredicate(
          (x) => x is ConstrainedBox && x.constraints.maxWidth == 520);
      // ignore: avoid_print
      print('WIDTH history window=${w.toStringAsFixed(0)} '
          'rowWidth=${tile.width.toStringAsFixed(1)} '
          'has520Cap=${tester.any(capped)}');
    }
    debugDefaultTargetPlatformOverride = null;
    tester.view.reset();
  });
}
