import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_spacing.dart';

/// HTH Design System — Theme Configuration
/// Full Material 3 ThemeData for light and dark modes.
class AppTheme {
  AppTheme._();

  // ─── Light Theme ──────────────────────────────────────
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: const ColorScheme.light(
          primary: AppColors.primaryBlue,
          onPrimary: Colors.white,
          primaryContainer: Color(0xFFDBE4FF),
          onPrimaryContainer: AppColors.primaryNavy,
          secondary: AppColors.accentTeal,
          onSecondary: Colors.white,
          secondaryContainer: Color(0xFFC3FAE8),
          onSecondaryContainer: Color(0xFF004D40),
          surface: AppColors.surfaceLight,
          onSurface: AppColors.textPrimaryLight,
          onSurfaceVariant: AppColors.textSecondaryLight,
          outline: AppColors.borderLight,
          outlineVariant: AppColors.dividerLight,
          error: AppColors.error,
          onError: Colors.white,
        ),
        scaffoldBackgroundColor: AppColors.surfaceLight,
        textTheme: _buildTextTheme(Brightness.light),
        cardTheme: CardThemeData(
          color: AppColors.surfaceCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            side: const BorderSide(color: AppColors.borderLight, width: 1),
          ),
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            minimumSize: const Size(double.infinity, AppSpacing.buttonHeightMd),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            textStyle: AppTypography.buttonText,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryBlue,
            side: const BorderSide(color: AppColors.primaryBlue),
            minimumSize: const Size(double.infinity, AppSpacing.buttonHeightMd),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            textStyle: AppTypography.buttonText,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primaryBlue,
            textStyle: AppTypography.buttonText,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceWhite,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: const BorderSide(color: AppColors.borderLight),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: const BorderSide(color: AppColors.borderLight),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide:
                const BorderSide(color: AppColors.primaryBlue, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          hintStyle: AppTypography.bodyMedium
              .copyWith(color: AppColors.textTertiaryLight),
          labelStyle: AppTypography.bodyMedium
              .copyWith(color: AppColors.textSecondaryLight),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surfaceElevated,
          selectedColor: AppColors.primaryBlue.withValues(alpha: 0.15),
          labelStyle: AppTypography.labelMedium,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surfaceWhite,
          selectedItemColor: AppColors.primaryBlue,
          unselectedItemColor: AppColors.textTertiaryLight,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.dividerLight,
          space: 1,
          thickness: 1,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.surfaceWhite,
          foregroundColor: AppColors.textPrimaryLight,
          elevation: 0,
          scrolledUnderElevation: 1,
          centerTitle: true,
          titleTextStyle:
              AppTypography.titleLarge.copyWith(color: AppColors.textPrimaryLight),
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
      );

  // ─── Dark Theme ───────────────────────────────────────
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accentTeal,
          onPrimary: AppColors.primaryNavy,
          primaryContainer: Color(0xFF1B3A4B),
          onPrimaryContainer: AppColors.accentCyan,
          secondary: AppColors.accentMint,
          onSecondary: AppColors.primaryNavy,
          secondaryContainer: Color(0xFF1B3A2E),
          onSecondaryContainer: AppColors.accentMint,
          surface: AppColors.surfaceDark,
          onSurface: AppColors.textPrimaryDark,
          onSurfaceVariant: AppColors.textSecondaryDark,
          outline: AppColors.borderDark,
          outlineVariant: AppColors.dividerDark,
          error: AppColors.error,
          onError: AppColors.primaryNavy,
        ),
        scaffoldBackgroundColor: AppColors.surfaceDark,
        textTheme: _buildTextTheme(Brightness.dark),
        cardTheme: CardThemeData(
          color: AppColors.surfaceDarkCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            side: const BorderSide(color: AppColors.borderDark, width: 1),
          ),
          margin: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accentTeal,
            foregroundColor: AppColors.primaryNavy,
            elevation: 0,
            minimumSize: const Size(double.infinity, AppSpacing.buttonHeightMd),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            textStyle: AppTypography.buttonText,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.accentTeal,
            side: const BorderSide(color: AppColors.accentTeal),
            minimumSize: const Size(double.infinity, AppSpacing.buttonHeightMd),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            textStyle: AppTypography.buttonText,
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accentTeal,
            textStyle: AppTypography.buttonText,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceDarkCard,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.lg,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: const BorderSide(color: AppColors.borderDark),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: const BorderSide(color: AppColors.borderDark),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide:
                const BorderSide(color: AppColors.accentTeal, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            borderSide: const BorderSide(color: AppColors.error),
          ),
          hintStyle: AppTypography.bodyMedium
              .copyWith(color: AppColors.textTertiaryDark),
          labelStyle: AppTypography.bodyMedium
              .copyWith(color: AppColors.textSecondaryDark),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.surfaceDarkElevated,
          selectedColor: AppColors.accentTeal.withValues(alpha: 0.2),
          labelStyle: AppTypography.labelMedium
              .copyWith(color: AppColors.textPrimaryDark),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          ),
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.surfaceDarkCard,
          selectedItemColor: AppColors.accentTeal,
          unselectedItemColor: AppColors.textTertiaryDark,
          type: BottomNavigationBarType.fixed,
          elevation: 8,
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.dividerDark,
          space: 1,
          thickness: 1,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: AppColors.surfaceDark,
          foregroundColor: AppColors.textPrimaryDark,
          elevation: 0,
          scrolledUnderElevation: 1,
          centerTitle: true,
          titleTextStyle:
              AppTypography.titleLarge.copyWith(color: AppColors.textPrimaryDark),
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
      );

  // ─── Text Theme Builder ───────────────────────────────
  static TextTheme _buildTextTheme(Brightness brightness) {
    final color = brightness == Brightness.light
        ? AppColors.textPrimaryLight
        : AppColors.textPrimaryDark;

    return TextTheme(
      displayLarge: AppTypography.displayLarge.copyWith(color: color),
      displayMedium: AppTypography.displayMedium.copyWith(color: color),
      displaySmall: AppTypography.displaySmall.copyWith(color: color),
      headlineLarge: AppTypography.headlineLarge.copyWith(color: color),
      headlineMedium: AppTypography.headlineMedium.copyWith(color: color),
      headlineSmall: AppTypography.headlineSmall.copyWith(color: color),
      titleLarge: AppTypography.titleLarge.copyWith(color: color),
      titleMedium: AppTypography.titleMedium.copyWith(color: color),
      titleSmall: AppTypography.titleSmall.copyWith(color: color),
      bodyLarge: AppTypography.bodyLarge.copyWith(color: color),
      bodyMedium: AppTypography.bodyMedium.copyWith(color: color),
      bodySmall: AppTypography.bodySmall.copyWith(color: color),
      labelLarge: AppTypography.labelLarge.copyWith(color: color),
      labelMedium: AppTypography.labelMedium.copyWith(color: color),
      labelSmall: AppTypography.labelSmall.copyWith(color: color),
    );
  }
}
