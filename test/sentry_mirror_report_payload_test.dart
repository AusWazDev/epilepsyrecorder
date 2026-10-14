// Brief MER-F4 · the legacy mirror's read-failure report carries no record
// content to Sentry.
//
// ⛔ THE BEHAVIOUR. When the iOS legacy mirror cannot be read, a report goes to
// Sentry. Before this brief it was a `StateError` whose text held `$e`, and a
// `FormatException`'s `toString()` quotes up to ~78 characters of the payload,
// which is the user's records. `beforeSend` recognises `FormatException` but
// not a `StateError`, so the payload text went out.
//
// ⭐ DRIVEN END TO END, NOT AT THE HELPER. The payload is served by the mocked
// Swift channel, read by the real `reconcileLegacySharedRecords`, reported
// through the real funnel `reportCaptureChannelError`, passed through the
// production `beforeSend` sanitiser, and caught at the TRANSPORT. The assertion
// is on the serialised envelope, so message, exception value, breadcrumbs,
// extras and contexts are all inside what is searched.
//
// ⚠️ ONE prefs-dependent test in this file, per CLAUDE.md's harness rule. Both
// phases run inside it.

import 'dart:convert';

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:medical_event_recorder/main.dart' show sanitiseEventValues;
import 'package:medical_event_recorder/models/event_record.dart';
import 'package:medical_event_recorder/services/ios_capture_bridge.dart';

import 'legacy_mirror_harness.dart';

/// Distinctive text standing in for a user's notes. It must never leave.
const kMarker = 'ZQX-MER-F4-MARKER-7731';

/// Holds every envelope the client tried to send.
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

  test('the legacy mirror read-failure report carries counts and type, '
      'never payload text', () async {
    final transport = CapturingTransport();
    await Sentry.init((o) {
      o.dsn = 'https://public@example.invalid/1';
      o.transport = transport;
      // The production sanitiser, as `main.dart` installs it.
      o.beforeSend = (event, hint) => sanitiseEventValues(event);
    });
    addTearDown(Sentry.close);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    Future<String> runAndCapture(String payload) async {
      final spy = MirrorSpy(payload)..install();
      debugResetIncompleteReport();
      await prefs.setBool(kSharedRecordsReconciledKey, false);
      final store = EventStore();
      await store.save(const <EventRecord>[]);
      final before = transport.envelopes.length;
      await reconcileLegacySharedRecords(
        channel: kTestChannel, prefs: prefs, store: store,
        loaded: await store.load(),
        onError: reportCaptureChannelError,
      );
      // The capture is unawaited inside the funnel. Wait for it, bounded.
      for (var i = 0; i < 100 && transport.envelopes.length == before; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      spy.remove();
      expect(transport.envelopes.length, before + 1,
          reason: 'RUN CONTROL: exactly one report must reach the transport, '
              'or every assertion below is vacuous.');
      return envelopeText(transport.envelopes.last);
    }

    // ── PHASE 1: the payload does not decode ─────────────────────────────
    const broken = '[{"id":"m1","notes":"$kMarker"} NOT JSON';
    Object? premise;
    try {
      jsonDecode(broken);
    } catch (e) {
      premise = e;
    }
    expect(premise, isA<FormatException>(),
        reason: 'RUN CONTROL: the payload must fail to decode.');
    expect(premise.toString(), contains(kMarker),
        reason: '⛔ THE PREMISE: Dart quotes the payload in the exception\'s '
            'text. If this stops being true the test no longer tests the leak.');

    final sent1 = await runAndCapture(broken);
    expect(sent1, isNot(contains(kMarker)),
        reason: '⛔ PAYLOAD TEXT REACHED SENTRY: "$kMarker" is in the event.');
    expect(sent1, contains('Legacy mirror read INCOMPLETE'),
        reason: 'the report still says which read failed.');
    expect(sent1, contains('decode threw FormatException'),
        reason: 'the exception TYPE is kept.');
    expect(sent1, contains('kept 0 of 0'),
        reason: 'the counts are kept.');

    // ── PHASE 2: it decodes, but one element produces no record ──────────
    final good1 = mirrorRec(id: 'g1', timestamp: DateTime(2026, 10, 1, 9)).toMap();
    final good2 = mirrorRec(id: 'g2', timestamp: DateTime(2026, 10, 2, 9)).toMap();
    final bad = {'id': 'b1', 'timestamp': kMarker, 'notes': kMarker};
    final partial = jsonEncode([good1, bad, good2]);

    final sent2 = await runAndCapture(partial);
    expect(sent2, isNot(contains(kMarker)),
        reason: '⛔ PAYLOAD TEXT REACHED SENTRY: "$kMarker" is in the event.');
    expect(sent2, contains('1 of 3 elements produced no record'),
        reason: 'the drop count is kept.');
    expect(sent2, contains('kept 2 of 3'),
        reason: 'the kept count is kept.');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('the capture funnel is default-deny: an unrecognised error is reduced '
      'to its type', () {
    final sent = captureReportable(StateError('notes: $kMarker'));
    expect(sent.toString(), isNot(contains(kMarker)),
        reason: '⛔ an unrecognised error\'s text passed through the funnel.');
    expect(sent.toString(), contains('StateError'),
        reason: 'its type survives.');
    // And a recognised channel error is left for beforeSend, unchanged.
    final pe = PlatformException(code: 'channel-error');
    expect(identical(captureReportable(pe), pe), isTrue,
        reason: 'a PlatformException passes; beforeSend reduces it to code.');
  });
}
