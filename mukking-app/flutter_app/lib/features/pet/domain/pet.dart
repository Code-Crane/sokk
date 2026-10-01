enum PetMood { happy, eating, sleep }

enum PetType {
  healthy('건강이', '채소와 건강한 식탁을 좋아하는 친구'),
  night('야식이', '야식과 매콤한 식탁을 좋아하는 친구'),
  hearty('든든이', '한식과 든든한 식탁을 좋아하는 친구'),
  dog('강아지', '함께 먹고 성장하는 다정한 친구'),
  cat('고양이', '함께 먹고 성장하는 포근한 친구');

  const PetType(this.label, this.description);
  final String label;
  final String description;
  static const selectable = [dog, cat];
  bool get isLegacy => this != dog && this != cat;

  // Image fallback only: never converts persisted type or user selection.
  String assetForMood([PetMood mood = PetMood.happy]) {
    final species = this == cat ? 'cat' : 'dog';
    final pose = isLegacy ? PetMood.happy : mood;
    return 'assets/pets/$species/${species}_${pose.name}.png';
  }

  // Growth stages do not imply a feeding/sleeping state.
  String assetForStage(String stage) => assetForMood();
}

class Pet {
  const Pet(
      {required this.id,
      required this.type,
      required this.xp,
      required this.level,
      required this.growthStage,
      required this.levelXp,
      required this.nextLevelXp,
      required this.remainingXp,
      required this.progress,
      this.name});
  final String id;
  final PetType type;
  final String? name;
  final int xp, level, levelXp, remainingXp;
  final int? nextLevelXp;
  final String growthStage;
  final double progress;
  String get displayName =>
      name?.trim().isNotEmpty == true ? name! : type.label;
  String get progressLabel => nextLevelXp == null
      ? '최고 레벨 · 총 $xp XP'
      : '다음 레벨까지 $remainingXp XP · $levelXp / $nextLevelXp XP';
  String get nextGrowthLabel => level < 5
      ? 'Lv. 5 새싹 친구'
      : level < 10
          ? 'Lv. 10 단골 친구'
          : level < 20
              ? 'Lv. 20 식탁 친구'
              : level < 30
                  ? 'Lv. 30 먹킹 마스터'
                  : '먹킹 마스터에 도달했어요';
  factory Pet.fromJson(Map<String, dynamic> json) => Pet(
        id: json['id'] as String,
        type: PetType.values.byName(json['petType'] as String),
        name: json['name'] as String?,
        xp: (json['xp'] as num).toInt(),
        level: (json['level'] as num).toInt(),
        growthStage: json['growthStage'] as String,
        levelXp: (json['levelXp'] as num).toInt(),
        nextLevelXp: (json['nextLevelXp'] as num?)?.toInt(),
        remainingXp: (json['remainingXp'] as num).toInt(),
        progress: (json['progress'] as num).toDouble().clamp(0, 1),
      );
}
