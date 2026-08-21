class Restaurant {
  const Restaurant({
    required this.id,
    required this.name,
    required this.region,
    required this.category,
    required this.distanceLabel,
    required this.waitingSignal,
    required this.partyCount,
    required this.imageLabel,
    required this.markerDx,
    required this.markerDy,
  });

  final String id;
  final String name;
  final String region;
  final String category;
  final String distanceLabel;
  final String waitingSignal;
  final int partyCount;
  final String imageLabel;
  final double markerDx;
  final double markerDy;
}
