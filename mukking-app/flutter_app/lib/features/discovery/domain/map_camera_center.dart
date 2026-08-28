class MapCameraCenter {
  const MapCameraCenter({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

class MapCameraIdleEvent {
  const MapCameraIdleEvent({
    required this.center,
    required this.userInitiated,
  });

  final MapCameraCenter center;
  final bool userInitiated;
}
