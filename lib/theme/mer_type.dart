import 'package:flutter/material.dart';

import 'mer_theme.dart';

/// The type scale. ⛔ **THE SOURCE, AND THE THEME IS BUILT FROM IT.**
///
/// ## Why this exists rather than `textTheme` alone
///
/// `Theme.of(context).textTheme.X` needs a `BuildContext` and is not a
/// constant. **108 of 124 styled sites in this app are const-affected** — 51
/// declare `const TextStyle(` directly and 57 sit inside a const ancestor —
/// so routing every site through the theme would strip `const` from most of
/// the widget tree and cascade. Measured before it was attempted.
///
/// ## ⛔ Why BUILT FROM rather than BESIDE
///
/// Two definitions of one value with nothing holding them together is
/// `textPrimary` byte-identical to `primary`, in a new medium — the shape
/// the colour system exists to prevent. `MERTheme.light`'s `textTheme` is
/// assembled from the constants below, so **one definition has two access
/// paths and divergence is not expressible**: a widget with a context reads
/// the theme, a const widget reads `MERType`, and both resolve to the same
/// object.
///
/// ## The rule
///
/// ⛔ **No literal `fontSize` or `fontWeight` anywhere outside this class.**
/// Enforceable by the same shape of checker rule 2 uses for colour.
///
/// ## ⚠️ Why the styles carry a COLOUR and are named for it
///
/// `TextStyle.copyWith` is not `const` either, so a const site that needs a
/// non-default colour cannot compose one at the call site. The set below is
/// therefore every (step, colour) pair **actually in use** — measured, not a
/// cross product — and a pair nothing uses is not declared.
abstract final class MERType {
  // ── THE SIX STEPS. Declared once; every style below references these, so
  // a size lives in exactly one place. ──
  static const double micro    = 10;
  static const double caption  = 12;
  static const double body     = 14;
  static const double subhead  = 16;
  static const double heading  = 18;
  static const double display  = 28;

  // ── THE THREE WEIGHTS. `w500` is retired into `emphasis`; `strong` is
  // reserved for `display` and the capture action. ──
  static const FontWeight regular  = FontWeight.w400;
  static const FontWeight emphasis = FontWeight.w600;
  static const FontWeight strong   = FontWeight.w700;

  /// Positive tracking for the UPPERCASE register.
  ///
  /// ⚠️ V4 renders screen furniture uppercase, and uppercase without
  /// tracking is measurably harder to read. **Verified across seventeen
  /// uppercase sites** — three via `.toUpperCase()` and fourteen as literal
  /// capitals — of which sixteen already resolved to 0.8. Lowercase steps
  /// carry none.
  static const double upperTracking = 0.8;

  // ── micro 10/regular — app-bar subtitle, stat caption ──
  static const TextStyle microOnPrimaryMuted = TextStyle(
      fontSize: micro, fontWeight: regular, color: MERColours.onPrimaryMuted);
  static const TextStyle microOnSurfaceMuted = TextStyle(
      fontSize: micro, fontWeight: regular, color: MERColours.onSurfaceMuted);

  // ── caption 12/regular — hint, metadata, list-tile secondary, tagline ──
  static const TextStyle captionCriticalOnContainer = TextStyle(
      fontSize: caption, fontWeight: regular, color: MERColours.criticalOnContainer);
  static const TextStyle captionOnPrimaryMuted = TextStyle(
      fontSize: caption, fontWeight: regular, color: MERColours.onPrimaryMuted);
  static const TextStyle captionOnSurface = TextStyle(
      fontSize: caption, fontWeight: regular, color: MERColours.onSurface);
  static const TextStyle captionOnSurfaceMuted = TextStyle(
      fontSize: caption, fontWeight: regular, color: MERColours.onSurfaceMuted);

  // ── caption 12/emphasis — badge or count. NO tracking: a badge is not uppercase ──
  static const TextStyle captionStrongOnFill = TextStyle(
      fontSize: caption, fontWeight: emphasis, color: MERColours.onFill);
  static const TextStyle captionStrongOnSurface = TextStyle(
      fontSize: caption, fontWeight: emphasis, color: MERColours.onSurface);
  static const TextStyle captionStrongOnSurfaceMuted = TextStyle(
      fontSize: caption, fontWeight: emphasis, color: MERColours.onSurfaceMuted);
  static const TextStyle captionStrongPrimary = TextStyle(
      fontSize: caption, fontWeight: emphasis, color: MERColours.primary);

  // ── caption 12/emphasis + tracking — THE UPPERCASE REGISTER, field labels ──
  static const TextStyle captionUpperOnSurface = TextStyle(
      fontSize: caption, fontWeight: emphasis, color: MERColours.onSurface, letterSpacing: upperTracking);
  static const TextStyle captionUpperOnSurfaceMuted = TextStyle(
      fontSize: caption, fontWeight: emphasis, color: MERColours.onSurfaceMuted, letterSpacing: upperTracking);

  // ── body 14/regular — body prose, list-tile primary, dropdown item ──
  static const TextStyle bodyCautionOnContainer = TextStyle(
      fontSize: body, fontWeight: regular, color: MERColours.cautionOnContainer);
  static const TextStyle bodyOnSurface = TextStyle(
      fontSize: body, fontWeight: regular, color: MERColours.onSurface);
  static const TextStyle bodyOnSurfaceMuted = TextStyle(
      fontSize: body, fontWeight: regular, color: MERColours.onSurfaceMuted);
  static const TextStyle bodyPositiveOnContainer = TextStyle(
      fontSize: body, fontWeight: regular, color: MERColours.positiveOnContainer);

  // ── body 14/emphasis — section heading, button label, banner title ──
  static const TextStyle bodyStrongCautionOnContainer = TextStyle(
      fontSize: body, fontWeight: emphasis, color: MERColours.cautionOnContainer);
  static const TextStyle bodyStrongCriticalOnContainer = TextStyle(
      fontSize: body, fontWeight: emphasis, color: MERColours.criticalOnContainer);
  static const TextStyle bodyStrongInfoOnContainer = TextStyle(
      fontSize: body, fontWeight: emphasis, color: MERColours.infoOnContainer);
  static const TextStyle bodyStrongLink = TextStyle(
      fontSize: body, fontWeight: emphasis, color: MERColours.link);
  static const TextStyle bodyStrongOnPrimary = TextStyle(
      fontSize: body, fontWeight: emphasis, color: MERColours.onPrimary);
  static const TextStyle bodyStrongOnSurface = TextStyle(
      fontSize: body, fontWeight: emphasis, color: MERColours.onSurface);
  static const TextStyle bodyStrongOnSurfaceMuted = TextStyle(
      fontSize: body, fontWeight: emphasis, color: MERColours.onSurfaceMuted);
  static const TextStyle bodyStrongPositiveOnContainer = TextStyle(
      fontSize: body, fontWeight: emphasis, color: MERColours.positiveOnContainer);
  static const TextStyle bodyStrongPrimary = TextStyle(
      fontSize: body, fontWeight: emphasis, color: MERColours.primary);

  // ── subhead 16/emphasis — app-bar title. Measured to fit: 335.0 slot, 274.2 extent ──
  static const TextStyle subheadOnPrimary = TextStyle(
      fontSize: subhead, fontWeight: emphasis, color: MERColours.onPrimary);
  static const TextStyle subheadOnSurface = TextStyle(
      fontSize: subhead, fontWeight: emphasis, color: MERColours.onSurface);

  // ── heading 18/emphasis ──
  static const TextStyle headingOnSurface = TextStyle(
      fontSize: heading, fontWeight: emphasis, color: MERColours.onSurface);

  // ── display 28/strong — the splash wordmark ──
  static const TextStyle displayOnPrimary = TextStyle(
      fontSize: display, fontWeight: strong, color: MERColours.onPrimary);

  // ── COLOURLESS VARIANTS. Used where the site inherits its colour from
  // the ambient DefaultTextStyle; `TextStyle.inherit` is true by default, so
  // these MERGE rather than override. ──
  static const TextStyle microInherit = TextStyle(
      fontSize: micro, fontWeight: regular);
  static const TextStyle captionInherit = TextStyle(
      fontSize: caption, fontWeight: regular);
  static const TextStyle captionStrongInherit = TextStyle(
      fontSize: caption, fontWeight: emphasis);
  static const TextStyle captionUpperInherit = TextStyle(
      fontSize: caption, fontWeight: emphasis, letterSpacing: upperTracking);
  static const TextStyle bodyInherit = TextStyle(
      fontSize: body, fontWeight: regular);
  static const TextStyle bodyStrongInherit = TextStyle(
      fontSize: body, fontWeight: emphasis);
  static const TextStyle subheadInherit = TextStyle(
      fontSize: subhead, fontWeight: emphasis);
  static const TextStyle headingInherit = TextStyle(
      fontSize: heading, fontWeight: emphasis);
  static const TextStyle displayInherit = TextStyle(
      fontSize: display, fontWeight: strong);
}
