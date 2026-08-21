import '../../discovery/domain/restaurant.dart';
import '../domain/matching_party.dart';
import 'matching_repository.dart';
import 'matching_api.dart';

class MatchingPostMapper {
  const MatchingPostMapper();

  MatchingFeed toFeed(List<MatchingPostDto> posts) {
    final parties = <MatchingParty>[];
    final restaurants = <Restaurant>[];

    for (var index = 0; index < posts.length; index += 1) {
      final post = posts[index];
      final restaurantId = _restaurantIdFor(post);
      final scheduledAt = DateTime.tryParse(post.scheduledAt)?.toLocal() ??
          DateTime.now().add(const Duration(days: 1));
      final currentMembers = post.participantIds.length + 1;
      final status = _statusFor(
        backendStatus: post.status,
        currentMembers: currentMembers,
        maxMembers: post.maxParticipants,
        scheduledAt: scheduledAt,
      );

      parties.add(
        MatchingParty(
          id: post.id,
          restaurantId: restaurantId,
          title: post.intro.isEmpty ? '${post.restaurantName} 파티' : post.intro,
          scheduledAt: scheduledAt,
          currentMembers: currentMembers,
          maxMembers: post.maxParticipants,
          distanceKm: 0,
          rewardXp: _rewardXpFor(post.maxParticipants, currentMembers),
          rewardPoints: _rewardPointsFor(post.maxParticipants, currentMembers),
          status: status,
          hostName: '파티장',
          memberNames: [
            '파티장',
            for (var memberIndex = 0;
                memberIndex < post.participantIds.length;
                memberIndex += 1)
              '참여자 ${memberIndex + 1}',
          ],
          tags: ['실제API', post.status],
          description: post.intro,
        ),
      );

      restaurants.add(
        Restaurant(
          id: restaurantId,
          name: post.restaurantName,
          category: '맛집',
          address: post.address,
          distanceKm: 0,
          imageUrl: '',
          imageLabel: post.restaurantName,
          isFavorite: false,
          activePartyCount: post.status == 'open' ? 1 : 0,
          markerDx: 0.18 + (index % 3) * 0.26,
          markerDy: 0.2 + (index % 4) * 0.16,
        ),
      );
    }

    return MatchingFeed(parties: parties, restaurants: restaurants);
  }

  MatchingPartyStatus _statusFor({
    required String backendStatus,
    required int currentMembers,
    required int maxMembers,
    required DateTime scheduledAt,
  }) {
    if (backendStatus != 'open' || currentMembers >= maxMembers) {
      return MatchingPartyStatus.full;
    }

    final remaining = scheduledAt.difference(DateTime.now());
    if (remaining.inHours <= 6 || currentMembers >= maxMembers - 1) {
      return MatchingPartyStatus.urgent;
    }

    if (currentMembers >= 2) {
      return MatchingPartyStatus.hot;
    }

    return MatchingPartyStatus.open;
  }

  int _rewardXpFor(int maxMembers, int currentMembers) {
    return 60 + (maxMembers * 10) + (currentMembers * 10);
  }

  int _rewardPointsFor(int maxMembers, int currentMembers) {
    return _rewardXpFor(maxMembers, currentMembers) * 5;
  }

  String _restaurantIdFor(MatchingPostDto post) {
    return 'api-restaurant-${post.id}';
  }
}
