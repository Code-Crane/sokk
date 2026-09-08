import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/config/app_config.dart';
import '../../../core/network/dio_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../data/pet_repository.dart';
import '../domain/pet.dart';

final _mockPetsProvider = Provider((ref) => <String, Pet>{});
final petRepositoryProvider = Provider<PetRepository>((ref) {
  final id = ref.watch(currentUserProvider.select((user) => user?.id));
  if (ref.watch(appConfigProvider).usesApiData) {
    return ApiPetRepository(ref.watch(apiClientProvider));
  }
  return MockPetRepository(id ?? 'mock-preview', ref.watch(_mockPetsProvider));
});
final myPetProvider = FutureProvider.autoDispose<Pet?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (ref.watch(appConfigProvider).usesApiData && user == null) return null;
  return ref.watch(petRepositoryProvider).getMe();
});
final selectPetProvider =
    StateNotifierProvider.autoDispose<SelectPetController, AsyncValue<Pet?>>(
        (ref) {
  ref.watch(currentUserProvider.select((user) => user?.id));
  return SelectPetController(ref);
});

class SelectPetController extends StateNotifier<AsyncValue<Pet?>> {
  SelectPetController(this.ref) : super(const AsyncData(null));
  final Ref ref;
  Future<bool> select(PetType type) async {
    if (state.isLoading) return false;
    state = const AsyncLoading();
    try {
      final pet = await ref.read(petRepositoryProvider).select(type);
      if (!mounted) return false;
      state = AsyncData(pet);
      ref.invalidate(myPetProvider);
      return true;
    } catch (error, stack) {
      if (mounted) {
        state = AsyncError(error, stack);
        // A response can be lost after the server committed the selection.
        ref.invalidate(myPetProvider);
      }
      return false;
    }
  }
}
