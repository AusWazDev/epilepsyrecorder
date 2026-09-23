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
// ⭐ THE LEVER IS `AwesomeNotificationsPlatform.operatingSystem`, which the
// plugin marks `@visibleForTesting`. Off android/ios the plugin resolves to
// `AwesomeNotificationsEmpty`, whose `isNotificationAllowed()` returns false
// unconditionally and reaches no channel — so a channel mock alone CANNOT move
// this, and an earlier attempt that appeared to work was `pumpWidget` reusing
// the element tree. Every pump here is preceded by a teardown pump and a
// distinct key for that reason.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:awesome_notifications/awesome_notifications_platform_interface.dart';
import 'package:medical_event_recorder/screens/home_screen.dart';

const _channel = MethodChannel('awesome_notifications');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    AwesomeNotificationsPlatform.resetInstance();
    AwesomeNotificationsPlatform.operatingSystem = Platform.operatingSystem;
  });

  /// Pumps HomeScreen with the nudge card SHOWN, at [w] logical px and [scale].
  Future<void> pumpWithCard(WidgetTester tester,
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

  group('the card survives large text on the narrowest supported width', () {
    for (final w in <double>[375, 430, 800]) {
      for (final scale in <double>[1.0, 1.5, 2.0]) {
        testWidgets('no overflow at ${w.toInt()} @ ${(scale * 100).toInt()}%',
            (tester) async {
          await pumpWithCard(tester, w: w, scale: scale);

          // The card must actually be there, or this measures nothing.
          expect(find.text('Notifications are off'), findsOneWidget,
              reason: 'positive control: the nudge card is in the tree. '
                  'Without it this test passes against anything.');

          final errors = <String>[];
          for (var e = tester.takeException(); e != null;
              e = tester.takeException()) {
            errors.add('$e'.split('\n').first);
          }
          expect(errors, isEmpty,
              reason: '⛔ THE CARD MUST SURVIVE AT 200% ON THE NARROWEST '
                  'SUPPORTED WIDTH. It renders precisely when notifications '
                  'are denied — the state it exists to report — and 200% is an '
                  'ordinary accessibility setting, not an extreme. '
                  '⚠️ The fix is to the LAYOUT: the copy is not negotiable.\n'
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
      await pumpWithCard(tester, w: w, scale: 1.0);
      final got = cardGeometry(tester);
      // ignore: avoid_print
      print('  CAPTURE ${w.toInt()}@100% => $got');
      expect(got, before['${w.toInt()}'],
          reason: '⚠️ THE CONTROL ON THE FIX ITSELF. 200% must not be bought '
              'with a change at 100%.');
      for (var e = tester.takeException(); e != null;) {
        e = tester.takeException();
      }
    });
    }
  });
}
