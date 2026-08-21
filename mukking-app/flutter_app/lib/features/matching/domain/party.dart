class Party {
  const Party({
    required this.id,
    required this.title,
    required this.restaurantName,
    required this.imageLabel,
    required this.scheduledAt,
    required this.region,
    required this.maxParticipants,
    required this.currentParticipants,
    required this.distanceLabel,
    required this.rewardXp,
    required this.hostName,
    required this.memberNames,
    required this.tags,
    required this.description,
  });

  final String id;
  final String title;
  final String restaurantName;
  final String imageLabel;
  final DateTime scheduledAt;
  final String region;
  final int maxParticipants;
  final int currentParticipants;
  final String distanceLabel;
  final int rewardXp;
  final String hostName;
  final List<String> memberNames;
  final List<String> tags;
  final String description;

  String get participantLabel => '$currentParticipants/$maxParticipants명';

  String get scheduledLabel {
    final hour = scheduledAt.hour.toString().padLeft(2, '0');
    final minute = scheduledAt.minute.toString().padLeft(2, '0');
    return '${scheduledAt.month}/${scheduledAt.day} $hour:$minute';
  }
}
