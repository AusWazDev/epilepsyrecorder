import 'package:flutter/material.dart';

class MERColours {
  static const Color primary      = Color(0xFF0D4F82);
  static const Color action       = Color(0xFF1A8FCB);
  static const Color background   = Color(0xFFF5F8FB);
  static const Color surface      = Color(0xFFFFFFFF);
  static const Color alert        = Color(0xFFE05B3A);
  static const Color border       = Color(0xFFB5D4F4);
  static const Color textPrimary  = Color(0xFF0D4F82);
  static const Color textMuted    = Color(0xFF4A7FA5);
  static const Color success      = Color(0xFF3B6D11);
  static const Color warning      = Color(0xFFBA7517);
}

class MERTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.light(
      primary:          MERColours.primary,
      secondary:        MERColours.action,
      surface:          MERColours.surface,
      error:            MERColours.alert,
      onPrimary:        Colors.white,
      onSecondary:      Colors.white,
      onSurface:        MERColours.textPrimary,
      surfaceContainer: MERColours.background,
      outline:          MERColours.border,
    ),
    scaffoldBackgroundColor: MERColours.background,

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
      displayLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: MERColours.textPrimary),
      titleLarge:   TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: MERColours.textPrimary),
      titleMedium:  TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: MERColours.textPrimary),
      titleSmall:   TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: MERColours.textPrimary),
      bodyLarge:    TextStyle(fontSize: 15, fontWeight: FontWeight.w400, color: MERColours.textPrimary),
      bodyMedium:   TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: MERColours.textMuted),
      bodySmall:    TextStyle(fontSize: 11, fontWeight: FontWeight.w400, color: MERColours.textMuted),
      labelLarge:   TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: MERColours.textMuted, letterSpacing: 0.8),
    ),

    cardTheme: CardThemeData(
      color:     MERColours.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: MERColours.border, width: 0.5),
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
        borderSide: const BorderSide(color: MERColours.border, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: MERColours.border, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: MERColours.action, width: 1.5),
      ),
      labelStyle: const TextStyle(
        color:    MERColours.textMuted,
        fontSize: 13,
      ),
      hintStyle: const TextStyle(
        color:    MERColours.textMuted,
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
              : MERColours.textPrimary,
        ),
      ),
      // Kept for ChoiceChip and InputChip, which do use it.
      secondaryLabelStyle: const TextStyle(
        fontSize:   13,
        fontWeight: FontWeight.w600,
        color:      Colors.white,
      ),
      side: const BorderSide(color: MERColours.border, width: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),

    dividerTheme: const DividerThemeData(
      color:     MERColours.border,
      thickness: 0.5,
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor:  MERColours.primary,
      contentTextStyle: const TextStyle(color: Colors.white),
      actionTextColor:  MERColours.action,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}