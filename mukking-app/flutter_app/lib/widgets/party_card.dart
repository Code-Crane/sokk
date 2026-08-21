import 'package:flutter/material.dart';

import '../core/theme/theme_tokens.dart';
import '../features/discovery/domain/restaurant.dart';
import '../features/matching/domain/matching_party.dart';
import 'mukking_card.dart';

class PartyCard extends StatelessWidget {
  const PartyCard({
    required this.party,
    required this.restaurant,
    this.compact = false,
    this.showJoinCta = true,
    this.onTap,
    this.onJoinTap,
    super.key,
  });

  final MatchingParty party;
  final Restaurant restaurant;
  final bool compact;
  final bool showJoinCta;
  final VoidCallback? onTap;
  final VoidCallback? onJoinTap;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return MukkingCard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FoodHero(
            party: party,
            restaurant: restaurant,
            height: compact ? 122 : 164,
          ),
          Padding(
            padding: EdgeInsets.all(compact ? 14 : 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            restaurant.name,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: tokens.primary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            party.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ],
                      ),
                    ),
                    _StatusPill(status: party.status),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _PartyMetaChip(
                      icon: Icons.people_alt_rounded,
                      label: party.memberLabel,
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    _RewardChip(
                      label: '+${party.rewardXp} XP',
                      color: tokens.rewardXp,
                    ),
                    const SizedBox(width: 8),
                    _RewardChip(
                      label: '+${party.rewardPoints}P',
                      color: tokens.rewardPoint,
                    ),
                    const Spacer(),
                    if (showJoinCta)
                      FilledButton(
                        onPressed: onJoinTap ?? onTap,
                        child: const Text('바로 참여'),
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

class _FoodHero extends StatelessWidget {
  const _FoodHero({
    required this.party,
    required this.restaurant,
    required this.height,
  });

  final MatchingParty party;
  final Restaurant restaurant;
  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(28),
        ),
        gradient: LinearGradient(
          colors: [
            tokens.secondary.withValues(alpha: 0.92),
            tokens.primary.withValues(alpha: 0.82),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -18,
            bottom: -18,
            child: Icon(
              Icons.restaurant_rounded,
              color: tokens.surface.withValues(alpha: 0.16),
              size: 132,
            ),
          ),
          Positioned(
            left: 18,
            bottom: 18,
            right: 18,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  restaurant.imageLabel,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: tokens.surface,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${restaurant.category} · ${restaurant.distanceLabel}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: tokens.surface.withValues(alpha: 0.86),
                      ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 16,
            top: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: party.isUrgent ? tokens.partyUrgent : tokens.rewardXp,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                party.isUrgent ? '마감 임박' : '+${party.rewardXp} XP',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color:
                          party.isUrgent ? tokens.surface : tokens.textPrimary,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final MatchingPartyStatus status;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final color = switch (status) {
      MatchingPartyStatus.hot => tokens.partyHot,
      MatchingPartyStatus.urgent => tokens.partyUrgent,
      MatchingPartyStatus.full => tokens.textSecondary,
      MatchingPartyStatus.open => tokens.success,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color),
      ),
    );
  }
}

class _RewardChip extends StatelessWidget {
  const _RewardChip({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge,
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
