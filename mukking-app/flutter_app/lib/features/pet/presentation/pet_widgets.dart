import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/theme/brand_assets.dart';
import '../domain/pet.dart';
import '../providers/pet_provider.dart';

class PetImage extends StatelessWidget {
  const PetImage(
      {required this.type,
      this.stage = '꼬마',
      this.size = 120,
      this.mood = PetMood.happy,
      this.mascotAsset = BrandAssets.defaultMascot,
      super.key});
  final PetType type;
  final String stage;
  final double size;
  final PetMood mood;
  final String mascotAsset;
  @override
  Widget build(BuildContext context) => Image.asset(mascotAsset,
      width: size, height: size, fit: BoxFit.contain, semanticLabel: '먹킹');
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
  const MyPetCard({this.embedded = false, super.key});
  final bool embedded;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
        padding: embedded ? EdgeInsets.zero : const EdgeInsets.all(16),
        decoration: embedded
            ? null
            : BoxDecoration(
                color: MukkingBrand.mint,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: MukkingBrand.border),
              ),
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
                    if (!embedded)
                      Row(children: [
                        const Icon(Icons.eco_rounded,
                            size: 20, color: MukkingBrand.green),
                        const SizedBox(width: 7),
                        Expanded(
                            child: Text('내 먹킹',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800))),
                      ]),
                    if (!embedded) const SizedBox(height: 12),
                    if (pet == null) ...[
                      const Text('먹킹과 함께하는 성장 기능을 준비하고 있어요.'),
                      FilledButton(
                          onPressed: () => context.push(AppRoutes.pet),
                          child: const Text('먹킹 보러가기')),
                    ] else ...[
                      if (embedded)
                        Row(children: [
                          Expanded(
                              child: Text('총 ${pet.xp} XP',
                                  style:
                                      Theme.of(context).textTheme.bodySmall)),
                          TextButton(
                              onPressed: () => context.push(AppRoutes.pet),
                              child: const Text('펫 보러가기')),
                        ])
                      else
                        Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              PetImage(
                                  mascotAsset: BrandAssets.heart,
                                  type: pet.type,
                                  stage: pet.growthStage,
                                  size: 88),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text('먹킹',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium),
                                    Text(
                                        'Lv. ${pet.level} · ${pet.growthStage}'),
                                    Text('총 ${pet.xp} XP'),
                                  ])),
                            ]),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                          value: pet.progress,
                          color: MukkingBrand.green,
                          backgroundColor: MukkingBrand.surface,
                          minHeight: 7,
                          borderRadius: BorderRadius.circular(8),
                          semanticsLabel: '펫 성장',
                          semanticsValue: '${(pet.progress * 100).round()}%'),
                      const SizedBox(height: 8),
                      Text(pet.progressLabel),
                      if (!embedded)
                        TextButton(
                            onPressed: () => context.push(AppRoutes.pet),
                            child: const Text('펫 보러가기')),
                    ],
                  ]),
            ));
  }
}
