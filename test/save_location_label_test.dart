import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/constants.dart';

/// THE SAVE-TO-DEVICE LABEL IS ONE LABEL, AND THE RULE IS CHECKED RATHER THAN
/// ASSERTED.
///
/// ⛔ **THIS EXISTS BECAUSE THE RULE WAS A COMMENT FOR MONTHS AND THE COMMENT
/// WAS FALSE.** `backup_service.dart` carried *"Same wording as the export
/// sheet for the same action"* beside a sheet reading `'Save to a file'`, while
/// the export sheet read `'Save to device'`. ⭐ **A comment asserting a
/// compliance is the thing a reader checks INSTEAD of checking the code.**
///
/// ⚠️ **So the claim "they cannot diverge" is itself a claim, and it gets a
/// check.** Two of these read the source, the way this project's other
/// structural guards do — brittle to reformatting and worth it, because the
/// alternative is an invariant with nothing behind it.
void main() {
  group('the label is platform-correct', () {
    test('Android promises no choice; desktop does', () {
      // ⭐ The behaviour differs by platform, so the label must:
      //   Android              writes straight to Downloads, NO chooser
      //   Windows/macOS/Linux  getSaveLocation() — a real chooser
      //   iOS                  the option is never shown
      if (Platform.isAndroid) {
        expect(kSaveToDeviceTitle, 'Save to Downloads');
        expect(kSaveToDeviceSubtitle, isNull,
            reason: 'Android offers no location to choose, so promising one is '
                'the defect this pair exists to remove');
      } else {
        expect(kSaveToDeviceTitle, 'Save to device');
        expect(kSaveToDeviceSubtitle, 'Choose location and file name',
            reason: 'on desktop a chooser really does open, so the subtitle is '
                'true there and is kept');
      }
    });
  });

  group('both sheets read the one pair', () {
    // ⛔ A BEHAVIOURAL TEST CANNOT SEE THIS. Each sheet renders on its own
    // screen, and nothing in either widget tree can observe that the OTHER one
    // used the same source. A second hard-coded label would leave every
    // rendering test green — which is exactly how the divergence survived.
    String src(String p) => File(p).readAsStringSync();

    test('the backup sheet reads the shared title', () {
      final s = src('lib/services/backup_service.dart');
      expect(s, contains('title: Text(kSaveToDeviceTitle)'),
          reason: 'the backup sheet must read the shared label, not its own');
      expect(s, isNot(contains("Text('Save to a file')")),
          reason: 'and the old hard-coded label must not return');
    });

    test('the export sheet reads the shared title', () {
      final s = src('lib/models/event_record.dart');
      expect(s, contains('kSaveToDeviceTitle'),
          reason: 'the export sheet must read the shared label, not its own');
      expect(s, isNot(contains("'Choose location and file name',\n")),
          reason: 'and its hard-coded subtitle must not return — that string '
              'now lives in constants.dart and is null on Android');
    });

    test('CONTROL: the shared names are really in constants.dart', () {
      // ⭐ Without this, both assertions above would pass against a typo that
      // happens to appear in both files.
      final s = src('lib/constants.dart');
      expect(s, contains('String get kSaveToDeviceTitle'));
      expect(s, contains('String? get kSaveToDeviceSubtitle'));
    });
  });
}
