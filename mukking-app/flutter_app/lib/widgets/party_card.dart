import 'package:flutter/material.dart';

import '../core/theme/theme_tokens.dart';
import '../features/matching/domain/party.dart';
import 'mukking_card.dart';

class PartyCard extends StatelessWidget {
  const PartyCard({
    required this.party,
    this.onTap,
    super.key,
  });

  final Party party;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return MukkingCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 152,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              gradient: LinearGradient(
                colors: [
                  tokens.secondary.withValues(alpha: 0.9),
                  tokens.primary.withValues(alpha: 0.82),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  left: 18,
                  bottom: 18,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        party.imageLabel,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: tokens.surface,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        party.restaurantName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: tokens.surface.withValues(alpha: 0.86),
                            ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 18,
                  top: 18,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '+${party.rewardXp} XP',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  party.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _PartyMetaChip(
                      icon: Icons.people_alt_rounded,
                      label: party.participantLabel,
                    ),
                    _PartyMetaChip(
                      icon: Icons.schedule_rounded,
                      label: party.scheduledLabel,
                    ),
                    _PartyMetaChip(
                      icon: Icons.near_me_rounded,
                      label: party.distanceLabel,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PartyMetaChip extends StatelessWidget {
  const _PartyMetaChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: tokens.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: tokens.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: tokens.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
