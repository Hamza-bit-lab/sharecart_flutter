import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_decorations.dart';
import 'app_palette.dart';

/// App-facing aliases (maps to [VintagePalette]).
class AppColors {
  AppColors._();

  /// Yellow — accents, default filled buttons, links, chips tint.
  static const Color primary = VintagePalette.yellow;
  static const Color primaryLight = VintagePalette.yellowLight;
  static const Color primaryDark = VintagePalette.yellowDark;

  /// Text / icons on yellow (e.g. default FilledButton).
  static const Color onPrimary = VintagePalette.black;

  /// Soft charcoal — alternate filled CTAs (Join, Send, etc. when overridden).
  static const Color cta = VintagePalette.black;

  /// Text / icons on charcoal CTA buttons.
  static const Color onCta = Colors.white;

  static const Color surface = VintagePalette.beige;
  static const Color surfaceVariant = VintagePalette.beigeDeep;
  static const Color cardBg = VintagePalette.cream;

  static const Color onSurface = VintagePalette.brown;
  static const Color onSurfaceVariant = VintagePalette.brownMuted;

  static const Color success = Color(0xFF2D6A4F);
  static const Color error = Color(0xFFC94C4C);
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: VintagePalette.yellowContainer,
      onPrimaryContainer: VintagePalette.black,
      secondary: AppColors.cta,
      onSecondary: AppColors.onCta,
      secondaryContainer: VintagePalette.orangeContainer,
      onSecondaryContainer: VintagePalette.black,
      tertiary: VintagePalette.brownMuted,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      surfaceContainerHighest: AppColors.surfaceVariant,
      error: AppColors.error,
      onError: Colors.white,
      outline: VintagePalette.black.withValues(alpha: 0.18),
      outlineVariant: VintagePalette.black.withValues(alpha: 0.10),
    );

    final baseText = ThemeData.light().textTheme;
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(baseText).copyWith(
      displaySmall: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
        height: 1.2,
        color: AppColors.onSurface,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.35,
        height: 1.25,
        color: AppColors.onSurface,
      ),
      headlineSmall: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
        height: 1.3,
        color: AppColors.onSurface,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: AppColors.onSurface,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w600,
        color: AppColors.onSurface,
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: AppColors.onSurface,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        height: 1.4,
        color: AppColors.onSurface,
      ),
      bodySmall: GoogleFonts.plusJakartaSans(
        color: AppColors.onSurfaceVariant,
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _SharedAxisPageTransitionsBuilder(),
          TargetPlatform.iOS: _SharedAxisPageTransitionsBuilder(),
          TargetPlatform.macOS: _SharedAxisPageTransitionsBuilder(),
          TargetPlatform.windows: _SharedAxisPageTransitionsBuilder(),
          TargetPlatform.linux: _SharedAxisPageTransitionsBuilder(),
        },
      ),
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: AppColors.cardBg,
        foregroundColor: AppColors.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          color: AppColors.onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: AppColors.onSurface, size: 22),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: BorderSide(color: VintagePalette.black.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: TextStyle(color: AppColors.onSurfaceVariant, fontSize: 15),
      ),
      // Default filled = yellow surface, black label (primary actions).
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          animationDuration: const Duration(milliseconds: 180),
          elevation: 0,
          shadowColor: AppColors.primary.withValues(alpha: 0.35),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 16,
            letterSpacing: 0.15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          animationDuration: const Duration(milliseconds: 180),
          foregroundColor: AppColors.onSurface,
          side: BorderSide(color: VintagePalette.black.withValues(alpha: 0.85), width: 2),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          animationDuration: const Duration(milliseconds: 160),
          foregroundColor: AppColors.primaryDark,
          textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 4,
        backgroundColor: VintagePalette.blackSoft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        contentTextStyle: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.cardBg,
        selectedItemColor: AppColors.primaryDark,
        unselectedItemColor: AppColors.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: VintagePalette.yellowContainer,
        deleteIconColor: VintagePalette.yellowDark,
        labelStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: VintagePalette.black,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xs)),
        side: BorderSide.none,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      dividerTheme: DividerThemeData(
        color: VintagePalette.black.withValues(alpha: 0.12),
        thickness: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurface,
        ),
      ),
    );
  }
}

class _SharedAxisPageTransitionsBuilder extends PageTransitionsBuilder {
  const _SharedAxisPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (route.settings.name == '/') return child;

    final eased = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    return FadeTransition(
      opacity: Tween<double>(begin: 0.92, end: 1).animate(eased),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.03, 0),
          end: Offset.zero,
        ).animate(eased),
        child: child,
      ),
    );
  }
}
