import 'package:file_selector/file_selector.dart';
import 'package:file_selector_ios/file_selector_ios.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical_event_recorder/services/backup_service.dart';

/// Tests at the file_selector plugin boundary.
///
/// The backup and restore flows were covered by parse / plan / merge tests, all
/// of which sat on this side of the plugin call. None of them crossed into the
/// platform implementation, which is why a type group iOS cannot translate
/// reached a device test as "Restore from backup does nothing on tap".
///
/// These drive the real `FileSelectorIOS` translation rather than a local copy
/// of its rules, so they keep working if the plugin changes its mind.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Runs [group] through the genuine iOS implementation and returns whatever
  /// it threw, or null.
  ///
  /// No platform channel exists in a unit test, so a call that gets as far as
  /// the channel fails with a PlatformException. That is success for our
  /// purposes: it means the Dart-side translation accepted the group. The
  /// failure being guarded against is ArgumentError, which is thrown while
  /// building the arguments, before the channel is reached.
  Future<Object?> iosTranslationError(XTypeGroup group) async {
    try {
      await FileSelectorIOS().openFile(acceptedTypeGroups: <XTypeGroup>[group]);
    } catch (e) {
      return e;
    }
    return null;
  }

  group('kBackupTypeGroup', () {
    test('is accepted by the real iOS type-group translation', () async {
      final error = await iosTranslationError(kBackupTypeGroup);
      expect(
        error,
        isNot(isA<ArgumentError>()),
        reason: 'FileSelectorIOS rejected the group before reaching the '
            'platform channel. On a device this throws into a discarded '
            'Future and the picker never appears.',
      );
    });

    test('an extensions-only group is rejected by iOS — the original defect',
        () async {
      // Negative control. Without this, the test above would still pass if the
      // group silently lost its uniformTypeIdentifiers, because a group that
      // allows everything is also accepted. This pins the actual rule.
      final error = await iosTranslationError(
        const XTypeGroup(label: 'Backup files', extensions: ['json']),
      );
      expect(error, isA<ArgumentError>());
    });

    test('satisfies the field each other platform reads', () {
      // macOS accepts any one of extensions / UTIs / mimeTypes; Windows
      // requires extensions; Android requires extensions or mimeTypes. All
      // three are satisfied by extensions alone, which iOS ignores entirely.
      expect(kBackupTypeGroup.extensions, isNotEmpty);
      expect(kBackupTypeGroup.uniformTypeIdentifiers, isNotEmpty);

      // A group that allows everything would pass every platform check while
      // filtering nothing, so assert this filter is a real one.
      expect(kBackupTypeGroup.allowsAny, isFalse);
    });

    test('accepts the extension this app actually writes', () {
      // The UTI is only correct while backups are written as .json. If the
      // filename ever changes extension, public.json stops matching and restore
      // becomes visible but unusable — worse than an outright failure.
      expect(kBackupTypeGroup.extensions, contains('json'));
      expect(kBackupTypeGroup.uniformTypeIdentifiers, contains('public.json'));
    });
  });
}
