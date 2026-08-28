import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';

import '../../domain/restaurant_map_marker.dart';
import '../../domain/user_location.dart';

const kakaoCurrentLocationMarkerId = '__mukking_current_location__';

bool isRestaurantMarkerTap(
  String markerId,
  Iterable<RestaurantMapMarker> markers,
) {
  return markerId != kakaoCurrentLocationMarkerId &&
      markers.any((marker) => marker.id == markerId);
}

List<MarkerOption> buildKakaoMarkerOptions({
  required List<RestaurantMapMarker> markers,
  required String? selectedRestaurantId,
  required UserLocation? userLocation,
}) {
  return [
    ...buildKakaoRestaurantMarkerOptions(
      markers: markers,
      selectedRestaurantId: selectedRestaurantId,
    ),
    if (buildKakaoCurrentLocationMarkerOption(userLocation) case final option?)
      option,
  ];
}

List<MarkerOption> buildKakaoRestaurantMarkerOptions({
  required List<RestaurantMapMarker> markers,
  required String? selectedRestaurantId,
}) {
  return [
    for (final marker in markers)
      MarkerOption(
        id: marker.id,
        latLng: LatLng(
          latitude: marker.latitude,
          longitude: marker.longitude,
        ),
        rank: marker.id == selectedRestaurantId ? 9000 : 1000,
        text: kakaoMarkerLabel(
          marker,
          selected: marker.id == selectedRestaurantId,
        ),
      ),
  ];
}

MarkerOption? buildKakaoCurrentLocationMarkerOption(
  UserLocation? userLocation,
) {
  if (userLocation == null) return null;
  return MarkerOption(
    id: kakaoCurrentLocationMarkerId,
    latLng: LatLng(
      latitude: userLocation.latitude,
      longitude: userLocation.longitude,
    ),
    rank: 10000,
    text: '내 위치',
  );
}

String kakaoMarkerLabel(
  RestaurantMapMarker marker, {
  required bool selected,
}) {
  final selectedPrefix = selected ? '선택 · ' : '';
  final statusPrefix = switch (marker.status) {
    RestaurantMapMarkerStatus.favorite => '찜 · ',
    RestaurantMapMarkerStatus.activeParty => '파티 · ',
    RestaurantMapMarkerStatus.urgentParty => '마감 임박 · ',
    RestaurantMapMarkerStatus.normal => '',
  };
  return '$selectedPrefix$statusPrefix${marker.name}';
}
