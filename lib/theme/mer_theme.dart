import 'package:flutter/material.dart';

/// The colour system. 34 tokens, role-named.
///
/// ## ⛔ FOUR RULES. They are part of the set, not commentary on it.
///
/// **1. NO OPACITY ON TEXT.** A tone is a token, not a transparency. Every
/// alpha composite this app had failed: the two nudge-card bodies at `.85`
/// (§13(s) rows 10 and 16) and home's *"Tap edit to update details"* at
/// `textMuted.withOpacity(0.7)`, which composites to `#7C9EB7` = **2.83** and
/// was not even one of the 28 measured pairs.
///
/// **2. NO WIDGET NAMES A COLOUR.** Every `Color(0x…)` outside this file was
/// assigned a role or deleted. §13(w) is the argument: a fix confined to the
/// palette file *"would look complete and leave 17 of 28 untouched"*.
///
/// > ⛔ **EXTENDED 13 Sep 2026, BECAUSE THE CHECK ONLY LOOKED FOR HEX.** The
/// > rule was verified over `Color(0x…)` literals and reported zero outside
/// > this file — **which was true, and was not the same as no widget naming a
/// > colour.** `Colors.red.shade700` and `Colors.red.shade300` had survived
/// > every sweep, on the app's most destructive control, and one of them was
/// > a live 2.9866 against 3.0. ⭐ **Third instance of one class**: a fill hid
/// > `warning` from a text-only sweep, a text-only sweep hid it twice, and a
/// > hex-only sweep hid these. **A sweep sees the shape it was written to
/// > see.**
/// >
/// > **The rule now covers NAMED palette colours too — `Colors.*` — and not
/// > only hex.** ⚠️ **But it is two rules, not one, and conflating them is
/// > what makes it unenforceable.** A site where a token already holds the
/// > value is a NAMING problem and the substitution changes no pixel. A site
/// > where NO token holds the value is a DESIGN decision, and substituting
/// > the nearest token changes what renders. Only the second needs a
/// > decision, and neither may be answered by inventing a token to absorb it.
/// >
/// > ⚠️ **Consequently this rule is NOT clean today, and the residue is
/// > enumerated rather than waved at. FOURTEEN sites** outside this file still
/// > name a neutral, all of them real code and none in a comment: **seven**
/// > `Colors.white.withOpacity(…)`, **one** `Colors.black45`, and **six** bare
/// > whites sitting on grounds this set has no on-token for — `infoAccent`,
/// > `cautionOnContainer`, a 15%-white box, and the identity colours, whose
/// > selected chips paint white on a per-type hue. The chromatic residue is
/// > **zero**. `Colors.white` INSIDE this file is a definition and is fine.
/// >
/// > ⚠️ **And the sweep that produced those numbers counts COMMENTS**, so it
/// > reports the two `Colors.red.shade…` names quoted three paragraphs above
/// > as occurrences inside this file. They are a record of what was removed,
/// > not a use. Any checker built from this rule must skip comment lines, or
/// > it will flag the rule's own documentation.
///
/// **3. NOTHING MAY ASSUME `onSurface == primary`.** They hold the same value
/// today. §13(w) records that as *"two names, one colour"*. The value is not
/// the defect; the defect would be code that relies on the coincidence.
/// Either may move without the other.
///
/// **4. THREE TOKENS CARRY A CONSTRAINT IN THEIR NAME.**
///   * `focusRing` is NON-TEXT. 3.60 clears 3.0 as a border and fails 4.5 as
///     text. It is the 1.5 px focused input border and nothing else. A link
///     or label needing this hue as text takes `link` instead.
///   * `accentOnPrimary` is ON-PRIMARY ONLY. It is 1.88 on white.
///   * `captureFill` is a fill valid ONLY AT LARGE-TEXT SIZE. White on it is
///     3.67, which passes at `Record Event`'s 26 px w700 and fails the moment
///     that label drops below 18.67 px bold. ⚠️ **That dependency has already
///     been violated once**, by the same value behind a 13 px w600 severity
///     chip, so `colour_system_test` asserts the SIZE and not only the ratio.
///
/// Every value is verified against all three grounds it can land on — its own
/// container, `surface` and `surfaceSunken` — by `test/colour_system_test.dart`,
/// which is the set's own contract and fails if a tint is nudged.
class MERColours {
  // ── FOUNDATION ─────────────────────────────────────────────────────────
  static const Color surface = Color(0xFFFFFFFF);

  /// The scaffold. Renamed from `background`, 13 Sep 2026.
  static const Color surfaceSunken = Color(0xFFF5F8FB);

  /// Every card, chip and input outline, and the divider. Renamed from
  /// `border`. ⭐ Darkened 11 Sep 2026 from `#B5D4F4` (1.53 / 1.44).
  /// ⚠️ 3.38 is the DEFINED pair. §13(ck) measured it painting at **1.72** on
  /// a 1× device because every theme stroke is 0.5 logical. **C3 takes strokes
  /// to 1.0 and this value is not honest until it does.**
  static const Color outline = Color(0xFF798EA3);

  // ── TEXT ───────────────────────────────────────────────────────────────
  /// Renamed from `textPrimary`. 8.54 · 8.02.
  static const Color onSurface = Color(0xFF0D4F82);

  /// Renamed from `textMuted`. 4.95 · 4.64. ⭐ Darkened 11 Sep 2026 from
  /// `#4A7FA5` (4.31 / 4.05).
  static const Color onSurfaceMuted = Color(0xFF447598);

  // ── BRAND AND FOCUS ────────────────────────────────────────────────────
  static const Color primary = Color(0xFF0D4F82);
  static const Color onPrimary = Color(0xFFFFFFFF);

  /// ⛔ NON-TEXT. See rule 4. Renamed from `action`, whose name invited the
  /// failure: it was live text at two sites, both at 3.60.
  static const Color focusRing = Color(0xFF1A8FCB);

  /// ⛔ ON-PRIMARY ONLY, 1.88 on white. One job: the SnackBar action label on
  /// the navy SnackBar, §13(s) row 11, which was 2.37.
  static const Color accentOnPrimary = Color(0xFF88C5E4);

  /// The app-bar subtitle, on `primary`. 5.11. Added 13 Sep 2026 by C2.
  ///
  /// ⛔ IT REPLACES TWO OPACITY FORMS OF THE SAME ELEMENT, one of which was a
  /// live failure. Ten app bars carry the same 10–11 px subtitle and they did
  /// not agree: seven used `Colors.white54`, which composites to `#90AEC6` =
  /// **3.6844** against 4.5, and three used `Colors.white70` at 5.1135. Same
  /// element, two values, one of them failing — and rule 1 forbids both,
  /// because a tone is a token and not a transparency.
  ///
  /// ⚠️ The value is the MEASURED composite of the passing form, `#B7CBDA`
  /// read off a render, not the computed blend `#B6CADA` (5.0653). Where the
  /// two disagree the render is the instrument and the arithmetic is the
  /// approximation.
  ///
  /// ⛔ NOT `accentOnPrimary`, which is also on-primary and also passes. That
  /// one is a SnackBar ACTION LABEL — a control. This is muted prose. Two
  /// roles that happen to share a ground are still two roles.
  static const Color onPrimaryMuted = Color(0xFFB7CBDA);

  // ── CAPTURE ────────────────────────────────────────────────────────────
  /// The `Record Event` fill, and nothing else. ⛔ Large-text sizes only —
  /// see rule 4. Was `alert`, which did six jobs.
  static const Color captureFill = Color(0xFFE05B3A);
  static const Color onCapture = Color(0xFFFFFFFF);

  // ── LINK ───────────────────────────────────────────────────────────────
  /// An action rendered as text. 4.81 · 4.51. New 13 Sep 2026: `focusRing`'s
  /// hue is not text-safe and two sites were using it as 14 px text.
  static const Color link = Color(0xFF1679AC);

  // ── STATUS ─────────────────────────────────────────────────────────────
  // ⛔ THE FOUR CONTAINERS ARE THE EXISTING TINTS AND ARE LOAD-BEARING. Every
  // `onContainer` was derived against them, and four clear 4.5 by less than
  // 0.04 — `caution` by 0.0037. A one-step change to a tint fails the test.
  // That is deliberate: the failures were never in the backgrounds, they were
  // in the foregrounds placed on them by hand at seven sites with no system.
  static const Color infoContainer   = Color(0xFFE3F2FD);
  static const Color infoOnContainer = Color(0xFF176EC4);
  static const Color infoAccent      = Color(0xFF1976D2);
  static const Color cautionContainer   = Color(0xFFFFF3E0);
  static const Color cautionOnContainer = Color(0xFFAF5900);
  static const Color cautionAccent      = Color(0xFFDC7000);
  static const Color positiveContainer   = Color(0xFFE8F5E9);
  static const Color positiveOnContainer = Color(0xFF317D35);
  static const Color positiveAccent      = Color(0xFF388E3C);
  static const Color criticalContainer   = Color(0xFFFFEBEE);
  static const Color criticalOnContainer = Color(0xFFCE2E2E);
  static const Color criticalAccent      = Color(0xFFD32F2F);

  // ── IDENTITY ───────────────────────────────────────────────────────────
  // ⛔ WHICH KIND OF EVENT A RECORD IS. Not status, and it must never borrow
  // one: mapping seizure to `critical` would have the app assert that a
  // seizure is an error state and that taking medication is a success. That
  // is the app editorialising about a medical record, which D2 forbids.
  //
  // ⭐ A colour per SEEDED type and one neutral pair for everything else.
  // Inventing an entry per user-defined type would either repeat colours or
  // drift from the four the app's identity is built on; neutral is the honest
  // rendering of "MER has no opinion about this one". Every value here was
  // already in the app and already correct — nothing was invented or moved.
  static const Color identitySeizureContainer = Color(0xFFFAECE7);
  static const Color identitySeizureOn        = Color(0xFF993C1D);
  static const Color identityAbsenceContainer = Color(0xFFEAF4FB);
  static const Color identityAbsenceOn        = Color(0xFF185FA5);

  /// ⭐ `on` was `success`, renamed not deleted. It never duplicated
  /// `positive.onContainer` — 6.21 against 5.10, different values. It is
  /// medication's badge foreground and always was.
  static const Color identityMedicationContainer = Color(0xFFEAF3DE);
  static const Color identityMedicationOn        = Color(0xFF3B6D11);
  static const Color identityOtherContainer = Color(0xFFF1EFE8);
  static const Color identityOtherOn        = Color(0xFF5F5E5A);

  // ── DESTRUCTIVE ────────────────────────────────────────────────────────
  /// 5.18 · 4.86. Shares the critical hue deliberately: one red family, one
  /// meaning. C2 decided FORM carries the distinction — destructive is the
  /// only outlined action in a dialog — so the shared hue does not collapse
  /// state and action.
  static const Color destructive = Color(0xFFCE2E2E);
}

class MERTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary:          MERColours.primary,
      secondary:        MERColours.focusRing,
      surface:          MERColours.surface,
      error:            MERColours.criticalOnContainer,
      onPrimary:        Colors.white,
      onSecondary:      Colors.white,
      onSurface:        MERColours.onSurface,
      surfaceContainer: MERColours.surfaceSunken,
      outline:          MERColours.outline,
    ),
    scaffoldBackgroundColor: MERColours.surfaceSunken,

    appBarTheme: const AppBarTheme(
      backgroundColor: MERColours.primary,
      foregroundColor: Colors.white,
      elevation:       0,
      centerTitle:     false,
      titleTextStyle:  TextStyle(
        fontSize:   16,
        fontWeight: FontWeight.w600,
        color:      Colors.white,
      ),
    ),

    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: MERColours.onSurface),
      titleLarge:   TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: MERColours.onSurface),
      titleMedium:  TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: MERColours.onSurface),
      titleSmall:   TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: MERColours.onSurface),
      bodyLarge:    TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: MERColours.onSurface),
      bodyMedium:   TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: MERColours.onSurfaceMuted),
      bodySmall:    TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: MERColours.onSurfaceMuted),
      labelLarge:   TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: MERColours.onSurfaceMuted, letterSpacing: 0.8),
    ),

    cardTheme: CardThemeData(
      color:     MERColours.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: MERColours.outline, width: 1.0),
      ),
      margin: const EdgeInsets.symmetric(vertical: 4),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: MERColours.primary,
        foregroundColor: Colors.white,
        elevation:       0,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontSize:   14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: MERColours.primary,
        foregroundColor: Colors.white,
        elevation:       0,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontSize:   14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: MERColours.primary,
        side: const BorderSide(color: MERColours.primary, width: 1),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        textStyle: const TextStyle(
          fontSize:   14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled:    true,
      fillColor: MERColours.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: MERColours.outline, width: 1.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: MERColours.outline, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: MERColours.focusRing, width: 1.5),
      ),
      labelStyle: const TextStyle(
        color:    MERColours.onSurfaceMuted,
        fontSize: 13,
      ),
      hintStyle: const TextStyle(
        color:    MERColours.onSurfaceMuted,
        fontSize: 13,
      ),
    ),

chipTheme: ChipThemeData(
      backgroundColor: MERColours.surface,
      selectedColor:   MERColours.primary,
      // ⚠️ THE COLOUR RESOLVES PER STATE, and it has to.
      //
      // `secondaryLabelStyle` is used by ChoiceChip and InputChip when
      // selected — but NOT by FilterChip, which uses `labelStyle` in every
      // state. So a selected FilterChip took `textPrimary` (dark) on
      // `selectedColor` (dark navy) and its label was INVISIBLE: the chip
      // rendered as a blank navy pill with a tick.
      //
      // Found on the tablet the moment a multi-select chip was first selected
      // in the wizard, which is the first time this app ever selected a
      // FilterChip. Every earlier selected chip was a ChoiceChip, which the
      // secondary style covers, so the defect had never been reachable.
      labelStyle: TextStyle(
        fontSize: 13,
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Colors.white
              : MERColours.onSurface,
        ),
      ),
      // Kept for ChoiceChip and InputChip, which do use it.
      secondaryLabelStyle: const TextStyle(
        fontSize:   13,
        fontWeight: FontWeight.w600,
        color:      Colors.white,
      ),
      side: const BorderSide(color: MERColours.outline, width: 1.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),

    dividerTheme: const DividerThemeData(
      color:     MERColours.outline,
      thickness: 1.0,
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor:  MERColours.primary,
      contentTextStyle: const TextStyle(color: Colors.white),
      actionTextColor:  MERColours.accentOnPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}