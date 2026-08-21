import 'package:flutter/material.dart';

import '../../../core/theme/theme_tokens.dart';
import '../../../widgets/mukking_card.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '채팅',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.more_horiz_rounded),
                tooltip: '신고/차단 메뉴',
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            children: [
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: tokens.secondary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '시스템 메시지 · 라멘 보스전 파티가 생성됐어요',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              MukkingCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('약속/파티 카드', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Text(
                      '멘야 하쿠 · 8/22 19:30 · 2/4명 · +120 XP',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _MessageBubble(
                text: '저는 7시 20분쯤 도착할 것 같아요!',
                isMine: false,
              ),
              _MessageBubble(
                text: '좋아요. 도착하면 입구에서 만나요.',
                isMine: true,
              ),
              _MessageBubble(
                text: '신고/차단 메뉴는 우측 상단 영역에 연결 예정입니다.',
                isMine: false,
                isSystemHint: true,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 18),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  enabled: false,
                  decoration: InputDecoration(
                    hintText: '메시지 입력은 추후 realtime 연결',
                    prefixIcon: Icon(Icons.lock_outline_rounded, color: tokens.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: null,
                child: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.text,
    required this.isMine,
    this.isSystemHint = false,
  });

  final String text;
  final bool isMine;
  final bool isSystemHint;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSystemHint
              ? tokens.warning.withValues(alpha: 0.14)
              : isMine
                  ? tokens.primary
                  : tokens.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isMine ? tokens.surface : tokens.textPrimary,
              ),
        ),
      ),
    );
  }
}
