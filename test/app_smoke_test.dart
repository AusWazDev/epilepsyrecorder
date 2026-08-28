import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Update package name if needed:
import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/main.dart';

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration step = const Duration(milliseconds: 50),
  int maxPumps = 200,
}) async {
  for (var i = 0; i < maxPumps; i++) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Timed out waiting for: $finder');
}

Finder popupMenuItemWithLabel(String label) {
  final textFinder = find.text(label).last;
  return find.ancestor(
    of: textFinder,
    matching: find.byWidgetPredicate((w) => w is PopupMenuItem),
  );
}

Future<void> tapOverflowMenuItem(WidgetTester tester, String label) async {
  await tester.tap(find.byIcon(Icons.more_vert));
  // ⚠️ SETTLE THE MENU BEFORE TAPPING AN ITEM. `pump()` alone leaves the popup
  // mid-animation: the item is FOUND, `tap` does not throw, and nothing
  // happens, because a tap during a route or menu transition is absorbed.
  // Indistinguishable from a missing widget, and it cost several passes here.
  await tester.pumpAndSettle();

  await pumpUntilFound(tester, find.text(label));
  final itemFinder = popupMenuItemWithLabel(label);
  await pumpUntilFound(tester, itemFinder);

  await tester.tap(itemFinder);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Mock SharedPreferences so getInstance() doesn't rely on platform channels in tests.
    // ⛔ BOTH GATES, and the key names matter.
    //
    // `disclaimerAccepted` (bool) has not been read since the disclaimer became
    // VERSIONED — main.dart reads `disclaimerAcceptedVersion` (String). These
    // two tests set the obsolete bool and had been failing on that ever since,
    // parked as "pre-existing" through many sessions.
    //
    // ⚠️ The walkthrough is a SECOND gate, added 27 Aug 2026. Fixing only the
    // disclaimer lands the app on the walkthrough rather than Home, so this
    // would still have failed — and the "pre-existing, disclaimer only"
    // diagnosis carried in the memory file was already incomplete.
    SharedPreferences.setMockInitialValues({
      'disclaimerAcceptedVersion': kDisclaimerVersion,
      kWalkthroughSeenVersionKey: kWalkthroughVersion,
    });
  });

  testWidgets('App launches and can open History screen', (WidgetTester tester) async {
    await tester.pumpWidget(const AppBootstrap());

    // Avoid pumpAndSettle: it can time out if an infinite animation exists. [1](https://www.positioniseverything.net/a-positional-parameter-cannot-be-found-that-accepts-argument/)[2](https://stackoverflow.com/questions/35433151/powershell-a-positional-parameter-cannot-be-found-that-accepts-argument-xxx)
    await pumpUntilFound(tester, find.text('Record Event'));
    expect(find.text('Record Event'), findsOneWidget);

    await tapOverflowMenuItem(tester, 'History');

    await pumpUntilFound(tester, find.text('History'));
    expect(find.text('History'), findsWidgets);

    expect(find.byIcon(Icons.ios_share), findsOneWidget);

    // ⚠️ THE FILTERS MOVED INTO A SHEET (26 Aug 2026, `b3c6012`), behind the
    // AppBar filter icon. This assertion looked for "Referral required only" on
    // the History screen itself, where it had stopped being — so the test was
    // failing for a SECOND reason behind the disclaimer gate, and only the
    // first reason was ever recorded.
    //
    // A smoke test should follow the route a user takes, so it opens the sheet
    // rather than being loosened to stop looking.
    // ⚠️ A TALL SURFACE. The sheet's last row sits below the fold on the
    // default 800x600 test view, and a widget that is not laid out is not in
    // the tree — so the finder times out and reads as "the row is gone" rather
    // than "the row is off-screen". Same trap as `vocabulary_screen_test`.
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // ⚠️ SETTLE BEFORE TAPPING. The History route was still animating in, and a
    // tap during a route transition is absorbed — the icon is found, `tap`
    // does not throw, and `onPressed` never fires. That reads exactly like a
    // missing widget and cost several passes to tell apart.
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.filter_list));
    await tester.pumpAndSettle();
    await pumpUntilFound(tester, find.text('Referral required only'));
    expect(find.text('Referral required only'), findsOneWidget);
  });
}