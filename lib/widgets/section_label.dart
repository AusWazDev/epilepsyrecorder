import 'package:flutter/material.dart';

/// Screen furniture: the small uppercase label that names a section.
///
/// ## ⛔ THE WIDGET OWNS THE REGISTER, AND THAT IS THE POINT
///
/// V4's outcome is that screen furniture is **uppercase applied at render**.
/// Before this, seventeen sites carried literal capitals in the source string
/// and two called `toUpperCase()` — the same register reached two ways, which
/// has three costs:
///
///  * ⚠️ **The register was not mechanically detectable.** A checker cannot
///    ask "is this the uppercase register" when the answer lives in how the
///    author happened to type the string. `mer_type.dart` records exactly this
///    problem: *"the register is not detectable by the transform that applies
///    it"*.
///  * **The source stopped being readable copy.** `'DATA STORAGE & PRIVACY'`
///    is a rendering instruction wearing a sentence's clothes. A copy sweep
///    that greps for what the app says has to know to shout.
///  * **Changing the register meant editing every string** rather than one
///    widget.
///
/// ⭐ **Source strings are now sentence case and this widget uppercases.** The
/// RENDERED string is unchanged at every site — which is what makes the
/// conversion safe, and what the paragraph-hash census checks.
///
/// ## ⚠️ The style, and the one site that differs
///
/// Defaults to `textTheme.labelLarge`, which IS
/// `MERType.captionUpperOnSurfaceMuted` — the uppercase register, carrying its
/// 0.8 tracking. `OccurredAtField` passes `captionUpperOnSurface` instead: the
/// non-muted colour, which was already deliberate there and is preserved
/// rather than flattened into the default.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.style});

  /// Written in SENTENCE CASE. This widget applies the register.
  final String text;

  /// Overrides the default uppercase-register style. Null takes `labelLarge`.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: style ?? Theme.of(context).textTheme.labelLarge,
      );
}
