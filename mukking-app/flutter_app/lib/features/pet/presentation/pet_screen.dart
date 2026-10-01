import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/brand_assets.dart';
import '../../discovery/presentation/discovery_visuals.dart';
import '../providers/pet_provider.dart';
import 'pet_widgets.dart';

class PetScreen extends ConsumerStatefulWidget {
  const PetScreen({super.key});
  @override
  ConsumerState<PetScreen> createState() => _PetScreenState();
}

class _PetScreenState extends ConsumerState<PetScreen> {
  @override
  Widget build(BuildContext context) {
    return DiscoveryTheme(
        child: Builder(
            builder: (context) => ColoredBox(
                color: MukkingBrand.background, child: _content(context))));
  }

  Widget _content(BuildContext context) {
    final pet = ref.watch(myPetProvider);
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
                  error: (_, __) => _PetSurface(
                          child: Column(children: [
                        const Text('펫 정보를 불러오지 못했어요. 잠시 후 다시 시도해주세요.'),
                        TextButton(
                            onPressed: () => ref.invalidate(myPetProvider),
                            child: const Text('다시 시도')),
                      ])),
                  data: (pet) {
                    if (pet != null) {
                      return _PetSurface(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                            PetImage(
                                type: pet.type,
                                stage: pet.growthStage,
                                size: 240),
                            Text('먹킹',
                                textAlign: TextAlign.center,
                                style:
                                    Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 16),
                            PetProgress(pet),
                            const SizedBox(height: 12),
                            Text('총 ${pet.xp} XP'),
                            Text('다음 성장: ${pet.nextGrowthLabel}'),
                            const SizedBox(height: 20),
                            const Text('모임 완료와 모임당 최초 매너 평가로 XP를 받아요.'),
                            const SizedBox(height: 8),
                            const Text('펫을 선택한 이후 완료된 활동부터 함께 성장해요.'),
                          ]));
                    }
                    return const _PetSurface(
                        child: Column(children: [
                      MukkingMascot(size: 160),
                      SizedBox(height: 16),
                      Text('먹킹과 함께할 준비 중이에요.'),
                      SizedBox(height: 8),
                      Text('캐릭터 선택 기능을 정비하고 있어요. 기존 성장 데이터는 그대로 유지됩니다.',
                          textAlign: TextAlign.center),
                    ]));
                  }),
            ])));
  }
}

class _PetSurface extends StatelessWidget {
  const _PetSurface({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: MukkingBrand.surface,
          border: Border.all(color: MukkingBrand.border),
          borderRadius: BorderRadius.circular(18)),
      child: child);
}
