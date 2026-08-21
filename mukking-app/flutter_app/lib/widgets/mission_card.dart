import 'package:flutter/material.dart';

import '../core/theme/theme_tokens.dart';
import 'mukking_card.dart';

class MissionCard extends StatelessWidget {
  const MissionCard({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return MukkingCard(
      backgroundColor: tokens.primary.withValues(alpha: 0.08),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: tokens.accent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.flag_rounded,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘의 미션',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  '관심 식당 1곳 저장하고 파티 후보를 열어보세요.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '+40 XP',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: tokens.primary,
                ),
          ),
        ],
      ),
    );
  }
}
