import 'package:flutter/material.dart';

/// Home-scoped v2 theme. Other screen themes and saved presets are unchanged.
abstract final class DiningTokens {
  static const primary = Color(0xFFE8643A);
  static const background = Color(0xFFF7F3EC);
  static const surface = Color(0xFFFFFDF9);
  static const text = Color(0xFF292622);
  static const secondary = Color(0xFF756F68);
  static const border = Color(0xFFE8E0D6);
  static const success = Color(0xFF2F8F62);
  static const warning = Color(0xFFD39A2F);
  static const error = Color(0xFFC94C4C);
  // Reference-specific accents; existing Pet screen palette stays unchanged.
  static const homeBackground = Color(0xFFFFFDF9);
  static const homePrimary = Color(0xFFFF683E);
  static const mint = Color(0xFF55BFA0);
  static const mintSurface = Color(0xFFE8F5ED);
  static const peachSurface = Color(0xFFFFF0EA);
  static const homeText = Color(0xFF242B36);
  static const homeSecondary = Color(0xFF737E8C);

  static ThemeData theme(ThemeData base) => base.copyWith(
        colorScheme: base.colorScheme.copyWith(
            primary: primary, surface: surface, onSurface: text, error: error),
        textTheme:
            base.textTheme.apply(bodyColor: text, displayColor: text).copyWith(
                  displaySmall: const TextStyle(
                      color: text, fontSize: 32, fontWeight: FontWeight.w800),
                  headlineSmall: const TextStyle(
                      color: text, fontSize: 26, fontWeight: FontWeight.w800),
                  titleLarge: const TextStyle(
                      color: text, fontSize: 22, fontWeight: FontWeight.w700),
                  titleMedium: const TextStyle(
                      color: text, fontSize: 18, fontWeight: FontWeight.w700),
                  bodyLarge: const TextStyle(
                      color: text,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 1.45),
                  bodyMedium: const TextStyle(
                      color: text,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.45),
                  bodySmall: const TextStyle(
                      color: secondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500),
                  labelSmall: const TextStyle(
                      color: secondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
        textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
                foregroundColor: text, minimumSize: const Size(44, 44))),
        filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: surface,
                minimumSize: const Size(44, 52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)))),
      );
}
