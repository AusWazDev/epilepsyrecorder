import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/storage_boot.dart';
import 'package:medical_event_recorder/models/vocabulary_store.dart';
import 'package:medical_event_recorder/screens/event_wizard_screen.dart';

import 'semantics_names.dart';

/// AUDIT.md §13(z), control 1 of 5 — the wizard's back arrow announced nothing.
///
/// ⭐ "Back" and not "Cancel" or "Discard": at step 0 it leaves (capturing the
/// draft, per §13(b)) and otherwise it steps backwards, so "Back" is the only
/// word true of BOTH states. It is also the word `MaterialLocalizations` gives
/// `BackButton`.
///
/// ⛔ ONE SCREEN, ONE TEST — see `semantics_names.dart` for the measured reason.

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

  testWidgets('wizard back announces "Back", and nothing moved', (tester) async {
    final handle = tester.ensureSemantics();
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(430, 1200);

    await tester.pumpWidget(const MaterialApp(home: EventWizardScreen()));
    await tester.pumpAndSettle();

    final names = announcedNames(tester);
    // ignore: avoid_print
    print('  wizard: "Back" announced = ${names.contains('Back')}');
    expect(names, contains('Back'),
        reason: 'the wizard back arrow must announce a name');

    // ⛔ BASELINE CAPTURED FROM UNPATCHED CODE, so this passes in BOTH states.
    expect(iconRects(tester, const [Icons.arrow_back]),
        <String>['16.0,16.0 24.0x24.0'],
        reason: 'adding a tooltip must not move the icon');

    handle.dispose();
  });
}
