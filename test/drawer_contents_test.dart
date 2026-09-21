// Brief 69 — the drawer's contents, order and grouping, and the door count.
//
// ⛔ THIS IS NEW WORK, NOT A DEFECT FIX, so there is no failing behaviour to
// verify against and no baseline may be captured — a baseline would bless
// whatever was built. The brief states its acceptance in advance; these tests
// are that statement, made executable.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/home_screen.dart';

/// The drawer's contents, in order, with section labels in position.
/// ⭐ Section labels are SENTENCE CASE in source and uppercased at render by
/// `SectionLabel`, so the expectation carries the rendered form.
const expectedInOrder = <String>[
  'History',
  'Your data',
  'SET UP WHAT YOU TRACK',
  'Medication',
  'What you track',
  'Your lists',
  'HELP',
  'Help',
  'About',
];

const destinations = <String>[
  'History', 'Your data', 'Medication', 'What you track', 'Your lists', 'Help', 'About',
];

Future<void> openDrawer(WidgetTester tester, {double w = 375}) async {
  addTearDown(tester.view.reset);
  tester.view.physicalSize = Size(w * 3, 900 * 3);
  tester.view.devicePixelRatio = 3.0;
  await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
  await tester.pumpAndSettle();
  final opener = find.byTooltip('Open navigation menu');
  expect(opener, findsOneWidget,
      reason: 'CONTROL: the drawer must be openable at all. No hamburger means '
              'the Scaffold has no drawer and every assertion below is vacuous.');
  await tester.tap(opener);
  await tester.pumpAndSettle();
}

/// Reads every Text in the drawer, in visual order (top to bottom).
List<String> drawerTextsInOrder(WidgetTester tester) {
  final texts = find.descendant(of: find.byType(Drawer), matching: find.byType(Text));
  final out = <({double y, String s})>[];
  for (final e in texts.evaluate()) {
    final w = e.widget as Text;
    final s = w.data;
    if (s == null || s.trim().isEmpty) continue;
    out.add((y: tester.getTopLeft(find.byWidget(w)).dy, s: s));
  }
  out.sort((a, b) => a.y.compareTo(b.y));
  return out.map((e) => e.s).toList();
}

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

  testWidgets('1. the drawer carries the seven destinations, in order, in their sections',
      (tester) async {
    await openDrawer(tester);
    expect(drawerTextsInOrder(tester), expectedInOrder,
        reason: 'Acceptance 1: seven destinations reachable from the drawer, in '
                'the sections and order the brief states. Order and grouping are '
                'the design — a drawer with the right items in the wrong order is '
                'a different design, not a smaller one.');
  });

  testWidgets('2. every drawer item has a label and clears the 50.0 touch target',
      (tester) async {
    await openDrawer(tester);
    for (final label in destinations) {
      final tile = find.ancestor(
        of: find.text(label),
        matching: find.byType(ListTile),
      );
      expect(tile, findsOneWidget, reason: 'Acceptance 5: "$label" must be a labelled tile');
      final h = tester.getSize(tile).height;
      expect(h, greaterThanOrEqualTo(50.0),
          reason: 'Acceptance 5: "$label" is ${h.toStringAsFixed(1)} high; the '
                  'standing minimum is 50.0 and this drawer sets 56.');
    }
  });

  testWidgets('3. no overflow at 200% at 375 and 800', (tester) async {
    for (final w in <double>[375, 800]) {
      tester.view.physicalSize = Size(w * 3, 900 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: const HomeScreen(),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: 'Acceptance 5: the drawer must not overflow at 200% at ${w.toInt()}');
    }
  });

  // ── SOURCE SCAN — the half no behavioural test can reach ────────────────
  test('4. no destination lost a door, and the route model is unchanged', () {
    final home = File('lib/screens/home_screen.dart').readAsStringSync();
    final help = File('lib/screens/help_screen.dart').readAsStringSync();
    final all  = home + help;

    // CONTROL on the reader.
    expect(home.contains('MaterialPageRoute'), isTrue,
        reason: 'CONTROL: if no routes can be found the counts below are vacuous.');

    int doors(String cls) =>
        RegExp(r'=>\s*(?:const\s+)?' + cls + r'\b').allMatches(all).length;

    // The counts from the route-model read at 483893a.
    for (final e in <String, int>{
      'HelpScreen': 3, 'WalkthroughScreen': 2, 'HistoryScreen': 1, 'YourDataScreen': 1,
      'AboutScreen': 1, 'VocabularyScreen': 1, 'ConditionsScreen': 1, 'MedicationScreen': 1,
    }.entries) {
      expect(doors(e.key), e.value,
          reason: 'Acceptance 2: ${e.key} had ${e.value} door(s) before the drawer. '
                  'A navigation change that costs a door is not a smaller version '
                  'of this change — it is a different one.');
    }

    // Acceptance 3: the route model is unchanged.
    expect(home.contains('pushNamed'), isFalse, reason: 'Acceptance 3: no named routes');
    expect(home.contains('onGenerateRoute'), isFalse, reason: 'Acceptance 3: no route table');
    expect(RegExp(r'Navigator\.of\(context\)\.push\b').allMatches(home).length, 12,
        reason: 'Acceptance 3: the push count is unchanged from the read — an '
                'extra stack level would show up here first.');
    expect(RegExp(r'popUntil').allMatches(home).length, 0,
        reason: 'Acceptance 3: popUntil stays unused; every pop is depth-relative '
                'and the drawer must not have changed a depth.');

    // Acceptance 4: _records ownership unchanged.
    expect(home.contains('records:          _records'), isTrue,
        reason: 'Acceptance 4: HistoryScreen still takes this State\'s live records '
                'directly, with no new frame between owner and consumer.');

    // Acceptance 6: no new platform conditional.
    expect(RegExp(r'Platform\.is[A-Za-z]+').allMatches(home).length, 14,
        reason: 'Acceptance 6: the sweep counted 14 Platform.is occurrences in this '
                'file at 483893a. The drawer adds none.');
  });
}

extension on String {
  Iterable<Match> allMatches(String input) => RegExp(this).allMatches(input);
}
