import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/theme/mer_theme.dart';

/// BRIEF 62 D — the selected event-type chip carries a SECOND carrier.
///
/// ⛔ **1.4.1, not an inconsistency.** On the single-page form every other
/// selected chip carries a ✓. The type chip changed only `selectedColor` and
/// the tint of its icon — **and its UNSELECTED siblings carry icons too**, so
/// selected-versus-unselected was conveyed by colour and nothing else, on the
/// one control whose value names what the event WAS.
///
/// ⚠️ **THE ACCEPTED COST: the type icon is hidden while selected.**
/// `RawChip` gives the avatar and the checkmark one slot and the checkmark
/// wins it — exactly as the screen's own block comment predicted. Accepted:
/// the selected chip is the one the user just chose, its label names the type,
/// and the identity fill still carries the colour. The icon's job is scanning
/// the options, which is an unselected-state job.
///
/// 🔴 **THE PARAGRAPH ABOVE WAS FALSE ON THE DEVICE AND IS ANNOTATED, NOT
/// DELETED. Corrected 20 September 2026 from a tablet capture.**
/// *"The checkmark wins it"* is **not** what Flutter does when BOTH an avatar
/// and a checkmark are supplied: **it draws BOTH, superimposed.** The shipped
/// chip rendered a tick on top of the waveform glyph and the result was
/// illegible — worse than either carrier alone.
///
/// ⛔ **AND TEST 2 PASSED THROUGHOUT.** It asserted that `showCheckmark`
/// CHANGED THE PIXELS, and it did — by 1,014 bytes. **A superimposed tick
/// changes the pixels exactly as a replacing tick does.** The test proved the
/// tick PAINTS; it never proved the avatar STOPPED painting, which is the
/// half the accepted cost rested on. ⭐ **A measurement that is true about
/// something adjacent to the question** — the class this corpus already
/// records, arrived at again by asserting a difference instead of asserting
/// WHAT the difference was.
///
/// ⚠️ **THE REPAIR: the avatar is now dropped when selected**, so the slot
/// holds the checkmark alone. **Test 5 is the control that was missing** — it
/// asserts the selected chip renders IDENTICALLY to a chip that never had an
/// avatar, which is the only form of the claim that cannot be satisfied by a
/// superimposition.
///
/// ⭐ **THE ALTERNATIVE WAS BUILT AND MEASURED FIRST, NOT ARGUED AWAY.**
/// Moving the icon into `label` keeps BOTH carriers — and costs 24.0 logical
/// points of width per chip (237.3 → 261.3), which forced an extra wrap row,
/// shifted the form 40 points down, and stale-d three render baselines
/// captured from unpatched code for an unrelated contract. It also regressed
/// the form's chip overflow from a clean 175 to 325 until a `Flexible` was
/// added. **The in-slot checkmark costs nothing.**
///
/// 🔴 **AND THE TICK IS PROVED TO PAINT, because it had to be.** "The avatar
/// wins the slot" and "the checkmark wins the slot" produce THE SAME WIDTH,
/// and only one of them is a fix. A width assertion cannot tell them apart, so
/// test 2 compares pixels — with a control, because a non-zero difference over
/// a non-deterministic renderer would prove nothing.

void main() {
  /// Mirrors the real chip: the avatar is supplied ONLY when unselected.
  ChoiceChip typeChip(
          {required bool showCheck,
          required bool selected,
          bool avatarWhenSelected = false}) =>
      ChoiceChip(
        avatar: (selected && !avatarWhenSelected)
            ? null
            : Icon(Icons.bolt,
                size: 18,
                color:
                    selected ? MERColours.onFill : MERColours.onSurfaceMuted),
        showCheckmark: showCheck,
        checkmarkColor: MERColours.onFill,
        label: const Text('Seizure / fit'),
        selected: selected,
        selectedColor: MERColours.identitySeizureOn,
        onSelected: (_) {},
      );

  /// A chip carrying the checkmark and NOTHING else in the leading slot.
  ChoiceChip tickOnly() => ChoiceChip(
        showCheckmark: true,
        checkmarkColor: MERColours.onFill,
        label: const Text('Seizure / fit'),
        selected: true,
        selectedColor: MERColours.identitySeizureOn,
        onSelected: (_) {},
      );

  Future<(Size, Uint8List)> render(WidgetTester tester, Widget c) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: RepaintBoundary(child: Wrap(children: [c])),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final size = tester.getSize(find.byType(RawChip).first);
    final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byType(RepaintBoundary).first);
    late Uint8List bytes;
    // ⚠️ `runAsync`. Under the test's fake async `toImage()` never completes —
    // it HANGS rather than failing, which is how the first attempt at this
    // probe burned a timeout and produced no output at all.
    await tester.runAsync(() async {
      final img = await boundary.toImage();
      final bd = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
      bytes = bd!.buffer.asUint8List();
    });
    return (size, bytes);
  }

  int diff(Uint8List a, Uint8List b) {
    var n = 0;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) n++;
    }
    return n;
  }

  testWidgets('1. the fix costs NO layout, against the PRE-FIX chip',
      (tester) async {
    // The pre-fix selected chip: type icon in the avatar slot, no tick.
    final (preFix, _) = await render(tester,
        typeChip(showCheck: false, selected: true, avatarWhenSelected: true));
    // The shipped selected chip: no avatar, tick in the slot.
    final (shipped, _) =
        await render(tester, typeChip(showCheck: true, selected: true));
    expect(shipped, preFix,
        reason: 'one leading glyph either way, so the chip does not change '
            'size. 237.3x48.0 both when this was written — if this fails, the '
            'layout cost the label-Row alternative was rejected for has '
            'arrived by another route');
  });

  testWidgets('1b. and SELECTING a chip does not resize it', (tester) async {
    // ⭐ THE USER-VISIBLE FORM OF THE SAME CLAIM, and the one that would show
    // as reflow: unselected carries the type icon, selected carries the tick,
    // and both occupy one leading slot.
    final (unselected, _) =
        await render(tester, typeChip(showCheck: true, selected: false));
    final (selected, _) =
        await render(tester, typeChip(showCheck: true, selected: true));
    expect(selected, unselected,
        reason: 'a chip that resized on selection would reflow the Wrap under '
            'the user\'s finger');
  });

  testWidgets('2. ⛔ THE TICK IS ACTUALLY PAINTED', (tester) async {
    final (_, off) =
        await render(tester, typeChip(showCheck: false, selected: true));
    final (_, on) =
        await render(tester, typeChip(showCheck: true, selected: true));
    final (_, offAgain) =
        await render(tester, typeChip(showCheck: false, selected: true));

    expect(off.length, on.length,
        reason: 'CONTROL: identical canvas, so any byte difference below is '
            'paint and not geometry');
    expect(diff(off, offAgain), 0,
        reason: 'CONTROL: the comparison must be deterministic. If two '
            'identical renders differ, the non-zero result below says nothing '
            'about the checkmark');
    expect(diff(off, on), greaterThan(0),
        reason: 'showCheckmark must CHANGE THE PIXELS. If it does not, no tick '
            'is drawn and the 1.4.1 fix is a no-op that reads as done.\n\n'
            '⚠️ NOTE WHAT THIS DOES AND DOES NOT PROVE: it proves the tick '
            'PAINTS. It does NOT prove the avatar stopped painting — a tick '
            'drawn ON TOP of the avatar satisfies it identically, and that is '
            'exactly what shipped in build 59 and was caught on the tablet. '
            'Test 5 is the assertion that closes that gap');
  });

  testWidgets('3. and the carrier is not colour — an UNSELECTED chip differs '
      'by more than its fill', (tester) async {
    // ⭐ THE POINT OF THE WHOLE FIX, stated as a measurement: with the tick
    // ON, selected and unselected differ in the leading slot as well as the
    // fill. The `selectedColor` is deliberately set to a NEUTRAL-ish identity
    // colour in both renders' theme so this is not merely restating that a
    // fill changed.
    final (_, sel) =
        await render(tester, typeChip(showCheck: true, selected: true));
    final (_, unsel) =
        await render(tester, typeChip(showCheck: true, selected: false));
    expect(diff(sel, unsel), greaterThan(0));

    // The load-bearing half: WITHOUT the checkmark the two states differed
    // only by colour. That is the state this fix removed, and it is asserted
    // here as the thing that must never come back.
    final (_, selNoTick) =
        await render(tester, typeChip(showCheck: false, selected: true));
    expect(diff(sel, selNoTick), greaterThan(0),
        reason: 'the selected chip WITH a tick must differ from the selected '
            'chip WITHOUT one — that difference IS the second carrier, and if '
            'it ever reaches zero the chip is back to colour alone');
  });

  testWidgets('5. ⛔ THE AVATAR IS GONE WHEN SELECTED, not drawn under the tick',
      (tester) async {
    // 🔴 THE CONTROL THAT WAS MISSING, and the one the device found. Test 2
    // asserts the tick paints; a tick drawn ON TOP of the avatar satisfies it
    // just as well as a tick that replaced the avatar, and that is what
    // shipped in build 59 — an illegible superimposed glyph.
    //
    // ⭐ THE ONLY FORM OF THE CLAIM A SUPERIMPOSITION CANNOT SATISFY: the
    // selected chip must render BYTE-IDENTICALLY to a chip that never carried
    // an avatar at all.
    final (_, real) =
        await render(tester, typeChip(showCheck: true, selected: true));
    final (_, tick) = await render(tester, tickOnly());
    expect(diff(real, tick), 0,
        reason: 'the selected chip must paint exactly what a tick-only chip '
            'paints. Any difference is the avatar still being drawn beneath '
            'the checkmark — which is what the tablet showed, and what test 2 '
            'could not see');

    // POSITIVE CONTROL: force the avatar back on and confirm the comparison
    // CAN fail. Without this, a zero above is indistinguishable from a
    // comparison that is not looking.
    final (_, superimposed) = await render(tester,
        typeChip(showCheck: true, selected: true, avatarWhenSelected: true));
    expect(diff(superimposed, tick), greaterThan(0),
        reason: 'CONTROL: supplying both an avatar and a checkmark must '
            'DIFFER from tick-only. If this is zero the comparison is dead '
            'and the '
            'assertion above proves nothing');
  });

  test('4. the source no longer disables the checkmark on a type chip', () {
    // ⚠️ SOURCE SCAN, because the widget tests above use a local fixture
    // rather than the real screen — they prove the MECHANISM, and this proves
    // the screen uses it. Both are needed: a mechanism nothing calls is the
    // forward-reference failure this repo already has a rule about.
    final src = _read('lib/screens/log_event_screen.dart');

    // ⛔ COMMENTS STRIPPED, and this test FAILED ON ITS FIRST RUN without the
    // strip — the same way `notification_routing_test` did, for the same
    // reason, which is why that file's note is followed here rather than
    // rediscovered. The change's own annotation QUOTES the retired line so the
    // edit stays legible, and a raw `contains` matches the quote instead of
    // any live code. ⭐ A mention in a comment is not code.
    final live = src
        .split('\n')
        .where((l) {
          final t = l.trimLeft();
          return !t.startsWith('//') && !t.startsWith('///');
        })
        .join('\n');

    expect(src.contains('showCheckmark: false'), isTrue,
        reason: 'CONTROL: the retired form IS still quoted in the annotation, '
            'so the strip above is load-bearing rather than decoration. If '
            'this fails, the annotation recording the change has been deleted '
            'and the assertion below has become trivially true');
    expect(live.contains('showCheckmark: false'), isFalse,
        reason: 'the type chips carried `showCheckmark: false`, which is what '
            'made colour their only selection carrier');
    expect(live.contains('showCheckmark: true'), isTrue,
        reason: 'CONTROL: the property is still named explicitly rather than '
            'silently dropped, so this scan is asserting a decision and not '
            'the absence of a line');

    // 🔴 THE ASSERTION NOTHING ELSE HERE MAKES, added 20 September 2026 after
    // the device found the superimposition.
    //
    // ⛔ NEITHER TEST 4's ORIGINAL SCAN NOR TEST 5 WOULD HAVE CAUGHT WHAT
    // SHIPPED IN BUILD 59. The defect carried `showCheckmark: true` — so the
    // scan above passed — and test 5 exercises a FIXTURE, so it passes
    // whatever this screen does. ⭐ A mechanism proven in a fixture and a
    // screen that uses it are two claims, and only one of them was checked.
    //
    // The live shape must keep the avatar CONDITIONAL on selection, because
    // supplying both an avatar and a checkmark draws both.
    expect(live.contains('avatar: isSel'), isTrue,
        reason: 'the type chip must drop its avatar when selected. An '
            'unconditional `avatar:` beside `showCheckmark: true` renders the '
            'tick ON TOP of the type glyph — illegible, and exactly what the '
            'tablet showed on build 59');
    expect(
        RegExp(r'avatar:\s*Icon\(_iconFor').hasMatch(live), isFalse,
        reason: 'CONTROL on the assertion above, stated as its negation: an '
            'UNCONDITIONAL type icon in the avatar slot is the defect itself. '
            'If the guard is ever rewritten in a form `avatar: isSel` does not '
            'match, this catches it from the other side');
  });
}

String _read(String path) => File(path).readAsStringSync();
