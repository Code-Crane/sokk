import 'package:flutter/material.dart';

import '../../domain/restaurant.dart';
import '../../domain/map_camera_center.dart';
import '../../domain/restaurant_map_marker.dart';
import '../../domain/user_location.dart';
import 'restaurant_map_fallback.dart';
import 'restaurant_map_view_kakao.dart';

class RestaurantMapView extends StatelessWidget {
  const RestaurantMapView({
    required this.enableMap,
    required this.restaurants,
    required this.markers,
    required this.selectedRestaurantId,
    required this.focusSelectedRestaurantRequest,
    required this.userLocation,
    required this.onMarkerSelected,
    required this.onCameraIdle,
    this.expanded = false,
    this.focusCurrentLocationRequest = 0,
    this.initialCenter,
    super.key,
  });

  final bool enableMap;
  final List<Restaurant> restaurants;
  final List<RestaurantMapMarker> markers;
  final String? selectedRestaurantId;
  final int focusSelectedRestaurantRequest;
  final UserLocation? userLocation;
  final ValueChanged<String> onMarkerSelected;
  final ValueChanged<MapCameraIdleEvent> onCameraIdle;
  final bool expanded;
  final int focusCurrentLocationRequest;
  final MapCameraCenter? initialCenter;

  @override
  Widget build(BuildContext context) {
    if (!enableMap) {
      return RestaurantMapFallback(
        restaurants: restaurants,
        markers: markers,
        selectedRestaurantId: selectedRestaurantId,
        onMarkerSelected: onMarkerSelected,
        expanded: expanded,
        title: 'Kakao Map 설정 필요',
        subtitle: '키 없이도 목록과 찜 기능은 계속 사용할 수 있어요.',
      );
    }

    return KakaoRestaurantMap(
      restaurants: restaurants,
      markers: markers,
      selectedRestaurantId: selectedRestaurantId,
      focusSelectedRestaurantRequest: focusSelectedRestaurantRequest,
      userLocation: userLocation,
      onMarkerSelected: onMarkerSelected,
      onCameraIdle: onCameraIdle,
      expanded: expanded,
      focusCurrentLocationRequest: focusCurrentLocationRequest,
      initialCenter: initialCenter,
    );
  }
}
