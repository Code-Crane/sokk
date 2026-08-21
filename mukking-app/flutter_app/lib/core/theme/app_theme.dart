import 'package:flutter/material.dart';

import 'app_theme_presets.dart';
import 'theme_tokens.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData build(MukkingThemeId id) {
    final tokens = AppThemePresets.byId(id).tokens;
    final colorScheme = ColorScheme.light(
      primary: tokens.primary,
      secondary: tokens.secondary,
      tertiary: tokens.accent,
      surface: tokens.surface,
      error: tokens.danger,
      onPrimary: tokens.surface,
      onSecondary: tokens.textPrimary,
      onTertiary: tokens.textPrimary,
      onSurface: tokens.textPrimary,
      onError: tokens.surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.background,
      fontFamily: 'Roboto',
      extensions: <ThemeExtension<dynamic>>[
        tokens,
      ],
      textTheme: TextTheme(
        displaySmall: TextStyle(
          color: tokens.textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.w800,
        ),
        headlineSmall: TextStyle(
          color: tokens.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w800,
        ),
        titleLarge: TextStyle(
          color: tokens.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        titleMedium: TextStyle(
          color: tokens.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          color: tokens.textPrimary,
          fontSize: 16,
          height: 1.45,
        ),
        bodyMedium: TextStyle(
          color: tokens.textSecondary,
          fontSize: 14,
          height: 1.45,
        ),
        labelLarge: TextStyle(
          color: tokens.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.background,
        foregroundColor: tokens.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: tokens.primary,
          foregroundColor: tokens.surface,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.primary,
          side: BorderSide(color: tokens.primary),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surface,
        hintStyle: TextStyle(color: tokens.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tokens.surface,
        indicatorColor: tokens.secondary.withValues(alpha: 0.22),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return TextStyle(
            color: isSelected ? tokens.primary : tokens.textSecondary,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: isSelected ? tokens.primary : tokens.textSecondary,
          );
        }),
      ),
    );
  }
}
