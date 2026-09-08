import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/theme_controller.dart';

/// Nocturne — the same design-system tokens used by the SIGRA FORCE
/// dashboard (dashboard-web/src/styles/tokens.css), ported to Flutter, with
/// two versions: "Nocturnal" (dark, the app's original look) and "Light".
/// Every field reads [ThemeController.instance] live, so existing call
/// sites like `NocturneColors.bg` automatically track whichever mode is
/// active — no screen needs to know the theme exists.
class NocturneColors {
  static bool get _dark => ThemeController.instance.isDark;

  static Color get bg => _dark ? const Color(0xFF161826) : const Color(0xFFF5F5FA);
  static Color get surface => _dark ? const Color(0xFF232532) : const Color(0xFFFFFFFF);
  static Color get text => _dark ? const Color(0xFFE9E9ED) : const Color(0xFF1B1B24);
  static Color get accent => _dark ? const Color(0xFF9184D9) : const Color(0xFF7A6BC4);
  static Color get accent2 => _dark ? const Color(0xFFA7A1DB) : const Color(0xFF6F63A8);
  static Color get divider => _dark ? const Color(0x29E9E9ED) : const Color(0x1F1B1B24);

  /// Tag-chip pair: `neutral800` is the chip background, `neutral100` its text.
  static Color get neutral100 => _dark ? const Color(0xFFF3F5FE) : const Color(0xFF33333D);
  static Color get neutral800 => _dark ? const Color(0xFF3F424D) : const Color(0xFFE4E4EA);
  static Color get neutral900 => _dark ? const Color(0xFF292B31) : const Color(0xFFECECF2);

  /// Same pairing as neutral100/800, for the accent-colored tag variant.
  static Color get accent100 => _dark ? const Color(0xFFF5F4FF) : const Color(0xFF4A3F87);
  static Color get accent800 => _dark ? const Color(0xFF423A6A) : const Color(0xFFE9E5FA);

  static Color get danger => _dark ? const Color(0xFFE08D84) : const Color(0xFFC23B30);
  static Color get dangerBorder => _dark ? const Color(0xFFB5483F) : const Color(0xFFE8B4AE);

  static Color textMuted(double opacity) => text.withValues(alpha: opacity);
}

class NocturneSpace {
  static const s1 = 3.0;
  static const s2 = 6.0;
  static const s3 = 8.0;
  static const s4 = 11.0;
  static const s6 = 17.0;
  static const s8 = 22.0;
}

class NocturneRadius {
  static const sm = 4.0;
  static const md = 8.0;
  static const lg = 14.0;
}

ThemeData buildNocturneTheme() {
  final dark = ThemeController.instance.isDark;
  final base = dark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
  final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
    bodyColor: NocturneColors.text,
    displayColor: NocturneColors.text,
  );

  return base.copyWith(
    scaffoldBackgroundColor: NocturneColors.bg,
    primaryColor: NocturneColors.accent,
    colorScheme: base.colorScheme.copyWith(
      brightness: dark ? Brightness.dark : Brightness.light,
      surface: NocturneColors.bg,
      primary: NocturneColors.accent,
      secondary: NocturneColors.accent2,
      error: NocturneColors.danger,
    ),
    textTheme: textTheme,
    dividerColor: NocturneColors.divider,
    cardColor: NocturneColors.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: NocturneColors.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      foregroundColor: NocturneColors.text,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: NocturneColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(NocturneRadius.md),
        borderSide: BorderSide(color: NocturneColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(NocturneRadius.md),
        borderSide: BorderSide(color: NocturneColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(NocturneRadius.md),
        borderSide: BorderSide(color: NocturneColors.accent, width: 1.4),
      ),
      hintStyle: TextStyle(color: NocturneColors.textMuted(0.4)),
      labelStyle: TextStyle(color: NocturneColors.textMuted(0.7), fontSize: 12),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: NocturneColors.accent,
        disabledForegroundColor: NocturneColors.textMuted(0.4),
        elevation: 0,
        side: BorderSide(color: NocturneColors.accent),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NocturneRadius.md)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: NocturneColors.text,
        side: BorderSide(color: NocturneColors.divider),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NocturneRadius.md)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: NocturneColors.accent,
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 14),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: NocturneColors.bg,
      selectedItemColor: NocturneColors.accent,
      unselectedItemColor: NocturneColors.textMuted(0.35),
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: NocturneColors.accent),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: NocturneColors.surface,
      contentTextStyle: TextStyle(color: NocturneColors.text),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(NocturneRadius.md)),
    ),
  );
}
