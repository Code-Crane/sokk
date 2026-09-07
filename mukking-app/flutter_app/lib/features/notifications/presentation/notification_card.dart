import 'package:flutter/material.dart';

import '../../../core/theme/theme_tokens.dart';
import '../../../widgets/mukking_card.dart';
import '../domain/app_notification.dart';

class NotificationCard extends StatelessWidget {
  const NotificationCard({
    required this.notification,
    required this.onTap,
    super.key,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return MukkingCard(
      onTap: onTap,
      backgroundColor: tokens.favorite.withValues(
        alpha: notification.isRead ? 0.05 : 0.1,
      ),
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
              switch (notification.type) {
                'favorite_restaurant_party_created' => Icons.restaurant,
                'chat_message_created' => Icons.chat_bubble_outline,
                'join_request_received' => Icons.person_add_alt,
                'join_request_accepted' => Icons.check_circle_outline,
                'join_request_rejected' => Icons.info_outline,
                _ => Icons.notifications_none_rounded,
              },
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
                  notification.body,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                    '${notification.createdAt.toLocal().year}/${notification.createdAt.toLocal().month}/${notification.createdAt.toLocal().day} '
                    '${notification.createdAt.toLocal().hour.toString().padLeft(2, '0')}:${notification.createdAt.toLocal().minute.toString().padLeft(2, '0')} · '
                    '${notification.isRead ? "읽음" : "안 읽음"}',
                    style: Theme.of(context).textTheme.labelSmall),
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
