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
    // Mock SharedPreferences so getInstance() doesn't rely on platform channels in tests.
    SharedPreferences.setMockInitialValues({
      'disclaimerAccepted': true,
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
    expect(find.text('Referral required only'), findsOneWidget);
  });
}