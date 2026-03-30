import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Тема дизайну CLIX
/// Акцент: глибокий фіолетовий/індиго (#5E48E8)
/// Базова: світла тема з темною картою

class CLIXTheme {
  // ── Кольори ──
  static const Color primary = Color(0xFF5E48E8);
  static const Color primaryLight = Color(0xFF8B7CF6);
  static const Color primaryDark = Color(0xFF4338CA);
  static const Color accent = Color(0xFF7C3AED);
  static const Color surface = Color(0xFFF4F4F8);
  static const Color background = Colors.white;
  static const Color card = Colors.white;
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF59E0B);

  // Кольори для ролі водія (темна тема)
  static const Color driverBg = Color(0xFF0F0A2A);
  static const Color driverCard = Color(0xFF1A1145);
  static const Color driverSurface = Color(0xFF241B5E);

  // ── Заокруглення ──
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;
  static const double radiusFull = 100.0;

  // ── Відступи (spacing tokens) ──
  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 24.0;
  static const double spaceXl = 32.0;
  static const double pageHPad = 24.0; // горизонтальний padding сторінки

  // ── Світла тема (Пасажир / Логін) ──
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.light(
        primary: primary,
        secondary: accent,
        surface: surface,
        error: error,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme)
          .copyWith(
            headlineLarge: GoogleFonts.inter(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: textPrimary,
              letterSpacing: -0.5,
            ),
            headlineMedium: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: textPrimary,
              letterSpacing: -0.3,
            ),
            titleLarge: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
            titleMedium: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
            bodyLarge: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: textPrimary,
            ),
            bodyMedium: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: textSecondary,
            ),
            labelLarge: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radiusMd),
              ),
              textStyle: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              elevation: 0,
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered)) {
                  return Colors.white.withValues(alpha: 0.12);
                }
                if (states.contains(WidgetState.pressed)) {
                  return Colors.white.withValues(alpha: 0.2);
                }
                return null;
              }),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(radiusMd),
                ),
              ),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              foregroundColor: primary,
              minimumSize: const Size(double.infinity, 54),
              side: const BorderSide(color: primary, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radiusMd),
              ),
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered)) {
                  return primary.withValues(alpha: 0.08);
                }
                if (states.contains(WidgetState.pressed)) {
                  return primary.withValues(alpha: 0.16);
                }
                return null;
              }),
            ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spaceMd,
          vertical: spaceMd,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        hintStyle: GoogleFonts.inter(color: textHint, fontSize: 14),
        labelStyle: GoogleFonts.inter(color: textSecondary, fontSize: 14),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: divider, width: 1),
        ),
        margin: const EdgeInsets.only(bottom: spaceSm),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: spaceMd, vertical: spaceXs),
        minLeadingWidth: 20,
      ),
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: spaceXl,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: background,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
    );
  }

  // ── Темна тема (Водій) ──
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: driverBg,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: primaryLight,
        surface: driverCard,
        error: error,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
              backgroundColor: primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radiusMd),
              ),
              elevation: 0,
            ).copyWith(
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.hovered)) {
                  return Colors.white.withValues(alpha: 0.12);
                }
                if (states.contains(WidgetState.pressed)) {
                  return Colors.white.withValues(alpha: 0.2);
                }
                return null;
              }),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(radiusMd),
                ),
              ),
            ),
      ),
      cardTheme: CardThemeData(
        color: driverCard,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
        margin: const EdgeInsets.only(bottom: spaceSm),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: spaceMd, vertical: spaceXs),
        minLeadingWidth: 20,
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.1),
        thickness: 1,
        space: spaceXl,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: driverCard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: driverCard,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
    );
  }
}

