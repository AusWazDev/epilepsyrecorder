import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/screens/home_screen.dart';
import 'package:medical_event_recorder/theme/mer_theme.dart';

/// The 200% half of the C1 measurement. ⛔ SEPARATE FILE because HomeScreen
/// is prefs-dependent and this project allows ONE such test per process.
///
/// ⛔ DOES CENTRING HOME'S COLUMN OVERFLOW AT 200% TEXT?
///
/// Brief 55 part C1 asks for the measurement rather than a choice:
/// `6fd3f1c` replaced `Center` with `Align.topCenter` inside a
/// `ConstrainedBox(minHeight: maxHeight - 40)`. ⭐ **Centring only overflows if
/// the content is TALLER than the viewport — at which point the `Align`'s
/// alignment is irrelevant, because the scroll view scrolls either way.**
///
/// ⚠️ **What actually decides it is whether the CONTENT exceeds the viewport at
/// 200%, so that is what this measures** — at the developer's device size, and
/// with the real font, because wrapping is what content height IS.
///
/// ⛔ MEASURES AND PRINTS. No layout compensation and no gate.

void main() {
  setUpAll(() async {
    final path =
        '${Platform.environment['FLUTTER_ROOT'] ?? 'C:/Flutter/flutter'}'
        '/bin/cache/artifacts/material_fonts/roboto-regular.ttf';
    final file = File(path);
    if (!file.existsSync()) fail('Roboto not found at $path');
    final bytes = file.readAsBytesSync();
    final loader = FontLoader('Roboto')
      ..addFont(Future.value(bytes.buffer.asByteData()));
    await loader.load();
  });

  Future<void> measure(WidgetTester tester, double scale) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(MaterialApp(
      theme: MERTheme.light,
      home: const HomeScreen(),
    ));
    await tester.pumpAndSettle();

    final caught = <String>[];
    for (var e = tester.takeException(); e != null; e = tester.takeException()) {
      caught.add(e.toString().split('\n').first);
    }

    final scrollable = find.byType(Scrollable).first;
    final pos = tester.state<ScrollableState>(scrollable).position;
    final viewport = pos.viewportDimension;
    final content  = viewport + pos.maxScrollExtent;

    // ignore: avoid_print
    print('HOME @800x1280, scale $scale, Roboto\n'
        '  viewport                 : ${viewport.toStringAsFixed(1)}\n'
        '  content                  : ${content.toStringAsFixed(1)}\n'
        '  ⭐ scrolls?               : '
        '${pos.maxScrollExtent > 0 ? "YES — content exceeds the viewport, so "
            "CENTRING CANNOT APPLY: there is no spare space to centre in" :
            "NO — content fits, so the Align's alignment is what decides "
            "where it sits"}\n'
        '  spare space (viewport-content): '
        '${(viewport - content).toStringAsFixed(1)}\n'
        '  exceptions               : ${caught.isEmpty ? "none" : caught.join(" | ")}');
  }

  testWidgets('home at 200%', (tester) async => measure(tester, 2.0));
}
