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

class MatchingParty {
  const MatchingParty({
    required this.id,
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
  });

  final String id;
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

  bool get isUrgent => status == MatchingPartyStatus.urgent;

  bool get isHot => status == MatchingPartyStatus.hot;

  String get memberLabel => '$currentMembers/$maxMembers명';

  String get distanceLabel => '${distanceKm.toStringAsFixed(1)}km';

  String get scheduledLabel {
    final hour = scheduledAt.hour.toString().padLeft(2, '0');
    final minute = scheduledAt.minute.toString().padLeft(2, '0');
    return '${scheduledAt.month}/${scheduledAt.day} $hour:$minute';
  }
}
