class ApiEndpoints {
  const ApiEndpoints._();

  static const authMe = '/api/auth/me';
  static const verificationStatus = '/api/auth/verification/status';

  static const matchingPosts = '/api/matching/posts';

  static String joinRequests(String postId) {
    return '/api/matching/posts/$postId/requests';
  }

  static const chatRooms = '/api/chat/rooms';

  static String chatMessages(String roomId) {
    return '/api/chat/rooms/$roomId/messages';
  }

  static const pendingRatings = '/api/rating/pending';
}
