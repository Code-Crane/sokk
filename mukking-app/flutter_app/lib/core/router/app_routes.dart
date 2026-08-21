class AppRoutes {
  const AppRoutes._();

  static const home = '/';
  static const discovery = '/discovery';
  static const createParty = '/create-party';
  static const chat = '/chat';
  static const my = '/my';
  static const partyDetail = '/party/:partyId';

  static String partyDetailPath(String partyId) => '/party/$partyId';
}
