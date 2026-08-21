import 'package:flutter/material.dart';

enum MukkingThemeId {
  violet,
  coral,
  mint;

  String get label {
    switch (this) {
      case MukkingThemeId.violet:
        return 'Violet';
      case MukkingThemeId.coral:
        return 'Coral';
      case MukkingThemeId.mint:
        return 'Mint';
    }
  }

  static MukkingThemeId fromValue(String? value) {
    return MukkingThemeId.values.firstWhere(
      (themeId) => themeId.name == value,
      orElse: () => MukkingThemeId.violet,
    );
  }
}

class MukkingThemeTokens extends ThemeExtension<MukkingThemeTokens> {
  const MukkingThemeTokens({
    required this.primary,
    required this.secondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final Color primary;
  final Color secondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color success;
  final Color warning;
  final Color danger;

  @override
  MukkingThemeTokens copyWith({
    Color? primary,
    Color? secondary,
    Color? accent,
    Color? background,
    Color? surface,
    Color? textPrimary,
    Color? textSecondary,
    Color? success,
    Color? warning,
    Color? danger,
  }) {
    return MukkingThemeTokens(
      primary: primary ?? this.primary,
      secondary: secondary ?? this.secondary,
      accent: accent ?? this.accent,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
    );
  }

  @override
  MukkingThemeTokens lerp(
    ThemeExtension<MukkingThemeTokens>? other,
    double t,
  ) {
    if (other is! MukkingThemeTokens) {
      return this;
    }

    return MukkingThemeTokens(
      primary: Color.lerp(primary, other.primary, t)!,
      secondary: Color.lerp(secondary, other.secondary, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

extension MukkingThemeContext on BuildContext {
  MukkingThemeTokens get tokens {
    return Theme.of(this).extension<MukkingThemeTokens>()!;
  }
}
