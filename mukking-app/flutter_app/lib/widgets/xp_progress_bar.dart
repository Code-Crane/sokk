import 'package:flutter/material.dart';

import '../core/theme/theme_tokens.dart';

class XpProgressBar extends StatelessWidget {
  const XpProgressBar({
    required this.currentXp,
    required this.targetXp,
    super.key,
  });

  final int currentXp;
  final int targetXp;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final progress = (currentXp / targetXp).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 10,
            value: progress,
            color: tokens.accent,
            backgroundColor: tokens.secondary.withValues(alpha: 0.18),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$currentXp / $targetXp XP',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}
