import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Calm, friendly light theme for the "get help" flow.
/// One brand colour, a soft accent per section, rounded 20px cards,
/// big tap targets (>= 48px) and text that scales with system font size.
class AppColors {
  AppColors._();
  static const brand = Color(0xFF2F5BEA);
  static const brandDark = Color(0xFF1E3FB0);
  static const bg = Color(0xFFF6F7FB);
  static const card = Colors.white;
  static const ink = Color(0xFF17213A);
  static const muted = Color(0xFF5B6478);
  static const line = Color(0xFFE3E7F0);

  // Section accents
  static const shopping = Color(0xFF2F5BEA);
  static const shoppingSoft = Color(0xFFE8EEFF);
  static const travel = Color(0xFF0E8F86);
  static const travelSoft = Color(0xFFE1F5F2);

  // Status
  static const good = Color(0xFF1E8E4E);
  static const goodSoft = Color(0xFFE5F5EC);
  static const warn = Color(0xFFB86E00);
  static const warnSoft = Color(0xFFFFF3DD);
  static const urgent = Color(0xFFC62828);
  static const urgentSoft = Color(0xFFFDECEC);

  static Color accent(String? section) =>
      section == 'travel' ? travel : shopping;
  static Color accentSoft(String? section) =>
      section == 'travel' ? travelSoft : shoppingSoft;
}

class AppTheme {
  AppTheme._();
  static const radius = 20.0;

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brand,
        brightness: Brightness.light,
        surface: AppColors.bg,
      ),
      scaffoldBackgroundColor: AppColors.bg,
    );
    final text = GoogleFonts.plusJakartaSansTextTheme(base.textTheme).apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    );
    return base.copyWith(
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800, height: 1.2),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        bodyLarge: text.bodyLarge?.copyWith(fontSize: 17, height: 1.45),
        bodyMedium: text.bodyMedium?.copyWith(fontSize: 15, height: 1.45),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: AppColors.bg,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.ink),
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 52),
          foregroundColor: AppColors.ink,
          side: const BorderSide(color: AppColors.line, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 48),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(18),
        hintStyle: GoogleFonts.plusJakartaSans(color: AppColors.muted, fontSize: 17),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.line, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.line, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.brand, width: 2),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: const BorderSide(color: AppColors.line),
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      }),
    );
  }

  /// New-flow screens are pushed with this so they get the light theme,
  /// while the old triage screens keep their dark MaterialApp theme.
  static Route<T> route<T>(Widget page) => MaterialPageRoute<T>(
        builder: (_) => Theme(data: light, child: page),
      );

  /// True when the user asked the system to reduce motion.
  static bool reduceMotion(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}
