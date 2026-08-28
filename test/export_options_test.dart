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

  testWidgets('Export options sheet shows Share / Save / Cancel', (WidgetTester tester) async {
    // Make the test viewport taller so the bottom sheet fits.
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    await tester.pumpWidget(const AppBootstrap());
    await pumpUntilFound(tester, find.text('Record Event'));

    // Create one event so export is allowed (your export blocks empty lists)
    await tester.tap(find.text('Record Event'));
    await tester.pump();

    // ⚠️ THE ROUTE CHANGED. There is no "Export CSV (all events)" overflow item
    // any more — export, back up and restore moved behind **Your data**
    // (`home_screen.dart` says so at the top of the file). The test was asserting
    // a menu that had stopped existing, behind a disclaimer gate that stopped it
    // ever getting that far, so only the first failure was ever diagnosed.
    //
    // Followed as a user would, rather than loosened.
    await tapOverflowMenuItem(tester, 'Your data');

    // Settle before tapping: a tap during the route transition is absorbed, the
    // finder still matches, and `tap` does not throw. It reads as a missing
    // widget.
    await tester.pumpAndSettle();
    await tester.tap(find.text('Export all events'));
    await tester.pumpAndSettle();

    await pumpUntilFound(tester, find.text('Share to apps'));
    expect(find.text('Share to apps'), findsOneWidget);
    expect(find.text('Save to device'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Tap the ListTile instead of the Text to avoid hit-test issues.
    final cancelTile = find.widgetWithText(ListTile, 'Cancel');
    await pumpUntilFound(tester, cancelTile);
    await tester.tap(cancelTile);
    await tester.pump();
  });
}