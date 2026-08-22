import 'package:file_selector/file_selector.dart';
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/services/backup_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// How export and backup failures surface.
///
/// Each of these actions runs inside an async callback whose Future the
/// framework discards, so before the guards an exception became an unhandled
/// zone error — captured by Sentry and shown on screen as nothing at all. That
/// is indistinguishable from a dead button, which is exactly how the iOS
/// restore defect presented for a whole release cycle.
///
/// The negative controls matter more than the assertions they support. Each one
/// proves the underlying call really does fail in this environment, so a passing
/// guard test means the guard caught something rather than that nothing was
/// thrown.

/// Stands in for the real platform plugin so both outcomes can be forced.
///
/// `extends` rather than `implements`, as the platform interface requires, so
/// the instance carries the token `FileSelectorPlatform.instance` verifies.
class _FakeFileSelector extends FileSelectorPlatform {
  _FakeFileSelector({this.throwOnCall = false});

  /// When false, every dialog reports a user cancellation.
  final bool throwOnCall;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    if (throwOnCall) throw ArgumentError('forced picker failure');
    return null; // cancelled
  }

  @override
  Future<FileSaveLocation?> getSaveLocation({
    List<XTypeGroup>? acceptedTypeGroups,
    SaveDialogOptions options = const SaveDialogOptions(),
  }) async {
    if (throwOnCall) throw ArgumentError('forced save dialog failure');
    return null; // cancelled
  }
}

/// Fails the temp-directory lookup the two share paths start with.
///
/// A real path_provider call cannot be used to provoke this: under the
/// widget-test binding its platform-channel future never completes, so the
/// failure the guard is supposed to catch never arrives and the test hangs
/// rather than failing. This makes the failure immediate and deterministic.
class _FailingPathProvider extends PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async =>
      throw StateError('forced temp directory failure');
}

void main() {
  final records = <EventRecord>[
    EventRecord(
      id:               'test-1',
      timestamp:        DateTime(2026, 8, 22, 16, 47, 38),
      duration:         DurationCategory.oneToFive,
      feelings:         const <String>[],
      referralRequired: false,
      notes:            '',
    ),
  ];

  final originalSelector = FileSelectorPlatform.instance;
  final originalPaths    = PathProviderPlatform.instance;
  tearDown(() {
    FileSelectorPlatform.instance = originalSelector;
    PathProviderPlatform.instance = originalPaths;
  });

  /// Pumps a host with a Scaffold, runs [action] against its context, and
  /// returns without letting an exception escape the callback the way the
  /// framework would.
  Future<Object?> runAction(
    WidgetTester tester,
    Future<void> Function(BuildContext context) action,
  ) async {
    Object? escaped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                try {
                  await action(context);
                } catch (e) {
                  escaped = e;
                }
              },
              child: const Text('go'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    return escaped;
  }

  group('negative controls — these calls really do fail here', () {
    test('the forced temp-directory failure really throws', () async {
      // The share paths build a temp file first. This is the failure those
      // guards are catching; without it their tests would pass on an action
      // that simply succeeded.
      PathProviderPlatform.instance = _FailingPathProvider();
      await expectLater(getTemporaryDirectory(), throwsA(isA<StateError>()));
    });

    test('a forced picker failure really throws', () async {
      FileSelectorPlatform.instance = _FakeFileSelector(throwOnCall: true);
      await expectLater(
        getSaveLocation(suggestedName: 'x.csv'),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('a failure is surfaced, not silent', () {
    testWidgets('exportCsvShare tells the user instead of throwing',
        (tester) async {
      PathProviderPlatform.instance = _FailingPathProvider();
      final escaped = await runAction(
        tester,
        (context) => exportCsvShare(context, records),
      );
      expect(escaped, isNull,
          reason: 'an escaping exception is invisible on screen');
      expect(find.textContaining('Could not prepare the CSV'), findsOneWidget);
    });

    testWidgets('backupShare tells the user instead of throwing',
        (tester) async {
      PathProviderPlatform.instance = _FailingPathProvider();
      final escaped = await runAction(
        tester,
        (context) => backupShare(context, records),
      );
      expect(escaped, isNull);
      expect(
        find.textContaining('Could not prepare the backup'),
        findsOneWidget,
      );
    });

    testWidgets('exportCsvSaveAs surfaces a failing save dialog',
        (tester) async {
      FileSelectorPlatform.instance = _FakeFileSelector(throwOnCall: true);
      final escaped = await runAction(
        tester,
        (context) => exportCsvSaveAs(context, records),
      );
      expect(escaped, isNull);
      expect(find.textContaining('Could not open the save dialog'),
          findsOneWidget);
    });

    testWidgets('backupSaveAs surfaces a failing save dialog', (tester) async {
      FileSelectorPlatform.instance = _FakeFileSelector(throwOnCall: true);
      final escaped = await runAction(
        tester,
        (context) => backupSaveAs(context, records),
      );
      expect(escaped, isNull);
      expect(find.textContaining('Could not open the save dialog'),
          findsOneWidget);
    });

    testWidgets('restoreFromBackup surfaces a failing picker', (tester) async {
      FileSelectorPlatform.instance = _FakeFileSelector(throwOnCall: true);
      final escaped = await runAction(
        tester,
        (context) => restoreFromBackup(context, records),
      );
      expect(escaped, isNull);
      expect(find.textContaining('could not open the file picker'),
          findsOneWidget);
    });
  });

  group('cancelling stays silent', () {
    // The easiest way to satisfy "surface every failure" is to report on every
    // non-success, which would nag the user every time they backed out of a
    // dialog. These pin the distinction.
    testWidgets('a cancelled restore says nothing', (tester) async {
      FileSelectorPlatform.instance = _FakeFileSelector();
      final escaped = await runAction(
        tester,
        (context) => restoreFromBackup(context, records),
      );
      expect(escaped, isNull);
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('a cancelled CSV save dialog says nothing', (tester) async {
      FileSelectorPlatform.instance = _FakeFileSelector();
      final escaped = await runAction(
        tester,
        (context) => exportCsvSaveAs(context, records),
      );
      expect(escaped, isNull);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('a cancelled backup save dialog says nothing', (tester) async {
      FileSelectorPlatform.instance = _FakeFileSelector();
      final escaped = await runAction(
        tester,
        (context) => backupSaveAs(context, records),
      );
      expect(escaped, isNull);
      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
