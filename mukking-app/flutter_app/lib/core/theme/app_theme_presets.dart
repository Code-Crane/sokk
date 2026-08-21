import 'package:flutter/material.dart';

import 'theme_tokens.dart';

class MukkingThemePreset {
  const MukkingThemePreset({
    required this.id,
    required this.tokens,
  });

  final MukkingThemeId id;
  final MukkingThemeTokens tokens;

  String get label => id.label;
}

class AppThemePresets {
  const AppThemePresets._();

  static const violet = MukkingThemePreset(
    id: MukkingThemeId.violet,
    tokens: MukkingThemeTokens(
      primary: Color(0xFF5B3DF5),
      secondary: Color(0xFFB39DFF),
      accent: Color(0xFFFFD75E),
      background: Color(0xFFFFF8EC),
      surface: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF22252E),
      textSecondary: Color(0xFF69707D),
      success: Color(0xFF21B573),
      warning: Color(0xFFFFA726),
      danger: Color(0xFFE54D42),
    ),
  );

  static const coral = MukkingThemePreset(
    id: MukkingThemeId.coral,
    tokens: MukkingThemeTokens(
      primary: Color(0xFFFF6B4A),
      secondary: Color(0xFF1F9D8B),
      accent: Color(0xFFFFD7C8),
      background: Color(0xFFFFF3E6),
      surface: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF22313A),
      textSecondary: Color(0xFF68747A),
      success: Color(0xFF1F9D8B),
      warning: Color(0xFFFFB547),
      danger: Color(0xFFD94F45),
    ),
  );

  static const mint = MukkingThemePreset(
    id: MukkingThemeId.mint,
    tokens: MukkingThemeTokens(
      primary: Color(0xFF2FE3C3),
      secondary: Color(0xFF49C7F5),
      accent: Color(0xFFC8F15A),
      background: Color(0xFFF5F8F7),
      surface: Color(0xFFFFFFFF),
      textPrimary: Color(0xFF10182B),
      textSecondary: Color(0xFF64707E),
      success: Color(0xFF22B573),
      warning: Color(0xFFF6A400),
      danger: Color(0xFFE5484D),
    ),
  );

  static const presets = <MukkingThemeId, MukkingThemePreset>{
    MukkingThemeId.violet: violet,
    MukkingThemeId.coral: coral,
    MukkingThemeId.mint: mint,
  };

  static const all = <MukkingThemePreset>[
    violet,
    coral,
    mint,
  ];

  static MukkingThemePreset byId(MukkingThemeId id) {
    return presets[id] ?? violet;
  }
}
