enum AppLocationPermission {
  denied,
  deniedForever,
  whileInUse,
  always;

  bool get isGranted =>
      this == AppLocationPermission.whileInUse ||
      this == AppLocationPermission.always;
}

class UserLocation {
  const UserLocation({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

abstract class LocationService {
  Future<bool> isServiceEnabled();
  Future<AppLocationPermission> checkPermission();
  Future<AppLocationPermission> requestPermission();
  Future<UserLocation> getCurrentLocation();
  Future<bool> openAppSettings();
  Future<bool> openLocationSettings();
}
