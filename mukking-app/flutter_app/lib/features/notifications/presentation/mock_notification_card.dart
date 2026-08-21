import 'package:flutter/material.dart';

import '../../../core/theme/theme_tokens.dart';
import '../../../widgets/mukking_card.dart';
import '../domain/mock_notification.dart';

class MockNotificationCard extends StatelessWidget {
  const MockNotificationCard({
    required this.notification,
    required this.onTap,
    super.key,
  });

  final MockNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return MukkingCard(
      onTap: onTap,
      backgroundColor: tokens.favorite.withValues(alpha: 0.1),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: tokens.favorite.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              Icons.notifications_active_rounded,
              color: tokens.favorite,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  notification.message,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: tokens.favorite),
        ],
      ),
    );
  }
}
