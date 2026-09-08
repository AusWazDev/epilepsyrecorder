import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/home_screen.dart';

/// ⛔ WHY DOES THE APP-BAR TITLE GET 328 px ON THE FIRST LAYOUT AND ENOUGH ON
/// THE SECOND? Home's title `Row` is `const` and its single action is an
/// unconditional `PopupMenuButton`, so neither side of the app bar is
/// data-dependent. Something else changes the width available to the title.
///
/// This measures it instead of reasoning about it: the title `Row`'s incoming
/// constraint and its children's widths, on pump 1 and pump 2, same width.

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

  testWidgets('APPBAR — title constraint and children, pump 1 vs pump 2',
      (tester) async {
    addTearDown(tester.view.reset);
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    tester.view.devicePixelRatio = 1.25;
    tester.view.physicalSize = const Size(500, 682.5); // 400 x 546 logical

    for (final pass in <int>[1, 2]) {
      final captured = <FlutterErrorDetails>[];
      final prev = FlutterError.onError;
      FlutterError.onError = captured.add;
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.pumpAndSettle();
      FlutterError.onError = prev;

      // The title Row is the RenderFlex whose creator chain names
      // _AppBarTitleBox. Find it by walking every RenderFlex.
      final rows = <RenderFlex>[];
      for (final e in tester.allElements) {
        final ro = e.renderObject;
        if (ro is RenderFlex && ro.direction == Axis.horizontal) {
          final creator = ro.debugCreator?.toString() ?? '';
          if (creator.contains('_AppBarTitleBox')) rows.add(ro);
        }
      }

      // ignore: avoid_print
      print('  PASS $pass  errors=${captured.length}  titleRows=${rows.length}');
      for (final r in rows) {
        final kids = <String>[];
        var child = r.firstChild;
        var total = 0.0;
        while (child != null) {
          final s = child.hasSize ? child.size : Size.zero;
          kids.add('${child.runtimeType}=${s.width.toStringAsFixed(1)}');
          total += s.width;
          child = r.childAfter(child);
        }
        // ignore: avoid_print
        print('    constraint=${r.constraints}  size=${r.size}  '
            'childrenTotal=${total.toStringAsFixed(1)}');
        // ignore: avoid_print
        print('    children: ${kids.join("  ")}');
      }

      // Every widget occupying app-bar horizontal space, to see what moved.
      final tb = find.byType(AppBar);
      if (tester.any(tb)) {
        // ignore: avoid_print
        print('    appBar size=${tester.getSize(tb.first)}');
      }
      final icons = find.descendant(of: tb.first, matching: find.byType(IconButton));
      // ignore: avoid_print
      print('    appBar IconButtons=${tester.widgetList(icons).length}');
      final popups =
          find.descendant(of: tb.first, matching: find.byType(PopupMenuButton<Object?>));
      // ignore: avoid_print
      print('    appBar PopupMenuButtons(any)='
          '${tester.widgetList(find.descendant(of: tb.first, matching: find.byWidgetPredicate((w) => w.runtimeType.toString().startsWith("PopupMenuButton")))).length}'
          '  typedFinder=${tester.widgetList(popups).length}');
    }

    debugDefaultTargetPlatformOverride = null;
    expect(true, isTrue, reason: 'diagnostic file; the print output is the result');
  });
}
