import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/matching_party.dart';

final mockPartyRepositoryProvider = Provider<MockPartyRepository>((ref) {
  return const MockPartyRepository();
});

class MockPartyRepository {
  const MockPartyRepository();

  List<MatchingParty> featuredParties() {
    return [
      MatchingParty(
        id: 'party-ramen-001',
        restaurantId: 'restaurant-001',
        title: '퇴근 후 라멘 보스전',
        scheduledAt: DateTime(2026, 8, 22, 19, 30),
        maxMembers: 4,
        currentMembers: 2,
        distanceKm: 0.8,
        rewardXp: 120,
        rewardPoints: 600,
        status: MatchingPartyStatus.hot,
        hostName: '라멘탐험가 민준',
        memberNames: ['민준', '소연'],
        tags: ['라멘', '퇴근팟', '초보환영'],
        description: '말 많이 안 해도 괜찮은 라멘 파티예요. 맛집 발견과 가벼운 인증 미션을 같이 진행합니다.',
      ),
      MatchingParty(
        id: 'party-kbbq-002',
        restaurantId: 'restaurant-002',
        title: '고기 굽기 듀오 매칭',
        scheduledAt: DateTime(2026, 8, 23, 18),
        maxMembers: 6,
        currentMembers: 5,
        distanceKm: 1.2,
        rewardXp: 180,
        rewardPoints: 900,
        status: MatchingPartyStatus.urgent,
        hostName: '불판장인 지우',
        memberNames: ['지우', '태훈', '나리', '도윤', '하린'],
        tags: ['고기', '단체팟', '배지보상'],
        description:
            '고기 굽는 사람에게 보너스 XP가 있는 파티입니다. 과한 게임 요소 없이 실제 식사 경험을 우선합니다.',
      ),
      MatchingParty(
        id: 'party-dessert-003',
        restaurantId: 'restaurant-003',
        title: '디저트 지도 밝히기',
        scheduledAt: DateTime(2026, 8, 24, 15, 10),
        maxMembers: 3,
        currentMembers: 1,
        distanceKm: 0.6,
        rewardXp: 90,
        rewardPoints: 450,
        status: MatchingPartyStatus.open,
        hostName: '달달한 은채',
        memberNames: ['은채'],
        tags: ['디저트', '카페', '사진미션'],
        description: '새 카페를 같이 발견하고 짧은 리뷰 미션을 남기는 소규모 파티입니다.',
      ),
      MatchingParty(
        id: 'party-ramen-004',
        restaurantId: 'restaurant-001',
        title: '혼밥 탈출 라멘 2인팟',
        scheduledAt: DateTime(2026, 8, 22, 20, 10),
        maxMembers: 2,
        currentMembers: 1,
        distanceKm: 0.8,
        rewardXp: 80,
        rewardPoints: 300,
        status: MatchingPartyStatus.open,
        hostName: '국물파 지안',
        memberNames: ['지안'],
        tags: ['소규모', '빠른식사'],
        description: '조용히 맛만 보고 싶은 사람을 위한 2인 라멘 파티입니다.',
      ),
    ];
  }

  MatchingParty? findById(String partyId) {
    for (final party in featuredParties()) {
      if (party.id == partyId) {
        return party;
      }
    }
    return null;
  }
}
