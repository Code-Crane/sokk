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
      parties.add(toParty(post));
      restaurants.add(toRestaurant(post, index: index));
    }

    return MatchingFeed(parties: parties, restaurants: restaurants);
  }

  MatchingParty toParty(MatchingPostDto post) {
    final scheduledAt = DateTime.tryParse(post.scheduledAt)?.toLocal() ??
        DateTime.now().add(const Duration(days: 1));
    final currentMembers = post.participantIds.length + 1;
    final status = _statusFor(
      backendStatus: post.status,
      currentMembers: currentMembers,
      maxMembers: post.maxParticipants,
      scheduledAt: scheduledAt,
    );

    return MatchingParty(
      id: post.id,
      hostUserId: post.authorId,
      restaurantId: _restaurantIdFor(post),
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
        for (var index = 0; index < post.participantIds.length; index += 1)
          '참여자 ${index + 1}',
      ],
      tags: ['실제API', post.status],
      description: post.intro,
    );
  }

  Restaurant toRestaurant(MatchingPostDto post, {int index = 0}) {
    return Restaurant(
      id: _restaurantIdFor(post),
      name: post.restaurantName,
      category: '맛집',
      address: post.address,
      distanceMeters: null,
      imageUrl: '',
      imageLabel: post.restaurantName,
      isFavorite: false,
      activePartyCount: post.status == 'open' ? 1 : 0,
      markerDx: 0.18 + (index % 3) * 0.26,
      markerDy: 0.2 + (index % 4) * 0.16,
    );
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
    return post.restaurantId ?? 'legacy-restaurant-${post.id}';
  }
}
