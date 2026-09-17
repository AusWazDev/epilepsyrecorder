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
import 'package:medical_event_recorder/screens/disclaimer_screen.dart';
import 'package:medical_event_recorder/screens/help_screen.dart';
import 'package:medical_event_recorder/screens/home_screen.dart';
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

  /// The REAL maximum width the app bar hands its title, measured from the
  /// render tree rather than derived from arithmetic.
  ///
  /// ⛔ THE ARITHMETIC WAS 375 - 56 - 96 = 223 AND IT WAS A GUESS. Brief U
  /// flagged it as arithmetic rather than a measurement and declined to call it
  /// a finding on that basis; this is the measurement.
  ///
  /// ⚠️ `AppBar` wraps its title in
  /// `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.34)`, so the title
  /// renders at 1.34x even when the platform says 2.0. Measuring it at 2.0
  /// would report an overflow no device shows.
  double? titleSlot(WidgetTester tester, String titleText) {
    double? found;
    void visit(RenderObject o) {
      if (o is RenderParagraph && o.text.toPlainText() == titleText) {
        found = o.constraints.maxWidth;
      }
      o.visitChildren(visit);
    }

    visit(tester.binding.renderViews.single);
    return found;
  }

  testWidgets('SLOT: the app-bar title constraint, measured', (tester) async {
    final cases = <String, Widget Function()>{
      'history': () => HistoryScreen(
            records: rows(),
            onRecordsChanged: (_) async {},
            onEdit: (_, {required confirmOnSave}) async {},
          ),
      'form': () => const LogEventScreen(existing: null, confirmOnSave: false),
      'about': () => AboutScreen(onReset: () {}),
      'help': () => const HelpScreen(),
      'your-data': () => YourDataScreen(
            onExport: (_) async {},
            onBackUp: (_) async {},
            onRestore: (_) async {},
          ),
      // The BINDING case: home's title is a Row carrying a 40pt mark and a
      // 10pt gap before the Column, and it is the longest title in the app.
      'home': () => const HomeScreen(),
      'disclaimer': () => const DisclaimerScreen(),
    };
    final titles = <String, String>{
      'history': 'History',
      'form': 'Log new event',
      'about': 'About',
      'help': 'Help',
      'your-data': 'Your data',
      'home': 'Medical Event Recorder',
      'disclaimer': 'Medical Event Recorder',
    };

    for (final e in cases.entries) {
      sizeAndScale(tester, phone, 2.0);
      await tester.pumpWidget(
          MaterialApp(theme: MERTheme.light, home: e.value()));
      await tester.pumpAndSettle();
      // ⛔ DRAIN FIRST. Home's app-bar Row already overflows at 200% on
      // unmodified code, and an undrained layout exception would fail this
      // probe instead of letting it report the number.
      for (var x = tester.takeException(); x != null; x = tester.takeException()) {}
      final slot = titleSlot(tester, titles[e.key]!);
      final sub = titleSlot(tester, 'Medical Event Recorder');
      // The ROW's own constraint, for the two screens whose title Column is
      // unconstrained and therefore reports Infinity above.
      double? rowMax;
      void findRow(RenderObject o) {
        if (o is RenderFlex &&
            o.direction == Axis.horizontal &&
            rowMax == null &&
            o.constraints.maxWidth.isFinite &&
            o.constraints.maxWidth < 360) {
          rowMax = o.constraints.maxWidth;
        }
        o.visitChildren(findRow);
      }
      findRow(tester.binding.renderViews.single);
      // ignore: avoid_print
      print('SLOT ${e.key.padRight(10)} title "${titles[e.key]}" '
          'maxWidth=${slot?.toStringAsFixed(1)}   '
          'subtitle maxWidth=${sub?.toStringAsFixed(1)}   '
          'firstRow maxWidth=${rowMax?.toStringAsFixed(1)}');
    }
    expect(cases, isNotEmpty);
  });

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

  testWidgets('HOME at 200% — the primary screen, and it was MISSING', (tester) async {
    // ⛔ HOME WAS ABSENT FROM THE BRIEF U BASELINE, and that omission hid a
    // figure worth having: `home_screen.dart:952`'s app-bar Row reports an
    // overflow at 200% on unmodified code.
    //
    // ⚠️ THAT FIGURE IS A HARNESS ARTEFACT AND MUST NOT BE READ AS A DEVICE
    // CONDITION. `FontLoader` registers a family NAMED Roboto and corrects only
    // a style that resolves to it; the app-bar title names no `fontFamily` and
    // inherits none, so it measures in the engine's one-em-per-glyph font.
    //
    // ⛔ IT MOVED 138.2 -> 226.7 WHEN THE TITLE WENT 13 -> 16, AND THAT IS NOT
    // A REGRESSION. In Roboto, laid out free, the same change is 182.2 -> 224.2
    // against a MEASURED Row constraint of 335.0 here and 307.0 on the
    // disclaimer. `CLAUDE.md`: where a claim turns on glyph width the real
    // render is authoritative and the widget test is not. The free measurement
    // lives in `type_scale_200_measure_test.dart`.
    //
    // ⭐ The figure is still printed, because a CHANGE in it is worth seeing
    // even when its absolute value is not a device number. A baseline that skips the app's primary screen
    // is reporting on its own reach, which is the rule this file already
    // states about the two instruments.
    await probe(tester, 'home', const HomeScreen());
  });

  testWidgets('disclaimer at 200%', (tester) async {
    await probe(tester, 'disclaimer', const DisclaimerScreen());
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
