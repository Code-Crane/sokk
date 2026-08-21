class AuthUser {
  const AuthUser({
    required this.id,
    required this.nickname,
    required this.email,
    required this.verificationStatus,
    required this.mannerScore,
    required this.mannerGrade,
    required this.pendingEvaluationCount,
    required this.createdAt,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String? ?? '',
      nickname: json['nickname'] as String? ?? '먹킹러',
      email: json['email'] as String? ?? '',
      verificationStatus:
          VerificationStatusX.fromValue(json['verificationStatus']),
      mannerScore: (json['mannerScore'] as num?)?.toDouble() ?? 0,
      mannerGrade: MannerGradeX.fromValue(json['mannerGrade']),
      pendingEvaluationCount: json['pendingEvaluationCount'] as int? ?? 0,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  factory AuthUser.fallback({
    required String id,
    required String email,
    String? nickname,
  }) {
    return AuthUser(
      id: id,
      nickname: nickname ?? (email.isEmpty ? '먹킹러' : email.split('@').first),
      email: email,
      verificationStatus: VerificationStatus.unverified,
      mannerScore: 0,
      mannerGrade: MannerGrade.sprout,
      pendingEvaluationCount: 0,
      createdAt: DateTime.now(),
    );
  }

  final String id;
  final String nickname;
  final String email;
  final VerificationStatus verificationStatus;
  final double mannerScore;
  final MannerGrade mannerGrade;
  final int pendingEvaluationCount;
  final DateTime createdAt;

  bool get isVerified => verificationStatus == VerificationStatus.verified;
}

enum VerificationStatus {
  unverified,
  pending,
  verified;

  String get label {
    return switch (this) {
      VerificationStatus.unverified => '미인증',
      VerificationStatus.pending => '인증중',
      VerificationStatus.verified => '인증완료',
    };
  }
}

extension VerificationStatusX on VerificationStatus {
  static VerificationStatus fromValue(Object? value) {
    return switch (value) {
      'pending' => VerificationStatus.pending,
      'verified' => VerificationStatus.verified,
      _ => VerificationStatus.unverified,
    };
  }
}

enum MannerGrade {
  sprout,
  regular,
  foodie,
  mukking;

  String get label {
    return switch (this) {
      MannerGrade.sprout => '새싹 먹킹러',
      MannerGrade.regular => '일반 먹킹러',
      MannerGrade.foodie => '미식 탐험가',
      MannerGrade.mukking => '먹킹 마스터',
    };
  }
}

extension MannerGradeX on MannerGrade {
  static MannerGrade fromValue(Object? value) {
    return switch (value) {
      'regular' => MannerGrade.regular,
      'foodie' => MannerGrade.foodie,
      'mukking' => MannerGrade.mukking,
      _ => MannerGrade.sprout,
    };
  }
}
