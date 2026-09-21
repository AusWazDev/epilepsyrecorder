// ⛔ BRIEF 69 ESCAPE CLAUSE 1 — MEASURED, NOT ASSERTED.
//
// The brief says: "If the app bar cannot take a drawer without moving something
// — if HomeScreen's AppBar has a leading widget, or the hamburger displaces the
// title — stop and report the conflict rather than rearranging the bar."
//
// HomeScreen's AppBar declares no `leading`, so setting `drawer:` makes Flutter
// auto-insert a hamburger into the leading slot. That NARROWS the title slot.
// The question is whether the title still fits, and `home_screen.dart:1145`
// already records the pre-drawer figure: "274.2 required into a 335.0 Row
// constraint" in Roboto at the 1.34 title clamp.
//
// ⚠️ INSTRUMENT DISCIPLINE, per CLAUDE.md:
//   · the SLOT WIDTH is a CONSTRAINT -> a widget test is authoritative;
//   · the REQUIRED WIDTH depends on glyph widths -> it must be laid out FREE
//     with an explicit family, never read off a rendered paragraph, because one
//     that has already ellipsised reports the SLOT width and looks plausible.
//   · AppBar.title is clamped at _kMaxTitleTextScaleFactor = 1.34, so a 200%
//     figure that assumes 2.0 is wrong before the font is considered.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/theme/mer_type.dart';
import 'package:medical_event_recorder/widgets/mer_icon_widget.dart';

const double kTitleClamp = 1.34;   // AppBar's _kMaxTitleTextScaleFactor

/// The AppBar title exactly as `home_screen.dart:1131-1163` builds it.
///
/// ⚠️ KEYED, and that is not decoration. `find.byType(Row).first` catches an
/// AppBar-INTERNAL Row (NavigationToolbar builds its own), so an unkeyed find
/// measures the wrong box and reports a plausible number. First run read 343.0
/// where `home_screen.dart:1145` records 335.0, which is what prompted the key.
const titleKey = Key('mer-appbar-title-row');

Widget titleRow() => const Row(
      key: titleKey,
      children: [
        MERIconWidget(size: 40, style: MERIconStyle.mark),
        SizedBox(width: 10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(kAppName, style: MERType.subheadOnPrimary),
              Text('Record · Review · Share', style: MERType.microOnPrimaryMuted),
            ],
          ),
        ),
      ],
    );

/// ⛔ THE COMPARISON IS NOT "AppBar vs AppBar + hamburger". THE DRAWER REPLACES
/// THE POPUP MENU, so the trailing `actions:` slot is FREED at the same moment
/// the leading slot is taken. Measuring only the hamburger's cost would answer a
/// question nobody is asking and overstate the loss.
///
///   BEFORE : no leading  · actions [PopupMenuButton]
///   AFTER  : hamburger   · no actions
Widget harness({required bool withDrawer}) => MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: titleRow(),
          actions: withDrawer
              ? null
              : [
                  PopupMenuButton<int>(
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 0, child: Text('History')),
                    ],
                  ),
                ],
        ),
        drawer: withDrawer ? const Drawer(child: SizedBox()) : null,
        body: const SizedBox(),
      ),
    );

/// FREE layout — no slot, no ellipsis. The only honest source of a required width.
double freeWidth(String s, TextStyle style, double scale) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: style.copyWith(fontFamily: 'Roboto')),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.linear(scale),
  )..layout();
  return tp.width;
}

void main() {
  setUpAll(() async {
    final path = '${Platform.environment['FLUTTER_ROOT'] ?? 'C:/Flutter/flutter'}'
        '/bin/cache/artifacts/material_fonts/roboto-regular.ttf';
    final file = File(path);
    if (!file.existsSync()) {
      fail('Roboto not found at $path — cannot measure real glyph widths.');
    }
    final loader = FontLoader('Roboto')
      ..addFont(Future.value(file.readAsBytesSync().buffer.asByteData()));
    await loader.load();
  });

  Future<double> slotWidth(WidgetTester tester, bool withDrawer, double w) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = Size(w, 800 * 3);
    tester.view.devicePixelRatio = 3.0;
    await tester.pumpWidget(harness(withDrawer: withDrawer));
    await tester.pumpAndSettle();
    return tester.getSize(find.byKey(titleKey)).width;
  }

  Future<double> titleLeft(WidgetTester tester, bool withDrawer, double w) async {
    addTearDown(tester.view.reset);
    tester.view.physicalSize = Size(w, 800 * 3);
    tester.view.devicePixelRatio = 3.0;
    await tester.pumpWidget(harness(withDrawer: withDrawer));
    await tester.pumpAndSettle();
    return tester.getTopLeft(find.byKey(titleKey)).dx;
  }

  // ⛔ FITTING AND BEING DISPLACED ARE TWO DIFFERENT QUESTIONS, and the first
  // run of this file only answered the first. The brief's escape clause asks
  // whether the hamburger DISPLACES the title — a POSITION, not a width.
  testWidgets('does the drawer MOVE the title', (tester) async {
    for (final w in <double>[375, 800]) {
      final before = await titleLeft(tester, false, w * 3);
      final after  = await titleLeft(tester, true,  w * 3);
      // ignore: avoid_print
      print('  w=${w.toStringAsFixed(0)}  title left ${before.toStringAsFixed(1)} -> '
            '${after.toStringAsFixed(1)}  displaced by ${(after - before).toStringAsFixed(1)}');
    }
  });

  testWidgets('a drawer narrows the AppBar title slot — by how much, and does it still fit',
      (tester) async {
    final results = <String>[];
    var anyFails = false;

    for (final w in <double>[375, 800]) {
      for (final scale in <double>[1.0, kTitleClamp]) {
        final without = await slotWidth(tester, false, w * 3);
        final with_   = await slotWidth(tester, true,  w * 3);

        // Required = icon (40) + gap (10) + the wider of the two text lines,
        // each laid out FREE in Roboto at the clamped scale.
        final t1 = freeWidth(kAppName, MERType.subheadOnPrimary, scale);
        final t2 = freeWidth('Record · Review · Share', MERType.microOnPrimaryMuted, scale);
        final required = 40 + 10 + (t1 > t2 ? t1 : t2);

        final headroomBefore = without - required;
        final headroomAfter  = with_ - required;
        final fits = headroomAfter >= 0;
        if (!fits) anyFails = true;

        results.add(
          'w=${w.toStringAsFixed(0)} scale=${scale.toStringAsFixed(2)}  '
          'slot ${without.toStringAsFixed(1)} -> ${with_.toStringAsFixed(1)} '
          '(net change ${(without - with_).toStringAsFixed(1)})  '
          'required ${required.toStringAsFixed(1)}  '
          'headroom ${headroomBefore.toStringAsFixed(1)} -> ${headroomAfter.toStringAsFixed(1)}  '
          '${fits ? "FITS" : "⛔ DOES NOT FIT"}',
        );
      }
    }

    // ignore: avoid_print
    print('\n=== BRIEF 69 ESCAPE CLAUSE 1 — AppBar title headroom with a Drawer ===');
    for (final r in results) {
      // ignore: avoid_print
      print('  $r');
    }
    // ignore: avoid_print
    print('  verdict: ${anyFails ? "the hamburger DISPLACES the title" : "the title survives"}\n');

    // CONTROL: the measurement must be capable of reporting a narrowing at all.
    final a = await slotWidth(tester, false, 375 * 3);
    final b = await slotWidth(tester, true, 375 * 3);
    expect(b, lessThan(a),
        reason: 'CONTROL: adding a drawer must measurably narrow the title slot. '
                'If these are equal the harness is not inserting the hamburger '
                'and every figure above is meaningless.');
  });
}
