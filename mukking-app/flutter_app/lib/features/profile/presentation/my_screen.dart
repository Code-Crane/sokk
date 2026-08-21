import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../widgets/mukking_card.dart';
import '../../../widgets/xp_progress_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../discovery/providers/discovery_provider.dart';
import '../../settings/presentation/theme_selector.dart';
import '../providers/profile_provider.dart';

class MyScreen extends ConsumerWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final favoriteRestaurants = ref.watch(favoriteRestaurantsProvider);
    final profile = ref.watch(profileSummaryProvider);
    final auth = ref.watch(authControllerProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Text('MY', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        profile.when(
          data: (summary) => MukkingCard(
            child: Row(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: tokens.accent,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Icon(
                    Icons.person_rounded,
                    color: tokens.textPrimary,
                    size: 38,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(summary.user.nickname,
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        'Lv. 7 · ${summary.user.mannerGrade.label} · ${summary.verification?.label ?? summary.user.verificationStatus.label}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (auth.message != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          auth.message!,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: tokens.warning,
                                  ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      const XpProgressBar(currentXp: 840, targetXp: 1000),
                    ],
                  ),
                ),
              ],
            ),
          ),
          loading: () => const MukkingCard(
            child: Text('프로필을 불러오는 중이에요.'),
          ),
          error: (error, _) => _ProfileErrorCard(error: error),
        ),
        const SizedBox(height: 16),
        profile.when(
          data: (summary) => MukkingCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('활동 요약', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                _ProfileMetric(label: '참여 이력', value: 'API 연결 예정'),
                _ProfileMetric(
                  label: '평가',
                  value: summary.user.mannerScore == 0
                      ? '확인 필요'
                      : summary.user.mannerScore.toStringAsFixed(1),
                ),
                _ProfileMetric(
                  label: '인증 상태',
                  value: summary.verification?.label ??
                      summary.user.verificationStatus.label,
                ),
                _ProfileMetric(
                  label: '먹킹 등급',
                  value: summary.user.mannerGrade.label,
                ),
                _ProfileMetric(
                  label: '대기 평가',
                  value: '${summary.pendingEvaluationCount}건',
                ),
              ],
            ),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),
        MukkingCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('찜한 맛집', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              if (favoriteRestaurants.isEmpty)
                Text(
                  '아직 찜한 맛집이 없어요. 발견 탭에서 가고 싶어요를 눌러보세요.',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else
                for (final restaurant in favoriteRestaurants)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.favorite_rounded,
                            color: tokens.favorite, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${restaurant.name} · ${restaurant.category}',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                        Text(
                          '${restaurant.activePartyCount}개',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: tokens.primary,
                                  ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const ThemeSelector(),
        const SizedBox(height: 16),
        MukkingCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('설정', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              Text(
                '알림, 차단 목록, 개인정보 설정은 다음 단계에서 연결합니다.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileErrorCard extends StatelessWidget {
  const _ProfileErrorCard({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    final message =
        error is ApiError ? (error as ApiError).userMessage : '프로필을 불러오지 못했어요.';

    return MukkingCard(
      child: Text(message, style: Theme.of(context).textTheme.bodyMedium),
    );
  }
}

class _ProfileMetric extends StatelessWidget {
  const _ProfileMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ],
      ),
    );
  }
}
