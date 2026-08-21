import '../../auth/domain/auth_user.dart';

class VerificationSnapshot {
  const VerificationSnapshot({
    required this.status,
    required this.label,
    required this.canUseMatching,
    required this.canUseChat,
  });

  factory VerificationSnapshot.fromJson(Map<String, dynamic> json) {
    return VerificationSnapshot(
      status: VerificationStatusX.fromValue(json['status']),
      label: json['label'] as String? ?? '미인증',
      canUseMatching: json['canUseMatching'] as bool? ?? false,
      canUseChat: json['canUseChat'] as bool? ?? false,
    );
  }

  final VerificationStatus status;
  final String label;
  final bool canUseMatching;
  final bool canUseChat;
}

class ProfileSummary {
  const ProfileSummary({
    required this.user,
    required this.verification,
    required this.pendingEvaluationCount,
  });

  final AuthUser user;
  final VerificationSnapshot? verification;
  final int pendingEvaluationCount;
}
