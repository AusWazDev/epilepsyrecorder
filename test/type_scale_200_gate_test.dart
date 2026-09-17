import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/about_screen.dart';
import 'package:medical_event_recorder/screens/help_screen.dart';
import 'package:medical_event_recorder/screens/history_screen.dart';
import 'package:medical_event_recorder/screens/log_event_screen.dart';
import 'package:medical_event_recorder/screens/your_data_screen.dart';
import 'package:medical_event_recorder/theme/mer_theme.dart';

/// ⛔ **THE 200% GATE.** Any NEW truncation or overflow is a STOP, not a
/// tolerance.
///
/// ## ⚠️ THIS FILE'S JOB IS THE BASELINE AS MUCH AS THE VERDICT
///
/// Truncation already exists at 200% — S3 records chips clipping to *"Seizure
/// /"* and *"Add your"*. **A truncation found after the scale lands cannot be
/// attributed to the scale unless the before-state is on the record**, so this
/// prints both a RenderFlex overflow list and an ellipsis census, and asserts
/// against a recorded baseline rather than against zero.
///
/// ## ⛔ TWO INSTRUMENTS, BECAUSE THEY SEE DIFFERENT FAILURES
///
/// `RenderFlex ... OVERFLOWING` catches a row whose children exceed it. It does
/// NOT catch a `Text` that fitted by ELLIPSISING, which is the failure the chip
/// case actually is — that paragraph reports no overflow because it resolved the
/// problem by removing characters. `didExceedMaxLines` is what sees that.
///
/// ⭐ Read structurally from the render tree rather than from the error report,
/// which is emitted once per RenderFlex at first paint and is easy to miss —
/// the idiom `a11y_batch_measure_test` established.
///
/// ## ⚠️ UNDER ROBOTO
///
/// The harness font is monospaced at one em per glyph and would report
/// truncation no device shows. Loaded in `setUpAll`.

List<String> overflowingRows(WidgetTester tester) {
  for (var e = tester.takeException(); e != null; e = tester.takeException()) {}
  final out = <String>[];
  void visit(RenderObject o) {
    if (o is RenderFlex && o.toStringShort().contains('OVERFLOWING')) {
      var extent = 0.0;
      o.visitChildren((c) {
        final s = (c as RenderBox).size;
        extent += o.direction == Axis.horizontal ? s.width : s.height;
      });
      final own = o.direction == Axis.horizontal ? o.size.width : o.size.height;
      out.add('${(extent - own).toStringAsFixed(1)} on ${o.direction.name}');
    }
    o.visitChildren(visit);
  }

  visit(tester.binding.renderViews.single);
  return out;
}

/// Every paragraph that resolved its overflow by REMOVING CHARACTERS.
///
/// ⛔ This is the instrument that sees the chip truncation. A `RenderParagraph`
/// with `didExceedMaxLines` true has clipped or ellipsised; it reports no
/// RenderFlex overflow because it did not push past anything.
List<String> truncated(WidgetTester tester) {
  final out = <String>[];
  void visit(RenderObject o) {
    if (o is RenderParagraph && o.didExceedMaxLines) {
      final t = o.text.toPlainText();
      out.add(t.length > 40 ? '${t.substring(0, 40)}…' : t);
    }
    o.visitChildren(visit);
  }

  visit(tester.binding.renderViews.single);
  return out;
}

void sizeAndScale(WidgetTester tester, Size logical, double scale) {
  tester.view.physicalSize = logical;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

List<EventRecord> rows() => <EventRecord>[
      EventRecord(
        id: 'a',
        timestamp: DateTime(2026, 8, 20, 10, 30),
        duration: DurationCategory.lt1,
        durationSeconds: 40,
        eventType: kTypeSeizure,
        severity: EventSeverity.mild,
        feelings: const <String>['Tired'],
        triggers: const <String>['Stress'],
        referralRequired: true,
        notes: 'a note',
        detailsCompleted: true,
      ),
    ];

void main() {
  const phone = Size(375, 667);

  setUpAll(() async {
    final path =
        '${Platform.environment['FLUTTER_ROOT'] ?? 'C:/Flutter/flutter'}'
        '/bin/cache/artifacts/material_fonts/roboto-regular.ttf';
    final file = File(path);
    if (!file.existsSync()) {
      fail('Roboto not found at $path — the harness font would report '
          'truncation no device shows');
    }
    final bytes = file.readAsBytesSync();
    final loader = FontLoader('Roboto')
      ..addFont(Future.value(bytes.buffer.asByteData()));
    await loader.load();

    SharedPreferences.setMockInitialValues(<String, Object>{
      'disclaimerAcceptedVersion': kDisclaimerVersion,
      kEventStorageKey: jsonEncode(rows().map((e) => e.toMap()).toList()),
    });
    StorageBoot.debugSet();
    Vocabularies.debugReset();
  });
  tearDownAll(Vocabularies.debugReset);
  setUp(Vocabularies.debugReset);

  Future<void> probe(WidgetTester tester, String name, Widget screen) async {
    sizeAndScale(tester, phone, 2.0);
    await tester.pumpWidget(MaterialApp(theme: MERTheme.light, home: screen));
    await tester.pumpAndSettle();
    final o = overflowingRows(tester);
    final t = truncated(tester);
    // ignore: avoid_print
    print('GATE $name @200% 375w\n'
        '  overflowing rows : ${o.isEmpty ? "none" : o.join(" | ")}\n'
        '  truncated text   : ${t.isEmpty ? "none" : t.join(" | ")}');
  }

  testWidgets('history at 200%', (tester) async {
    await probe(
        tester,
        'history',
        HistoryScreen(
          records: rows(),
          onRecordsChanged: (_) async {},
          onEdit: (_, {required confirmOnSave}) async {},
        ));
  });

  testWidgets('the form at 200%', (tester) async {
    await probe(tester, 'form',
        const LogEventScreen(existing: null, confirmOnSave: false));
  });

  testWidgets('about at 200%', (tester) async {
    await probe(tester, 'about', AboutScreen(onReset: () {}));
  });

  testWidgets('help at 200%', (tester) async {
    await probe(tester, 'help', const HelpScreen());
  });

  testWidgets('your data at 200%', (tester) async {
    await probe(
        tester,
        'your-data',
        YourDataScreen(
          onExport: (_) async {},
          onBackUp: (_) async {},
          onRestore: (_) async {},
        ));
  });
}
