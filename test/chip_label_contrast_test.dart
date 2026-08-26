import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:medical_event_recorder/theme/mer_theme.dart';

/// A selected chip's label must be readable against a selected chip's fill.
///
/// **Found on the tablet, not in code review.** The theme set
/// `selectedColor` to the dark navy primary and `labelStyle.color` to the dark
/// `textPrimary`, relying on `secondaryLabelStyle` to supply white when
/// selected. `secondaryLabelStyle` is used by ChoiceChip and InputChip — but
/// NOT by FilterChip, which reads `labelStyle` in every state. So the first
/// FilterChip this app ever selected rendered as a blank navy pill with a tick
/// and no visible text at all.
///
/// It had never been reachable before: every selected chip in the app was a
/// ChoiceChip (event type, severity, referral), which the secondary style
/// covers. Multi-select observations in the wizard were the first FilterChips
/// a user could select.

/// Rough relative luminance, enough to tell "readable" from "invisible".
double _luminance(Color c) => c.computeLuminance();

void main() {
  final chip = MERTheme.light.chipTheme;

  test('1. the SELECTED label colour contrasts with the selected fill', () {
    final selectedFill = chip.selectedColor!;
    final labelColour = WidgetStateProperty.resolveAs<Color?>(
      chip.labelStyle!.color,
      <WidgetState>{WidgetState.selected},
    )!;

    final delta = (_luminance(selectedFill) - _luminance(labelColour)).abs();
    expect(delta, greaterThan(0.4),
        reason: 'a selected FilterChip label must be readable. Fill '
            '$selectedFill, label $labelColour');
  });

  test('2. NEGATIVE CONTROL: the UNSELECTED colour would FAIL that test', () {
    // Without this, test 1 passes just as well against a theme that made every
    // label white — which would make unselected chips unreadable instead, the
    // same defect pointing the other way.
    final selectedFill = chip.selectedColor!;
    final unselectedLabel = WidgetStateProperty.resolveAs<Color?>(
      chip.labelStyle!.color,
      <WidgetState>{},
    )!;

    final delta =
        (_luminance(selectedFill) - _luminance(unselectedLabel)).abs();
    expect(delta, lessThan(0.4),
        reason: 'this is the pairing that was actually shipping: the dark '
            'unselected label on the dark selected fill');
  });

  test('3. the UNSELECTED label contrasts with the unselected fill', () {
    final fill = chip.backgroundColor!;
    final label = WidgetStateProperty.resolveAs<Color?>(
      chip.labelStyle!.color,
      <WidgetState>{},
    )!;

    expect((_luminance(fill) - _luminance(label)).abs(), greaterThan(0.4));
  });

  testWidgets('4. a selected FilterChip actually renders a visible label',
      (tester) async {
    // The theme assertions above are about values. This is about what a person
    // sees — resolved through the real widget, with the real theme.
    await tester.pumpWidget(MaterialApp(
      theme: MERTheme.light,
      home: const Scaffold(
        body: Center(
          child: FilterChip(
            label: Text('Jaw ache'),
            selected: true,
            onSelected: null,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final text = tester.widget<Text>(find.text('Jaw ache'));
    final style = DefaultTextStyle.of(
            tester.element(find.text('Jaw ache')))
        .style
        .merge(text.style);
    final colour = WidgetStateProperty.resolveAs<Color?>(
        style.color, <WidgetState>{WidgetState.selected});

    expect(colour, isNotNull);
    expect(_luminance(colour!), greaterThan(0.5),
        reason: 'light text, because the selected fill is dark navy');
  });
}
