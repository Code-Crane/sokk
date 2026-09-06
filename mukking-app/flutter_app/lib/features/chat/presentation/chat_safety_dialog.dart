import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../data/chat_safety_repository.dart';
import '../domain/chat_message.dart';
import '../domain/chat_room.dart';

Future<bool?> showChatSafetyDialog(
  BuildContext context, {
  required ChatRoom room,
  required String currentUserId,
  ChatMessage? message,
}) =>
    showDialog<bool>(
        context: context,
        builder: (_) => _SafetyDialog(
            room: room, currentUserId: currentUserId, message: message));

class _SafetyDialog extends ConsumerStatefulWidget {
  const _SafetyDialog(
      {required this.room, required this.currentUserId, this.message});
  final ChatRoom room;
  final String currentUserId;
  final ChatMessage? message;
  @override
  ConsumerState<_SafetyDialog> createState() => _SafetyDialogState();
}

class _SafetyDialogState extends ConsumerState<_SafetyDialog> {
  final _description = TextEditingController();
  String? _target;
  String _reason = 'inappropriate_chat';
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    final others = widget.room.participantIds
        .where((id) => id != widget.currentUserId)
        .toList();
    _target =
        widget.message?.senderId ?? (others.length == 1 ? others.single : null);
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool block}) async {
    if (_busy || _target == null) return;
    final unblock = block &&
        (ref.read(chatBlockedUsersProvider).valueOrNull?.contains(_target) ??
            false);
    setState(() => _busy = true);
    if (block) {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: Text(unblock ? '차단을 해제할까요?' : '참여자를 차단할까요?'),
                content: Text(unblock
                    ? '이 사용자에게 설정한 차단을 해제해요. 상대방의 차단이나 다른 이용 제한은 유지돼요.'
                    : '이 사용자를 차단하면 모임 참여 신청과 새 메시지 등 상호작용이 제한됩니다. 기존 대화와 신고 기능은 유지돼요.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: Text(unblock ? '해제 확인' : '차단 확인'))
                ],
              ));
      if (!mounted) return;
      if (confirmed != true) {
        setState(() => _busy = false);
        return;
      }
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final repository = ref.read(chatSafetyRepositoryProvider);
      if (block) {
        if (unblock) {
          await repository.unblock(_target!);
        } else {
          await repository.block(_target!, roomId: widget.room.id);
        }
      } else {
        await repository.report(
            roomId: widget.room.id,
            userId: _target!,
            reason: _reason,
            description: _description.text,
            messageId: widget.message?.id);
      }
      if (!mounted) return;
      if (block) ref.invalidate(chatBlockedUsersProvider);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(unblock
              ? '내 차단을 해제했어요.'
              : block
                  ? '참여자를 차단했어요.'
                  : '신고가 접수됐어요. 차단은 별도로 선택할 수 있어요.')));
      Navigator.pop(context, unblock);
    } catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error is ApiError
              ? error.userMessage
              : '요청을 완료하지 못했어요. 다시 시도해주세요.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final blocks = ref.watch(chatBlockedUsersProvider);
    final isBlocked = blocks.valueOrNull?.contains(_target) ?? false;
    final others = widget.room.participantIds
        .where((id) => id != widget.currentUserId)
        .toList();
    return PopScope(
        canPop: !_busy,
        child: AlertDialog(
          title: Text(widget.message == null ? '신고 / 차단' : '메시지 신고'),
          content: SizedBox(
              width: 360,
              child: SingleChildScrollView(
                  child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.message != null)
                    Text(widget.message!.text,
                        maxLines: 3, overflow: TextOverflow.ellipsis),
                  if (widget.message == null)
                    DropdownButtonFormField<String>(
                        initialValue: _target,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: '대상 참여자'),
                        items: [
                          for (final id in others)
                            DropdownMenuItem(
                                value: id,
                                child: Text(others.length == 1
                                    ? '참여자'
                                    : '참여자 · ${id.substring(0, id.length < 8 ? id.length : 8)}'))
                        ],
                        onChanged: _busy
                            ? null
                            : (value) => setState(() => _target = value)),
                  DropdownButtonFormField<String>(
                      initialValue: _reason,
                      decoration: const InputDecoration(labelText: '신고 사유'),
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(
                            value: 'inappropriate_chat',
                            child: Text('부적절한 대화')),
                        DropdownMenuItem(
                            value: 'safety_risk', child: Text('안전 위협')),
                        DropdownMenuItem(value: 'spam', child: Text('스팸')),
                        DropdownMenuItem(value: 'other', child: Text('기타')),
                      ],
                      onChanged: _busy
                          ? null
                          : (value) => setState(() => _reason = value!)),
                  TextField(
                      controller: _description,
                      enabled: !_busy,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: '설명 (선택)')),
                  if (_error != null) Text(_error!),
                ],
              ))),
          actions: [
            TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text('닫기')),
            if (widget.message == null)
              TextButton(
                  onPressed: _busy ||
                          _target == null ||
                          blocks.isLoading ||
                          blocks.hasError
                      ? null
                      : () => _submit(block: true),
                  child: Text(isBlocked ? '차단 해제' : '차단하기')),
            FilledButton(
                onPressed: _busy || _target == null
                    ? null
                    : () => _submit(block: false),
                child: Text(_busy ? '처리 중…' : '신고 제출')),
          ],
        ));
  }
}
