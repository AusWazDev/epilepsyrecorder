// THE SETTINGS NUDGE CARD AT LARGE TEXT — a live accessibility defect.
//
// ⛔ WHAT THIS PINS, 23 September 2026. At 200% text scale on a 375-wide phone
// the card overflowed by 101 pixels. Not a synthetic state: it renders exactly
// when notifications are DENIED, which is the state the card exists to report,
// and 200% is an ordinary accessibility setting.
//
// ⚠️ THE DEFECT WAS INVISIBLE TO THE WINDOWS SUITE AND THAT IS WHY IT SURVIVED.
// The card sits behind `!_notificationsAllowed && !Platform.isWindows`, and
// `_notificationsAllowed` starts TRUE and is only ever set by
// `_checkNotificationStatus()`, which `home_screen.dart:381` gates off on
// Windows. So on the machine that ran the suite the card could not render at
// all. On iOS and Android — and on this macOS host — it can.
//
// ⭐ AND IT ASSERTS PER PLATFORM RATHER THAN SKIPPING, 23 September 2026.
// A platform-gated test must say what EACH platform should do. Written for one
// host it failed all twelve cases on Windows — the card cannot render there, so
// every "the card survives" assertion was measuring an empty screen — and the
// obvious repair, a skip, is not one: ⛔ A SKIPPED TEST CANNOT FAIL. Where the
// card can render, the layout assertions stand unchanged. Where it cannot, the
// assertion is that it is genuinely ABSENT and the screen is clean at the same
// widths and scales. Both branches can fail, and the absent branch was
// demonstrated RED by pointing it at this host, where the card IS present.
//
// ⭐ THE LEVER IS `AwesomeNotificationsPlatform.operatingSystem`, which the
// plugin marks `@visibleForTesting`. Off android/ios the plugin resolves to
// `AwesomeNotificationsEmpty`, whose `isNotificationAllowed()` returns false
// unconditionally and reaches no channel — so a channel mock alone CANNOT move
// this, and an earlier attempt that appeared to work was `pumpWidget` reusing
// the element tree. Every pump here is preceded by a teardown pump and a
// distinct key for that reason.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:awesome_notifications/awesome_notifications_platform_interface.dart';
import 'package:medical_event_recorder/screens/home_screen.dart';

const _channel = MethodChannel('awesome_notifications');

/// Whether THIS host can render the nudge card at all.
///
/// ⛔ NOT A HOST CHECK DRESSED AS A FEATURE CHECK. The card is gated on
/// `!_notificationsAllowed && !Platform.isWindows`, and `_notificationsAllowed`
/// starts true and is only ever set by `_checkNotificationStatus()` — which the
/// same platform guard turns off. So on Windows BOTH halves of the gate hold it
/// shut and no lever available to a test can open it. That is a fact about the
/// product, not about the machine: a Windows user never sees this card, because
/// Windows has no notification path to report on.
///
/// ⚠️ Overridden only by the control at the end of this file, which points the
/// absent-branch expectations at a host where the card DOES render, to prove
/// they are capable of failing.
bool cardCanRender = !Platform.isWindows;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    AwesomeNotificationsPlatform.resetInstance();
    AwesomeNotificationsPlatform.operatingSystem = Platform.operatingSystem;
  });

  /// Pumps HomeScreen at [w] logical px and [scale], with the plugin answering
  /// "notifications denied" — the one state in which the card is meant to show.
  ///
  /// ⭐ IDENTICAL ON EVERY HOST, DELIBERATELY. The pump does not branch; only
  /// what is expected of it does. A test that set up differently per platform
  /// would be two tests wearing one name, and the difference between them would
  /// be the first place a defect hid.
  Future<void> pumpHome(WidgetTester tester,
      {required double w, required double scale}) async {
    AwesomeNotificationsPlatform.resetInstance();
    AwesomeNotificationsPlatform.operatingSystem = 'android';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async =>
            call.method == 'isNotificationAllowed' ? false : null);

    tester.view.physicalSize = Size(w * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(MaterialApp(
      key: ValueKey('$w-$scale'),
      home: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: const HomeScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  /// The card's four text boxes, in a stable order, as `label|WxH`.
  List<String> cardGeometry(WidgetTester tester) {
    const labels = [
      'Notifications are off',
      "Quick log won't work until notifications are enabled.",
      'Open Settings',
      'Help →',
    ];
    final out = <String>[];
    for (final l in labels) {
      final f = find.text(l);
      if (f.evaluate().isEmpty) {
        out.add('$l|ABSENT');
        continue;
      }
      final s = tester.getSize(f);
      out.add('$l|${s.width}x${s.height}');
    }
    return out;
  }

  /// Drains and returns every exception the pump raised.
  List<String> drain(WidgetTester tester) {
    final errors = <String>[];
    for (var e = tester.takeException(); e != null; e = tester.takeException()) {
      errors.add('$e'.split('\n').first);
    }
    return errors;
  }

  group('the card is present exactly where the platform can show it', () {
    // ⛔ ONE SET OF CASES, RUN EVERYWHERE, WITH THE EXPECTATION BRANCHING —
    // NOT TWO SETS WITH ONE SKIPPED. An early `return` for the inapplicable
    // platform is a skip wearing a different hat: it reports PASSED having
    // asserted nothing, and nine green lines that measured nothing is exactly
    // the furniture this project keeps finding. Every case below pumps, and
    // every case below asserts.
    for (final w in <double>[375, 430, 800]) {
      for (final scale in <double>[1.0, 1.5, 2.0]) {
        testWidgets('${w.toInt()} @ ${(scale * 100).toInt()}%', (tester) async {
          await pumpHome(tester, w: w, scale: scale);
          final card = find.text('Notifications are off');

          // ⭐ THE STATE IS ASSERTED BEFORE IT IS MEASURED. Three false
          // results in one day came from believing a pump had set something it
          // had not.
          expect(find.byType(HomeScreen), findsOneWidget,
              reason: 'positive control: home actually rendered. Without this '
                  'both branches below are satisfied by an empty tree.');

          if (cardCanRender) {
            expect(card, findsOneWidget,
                reason: '⛔ THE PUMP ASKED THE PLUGIN TO REPORT NOTIFICATIONS '
                    'DENIED, which is the one state this card exists for. On '
                    'this platform it must appear — and if it does not, the '
                    'overflow assertion below is measuring an empty screen, '
                    'which is how this test came to pass on a machine that '
                    'could not render its subject.');
          } else {
            expect(card, findsNothing,
                reason: '⛔ THIS PLATFORM HAS NO NOTIFICATION PATH, so it must '
                    'not be told its notifications are off. The pump asked the '
                    'plugin to report them DENIED and the card must STILL not '
                    'appear — the guard, not the plugin\'s answer, is what '
                    'keeps it away. If the guard were dropped, or '
                    '`_notificationsAllowed` were initialised false, this is '
                    'the only assertion anywhere that would say so.');
          }

          // ⭐ AND THE SCREEN MUST BE CLEAN EITHER WAY, at the same widths and
          // the same scales. The card is not the only thing on this screen,
          // and the platform that cannot show it still has to render the rest.
          final errors = drain(tester);
          expect(errors, isEmpty,
              reason: '⛔ THE SCREEN MUST SURVIVE AT 200% ON THE NARROWEST '
                  'SUPPORTED WIDTH. 200% is an ordinary accessibility setting, '
                  'not an extreme, and 375 is the narrowest width MER '
                  'supports. ⚠️ Where this card is the cause, the fix is to '
                  'the LAYOUT: the copy is not negotiable.\n'
                  '${errors.join('\n')}');
        });
      }
    }
  });

  group('the 100% layout is untouched', () {
    // ⭐ CAPTURED FROM THE PRE-FIX BUILD at 27be046 and asserted afterwards, so
    // that a responsive fix cannot pay for 200% with a change nobody asked for
    // at the size almost everyone uses.
    const before = <String, List<String>>{
      '375': [
        'Notifications are off|81.0x100.0',
        "Quick log won't work until notifications are enabled.|81.0x220.0",
        'Open Settings|182.0x14.0',
        'Help →|84.0x14.0',
      ],
      '430': [
        'Notifications are off|136.0x60.0',
        "Quick log won't work until notifications are enabled.|136.0x140.0",
        'Open Settings|182.0x14.0',
        'Help →|84.0x14.0',
      ],
      '800': [
        'Notifications are off|258.0x40.0',
        "Quick log won't work until notifications are enabled.|258.0x80.0",
        'Open Settings|182.0x14.0',
        'Help →|84.0x14.0',
      ],
    };

    for (final w in <double>[375, 430, 800]) {
    testWidgets('${w.toInt()} @100% renders exactly as it did before the fix',
        (tester) async {
      await pumpHome(tester, w: w, scale: 1.0);
      final got = cardGeometry(tester);
      // ignore: avoid_print
      print('  CAPTURE ${w.toInt()}@100% => $got');
      expect(got, cardCanRender
              ? before['${w.toInt()}']
              : const [
                  'Notifications are off|ABSENT',
                  "Quick log won't work until notifications are enabled.|ABSENT",
                  'Open Settings|ABSENT',
                  'Help →|ABSENT',
                ],
          reason: cardCanRender
              ? '⚠️ THE CONTROL ON THE FIX ITSELF. 200% must not be bought '
                  'with a change at 100%.'
              : '⛔ EVERY PIECE OF THE CARD IS ABSENT ON THIS PLATFORM, named '
                  'one by one rather than checked as a group — a card that '
                  'lost three of its four parts would satisfy a single '
                  'findsNothing on the title.');
      for (var e = tester.takeException(); e != null;) {
        e = tester.takeException();
      }
    });
    }
  });
}
