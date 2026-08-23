import 'dart:convert';
import 'dart:typed_data';

// XFile and XTypeGroup come through the platform interface too, so importing
// file_selector as well is redundant here.
import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/services/backup_service.dart';

/// The four outcomes of a restore, and which of them says something.
///
/// Before this, `if (confirmed != true) return null` collapsed an explicit
/// Cancel and a barrier dismissal into one silent return, and the caller's
/// `if (merged == null) return` had no else. So THREE outcomes looked identical
/// to the user — cancel, dismissal, and a genuine failure — and all three also
/// looked exactly like success would have, since success said nothing either
/// unless a snackbar followed.
///
/// It was not hypothetical: on an 800x1280 tablet a tap landing on the barrier
/// beside a small action button produced this, and the reasonable conclusion was
/// that restore was broken. Two diagnostic passes followed.
///
/// The negative control is the pair of tests at the end: Cancel and dismissal
/// must produce DIFFERENT surfaces. If they ever collapse again, that test
/// fails even though both still "work".

/// Serves one backup file, or reports a cancellation.
///
/// `extends` rather than `implements`, as the platform interface requires, so
/// the instance carries the token `FileSelectorPlatform.instance` verifies.
class _FakeFileSelector extends FileSelectorPlatform {
  _FakeFileSelector(this.payload);

  /// The file content to serve, or null to report a cancelled picker.
  final String? payload;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async {
    final data = payload;
    if (data == null) return null; // user cancelled the picker
    return XFile.fromData(
      Uint8List.fromList(utf8.encode(data)),
      name: 'backup.json',
      mimeType: 'application/json',
    );
  }
}

EventRecord record(String id, int minute) => EventRecord(
      id: id,
      timestamp: DateTime(2026, 8, 22, 18, minute),
      duration: DurationCategory.lt1,
      feelings: const <String>[],
      referralRequired: false,
      notes: '',
    );

/// A backup envelope holding [ids], in the shape parseBackup accepts.
String backupJson(List<String> ids) => jsonEncode({
      'format': kBackupFormatId,
      'schemaVersion': kBackupSchemaVersion,
      'appVersion': '1.1.0+5',
      'exportedAt': DateTime(2026, 8, 24, 3).toIso8601String(),
      'records': [
        for (var i = 0; i < ids.length; i++) record(ids[i], i + 1).toMap(),
      ],
    });

/// Drives the real restoreFromBackup from a tappable button, inside a
/// ScaffoldMessenger so snackbars can be observed.
class _Host extends StatelessWidget {
  const _Host({required this.existing, required this.onResult});

  final List<EventRecord> existing;
  final void Function(List<EventRecord>?) onResult;

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Center(
              child: ElevatedButton(
                onPressed: () async =>
                    onResult(await restoreFromBackup(ctx, existing)),
                child: const Text('go'),
              ),
            ),
          ),
        ),
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Runs a restore and returns what it yielded, after [act] deals with the
  /// confirm dialog.
  Future<List<EventRecord>?> runRestore(
    WidgetTester tester, {
    required String? payload,
    required Future<void> Function(WidgetTester) act,
    List<EventRecord> existing = const <EventRecord>[],
  }) async {
    FileSelectorPlatform.instance = _FakeFileSelector(payload);
    List<EventRecord>? result;
    var called = false;

    await tester.pumpWidget(_Host(
      existing: existing,
      onResult: (r) {
        result = r;
        called = true;
      },
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    await act(tester);
    await tester.pumpAndSettle();

    expect(called, isTrue,
        reason: 'restoreFromBackup must complete, not hang');
    return result;
  }

  group('the confirm dialog distinguishes its three exits', () {
    // The contract the fix rests on — Cancel pops false, Restore pops true, a
    // barrier tap pops nothing so showDialog resolves null — is asserted
    // BEHAVIOURALLY by the tests below rather than restated here. An earlier
    // draft of this file "documented" it as `expect(false == null, isFalse)`,
    // which is a tautology that tests the language, not the dialog.

    testWidgets('tapping Restore returns the merged list and says nothing '
        'about dismissal', (tester) async {
      final result = await runRestore(
        tester,
        payload: backupJson(<String>['a', 'b', 'c']),
        // The body text also contains "Restore 3 events?", so target the
        // button specifically rather than the string.
        act: (t) async =>
            t.tap(find.widgetWithText(FilledButton, 'Restore 3 events')),
      );

      expect(result, isNotNull);
      expect(result!.map((r) => r.id), containsAll(<String>['a', 'b', 'c']));
      expect(find.textContaining('dismissed'), findsNothing);
    });

    testWidgets('tapping Cancel is SILENT — cancelling is not an error',
        (tester) async {
      final result = await runRestore(
        tester,
        payload: backupJson(<String>['a', 'b', 'c']),
        act: (t) async => t.tap(find.text('Cancel')),
      );

      expect(result, isNull);
      expect(find.byType(SnackBar), findsNothing,
          reason: 'an explicit cancellation is a decision, and must not be '
              'reported as though something went wrong');
    });

    testWidgets('dismissing the barrier SAYS SO — this is the case that was '
        'silent', (tester) async {
      final result = await runRestore(
        tester,
        payload: backupJson(<String>['a', 'b', 'c']),
        // Tap outside the dialog, which is what a mis-aimed tap does.
        act: (t) async => t.tapAt(const Offset(10, 10)),
      );

      expect(result, isNull);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Nothing was restored'), findsOneWidget);
      expect(find.textContaining('have not been changed'), findsOneWidget,
          reason: 'the message has to answer the question the user actually '
              'has, which is whether their data survived');
    });

    testWidgets('a cancelled file picker stays silent', (tester) async {
      final result = await runRestore(
        tester,
        payload: null, // picker cancelled
        act: (t) async {},
      );

      expect(result, isNull);
      expect(find.byType(SnackBar), findsNothing,
          reason: 'never choosing a file is a cancellation too');
    });

    testWidgets('an unreadable backup shows the refusal dialog, not a snackbar',
        (tester) async {
      final result = await runRestore(
        tester,
        payload: 'this is not a backup at all',
        // _refuse is modal and awaited, so restoreFromBackup does not return
        // until it is dismissed — the assertion has to happen inside act.
        act: (t) async {
          expect(find.text('Cannot restore'), findsOneWidget,
              reason: 'a real failure gets the dialog it already had');
          await t.tap(find.text('OK'));
        },
      );

      expect(result, isNull);
      expect(find.byType(SnackBar), findsNothing,
          reason: 'the refusal dialog already said it; a snackbar as well '
              'would be two reports of one failure');
    });
  });

  group('NEGATIVE CONTROL: cancel and dismissal must not collapse', () {
    // The defect was not that either outcome behaved wrongly on its own. It
    // was that they were the SAME. These two assertions are the only thing
    // that fails if `confirmed != true` ever comes back.

    testWidgets('cancel produces no snackbar where dismissal produces one',
        (tester) async {
      await runRestore(
        tester,
        payload: backupJson(<String>['a']),
        act: (t) async => t.tap(find.text('Cancel')),
      );
      final afterCancel = find.byType(SnackBar).evaluate().length;

      await runRestore(
        tester,
        payload: backupJson(<String>['a']),
        act: (t) async => t.tapAt(const Offset(10, 10)),
      );
      final afterDismiss = find.byType(SnackBar).evaluate().length;

      expect(afterCancel, 0);
      expect(afterDismiss, 1);
      expect(afterCancel == afterDismiss, isFalse,
          reason: 'if these two ever produce the same surface again, the '
              'original defect is back: a mis-aimed tap becomes '
              'indistinguishable from a deliberate cancellation, and from a '
              'completed restore');
    });
  });
}
