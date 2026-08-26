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

  Future<MatchingPostDto> createPost(CreateMatchingPostRequest request) async {
    final json = await _apiClient.postMap(
      ApiEndpoints.matchingPosts,
      data: request.toJson(),
    );
    return MatchingPostDto.fromJson(json);
  }

  Future<JoinRequestDto> createJoinRequest(String postId) async {
    final json = await _apiClient.postMap(ApiEndpoints.joinRequests(postId));
    return JoinRequestDto.fromJson(json);
  }

  Future<List<JoinRequestDto>> listJoinRequests(String postId) async {
    final list = await _apiClient.getList(ApiEndpoints.joinRequests(postId));
    return list
        .whereType<Map>()
        .map((json) => JoinRequestDto.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<RespondJoinRequestDto> respondJoinRequest({
    required String requestId,
    required String decision,
  }) async {
    final json = await _apiClient.postMap(
      ApiEndpoints.respondJoinRequest(requestId),
      data: {'decision': decision},
    );
    return RespondJoinRequestDto.fromJson(json);
  }
}

class CreateMatchingPostRequest {
  const CreateMatchingPostRequest({
    required this.restaurantId,
    required this.restaurantName,
    required this.address,
    required this.scheduledAt,
    required this.maxParticipants,
    required this.intro,
  });

  final String? restaurantId;
  final String restaurantName;
  final String address;
  final DateTime scheduledAt;
  final int maxParticipants;
  final String intro;

  Map<String, dynamic> toJson() {
    return {
      if (restaurantId != null) 'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'address': address,
      'scheduledAt': scheduledAt.toUtc().toIso8601String(),
      'maxParticipants': maxParticipants,
      'intro': intro,
    };
  }
}

class MatchingPostDto {
  const MatchingPostDto({
    required this.id,
    required this.authorId,
    required this.restaurantId,
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
      restaurantId: json['restaurantId'] as String?,
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
  final String? restaurantId;
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
    required this.createdAt,
  });

  factory JoinRequestDto.fromJson(Map<String, dynamic> json) {
    return JoinRequestDto(
      id: json['id'] as String? ?? '',
      postId: json['postId'] as String? ?? '',
      requesterId: json['requesterId'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      createdAt: json['createdAt'] as String? ?? '',
    );
  }

  final String id;
  final String postId;
  final String requesterId;
  final String status;
  final String createdAt;
}

class RespondJoinRequestDto {
  const RespondJoinRequestDto({
    required this.request,
    required this.chatRoomId,
  });

  factory RespondJoinRequestDto.fromJson(Map<String, dynamic> json) {
    final requestJson = json['request'];
    final chatRoomJson = json['chatRoom'];
    return RespondJoinRequestDto(
      request: JoinRequestDto.fromJson(
        requestJson is Map<String, dynamic>
            ? requestJson
            : Map<String, dynamic>.from(requestJson as Map? ?? const {}),
      ),
      chatRoomId: chatRoomJson is Map ? chatRoomJson['id'] as String? : null,
    );
  }

  final JoinRequestDto request;
  final String? chatRoomId;
}
