import 'package:flutter/material.dart';

abstract final class ZirconColors {
  static const Color canvas = Color(0xFF05070A);
  static const Color panel = Color(0xE611151B);
  static const Color panelStrong = Color(0xF20B0E13);
  static const Color panelSoft = Color(0xB3141A21);
  static const Color stroke = Color(0xFF303A45);
  static const Color strokeSoft = Color(0x99303A45);
  static const Color text = Color(0xFFF3F6F8);
  static const Color textMuted = Color(0xFF96A3AE);
  static const Color textDim = Color(0xFF65717C);
  static const Color accent = Color(0xFF3DD6CF);
  static const Color accentSoft = Color(0x263DD6CF);
  static const Color record = Color(0xFFFF4454);
  static const Color recordDark = Color(0xFF9B1725);
  static const Color warning = Color(0xFFFFB648);
  static const Color good = Color(0xFF73D68B);
  static const Color blue = Color(0xFF68A7FF);
  static const Color settingsBlue = Color(0xFF2D9BF0);
}

abstract final class ZirconSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
}

abstract final class ZirconRadius {
  static const double sm = 6;
  static const double md = 10;
  static const double lg = 16;
  static const double pill = 999;
}

ThemeData buildZirconTheme() {
  const TextTheme textTheme = TextTheme(
    displaySmall: TextStyle(
      color: ZirconColors.text,
      fontSize: 30,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.5,
      height: 1,
      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
    ),
    headlineSmall: TextStyle(
      color: ZirconColors.text,
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.1,
    ),
    titleMedium: TextStyle(
      color: ZirconColors.text,
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: .2,
    ),
    bodyMedium: TextStyle(
      color: ZirconColors.text,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
    bodySmall: TextStyle(
      color: ZirconColors.textMuted,
      fontSize: 11,
      fontWeight: FontWeight.w500,
    ),
    labelSmall: TextStyle(
      color: ZirconColors.textMuted,
      fontSize: 9,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
    ),
  );

  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: ZirconColors.canvas,
    colorScheme: const ColorScheme.dark(
      primary: ZirconColors.accent,
      secondary: ZirconColors.blue,
      surface: ZirconColors.panel,
      error: ZirconColors.record,
    ),
    fontFamily: 'Inter',
    textTheme: textTheme,
    splashFactory: InkSparkle.splashFactory,
    visualDensity: VisualDensity.compact,
  );
}
