import 'package:flutter/material.dart';

/// Yellow + soft-charcoal palette:
/// - Yellow — accents, primary filled actions, links, selected nav (~35%)
/// - Soft charcoal — alternate CTAs, strong text (~20%)
/// - White / warm light surfaces — backgrounds (~45%)
abstract final class VintagePalette {
  static const Color yellow = Color(0xFFFACC15);
  static const Color yellowLight = Color(0xFFFEF08A);
  static const Color yellowDark = Color(0xFFEAB308);
  static const Color yellowContainer = Color(0xFFFEF9C3);

  static const Color black = Color(0xFF2F2F2F);
  static const Color blackSoft = Color(0xFF3B3B3B);

  static const Color beige = Color(0xFFFFFBEB);
  static const Color cream = Color(0xFFFFFFFF);
  static const Color beigeDeep = Color(0xFFFEF3C7);

  static const Color brown = Color(0xFF1F2937);
  static const Color brownMuted = Color(0xFF6B7280);

  // Legacy names kept so existing imports keep working.
  static const Color blue = yellow;
  static const Color blueLight = yellowLight;
  static const Color blueDark = blackSoft;
  static const Color blueContainer = yellowContainer;
  static const Color orange = black;
  static const Color orangeLight = Color(0xFF5B5B5B);
  static const Color orangeDark = Color(0xFFCA8A04);
  static const Color orangeContainer = Color(0xFFFEF3C7);
}
