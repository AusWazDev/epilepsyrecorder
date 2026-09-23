// Platform-selected Help copy: every branch, on one host.
//
// ⭐ WHY THESE ARE FUNCTIONS OF A BOOL AND NOT READS OF `Platform`.
// A test runs on ONE host. A direct `Platform.isIOS` read means the iOS string
// is never exercised by any test on any developer machine, and the branch that
// shipped wrong once would be the branch nobody checks. That reasoning is
// `walkthrough_screen.dart:notificationInstruction`'s, cited not re-derived.
//
// ⛔ THE DEFECT THESE PIN. `storageClearingInstruction` was
// `Platform.isIOS ? iOS : ANDROID` — Android-specific text in the CATCH-ALL —
// so Windows and macOS were told to clear app storage "in Android settings",
// a control that does not exist on their device. The QUICK LOG section had the
// same shape one section down: gated `!Platform.isWindows` with its
// replacement gated `Platform.isWindows`, so macOS fell through to the Android
// instruction AND got no replacement.
//
// ⚠️ WHAT THESE CANNOT ESTABLISH: that the call sites pass the right
// arguments. These pin the functions; a source read is what shows
// `help_screen.dart` calls them with `Platform.*`. Both halves are needed and
// only one is here.

import 'package:flutter_test/flutter_test.dart';
import 'package:medical_event_recorder/screens/help_screen.dart';

void main() {
  group('storageClearingInstruction — every branch, including the catch-all', () {
    String forPlatform({bool ios = false, bool android = false, bool windows = false}) =>
        storageClearingInstruction(
          isIOS: ios, isAndroid: android, isWindows: windows);

    test('iOS names Offload and Delete App, and says which one destroys', () {
      final t = forPlatform(ios: true);
      expect(t, contains('Offload App'));
      expect(t, contains('keeps your data'));
      expect(t, contains('It is Delete App that destroys it.'));
      expect(t, isNot(contains('Android')));
      expect(t, isNot(contains('Windows')));
    });

    test('Android names clearing app storage', () {
      final t = forPlatform(android: true);
      expect(t, contains('Clearing app storage in Android settings'));
      expect(t, isNot(contains('Offload')));
      expect(t, isNot(contains('Windows')));
    });

    test('Windows names Reset and Repair, not Android settings', () {
      // ⭐ Reset and Repair are properties of a PACKAGED app. MSIX confirmed
      // from `msix_config` in pubspec.yaml before this branch was written.
      final t = forPlatform(windows: true);
      expect(t, contains('Reset'));
      expect(t, contains('Repair leaves your events alone'));
      expect(t, isNot(contains('Android')),
          reason: '⛔ THE ORIGINAL DEFECT. Windows received the Android text '
              'because Android-specific wording sat in the catch-all.');
      expect(t, isNot(contains('Offload')));
    });

    test('⛔ THE CATCH-ALL — macOS and anything future get NEUTRAL wording', () {
      // No flags set: not iOS, not Android, not Windows.
      final t = forPlatform();
      expect(t, contains('Uninstalling Medical Event Recorder removes every event'));
      expect(t, isNot(contains('Android')),
          reason: 'the defect this whole restructure exists to remove');
      expect(t, isNot(contains('Windows')),
          reason: '⛔ putting Windows-specific text in the catch-all would '
              'repeat the same polarity error one level down — the catch-all '
              'serves macOS, Linux and anything future');
      expect(t, isNot(contains('Offload')));
    });

    test('every branch returns a distinct, non-empty string', () {
      final all = <String>{
        forPlatform(ios: true),
        forPlatform(android: true),
        forPlatform(windows: true),
        forPlatform(),
      };
      expect(all, hasLength(4),
          reason: 'four branches must produce four different texts; a '
              'collision means one platform is silently reading another\'s');
      for (final t in all) {
        expect(t.trim(), isNotEmpty);
      }
    });
  });

  group('the quick-log replacement — macOS is no longer silently skipped', () {
    test('Windows keeps its own wording', () {
      expect(quickLogUnavailableTitle(isWindows: true), 'Not available on Windows');
      expect(quickLogUnavailableBody(isWindows: true), contains('On Windows'));
    });

    test('⛔ everything else gets neutral wording, not Windows wording', () {
      final title = quickLogUnavailableTitle(isWindows: false);
      final body  = quickLogUnavailableBody(isWindows: false);
      expect(title, 'Not available on this platform');
      expect(body, isNot(contains('Windows')),
          reason: 'macOS was previously told nothing at all here; telling it '
              '"On Windows" instead would be the same error wearing a fix');
      expect(body, contains('phone feature'),
          reason: 'the section is never silently omitted — a user who finds '
              'nothing cannot tell whether it is missing or absent');
    });
  });
}
