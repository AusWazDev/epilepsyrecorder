import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Update package name if needed:
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
  await tester.pump();

  await pumpUntilFound(tester, find.text(label));
  final itemFinder = popupMenuItemWithLabel(label);
  await pumpUntilFound(tester, itemFinder);

  await tester.tap(itemFinder);
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'disclaimerAccepted': true,
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

    await tapOverflowMenuItem(tester, 'Export CSV (all events)');

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