import 'package:geolocator/geolocator.dart';

import '../domain/user_location.dart';

class GeolocatorLocationService implements LocationService {
  const GeolocatorLocationService();

  @override
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  @override
  Future<AppLocationPermission> checkPermission() async {
    return _toDomain(await Geolocator.checkPermission());
  }

  @override
  Future<AppLocationPermission> requestPermission() async {
    return _toDomain(await Geolocator.requestPermission());
  }

  @override
  Future<UserLocation> getCurrentLocation() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 12),
      ),
    );
    return UserLocation(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  @override
  Future<bool> openAppSettings() => Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => Geolocator.openLocationSettings();

  AppLocationPermission _toDomain(LocationPermission permission) {
    return switch (permission) {
      LocationPermission.denied => AppLocationPermission.denied,
      LocationPermission.deniedForever => AppLocationPermission.deniedForever,
      LocationPermission.whileInUse => AppLocationPermission.whileInUse,
      LocationPermission.always => AppLocationPermission.always,
      LocationPermission.unableToDetermine => AppLocationPermission.denied,
    };
  }
}
