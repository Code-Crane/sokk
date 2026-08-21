class AppRoutes {
  const AppRoutes._();

  static const home = '/';
  static const discovery = '/discovery';
  static const createParty = '/create-party';
  static const chat = '/chat';
  static const my = '/my';
  static const partyDetail = '/party/:partyId';

  static String partyDetailPath(String partyId) => '/party/$partyId';

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
