import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../domain/pet.dart';

abstract interface class PetRepository {
  Future<Pet?> getMe();
  Future<Pet> select(PetType type);
}

class ApiPetRepository implements PetRepository {
  ApiPetRepository(this.client);
  final ApiClient client;
  @override
  Future<Pet?> getMe() async {
    final data = await client.getNullableMap(ApiEndpoints.petMe);
    return data == null ? null : Pet.fromJson(data);
  }

  @override
  Future<Pet> select(PetType type) async => Pet.fromJson(
      await client.postMap(ApiEndpoints.petMe, data: {'petType': type.name}));
}

// Real mode never falls back to local XP or selection.
class MockPetRepository implements PetRepository {
  MockPetRepository(this.userId, this.store);
  final String userId;
  final Map<String, Pet> store;
  @override
  Future<Pet?> getMe() async => store[userId];
  @override
  Future<Pet> select(PetType type) async {
    if (store.containsKey(userId)) throw StateError('Pet already selected');
    return store[userId] = Pet(
        id: 'mock-pet-$userId',
        type: type,
        xp: 0,
        level: 1,
        growthStage: '꼬마',
        levelXp: 0,
        nextLevelXp: 100,
        remainingXp: 100,
        progress: 0);
  }
}
