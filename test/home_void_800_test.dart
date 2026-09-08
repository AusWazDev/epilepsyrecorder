import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/home_screen.dart';

/// Home's content against its viewport, at 800x1280.
///
/// §7 measured the void above and below SEPARATELY and reported roughly 150 px
/// above at 430. This measures both as a PROPORTION of the viewport, which is
/// the figure that cannot be got by eye.
///
/// ⭐ ONE STATE PER PROCESS. `setMockInitialValues` does not take effect once an
/// instance exists earlier in the same file, so the 800 case lives in its own
/// file, `home_void_430_test.dart`. Two configurations produced convincing wrong
/// numbers on 8 September 2026.
///
/// Harness copied from `storage_fallback_banner_test.dart`, which is the working
/// precedent for pumping HomeScreen: both gate keys set, and `StorageBoot`
/// primed so the fallback banner does not appear and change the layout.

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

  testWidgets('home content vs viewport at 800x1280', (tester) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    final sv = find.byType(SingleChildScrollView);
    expect(sv, findsWidgets, reason: 'home scrolls, so a viewport exists');
    final viewport = tester.getSize(sv.first);
    final viewportTop = tester.getTopLeft(sv.first).dy;

    // \u26d4 The OUTER ConstrainedBox carries `minHeight: maxHeight - 40`, so
    // its height is the STRETCHED height and always viewport-40. Measuring it
    // reports the viewport back, not the content. The real content extent is
    // the span from the first painted child to the last, so it is measured
    // from the Column's CHILDREN.
    final col = find.descendant(of: sv.first, matching: find.byType(Column));
    final colRect = tester.getRect(col.first);

    // Every direct child of that Column, in paint order.
    final colWidget = tester.widget<Column>(col.first);
    double top = double.infinity, bottom = -1;
    for (final child in colWidget.children) {
      final f = find.byWidget(child);
      if (!tester.any(f)) continue;
      final r = tester.getRect(f);
      if (r.height <= 0) continue;
      if (r.top < top) top = r.top;
      if (r.bottom > bottom) bottom = r.bottom;
    }
    final contentTop = top;
    final contentBottom = bottom;

    // The INNER ConstrainedBox is the maxWidth: 520 one -- find it by value.
    final inner = find.byWidgetPredicate((w) =>
        w is ConstrainedBox && w.constraints.maxWidth == 520);
    final contentW = tester.any(inner) ? tester.getSize(inner.first).width : -1;

    final btn = find.textContaining('Record Event');
    expect(btn, findsWidgets);
    final b = tester.getRect(btn.first);

    // ignore: avoid_print
    print('MEASURED W=800 '
        'viewportTop=${viewportTop.toStringAsFixed(1)} '
        'viewportH=${viewport.height.toStringAsFixed(1)} '
        'viewportW=${viewport.width.toStringAsFixed(1)} '
        'colTop=${colRect.top.toStringAsFixed(1)} '
        'colH=${colRect.height.toStringAsFixed(1)} '
        'contentTop=${contentTop.toStringAsFixed(1)} '
        'contentBottom=${contentBottom.toStringAsFixed(1)} '
        'contentH=${(contentBottom - contentTop).toStringAsFixed(1)} '
        'contentW=${contentW.toStringAsFixed(1)} '
        'btnTop=${b.top.toStringAsFixed(1)} '
        'btnBottom=${b.bottom.toStringAsFixed(1)}');

    expect(viewport.height, greaterThan(0));
  });
}
