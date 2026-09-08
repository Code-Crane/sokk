class AppRoutes {
  const AppRoutes._();

  static const home = '/';
  static const discovery = '/discovery';
  static const discoveryMap = '/discovery/map';
  static const createParty = '/create-party';
  static const chat = '/chat';
  static const my = '/my';
  static const pet = '/pet';
  static const notifications = '/notifications';
  static const partyDetail = '/party/:partyId';
  static const restaurants = '/restaurants';
  static const restaurantDetail = '$restaurants/:restaurantId';

  static String partyDetailPath(String partyId, {String? returnTo}) {
    return Uri(
      path: '/party/$partyId',
      queryParameters: returnTo == null ? null : {'returnTo': returnTo},
    ).toString();
  }

  static String chatPath(String roomId) => Uri(
        path: chat,
        queryParameters: {'roomId': roomId},
      ).toString();

  static String restaurantDetailPath(String restaurantId) =>
      '$restaurants/${Uri.encodeComponent(restaurantId)}';

  static String createPartyPath({String? restaurantId}) {
    if (restaurantId == null) {
      return createParty;
    }

    return Uri(
      path: createParty,
      queryParameters: {'restaurantId': restaurantId},
    ).toString();
  }
}
