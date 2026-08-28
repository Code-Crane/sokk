import 'package:flutter/material.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';

const kakaoRestaurantClusterLayerId = 'mukking_restaurant_clusters';
const kakaoRestaurantClusterGridSize = 56;
const kakaoRestaurantClusterRadius = 56.0;
const kakaoRestaurantMinClusterSize = 3;
const kakaoRestaurantMinClusterLevel = 4;
const kakaoRestaurantClusterCalculator = [5, 10];
const kakaoRestaurantClusterSizes = [36, 42, 48];
const kakaoMapMaximumZoomLevel = 21;

class KakaoMarkerSyncPlan {
  const KakaoMarkerSyncPlan({
    required this.removedIds,
    required this.optionsToAdd,
  });

  final List<String> removedIds;
  final List<MarkerOption> optionsToAdd;

  bool get hasChanges => removedIds.isNotEmpty || optionsToAdd.isNotEmpty;
}

KakaoMarkerSyncPlan buildKakaoMarkerSyncPlan({
  required Map<String, MarkerOption> previous,
  required List<MarkerOption> next,
}) {
  final nextById = {for (final option in next) option.id: option};
  final removedIds =
      previous.keys.where((id) => !nextById.containsKey(id)).toSet();
  final changedIds = nextById.keys.where((id) {
    final oldOption = previous[id];
    return oldOption != null && !_sameMarkerOption(oldOption, nextById[id]!);
  }).toSet();

  return KakaoMarkerSyncPlan(
    removedIds: {...removedIds, ...changedIds}.toList(growable: false),
    optionsToAdd: next
        .where(
          (option) =>
              !previous.containsKey(option.id) ||
              changedIds.contains(option.id),
        )
        .toList(growable: false),
  );
}

bool isRestaurantClusterTap(ClusterClickEvent event) =>
    event.clustererId == kakaoRestaurantClusterLayerId;

CameraUpdate restaurantClusterCameraUpdate(
  ClusterClickEvent event, {
  int? currentZoomLevel,
}) {
  if (currentZoomLevel == null) {
    return CameraUpdate.fromBounds(event.bounds, padding: 48);
  }
  return CameraUpdate(
    position: event.position,
    zoomLevel: (currentZoomLevel + 1).clamp(1, kakaoMapMaximumZoomLevel),
    type: 0,
  );
}

Future<bool> handleRestaurantClusterTap(
  ClusterClickEvent event, {
  required Future<void> Function(CameraUpdate update) moveCamera,
  Future<int?> Function()? readZoomLevel,
}) async {
  if (!isRestaurantClusterTap(event)) return false;
  final currentZoomLevel = await readZoomLevel?.call();
  await moveCamera(
    restaurantClusterCameraUpdate(
      event,
      currentZoomLevel: currentZoomLevel,
    ),
  );
  return true;
}

List<Map<String, Object?>> kakaoWebClusterStyles(Color primary) {
  final red = (primary.r * 255).round();
  final green = (primary.g * 255).round();
  final blue = (primary.b * 255).round();

  Map<String, Object?> style(double opacity, int size) => {
        'width': '${size}px',
        'height': '${size}px',
        'background': 'rgba($red, $green, $blue, $opacity)',
        'border': '2px solid rgba(255, 255, 255, .92)',
        'border-radius': '${size ~/ 2}px',
        'box-shadow': '0 2px 8px rgba(0, 0, 0, .18)',
        'color': '#fff',
        'text-align': 'center',
        'font-weight': '700',
        'font-size': '${size >= 48 ? 15 : (size >= 42 ? 14 : 13)}px',
        'line-height': '${size - 4}px',
      };

  return [
    style(.90, kakaoRestaurantClusterSizes[0]),
    style(.93, kakaoRestaurantClusterSizes[1]),
    style(.96, kakaoRestaurantClusterSizes[2]),
  ];
}

bool _sameMarkerOption(MarkerOption first, MarkerOption second) {
  return first.id == second.id &&
      first.latLng.latitude == second.latLng.latitude &&
      first.latLng.longitude == second.latLng.longitude &&
      first.styleId == second.styleId &&
      first.rank == second.rank &&
      first.text == second.text;
}
