import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../widgets/mukking_card.dart';
import '../../discovery/providers/discovery_provider.dart';

class CreatePartyScreen extends ConsumerWidget {
  const CreatePartyScreen({
    this.restaurantId,
    super.key,
  });

  final String? restaurantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final restaurant = restaurantId == null
        ? null
        : ref.watch(restaurantByIdProvider(restaurantId!));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Text('파티 만들기', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          restaurant == null
              ? '먹고 싶은 식당을 선택하거나 직접 파티 조건을 입력해요.'
              : '${restaurant.name}에서 열 파티 정보를 미리 채웠어요.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        if (restaurant != null)
          MukkingCard(
            backgroundColor: tokens.primary.withValues(alpha: 0.08),
            child: Row(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: tokens.rewardXp.withValues(alpha: 0.42),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    Icons.restaurant_menu_rounded,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        restaurant.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${restaurant.category} · ${restaurant.distanceLabel}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Text(
                        restaurant.address,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          MukkingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.explore_rounded, color: tokens.primary, size: 36),
                const SizedBox(height: 12),
                Text(
                  '식당부터 고르면 더 빠르게 만들 수 있어요',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Discovery 식당 Bottom Sheet에서 진입하면 식당 정보가 자동으로 채워집니다.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => context.go(AppRoutes.discovery),
                  icon: const Icon(Icons.map_rounded),
                  label: const Text('식당 발견으로 이동'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        MukkingCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mock form', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 14),
              TextFormField(
                initialValue:
                    restaurant == null ? '' : '${restaurant.name} 저녁 파티',
                decoration: const InputDecoration(labelText: '파티 제목'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: restaurant?.name ?? '',
                decoration: const InputDecoration(labelText: '식당'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: '8/24 19:30',
                decoration: const InputDecoration(labelText: '날짜/시간'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: '4명',
                decoration: const InputDecoration(labelText: '모집 인원'),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: tokens.background,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  '이번 단계에서는 실제 생성 API를 호출하지 않습니다. 입력 흐름과 prefill UX만 검증합니다.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: null,
                icon: const Icon(Icons.lock_outline_rounded),
                label: const Text('Mock 저장 - 다음 단계 연결'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
