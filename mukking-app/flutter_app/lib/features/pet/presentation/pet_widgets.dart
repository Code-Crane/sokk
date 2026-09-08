import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_routes.dart';
import '../../../widgets/mukking_card.dart';
import '../domain/pet.dart';
import '../providers/pet_provider.dart';

class PetImage extends StatelessWidget {
  const PetImage(
      {required this.type, this.stage = '꼬마', this.size = 120, super.key});
  final PetType type;
  final String stage;
  final double size;
  @override
  Widget build(BuildContext context) => Image.asset(type.assetForStage(stage),
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: type.label);
}

class PetProgress extends StatelessWidget {
  const PetProgress(this.pet, {super.key});
  final Pet pet;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Lv. ${pet.level} · ${pet.growthStage}'),
        const SizedBox(height: 8),
        LinearProgressIndicator(
            value: pet.progress,
            semanticsLabel: '펫 성장',
          semanticsValue: '${(pet.progress * 100).round()}'),
        const SizedBox(height: 8),
        Text(pet.progressLabel),
      ]);
}

class MyPetCard extends ConsumerWidget {
  const MyPetCard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MukkingCard(
        child: ref.watch(myPetProvider).when(
              skipLoadingOnReload: false,
              skipLoadingOnRefresh: false,
              loading: () => const Text('내 펫을 불러오는 중이에요.'),
              error: (_, __) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('펫 정보를 불러오지 못했어요.'),
                    TextButton(
                        onPressed: () => ref.invalidate(myPetProvider),
                        child: const Text('다시 시도')),
                  ]),
              data: (pet) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('내 먹킹 펫',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    if (pet == null) ...[
                      const Text('함께 자랄 식탁 친구를 만나보세요.'),
                      FilledButton(
                          onPressed: () => context.push(AppRoutes.pet),
                          child: const Text('펫 선택하기')),
                    ] else ...[
                      Row(children: [
                        PetImage(
                            type: pet.type, stage: pet.growthStage, size: 88),
                        const SizedBox(width: 12),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(pet.displayName,
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              PetProgress(pet),
                            ])),
                      ]),
                      TextButton(
                          onPressed: () => context.push(AppRoutes.pet),
                          child: const Text('내 펫 자세히 보기')),
                    ],
                  ]),
            ));
  }
}
