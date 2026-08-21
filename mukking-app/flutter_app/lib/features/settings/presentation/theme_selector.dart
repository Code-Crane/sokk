import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme_presets.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../widgets/mukking_card.dart';

class ThemeSelector extends ConsumerWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final selectedThemeId = ref.watch(themeControllerProvider);

    return MukkingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('내 먹킹 테마', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            '색상 preset만 바꾸고 화면 구조와 로직은 그대로 유지합니다.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final preset in AppThemePresets.all)
                ChoiceChip(
                  selected: selectedThemeId == preset.id,
                  label: Text(preset.label),
                  avatar: CircleAvatar(
                    backgroundColor: preset.tokens.primary,
                    radius: 8,
                  ),
                  selectedColor: tokens.primary.withValues(alpha: 0.14),
                  backgroundColor: tokens.surface,
                  side: BorderSide(
                    color: selectedThemeId == preset.id
                        ? tokens.primary
                        : tokens.secondary.withValues(alpha: 0.22),
                  ),
                  labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selectedThemeId == preset.id
                            ? tokens.primary
                            : tokens.textPrimary,
                      ),
                  onSelected: (_) {
                    ref
                        .read(themeControllerProvider.notifier)
                        .setTheme(preset.id);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}
