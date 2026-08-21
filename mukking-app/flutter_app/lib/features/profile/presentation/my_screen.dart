import 'package:flutter/material.dart';

import '../../../core/theme/theme_tokens.dart';
import '../../../widgets/mukking_card.dart';
import '../../../widgets/xp_progress_bar.dart';
import '../../settings/presentation/theme_selector.dart';

class MyScreen extends StatelessWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Text('MY', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 16),
        MukkingCard(
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
                    Text('먹킹러 태훈', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      'Lv. 7 · 미식 탐험가 · 인증 대기',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 10),
                    const XpProgressBar(currentXp: 840, targetXp: 1000),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        MukkingCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('활동 요약', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              _ProfileMetric(label: '참여 이력', value: '12회'),
              _ProfileMetric(label: '평가', value: '4.8 / 5.0'),
              _ProfileMetric(label: '인증 상태', value: '휴대폰 인증 예정'),
              _ProfileMetric(label: '먹킹 등급', value: 'Silver Spoon'),
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
