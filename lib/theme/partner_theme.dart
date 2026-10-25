import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Palette sampled from `assets/images/logo.png` (KaamFast Partner K mark).
class PartnerColors {
  static const primary = Color(0xFF011431);
  static const primaryDeep = Color(0xFF001030);
  static const accent = Color(0xFF7AC42B);
  static const accentSoft = Color(0xFFE4F6C8);
  static const lavender = Color(0xFFC8E88A);
  static const bg = Color(0xFFF7F9F4);
  static const ink = Color(0xFF191C1D);
  static const muted = Color(0xFF454652);
  static const softMuted = Color(0xFF767683);
  static const line = Color(0xFFE1E3E4);
  static const chip = Color(0xFFEDEEEF);
  static const success = Color(0xFF10B981);
  static const danger = Color(0xFFBA1A1A);
  static const dangerSoft = Color(0xFFFFDAD6);
  static const navySoft = Color(0xFF0E2C52);
}

class PartnerTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: PartnerColors.bg,
      colorScheme: const ColorScheme.light(
        primary: PartnerColors.primary,
        secondary: PartnerColors.accent,
        surface: Colors.white,
        onPrimary: Colors.white,
        onSurface: PartnerColors.ink,
        error: PartnerColors.danger,
      ),
    );

    final body = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: PartnerColors.ink,
      displayColor: PartnerColors.ink,
    );
    final headline = GoogleFonts.hankenGroteskTextTheme(body);

    return base.copyWith(
      textTheme: body.copyWith(
        displayLarge: headline.displayLarge?.copyWith(fontWeight: FontWeight.w800),
        displayMedium: headline.displayMedium?.copyWith(fontWeight: FontWeight.w800),
        displaySmall: headline.displaySmall?.copyWith(fontWeight: FontWeight.w800),
        headlineLarge: headline.headlineLarge?.copyWith(fontWeight: FontWeight.w800),
        headlineMedium: headline.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        headlineSmall: headline.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        titleLarge: headline.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: headline.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: PartnerColors.bg.withValues(alpha: 0.92),
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: PartnerColors.ink,
        titleTextStyle: GoogleFonts.hankenGrotesk(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: PartnerColors.ink,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: PartnerColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PartnerColors.primary,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: PartnerColors.line),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: PartnerColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: PartnerColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: PartnerColors.accent, width: 1.5),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: PartnerColors.primary,
        unselectedItemColor: PartnerColors.softMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
