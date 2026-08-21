import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/theme/theme_tokens.dart';
import '../../../widgets/mukking_card.dart';

class CreatePartyScreen extends StatelessWidget {
  const CreatePartyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Text('파티 만들기', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          '첫 마일스톤에서는 CTA 위치와 흐름만 잡아둡니다.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        MukkingCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.add_task_rounded, color: tokens.primary, size: 36),
              const SizedBox(height: 14),
              Text(
                '식당 선택 → 일정 선택 → 모집 조건 입력',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '실제 작성 폼, 서버 저장, 알림은 다음 단계에서 연결합니다.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () => context.go(AppRoutes.discovery),
                child: const Text('식당 발견부터 시작하기'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
