import 'package:flutter/material.dart';

class CIPTheme {
  CIPTheme._();

  // ─── Brand Colors ───────────────────────────────────────────────────────────
  static const Color saudiNavy = Color(0xFF1B4F8A);
  static const Color saudiGold = Color(0xFFC8A84B);
  static const Color saudiGoldLight = Color(0xFFE8C86B);

  // ─── Semantic Colors ────────────────────────────────────────────────────────
  static const Color legalGreen = Color(0xFF2ECC71);
  static const Color legalGreenBg = Color(0xFFE8FAF0);
  static const Color warningAmber = Color(0xFFF39C12);
  static const Color warningAmberBg = Color(0xFFFEF9E7);
  static const Color violationRed = Color(0xFFE74C3C);
  static const Color violationRedBg = Color(0xFFFDECEB);

  // ─── Mode Colors ────────────────────────────────────────────────────────────
  static const Color moneyGreen = Color(0xFF27AE60);
  static const Color restBlue = Color(0xFF2980B9);
  static const Color balancedPurple = Color(0xFF8E44AD);

  // ─── Neutrals ───────────────────────────────────────────────────────────────
  static const Color grey50 = Color(0xFFF8F9FA);
  static const Color grey100 = Color(0xFFF1F3F5);
  static const Color grey200 = Color(0xFFE9ECEF);
  static const Color grey300 = Color(0xFFDEE2E6);
  static const Color grey500 = Color(0xFFADB5BD);
  static const Color grey700 = Color(0xFF495057);
  static const Color grey900 = Color(0xFF212529);

  // ─── Dark Mode Surfaces ─────────────────────────────────────────────────────
  static const Color darkBg = Color(0xFF0F1923);
  static const Color darkSurface = Color(0xFF1A2740);
  static const Color darkCard = Color(0xFF1E2E44);
  static const Color darkBorder = Color(0xFF2A3F5F);

  // ─── Typography ─────────────────────────────────────────────────────────────
  
  static const String fontLatin = 'Inter';
  static const String fontArabic = 'Inter';

  static const Color primary = saudiNavy;
  static const Color surface = grey50;
  static const Color card = Colors.white;
  static const Color success = legalGreen;
  static const Color error = violationRed;
  static const Color warning = warningAmber;
  static const Color info = restBlue;
  static const Color textPrimary = grey900;
  static const Color textSecondary = grey700;
  static const Color textMuted = grey500;
  static const Color navLight = grey100;
  static const Color divider = grey200;

  static TextTheme _buildTextTheme(Color bodyColor, Color displayColor, String fontFamily) {
    return TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: displayColor, fontFamily: fontFamily),
      displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: displayColor, fontFamily: fontFamily),
      displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: displayColor, fontFamily: fontFamily),
      headlineLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: displayColor, fontFamily: fontFamily),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: displayColor, fontFamily: fontFamily),
      headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: displayColor, fontFamily: fontFamily),
      titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: displayColor, fontFamily: fontFamily),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: bodyColor, fontFamily: fontFamily),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: bodyColor, fontFamily: fontFamily),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: bodyColor, fontFamily: fontFamily),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: bodyColor, fontFamily: fontFamily),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: bodyColor, fontFamily: fontFamily),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: bodyColor, fontFamily: fontFamily),
      labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: bodyColor, fontFamily: fontFamily),
      labelSmall: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: bodyColor, fontFamily: fontFamily),
    );
  }

  // ─── Light Theme ────────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: saudiNavy,
        primary: saudiNavy,
        secondary: saudiGold,
        surface: Colors.white,
        background: grey50,
        error: violationRed,
      ),
      textTheme: _buildTextTheme(grey900, grey900, fontArabic),
      scaffoldBackgroundColor: grey50,
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: grey900,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: grey900,
          fontFamily: fontLatin,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: grey100,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: saudiNavy, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: violationRed, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: saudiNavy,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, fontFamily: fontLatin),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: saudiNavy,
          side: const BorderSide(color: saudiNavy, width: 1.5),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: grey100,
        selectedColor: saudiNavy.withOpacity(0.1),
        labelStyle: const TextStyle(fontSize: 13, fontFamily: fontLatin),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: saudiNavy,
        unselectedItemColor: grey500,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(color: grey200, thickness: 1, space: 1),
      extensions: const [CIPColors.light],
    );
  }

  // ─── Dark Theme ─────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: saudiNavy,
        brightness: Brightness.dark,
        primary: saudiGoldLight,
        secondary: saudiGold,
        surface: darkSurface,
        background: darkBg,
        error: violationRed,
      ),
      textTheme: _buildTextTheme(Colors.white, Colors.white, fontArabic),
      scaffoldBackgroundColor: darkBg,
      cardTheme: CardTheme(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
        color: darkCard,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      extensions: const [CIPColors.dark],
    );
  }
}

// ─── Custom Theme Extension ──────────────────────────────────────────────────
class CIPColors extends ThemeExtension<CIPColors> {
  final Color domesticLeg;
  final Color internationalLeg;
  final Color layoverLeg;
  final Color restGap;
  final Color cardBorder;
  final Color shimmerBase;
  final Color shimmerHighlight;

  const CIPColors({
    required this.domesticLeg,
    required this.internationalLeg,
    required this.layoverLeg,
    required this.restGap,
    required this.cardBorder,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });

  static const light = CIPColors(
    domesticLeg: Color(0xFF3498DB),
    internationalLeg: Color(0xFF2ECC71),
    layoverLeg: Color(0xFFF39C12),
    restGap: Color(0xFFE9ECEF),
    cardBorder: Color(0xFFE9ECEF),
    shimmerBase: Color(0xFFF1F3F5),
    shimmerHighlight: Color(0xFFFFFFFF),
  );

  static const dark = CIPColors(
    domesticLeg: Color(0xFF2980B9),
    internationalLeg: Color(0xFF27AE60),
    layoverLeg: Color(0xFFE67E22),
    restGap: Color(0xFF2A3F5F),
    cardBorder: Color(0xFF2A3F5F),
    shimmerBase: Color(0xFF1E2E44),
    shimmerHighlight: Color(0xFF2A3F5F),
  );

  @override
  CIPColors copyWith({
    Color? domesticLeg, Color? internationalLeg, Color? layoverLeg,
    Color? restGap, Color? cardBorder, Color? shimmerBase, Color? shimmerHighlight,
  }) => CIPColors(
    domesticLeg: domesticLeg ?? this.domesticLeg,
    internationalLeg: internationalLeg ?? this.internationalLeg,
    layoverLeg: layoverLeg ?? this.layoverLeg,
    restGap: restGap ?? this.restGap,
    cardBorder: cardBorder ?? this.cardBorder,
    shimmerBase: shimmerBase ?? this.shimmerBase,
    shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
  );

  @override
  CIPColors lerp(ThemeExtension<CIPColors>? other, double t) {
    if (other is! CIPColors) return this;
    return CIPColors(
      domesticLeg: Color.lerp(domesticLeg, other.domesticLeg, t)!,
      internationalLeg: Color.lerp(internationalLeg, other.internationalLeg, t)!,
      layoverLeg: Color.lerp(layoverLeg, other.layoverLeg, t)!,
      restGap: Color.lerp(restGap, other.restGap, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight: Color.lerp(shimmerHighlight, other.shimmerHighlight, t)!,
    );
  }
}
