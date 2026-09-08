import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_routes.dart';
import '../../../widgets/mukking_card.dart';
import '../domain/pet.dart';
import '../providers/pet_provider.dart';
import 'pet_widgets.dart';

class PetScreen extends ConsumerStatefulWidget {
  const PetScreen({super.key});
  @override
  ConsumerState<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends ConsumerState<PetScreen> {
  bool _confirming = false;
  Future<void> _choose(PetType type) async {
    if (_confirming || ref.read(selectPetProvider).isLoading) return;
    setState(() => _confirming = true);
    final userAtOpen = ref.read(petRepositoryProvider);
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text('${type.label}와 함께할까요?'),
                content: const Text('선택 후에는 펫 종류를 바꿀 수 없어요.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('취소')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('함께하기')),
                ]));
    if (!mounted) return;
    setState(() => _confirming = false);
    if (confirmed == true &&
        identical(userAtOpen, ref.read(petRepositoryProvider))) {
      await ref.read(selectPetProvider.notifier).select(type);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pet = ref.watch(myPetProvider);
    final selection = ref.watch(selectPetProvider);
    return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(padding: const EdgeInsets.all(20), children: [
              Row(children: [
                BackButton(
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go(AppRoutes.my)),
                Expanded(
                    child: Text('내 먹킹 펫',
                        style: Theme.of(context).textTheme.headlineSmall)),
                IconButton(
                    tooltip: '펫 정보 새로고침',
                    onPressed: () => ref.invalidate(myPetProvider),
                    icon: const Icon(Icons.refresh)),
              ]),
              const SizedBox(height: 16),
              pet.when(
                  skipLoadingOnReload: false,
                  skipLoadingOnRefresh: false,
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, __) => MukkingCard(
                          child: Column(children: [
                        const Text('펫 정보를 불러오지 못했어요. 잠시 후 다시 시도해주세요.'),
                        TextButton(
                            onPressed: () => ref.invalidate(myPetProvider),
                            child: const Text('다시 시도')),
                      ])),
                  data: (pet) {
                    if (pet != null) {
                      return MukkingCard(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                            PetImage(
                                type: pet.type,
                                stage: pet.growthStage,
                                size: 240),
                            Text(pet.displayName,
                                textAlign: TextAlign.center,
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 16),
                            PetProgress(pet),
                            const SizedBox(height: 12),
                            Text('총 ${pet.xp} XP'),
                            Text('다음 성장: ${pet.nextGrowthLabel}'),
                            const SizedBox(height: 20),
                            const Text(
                                '모임 완료와 모임당 최초 매너 평가로 XP를 받아요.'),
                            const SizedBox(height: 8),
                            const Text('펫을 선택한 이후 완료된 활동부터 함께 성장해요.'),
                          ]));
                    }
                    return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('함께할 식탁 친구를 선택해주세요.'),
                          const Text('한 계정에 한 친구 · 선택 후 종류 변경은 지원하지 않아요.'),
                          if (selection.isLoading)
                            const LinearProgressIndicator(),
                          if (selection.hasError)
                            const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Text(
                                    '펫 선택을 완료하지 못했어요. 정보를 확인한 뒤 다시 시도해주세요.')),
                          for (final type in PetType.values)
                            Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: MukkingCard(
                                    child: Column(children: [
                                  PetImage(type: type, size: 160),
                                  Text(type.label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge),
                                  Text(type.description,
                                      textAlign: TextAlign.center),
                                  FilledButton(
                                      onPressed:
                                          selection.isLoading || _confirming
                                              ? null
                                              : () => _choose(type),
                                      child: Text('${type.label} 선택')),
                                ]))),
                        ]);
                  }),
            ])));
  }
}
