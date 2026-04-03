import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Shared radii for a consistent, modern rounded look.
abstract final class AppRadius {
  static const double xs = 10;
  static const double sm = 14;
  static const double md = 18;
  static const double lg = 22;
  static const double xl = 28;
}

/// Surfaces & shadows using the yellow + black + warm neutral system.
abstract final class AppDecorations {
  /// Full-screen wash — mostly beige (~40%), subtle variation.
  static BoxDecoration pageBackground() => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            VintagePalette.beige,
            VintagePalette.cream,
            VintagePalette.beigeDeep,
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      );

  /// Login / welcome panels — cream card, brown-tinted shadow, blue glow hint.
  static BoxDecoration heroCard(Color accentBlue) => BoxDecoration(
        color: VintagePalette.cream,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: VintagePalette.brown.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: accentBlue.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: VintagePalette.brown.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      );

  /// List rows — cream, blue edge accent.
  static BoxDecoration listCard(Color accentBlue, {bool archived = false}) {
    return BoxDecoration(
      color: VintagePalette.cream,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(
        color: archived
            ? VintagePalette.brown.withValues(alpha: 0.12)
            : accentBlue.withValues(alpha: 0.22),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: accentBlue.withValues(alpha: 0.07),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
        BoxShadow(
          color: VintagePalette.brown.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    );
  }

  static BoxDecoration splashLogoCard(Color blue) => BoxDecoration(
        color: VintagePalette.cream,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: VintagePalette.brown.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: blue.withValues(alpha: 0.22),
            blurRadius: 40,
            spreadRadius: 0,
            offset: const Offset(0, 14),
          ),
          BoxShadow(
            color: VintagePalette.brown.withValues(alpha: 0.07),
            blurRadius: 22,
            offset: const Offset(0, 6),
          ),
        ],
      );

  static BoxDecoration settingsSection(Color accentBlue) => BoxDecoration(
        color: VintagePalette.cream,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: VintagePalette.brown.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: accentBlue.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      );
}
