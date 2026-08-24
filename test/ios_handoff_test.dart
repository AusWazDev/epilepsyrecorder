import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medical_event_recorder/constants.dart';
import 'package:medical_event_recorder/models/capture_instruction.dart';
import 'package:medical_event_recorder/models/event_record.dart';

import 'package:medical_event_recorder/services/ios_capture_bridge.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Path with platform separators normalised to forward slashes.
///
/// `Directory.listSync` returns native separators, so on Windows every path
/// here arrives as `ios\MERWidget\...`. Every `contains('/Foo/')` predicate in
/// this file silently missed as a result, and the consequences ran BOTH ways:
///
///  * `/MERWidget/` was an INCLUSION, so the extension list came back empty and
///    the test's own positive control fired — it could not fail on Windows, and
///    passed on the Mac, so the guard was unfalsifiable on one of the two
///    machines that runs it.
///  * `/Pods/` and `/.symlinks/` are EXCLUSIONS, so they excluded nothing.
///    Harmless only because neither directory exists on a Windows checkout —
///    CocoaPods is Mac-only. One vendored-Pods checkout and the scan quietly
///    becomes the thing the setUp comment below warns against: a search through
///    other people's example apps, where a coincidental hit is a spurious
///    failure and a real one is buried.
///
/// Normalising is deliberately done at the comparison rather than by rewriting
/// `f.path`, so failure messages still print the real native path.
String _posix(String p) => p.replaceAll(Platform.pathSeparator, '/');

/// The iOS transport, the one-time reconciliation, and the guarantees that stop
/// being guarantees once a second language starts writing.
///
/// `capture_inbox_test.dart:559` scans every `.dart` file under `lib/` and fails
/// if anything but `event_record.dart` writes the record list. It cannot see a
/// Swift violation, and step 2 is exactly when that matters. The first group
/// here closes that gap.

const _channelName = 'au.com.notiva.mer/navigation';

EventRecord record(
  String id,
  DateTime at, {
  DurationCategory duration = DurationCategory.lt1,
}) =>
    EventRecord(
      id: id,
      timestamp: at,
      duration: duration,
      feelings: const <String>[],
      referralRequired: false,
      notes: '',
    );

String startPayload(String id, DateTime at) => jsonEncode({
      'v': kInboxSchemaVersion,
      'kind': kInboxKindStart,
      'id': id,
      'at': at.toIso8601String(),
    });

String endPayload(String id, DateTime at, int seconds) => jsonEncode({
      'v': kInboxSchemaVersion,
      'kind': kInboxKindEnd,
      'id': id,
      'at': at.toIso8601String(),
      'seconds': seconds,
    });

/// Stands in for AppDelegate over the method channel.
class _FakeIosHost {
  Map<String, String> inbox = const <String, String>{};
  String? legacyRecords;

  final List<String> deletedKeys = <String>[];
  int readCalls = 0;
  bool legacyCleared = false;

  /// When set, every call throws — a missing or erroring channel.
  bool failEverything = false;

  /// When set, reads never complete — a hung channel.
  bool hangReads = false;

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(_channelName),
            (MethodCall call) async {
      if (failEverything) {
        throw PlatformException(code: 'unavailable');
      }
      switch (call.method) {
        case 'readCaptureInbox':
          readCalls++;
          if (hangReads) return Completer<Map<String, String>>().future;
          return inbox;
        case 'deleteCaptureInbox':
          deletedKeys.addAll((call.arguments as List).cast<String>());
          return null;
        case 'readLegacySharedRecords':
          return legacyRecords;
        case 'clearLegacySharedRecords':
          legacyCleared = true;
          return null;
      }
      return null;
    });
  }

  void remove() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel(_channelName), null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the single-writer guarantee, extended to Swift', () {
    // The Dart-side scan cannot see these, and step 2 is the moment a second
    // language starts writing. Chose a literal-absence assertion over a
    // regex on write expressions: "the key is spelled nowhere in Swift" is
    // unambiguous and cannot be satisfied by a cleverly-formatted write.
    late List<File> swiftFiles;

    setUp(() {
      // followLinks: false is load-bearing. ios/.symlinks/plugins/** links to
      // every plugin's own example app, each with its own AppDelegate.swift —
      // fifteen of them here. Following those would both break the writer count
      // and quietly turn "no Swift file mentions the record key" into a scan of
      // other people's code, where a coincidental match is a spurious failure
      // and a real one would be buried.
      swiftFiles = Directory('ios')
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((f) => f.path.endsWith('.swift'))
          .where((f) => !_posix(f.path).contains('/Pods/'))
          .where((f) => !_posix(f.path).contains('/.symlinks/'))
          .toList();
    });

    test('no Swift file mentions the record-list key at all', () {
      expect(swiftFiles, isNotEmpty,
          reason: 'positive control: Swift files were scanned');

      final offenders = <String>[];
      for (final f in swiftFiles) {
        if (f.readAsStringSync().contains(kEventStorageKey)) {
          offenders.add(f.path);
        }
      }

      expect(offenders, isEmpty,
          reason: 'Swift must neither read nor write the record list. '
              'Scanned ${swiftFiles.length} files under ios/.');
    });

    test('no Swift file writes the legacy App Group record mirror', () {
      // The mirror may still be READ once, by the reconciliation, and removed.
      // A write would recreate the second source of truth this pass removes.
      final offenders = <String>[];
      for (final f in swiftFiles) {
        for (final line in f.readAsStringSync().split('\n')) {
          final isWrite = line.contains('.set(') || line.contains('.setValue(');
          if (isWrite &&
              (line.contains('mer_records') ||
                  line.contains('kSharedRecords') ||
                  line.contains('kLegacySharedRecords'))) {
            offenders.add('${f.path}: ${line.trim()}');
          }
        }
      }

      expect(offenders, isEmpty,
          reason: 'the App Group mirror is read-once then retired, never '
              'written');
    });

    test('the widget extension does not mention the record list or the mirror',
        () {
      // The extension runs in a separate process, so its read-modify-write was
      // the one that could not be serialised against anything. It should now
      // know nothing about records.
      final extension = swiftFiles
          .where((f) => _posix(f.path).contains('/MERWidget/'))
          .toList();
      expect(extension, isNotEmpty, reason: 'positive control');

      for (final f in extension) {
        final src = f.readAsStringSync();
        expect(src.contains('mer_records'), isFalse, reason: f.path);
        expect(src.contains(kEventStorageKey), isFalse, reason: f.path);
      }
    });

    test('both Swift writers emit the schema this build parses', () {
      // Not a compile of Swift — a check that the field names and the literal
      // version the two writers spell match what parseInboxEntry requires. A
      // typo here defers every instruction silently, on device only.
      final writers = swiftFiles.where((f) =>
          f.path.endsWith('AppDelegate.swift') ||
          f.path.endsWith('EndMEREventIntent.swift'));
      expect(writers, hasLength(2), reason: 'positive control');

      for (final f in writers) {
        final src = f.readAsStringSync();
        expect(src, contains('"$kInboxKindEnd"'), reason: f.path);
        expect(src, contains('"v": NSNumber(value: 1)'),
            reason: '${f.path}: v must decode as an int, not a Double');
        expect(src, contains('"seconds": NSNumber(value:'),
            reason: '${f.path}: seconds, never a bucket');
        expect(src, contains(kInboxKeyPrefix),
            reason: '${f.path}: one key per instruction');
      }
    });

    test('neither Swift writer buckets a duration any more', () {
      for (final f in swiftFiles) {
        final src = f.readAsStringSync();
        expect(src.contains('"oneToFive"'), isFalse,
            reason: '${f.path}: bucketFromSeconds in capture_inbox.dart is the '
                'one mapping');
      }
    });

    test('the iOS timeout equals the Dart one', () {
      // Two literals in two languages for one documented behaviour. This is the
      // closest thing to one source across the boundary.
      final appDelegate = swiftFiles
          .firstWhere((f) => f.path.endsWith('AppDelegate.swift'))
          .readAsStringSync();
      expect(appDelegate,
          contains('kActiveEventTimeoutSeconds: TimeInterval = 30 * 60'),
          reason: 'if this changes, _timeoutMins in notification_service.dart '
              'must change with it');

      final service =
          File('lib/services/notification_service.dart').readAsStringSync();
      expect(service, contains('_timeoutMins    = 30'),
          reason: 'the Dart half of the same constant');
    });

    test('the Live Activity is requested with a staleDate', () {
      final appDelegate = swiftFiles
          .firstWhere((f) => f.path.endsWith('AppDelegate.swift'))
          .readAsStringSync();
      expect(appDelegate.contains('staleDate: nil'), isFalse,
          reason: 'staleDate: nil gave an abandoned event a running timer for '
              'hours');
      expect(appDelegate, contains('staleDate: staleAt'));
    });

    test('staleDate uses the STALENESS window, not the abandonment timeout',
        () {
      // They answer different questions and must not be tidied into one. 30
      // minutes decides when an event is abandoned; this decides when the
      // display stops asserting what the app cannot confirm.
      final appDelegate = swiftFiles
          .firstWhere((f) => f.path.endsWith('AppDelegate.swift'))
          .readAsStringSync();
      expect(appDelegate,
          contains('kActivityStaleAfterSeconds: TimeInterval = 10 * 60'));
      expect(appDelegate,
          contains('.addingTimeInterval(kActivityStaleAfterSeconds)'),
          reason: 'requesting with the 30-minute timeout left the display '
              'confidently wrong for the whole window that matters');
    });

    test('the timeout is the same number in all three places', () {
      // Swift app, Swift widget, Dart. Three copies because two target
      // boundaries and a language boundary sit between them; this is the pin.
      final appDelegate = swiftFiles
          .firstWhere((f) => f.path.endsWith('AppDelegate.swift'))
          .readAsStringSync();
      expect(appDelegate,
          contains('kActiveEventTimeoutSeconds: TimeInterval = 30 * 60'));

      final widget = swiftFiles
          .firstWhere((f) => f.path.endsWith('MERLiveActivity.swift'))
          .readAsStringSync();
      expect(widget,
          contains('merActiveEventTimeoutSeconds: TimeInterval = 30 * 60'),
          reason: 'the widget bounds its timer with its own copy');

      final service =
          File('lib/services/notification_service.dart').readAsStringSync();
      expect(service, contains('_timeoutMins    = 30'));
    });

    group('the Live Activity tells the truth once it goes stale', () {
      late String widget;

      /// Code only. The comments here deliberately quote the defect they
      /// replaced — "previously ran to startDate + 86400", '"Event in progress"
      /// is a claim the app cannot support' — and a scan that could not tell a
      /// comment from a claim would force those explanations out of the file to
      /// keep itself green. That is the wrong trade: the comment is why the next
      /// person does not reintroduce the bug.
      late String widgetCode;

      setUp(() {
        widget = swiftFiles
            .firstWhere((f) => f.path.endsWith('MERLiveActivity.swift'))
            .readAsStringSync();
        widgetCode = widget
            .split('\n')
            .where((l) => !l.trimLeft().startsWith('//'))
            .join('\n');
      });

      test('the timer is bounded by the timeout, never 24 hours', () {
        // startDate + 86400 is why the lock screen read 32:55 and climbing: a
        // timer outrunning the timeout asserts the app still believes an event
        // is running long after it gave up on it.
        expect(widgetCode.contains('86400'), isFalse,
            reason: 'the 24-hour interval end is the defect');
        expect(widgetCode, contains('startDate + merActiveEventTimeoutSeconds'));
      });

      test('context.isStale is actually read', () {
        // The whole finding: staleDate was set and never rendered, so it was
        // working and unobservable. Three surfaces must consult it.
        expect(widgetCode, contains('context.isStale'));
        expect(widgetCode.split('isStale').length - 1, greaterThanOrEqualTo(6),
            reason: 'lock screen, island expanded, compact and minimal');
      });

      test('"Event in progress" is never asserted unconditionally', () {
        // It is a claim the app cannot support once it has stopped running.
        for (final line in widgetCode.split('\n')) {
          if (line.contains('"Event in progress"')) {
            expect(line, contains('isStale'),
                reason: 'every occurrence must be behind the stale branch: '
                    '${line.trim()}');
          }
        }
      });

      test('the stale wording states uncertainty rather than a state', () {
        expect(widgetCode, contains('"Event may still be running"'));
        expect(widgetCode, contains('"May still be running"'));
      });

      test('the live timer is replaced by a static start time when stale', () {
        expect(widgetCode, contains('Text(startDate, style: .time)'),
            reason: 'a frozen number is honest; a climbing one is not');
      });

      test('the End button survives staleness', () {
        // Removing it would strand the user with an event they cannot close.
        // Both surfaces keep it, and neither guards it on isStale.
        for (final line in widgetCode.split('\n')) {
          if (line.contains('Button(intent: EndMEREventIntent())')) {
            expect(line.contains('isStale'), isFalse, reason: line.trim());
          }
        }
        expect(
            widgetCode.split('Button(intent: EndMEREventIntent())').length - 1, 2,
            reason: 'lock screen and Dynamic Island expanded');
      });
    });
  });

  group('IosChannelInboxTransport', () {
    late _FakeIosHost host;

    setUp(() {
      host = _FakeIosHost();
      host.install();
    });
    tearDown(() => host.remove());

    test('reads entries and parses them with the shared parser', () async {
      final at = DateTime(2026, 8, 22, 18, 0);
      host.inbox = {
        '${kInboxKeyPrefix}a': startPayload('A', at),
        '${kInboxKeyPrefix}b': endPayload('A', at, 120),
      };

      final entries =
          await IosChannelInboxTransport(const MethodChannel(_channelName))
              .read();

      expect(entries, hasLength(2));
      expect(entries.where((e) => e.isDeferred), isEmpty);
      expect(entries.map((e) => e.instruction!.kind),
          containsAll(<String>[kInboxKindStart, kInboxKindEnd]));
    });

    test('acks only the keys it is given', () async {
      await IosChannelInboxTransport(const MethodChannel(_channelName))
          .delete(<String>['${kInboxKeyPrefix}a']);
      expect(host.deletedKeys, <String>['${kInboxKeyPrefix}a']);
    });

    test('an empty ack makes no channel call', () async {
      await IosChannelInboxTransport(const MethodChannel(_channelName))
          .delete(const <String>[]);
      expect(host.deletedKeys, isEmpty);
    });

    test('a failing channel degrades to no entries, and does not throw',
        () async {
      host.failEverything = true;
      Object? reported;

      final entries = await IosChannelInboxTransport(
        const MethodChannel(_channelName),
        onError: (e, _) => reported = e,
      ).read();

      expect(entries, isEmpty,
          reason: 'the alternative is throwing on the cold-start path and '
              'taking the first list render with it');
      expect(reported, isNotNull, reason: 'silently swallowed is not the same '
          'as handled');
    });

    test('a failing ack does not throw either', () async {
      host.failEverything = true;
      Object? reported;

      await IosChannelInboxTransport(
        const MethodChannel(_channelName),
        onError: (e, _) => reported = e,
      ).delete(<String>['${kInboxKeyPrefix}a']);

      expect(reported, isNotNull);
      // The write already succeeded, so an undeleted key is a replayed no-op.
    });

    test('a hung channel times out rather than holding the first render',
        () async {
      host.hangReads = true;
      Object? reported;

      final entries = await IosChannelInboxTransport(
        const MethodChannel(_channelName),
        onError: (e, _) => reported = e,
      ).read();

      expect(entries, isEmpty);
      expect(reported, isA<TimeoutException>());
    }, timeout: const Timeout(Duration(seconds: 15)));
  });

  group('the one-time reconciliation', () {
    late _FakeIosHost host;

    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      host = _FakeIosHost();
      host.install();
    });
    tearDown(() => host.remove());

    Future<SharedRecordsReconcileOutcome> run(
      List<EventRecord> loaded,
    ) async {
      final prefs = await SharedPreferences.getInstance();
      return reconcileLegacySharedRecords(
        channel: const MethodChannel(_channelName),
        prefs: prefs,
        store: EventStore(),
        loaded: loaded,
      );
    }

    test('THE DEFECT AFTERMATH: the mirror carries a duration the store lost',
        () async {
      // Exactly the three-step trace: start A, end A via the widget (mirror
      // only), start B (overwrote the store from a stale read). The store has
      // A at its default; the mirror has A with the real duration.
      final at = DateTime(2026, 8, 22, 16, 29, 59);
      host.legacyRecords = jsonEncode([
        record('A', at, duration: DurationCategory.oneToFive).toMap(),
      ]);

      final out = await run([record('A', at)]);

      expect(out.ran, isTrue);
      expect(out.wrote, isTrue);
      expect(out.durationsRecovered, <String>['A'],
          reason: 'the destroyed value is the whole reason this runs');
      expect(out.records.single.duration, DurationCategory.oneToFive);
      expect(host.legacyCleared, isTrue,
          reason: 'retired, so nothing can read it as a mirror again');
    });

    test('a record only the mirror has is added, by union not overwrite',
        () async {
      final at = DateTime(2026, 8, 22, 16, 0);
      host.legacyRecords = jsonEncode([record('MIRROR', at).toMap()]);

      final out = await run([record('STORE', at.add(const Duration(hours: 1)))]);

      expect(out.records.map((r) => r.id), containsAll(<String>['STORE', 'MIRROR']),
          reason: 'a wholesale copy in either direction is the defect');
      expect(out.addedIds, <String>['MIRROR']);
    });

    test('the store wins where the mirror has no duration to contribute',
        () async {
      // The store may hold user edits the mirror never saw.
      final at = DateTime(2026, 8, 22, 16, 0);
      host.legacyRecords = jsonEncode([record('A', at).toMap()]);

      final out = await run([
        record('A', at, duration: DurationCategory.gt5),
      ]);

      expect(out.records.single.duration, DurationCategory.gt5);
      expect(out.durationsRecovered, isEmpty);
    });

    test('id case is never folded', () async {
      // Swift writes UPPERCASE, Dart lowercase, and records in the wild carry
      // both. Folding here would break matching against every backup ever made.
      final at = DateTime(2026, 8, 22, 16, 0);
      host.legacyRecords = jsonEncode([record('ABC-UPPER', at).toMap()]);

      final out = await run([record('abc-upper', at)]);

      expect(out.records, hasLength(2),
          reason: 'two ids differing only in case are two records');
    });

    test('runs exactly once, then never again', () async {
      final at = DateTime(2026, 8, 22, 16, 0);
      host.legacyRecords = jsonEncode([record('A', at).toMap()]);

      final first = await run(const <EventRecord>[]);
      expect(first.ran, isTrue);

      final second = await run(first.records);
      expect(second.ran, isFalse, reason: 'the flag is set, so this is a no-op');
    });

    test('an unreachable channel leaves the flag unset and retries', () async {
      host.failEverything = true;

      final out = await run(const <EventRecord>[]);

      expect(out.ran, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kSharedRecordsReconciledKey), isNull,
          reason: 'marking it done on a failed read would skip the fold-in '
              'permanently');
    });

    test('an unreadable mirror payload costs nothing', () async {
      host.legacyRecords = 'not json at all';
      final at = DateTime(2026, 8, 22, 16, 0);

      final out = await run([record('A', at)]);

      expect(out.records.single.id, 'A', reason: 'the store is untouched');
      expect(out.wrote, isFalse);
    });

    test('no mirror at all still retires the key', () async {
      host.legacyRecords = null;

      final out = await run(const <EventRecord>[]);

      expect(out.ran, isFalse);
      expect(host.legacyCleared, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(kSharedRecordsReconciledKey), isTrue);
    });
  });
}
