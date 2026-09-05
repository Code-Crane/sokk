class ApiEndpoints {
  const ApiEndpoints._();

  static const authMe = '/api/auth/me';
  static const verificationStatus = '/api/auth/verification/status';
  static const verificationMockStart = '/api/auth/verification/mock/start';
  static const verificationMockComplete =
      '/api/auth/verification/mock/complete';

  static const matchingPosts = '/api/matching/posts';

  static const restaurants = '/api/restaurants';
  static const restaurantDiscover = '/api/restaurants/discover';
  static const favoriteRestaurants = '/api/restaurants/favorites/me';

  static String restaurant(String restaurantId) {
    return '/api/restaurants/$restaurantId';
  }

  static String restaurantFavorite(String restaurantId) {
    return '/api/restaurants/$restaurantId/favorite';
  }

  static const notifications = '/api/notifications';
  static const notificationUnreadCount = '/api/notifications/unread-count';

  static String notificationRead(String notificationId) {
    return '/api/notifications/$notificationId/read';
  }

  static String joinRequests(String postId) {
    return '/api/matching/posts/$postId/requests';
  }

  static String myJoinRequest(String postId) {
    return '/api/matching/posts/$postId/request/me';
  }

  static String respondJoinRequest(String requestId) {
    return '/api/matching/requests/$requestId/respond';
  }

  static const chatRooms = '/api/chat/rooms';

  static String chatMessages(String roomId) {
    return '/api/chat/rooms/$roomId/messages';
  }

  static const pendingRatings = '/api/rating/pending';
}
