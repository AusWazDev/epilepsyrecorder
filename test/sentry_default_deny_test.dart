// Brief MER-F5 · every Sentry capture path is default-deny for exception text.
//
// ⛔ THE BEHAVIOUR. Whatever path an error takes to Sentry, text it carries
// (exception messages, framework diagnostics, breadcrumb messages, extras,
// stored error strings) does not leave the device. The TYPE does, and so do
// the app's own fixed messages and content-free reports.
//
// ⭐ THROUGH THE REAL PIPELINE. `SentryFlutter.init` with the production
// `configureSentryOptions`, its own integrations (FlutterError, PlatformDispatcher
// onError) and event processors, and a capturing transport. Only the DSN, the
// transport and the native SDK switch are overridden. Assertions are on the
// serialised envelope, so every field of the event is searched.
//
// ⚠️ WHAT THIS FILE CANNOT REACH, stated so a green run is not read as more:
//   - ZONE ERRORS. On every non-web platform the SDK uses
//     PlatformDispatcher.onError and does NOT wrap the app in runZonedGuarded
//     (sentry_flutter 9.19.0, SentryFlutter.init: `useRunZonedGuarded =
//     !isOnErrorSupported && isRootZone`). An uncaught zone error therefore
//     arrives through test 2's path. flutter_test intercepts a real one.
//   - NATIVE CRASHES (iOS, Android). Captured and sent by the native SDKs, so
//     the Dart `beforeSend` never sees them. See the Change Register, CR-49.

import 'dart:async';
import 'dart:convert';

import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
// ignore: implementation_imports
import 'package:sentry_flutter/src/integrations/on_error_integration.dart';
// ignore: implementation_imports
import 'package:sentry_flutter/src/utils/platform_dispatcher_wrapper.dart';

import 'package:medical_event_recorder/main.dart';
import 'package:medical_event_recorder/services/ios_capture_bridge.dart'
    show LegacyMirrorReadIncomplete, MirrorFailure;
import 'package:medical_event_recorder/services/sentry_messages.dart';

/// Distinctive text standing in for anything a user typed.
const kMarker = 'ZQX-MER-F5-MARKER-2286';

class CapturingTransport implements Transport {
  final List<SentryEnvelope> envelopes = [];
  @override
  Future<SentryId?> send(SentryEnvelope envelope) async {
    envelopes.add(envelope);
    return SentryId.newId();
  }
}

Future<String> envelopeText(SentryEnvelope e) async {
  final parts = <String>[];
  for (final item in e.items) {
    parts.add(utf8.decode(await item.dataFactory()));
  }
  return parts.join('\n');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final transport = CapturingTransport();

  setUpAll(() async {
    await SentryFlutter.init((o) {
      configureSentryOptions(o);
      o.dsn = 'https://public@example.invalid/1';
      o.transport = transport;
      o.autoInitializeNativeSdk = false;
      // ⚠️ THE ONE SUBSTITUTION, AND WHY. The SDK installs its
      // PlatformDispatcher.onError handler on the BINDING's dispatcher, and
      // flutter_test 3.41.7's `TestPlatformDispatcher.onError` setter is a
      // no-op (it reads `_platformDispatcher.onError;` instead of assigning).
      // So the default integration can never be installed in a test. The SAME
      // integration class is added again here, bound to the real engine
      // dispatcher, so test 2 exercises the SDK's own handler code.
      o.addIntegration(OnErrorIntegration(
          dispatchWrapper: PlatformDispatcherWrapper(PlatformDispatcher.instance)));
    });
  });
  tearDownAll(Sentry.close);

  /// Runs [trigger] and returns the one event it produced, serialised.
  Future<String> capture(FutureOr<void> Function() trigger) async {
    final before = transport.envelopes.length;
    await trigger();
    for (var i = 0; i < 150 && transport.envelopes.length == before; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    expect(transport.envelopes.length, before + 1,
        reason: 'RUN CONTROL: exactly one event must reach the transport, '
            'or every assertion below is vacuous.');
    return envelopeText(transport.envelopes.last);
  }

  void expectNoMarker(String sent, String path) {
    expect(sent, isNot(contains(kMarker)),
        reason: '⛔ TEXT REACHED SENTRY through $path: "$kMarker" is in the '
            'event.');
  }

  test('1. FlutterError.onError: the framework report passes beforeSend and '
      'loses its text', () async {
    final sent = await capture(() => FlutterError.reportError(
          FlutterErrorDetails(
            exception: StateError('notes $kMarker'),
            library: 'widgets library',
            context: ErrorDescription('while building $kMarker'),
            informationCollector: () =>
                [DiagnosticsNode.message('Text("$kMarker")')],
          ),
        ));
    expectNoMarker(sent, 'FlutterError.onError');
    expect(sent, contains('"type":"StateError"'), reason: 'the type is kept.');
    expect(sent, contains('"library":"widgets library"'),
        reason: 'flutter_error_details keeps its library.');
  });

  test('2. PlatformDispatcher.onError (and so uncaught zone errors)', () async {
    final onError = PlatformDispatcher.instance.onError;
    expect(onError, isNotNull,
        reason: 'RUN CONTROL: the SDK must have installed its handler.');
    final sent = await capture(
        () => onError!(StateError('dispatcher $kMarker'), StackTrace.current));
    expectNoMarker(sent, 'PlatformDispatcher.onError');
    expect(sent, contains('"type":"StateError"'), reason: 'the type is kept.');
  });

  test('3. Sentry.captureException, the app\'s own path', () async {
    final sent = await capture(() =>
        Sentry.captureException(StateError('load $kMarker'),
            stackTrace: StackTrace.current));
    expectNoMarker(sent, 'captureException');
    expect(sent, contains('"type":"StateError"'), reason: 'the type is kept.');
    expect(sent, contains('"frames"'), reason: 'stack frames are kept.');
  });

  test('4. a FormatException keeps only its offset', () async {
    Object? e;
    try {
      jsonDecode('{"notes":"$kMarker" X');
    } catch (caught) {
      e = caught;
    }
    expect(e.toString(), contains(kMarker),
        reason: 'RUN CONTROL: Dart quotes the payload in the exception.');
    final sent = await capture(() => Sentry.captureException(e));
    expectNoMarker(sent, 'a FormatException');
    expect(sent, contains('FormatException(offset:'),
        reason: 'the type and the decode offset are kept.');
  });

  test('5. breadcrumbs: message and data values are withheld', () async {
    final sent = await capture(() async {
      await Sentry.addBreadcrumb(Breadcrumb(
          message: 'tapped $kMarker',
          category: 'mer.test',
          data: {'note': kMarker}));
      await Sentry.captureException(StateError('x'));
    });
    expectNoMarker(sent, 'a breadcrumb');
    expect(sent, contains('"category":"mer.test"'),
        reason: 'the breadcrumb itself, and its category, are kept.');
  });

  test('6. extras are withheld', () async {
    final sent = await capture(() => Sentry.captureEvent(SentryEvent(
          message: SentryMessage(kMsgStorageMigrated),
          // ignore: deprecated_member_use
          extra: {'note': kMarker},
        )));
    expectNoMarker(sent, 'extras');
  });

  test('7. a message that is not one of the app\'s fixed texts is withheld',
      () async {
    final sent = await capture(() => Sentry.captureMessage('saved $kMarker'));
    expectNoMarker(sent, 'captureMessage');
    expect(sent, contains(kSentryWithheld),
        reason: 'the message is replaced, not dropped.');
  });

  test('8. a stored error string (storage context) sends the type only',
      () async {
    final sent = await capture(() => Sentry.captureMessage(
          kMsgStorageFallback,
          withScope: (scope) => scope.setContexts('storage', {
            'error': sanitisedErrorText(StateError('migrate $kMarker')),
          }),
        ));
    expectNoMarker(sent, 'sanitisedErrorText');
    expect(sent, contains('"error":"StateError"'), reason: 'the type is kept.');
  });

  test('9. ALLOWED THROUGH: a fixed message and a content-free report keep '
      'their text', () async {
    final m = await capture(() => Sentry.captureMessage(kMsgStorageMigrated));
    expect(m, contains(kMsgStorageMigrated),
        reason: 'the app\'s own fixed message must arrive intact.');
    const report = LegacyMirrorReadIncomplete(
        reason: MirrorFailure.elementsDropped, kept: 2, elements: 3);
    final r = await capture(() => Sentry.captureException(report));
    expect(r, contains(report.categorical),
        reason: 'a content-free report must arrive with its text intact.');
  });
}
