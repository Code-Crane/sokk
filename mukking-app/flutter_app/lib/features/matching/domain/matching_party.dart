enum MatchingPartyStatus {
  open,
  hot,
  urgent,
  full;

  String get label {
    switch (this) {
      case MatchingPartyStatus.open:
        return '모집 중';
      case MatchingPartyStatus.hot:
        return '인기';
      case MatchingPartyStatus.urgent:
        return '마감 임박';
      case MatchingPartyStatus.full:
        return '모집 완료';
    }
  }
}

enum MatchingJoinRequestStatus {
  pending,
  accepted,
  rejected,
  cancelled;

  factory MatchingJoinRequestStatus.fromWire(String value) {
    return switch (value) {
      'accepted' => MatchingJoinRequestStatus.accepted,
      'rejected' => MatchingJoinRequestStatus.rejected,
      'cancelled' => MatchingJoinRequestStatus.cancelled,
      _ => MatchingJoinRequestStatus.pending,
    };
  }

  String get wireValue => name;

  String get label => switch (this) {
        MatchingJoinRequestStatus.pending => '승인 대기 중',
        MatchingJoinRequestStatus.accepted => '승인됨',
        MatchingJoinRequestStatus.rejected => '거절됨',
        MatchingJoinRequestStatus.cancelled => '취소됨',
      };
}

enum PartyViewerRole {
  author,
  available,
  pending,
  approved,
  rejected,
  cancelled,
  unavailable,
}

class MatchingParty {
  const MatchingParty({
    required this.id,
    required this.hostUserId,
    required this.restaurantId,
    required this.title,
    required this.scheduledAt,
    required this.currentMembers,
    required this.maxMembers,
    required this.distanceKm,
    required this.rewardXp,
    required this.rewardPoints,
    required this.status,
    required this.hostName,
    required this.memberNames,
    required this.tags,
    required this.description,
    this.restaurantName = '',
    this.address = '',
    this.participantIds = const [],
  });

  final String id;
  final String hostUserId;
  final String restaurantId;
  final String title;
  final DateTime scheduledAt;
  final int currentMembers;
  final int maxMembers;
  final double distanceKm;
  final int rewardXp;
  final int rewardPoints;
  final MatchingPartyStatus status;
  final String hostName;
  final List<String> memberNames;
  final List<String> tags;
  final String description;
  final String restaurantName;
  final String address;
  final List<String> participantIds;

  bool get isUrgent => status == MatchingPartyStatus.urgent;

  bool get isHot => status == MatchingPartyStatus.hot;

  bool get hasAvailableSeat => currentMembers < maxMembers;

  bool isParticipant(String userId) => participantIds.contains(userId);

  String get memberLabel => '$currentMembers/$maxMembers명';

  String get distanceLabel => '${distanceKm.toStringAsFixed(1)}km';

  String get scheduledLabel {
    final hour = scheduledAt.hour.toString().padLeft(2, '0');
    final minute = scheduledAt.minute.toString().padLeft(2, '0');
    return '${scheduledAt.month}/${scheduledAt.day} $hour:$minute';
  }
}

PartyViewerRole resolvePartyViewerRole({
  required MatchingParty party,
  required String? currentUserId,
  MatchingJoinRequestStatus? localRequestStatus,
}) {
  if (currentUserId == party.hostUserId) return PartyViewerRole.author;
  if ((currentUserId != null && party.isParticipant(currentUserId)) ||
      localRequestStatus == MatchingJoinRequestStatus.accepted) {
    return PartyViewerRole.approved;
  }
  if (localRequestStatus == MatchingJoinRequestStatus.pending) {
    return PartyViewerRole.pending;
  }
  if (party.status == MatchingPartyStatus.full || !party.hasAvailableSeat) {
    return PartyViewerRole.unavailable;
  }
  if (localRequestStatus == MatchingJoinRequestStatus.rejected) {
    return PartyViewerRole.rejected;
  }
  if (localRequestStatus == MatchingJoinRequestStatus.cancelled) {
    return PartyViewerRole.cancelled;
  }
  return PartyViewerRole.available;
}
