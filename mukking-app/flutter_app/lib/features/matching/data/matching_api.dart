import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';

class MatchingApi {
  const MatchingApi(this._apiClient);

  final ApiClient _apiClient;

  Future<List<MatchingPostDto>> listPosts() async {
    final list = await _apiClient.getList(ApiEndpoints.matchingPosts);
    return list
        .whereType<Map>()
        .map((json) => MatchingPostDto.fromJson(json))
        .toList();
  }

  Future<JoinRequestDto> createJoinRequest(String postId) async {
    final json = await _apiClient.postMap(ApiEndpoints.joinRequests(postId));
    return JoinRequestDto.fromJson(json);
  }
}

class MatchingPostDto {
  const MatchingPostDto({
    required this.id,
    required this.authorId,
    required this.restaurantName,
    required this.address,
    required this.scheduledAt,
    required this.maxParticipants,
    required this.intro,
    required this.status,
    required this.participantIds,
    required this.createdAt,
    required this.updatedAt,
  });

  factory MatchingPostDto.fromJson(Map<dynamic, dynamic> json) {
    return MatchingPostDto(
      id: json['id'] as String? ?? '',
      authorId: json['authorId'] as String? ?? '',
      restaurantName: json['restaurantName'] as String? ?? '식당 이름 없음',
      address: json['address'] as String? ?? '주소 확인 필요',
      scheduledAt: json['scheduledAt'] as String? ?? '',
      maxParticipants: json['maxParticipants'] as int? ?? 1,
      intro: json['intro'] as String? ?? '',
      status: json['status'] as String? ?? 'open',
      participantIds: (json['participantIds'] as List? ?? const [])
          .whereType<String>()
          .toList(),
      createdAt: json['createdAt'] as String? ?? '',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }

  final String id;
  final String authorId;
  final String restaurantName;
  final String address;
  final String scheduledAt;
  final int maxParticipants;
  final String intro;
  final String status;
  final List<String> participantIds;
  final String createdAt;
  final String updatedAt;
}

class JoinRequestDto {
  const JoinRequestDto({
    required this.id,
    required this.postId,
    required this.requesterId,
    required this.status,
  });

  factory JoinRequestDto.fromJson(Map<String, dynamic> json) {
    return JoinRequestDto(
      id: json['id'] as String? ?? '',
      postId: json['postId'] as String? ?? '',
      requesterId: json['requesterId'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
    );
  }

  final String id;
  final String postId;
  final String requesterId;
  final String status;
}
