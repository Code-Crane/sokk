import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';

import '../../domain/restaurant.dart';
import '../../domain/restaurant_map_marker.dart';
import '../../domain/user_location.dart';
import 'kakao_marker_adapter.dart';
import 'restaurant_camera_policy.dart';
import 'restaurant_map_fallback.dart';

class KakaoRestaurantMap extends StatefulWidget {
  const KakaoRestaurantMap({
    required this.restaurants,
    required this.markers,
    required this.selectedRestaurantId,
    required this.focusSelectedRestaurantRequest,
    required this.userLocation,
    required this.onMarkerSelected,
    this.expanded = false,
    this.focusCurrentLocationRequest = 0,
    super.key,
  });

  final List<Restaurant> restaurants;
  final List<RestaurantMapMarker> markers;
  final String? selectedRestaurantId;
  final int focusSelectedRestaurantRequest;
  final UserLocation? userLocation;
  final ValueChanged<String> onMarkerSelected;
  final bool expanded;
  final int focusCurrentLocationRequest;

  @override
  State<KakaoRestaurantMap> createState() => _KakaoRestaurantMapState();
}

class _KakaoRestaurantMapState extends State<KakaoRestaurantMap> {
  static const _cameraAnimation = CameraAnimation(
    duration: 280,
    autoElevation: false,
    isConsecutive: false,
  );

  KakaoMapController? _controller;
  RestaurantCameraCoordinator? _cameraCoordinator;
  StreamSubscription<LabelClickEvent>? _labelClickSubscription;
  Map<String, MarkerOption> _renderedMarkers = const {};
  bool _markerSyncRunning = false;
  bool _markerSyncPending = false;
  bool _didFitInitialContent = false;
  bool _mapUnavailable = false;

  @override
  void didUpdateWidget(covariant KakaoRestaurantMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller == null) return;

    final markersChanged = !_sameMarkers(oldWidget.markers, widget.markers);
    final locationChanged = oldWidget.userLocation != widget.userLocation;
    final selectionChanged =
        oldWidget.selectedRestaurantId != widget.selectedRestaurantId;
    if (markersChanged || locationChanged || selectionChanged) {
      _queueMarkerSync();
    }

    if (oldWidget.focusSelectedRestaurantRequest !=
        widget.focusSelectedRestaurantRequest) {
      _requestSelectedMarkerFocus();
    }
    if (locationChanged ||
        oldWidget.focusCurrentLocationRequest !=
            widget.focusCurrentLocationRequest) {
      _requestCurrentLocationFocus();
    }
  }

  @override
  void dispose() {
    _cameraCoordinator?.dispose();
    _labelClickSubscription?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_mapUnavailable) {
      return RestaurantMapFallback(
        restaurants: widget.restaurants,
        markers: widget.markers,
        selectedRestaurantId: widget.selectedRestaurantId,
        onMarkerSelected: widget.onMarkerSelected,
        expanded: widget.expanded,
        title: 'Kakao Map을 불러오지 못했어요',
        subtitle: '목록과 찜 기능은 계속 사용할 수 있어요.',
      );
    }

    final map = KakaoMap(
      key: const ValueKey('kakao-restaurant-map-instance'),
      initialPosition: _initialTarget,
      initialLevel: 14,
      onMapCreated: _onMapCreated,
    );
    final clippedMap = ClipRRect(
      borderRadius:
          widget.expanded ? BorderRadius.zero : BorderRadius.circular(28),
      child: map,
    );
    if (widget.expanded) {
      return SizedBox.expand(child: clippedMap);
    }
    return SizedBox(height: 348, child: clippedMap);
  }

  LatLng get _initialTarget {
    final selectedId = widget.selectedRestaurantId;
    if (selectedId != null) {
      for (final marker in widget.markers) {
        if (marker.id == selectedId) {
          return LatLng(
            latitude: marker.latitude,
            longitude: marker.longitude,
          );
        }
      }
    }
    final location = widget.userLocation;
    if (location != null) {
      return LatLng(
        latitude: location.latitude,
        longitude: location.longitude,
      );
    }
    if (widget.markers case [final first, ...]) {
      return LatLng(latitude: first.latitude, longitude: first.longitude);
    }
    return const LatLng(latitude: 37.5666, longitude: 126.979);
  }

  Future<void> _onMapCreated(KakaoMapController controller) async {
    if (_controller != null) return;
    _controller = controller;
    _cameraCoordinator = RestaurantCameraCoordinator(
      move: (update) => controller.moveCamera(
        cameraUpdate: update,
        animation: _cameraAnimation,
      ),
    );
    _labelClickSubscription = controller.onLabelClickedStream.listen((event) {
      if (isRestaurantMarkerTap(event.labelId, widget.markers)) {
        widget.onMarkerSelected(event.labelId);
      }
    });

    try {
      if (!kIsWeb) {
        await controller.addMarkerLayer(
          layerId: KakaoMapController.defaultLabelLayerId,
          zOrder: 1000,
          clickable: true,
        );
      }
      await _syncMarkersOnce();
      await _fitInitialContent();
    } catch (_) {
      if (mounted) setState(() => _mapUnavailable = true);
    }
  }

  void _queueMarkerSync() {
    _markerSyncPending = true;
    if (!_markerSyncRunning) unawaited(_drainMarkerSync());
  }

  Future<void> _drainMarkerSync() async {
    _markerSyncRunning = true;
    try {
      while (_markerSyncPending && mounted) {
        _markerSyncPending = false;
        await _syncMarkersOnce();
      }
    } finally {
      _markerSyncRunning = false;
    }
  }

  Future<void> _syncMarkersOnce() async {
    final controller = _controller;
    if (controller == null) return;

    try {
      final options = buildKakaoMarkerOptions(
        markers: widget.markers,
        selectedRestaurantId: widget.selectedRestaurantId,
        userLocation: widget.userLocation,
      );
      final nextMarkers = {for (final option in options) option.id: option};
      final removedIds = _renderedMarkers.keys
          .where((id) => !nextMarkers.containsKey(id))
          .toSet();
      final changedIds = nextMarkers.keys.where((id) {
        final previous = _renderedMarkers[id];
        return previous != null &&
            !_sameMarkerOption(previous, nextMarkers[id]!);
      }).toSet();
      final idsToRemove = {...removedIds, ...changedIds};

      if (idsToRemove.isNotEmpty) {
        await controller.removeMarkers(ids: idsToRemove.toList());
      }

      final optionsToAdd = options
          .where(
            (option) =>
                !_renderedMarkers.containsKey(option.id) ||
                changedIds.contains(option.id),
          )
          .toList();

      if (optionsToAdd.isNotEmpty) {
        await controller.addMarkers(markerOptions: optionsToAdd);
      }
      _renderedMarkers = nextMarkers;
    } catch (_) {
      if (mounted) setState(() => _mapUnavailable = true);
    }
  }

  Future<void> _fitInitialContent() async {
    if (_didFitInitialContent) return;
    _didFitInitialContent = true;
    await _fitContent();
  }

  Future<void> _fitContent() async {
    final controller = _controller;
    if (controller == null) return;
    final points = _contentPoints;
    if (points.isEmpty) return;

    if (points.length == 1 || _allSamePosition(points)) {
      return;
    }

    final update = CameraUpdate.fromBounds(_boundsFor(points), padding: 56);
    await controller.moveCamera(
      cameraUpdate: update,
      animation: _cameraAnimation,
    );
  }

  void _requestCurrentLocationFocus() {
    final location = widget.userLocation;
    final coordinator = _cameraCoordinator;
    if (coordinator == null || location == null) return;
    unawaited(
      coordinator.request(
        RestaurantCameraTarget(
          id: '__current_location__',
          latitude: location.latitude,
          longitude: location.longitude,
        ),
      ),
    );
  }

  void _requestSelectedMarkerFocus() {
    final coordinator = _cameraCoordinator;
    final selectedId = widget.selectedRestaurantId;
    if (coordinator == null || selectedId == null) return;

    for (final marker in widget.markers) {
      if (marker.id != selectedId) continue;
      unawaited(
        coordinator.request(
          RestaurantCameraTarget(
            id: marker.id,
            latitude: marker.latitude,
            longitude: marker.longitude,
          ),
        ),
      );
      return;
    }
  }

  List<LatLng> get _contentPoints => [
        if (widget.userLocation case final location?)
          LatLng(
            latitude: location.latitude,
            longitude: location.longitude,
          ),
        for (final marker in widget.markers)
          LatLng(latitude: marker.latitude, longitude: marker.longitude),
      ];

  LatLngBounds _boundsFor(List<LatLng> points) {
    var minLatitude = points.first.latitude;
    var maxLatitude = points.first.latitude;
    var minLongitude = points.first.longitude;
    var maxLongitude = points.first.longitude;
    for (final point in points.skip(1)) {
      minLatitude = point.latitude < minLatitude ? point.latitude : minLatitude;
      maxLatitude = point.latitude > maxLatitude ? point.latitude : maxLatitude;
      minLongitude =
          point.longitude < minLongitude ? point.longitude : minLongitude;
      maxLongitude =
          point.longitude > maxLongitude ? point.longitude : maxLongitude;
    }
    return LatLngBounds(
      southwest: LatLng(latitude: minLatitude, longitude: minLongitude),
      northeast: LatLng(latitude: maxLatitude, longitude: maxLongitude),
    );
  }

  bool _allSamePosition(List<LatLng> points) {
    final first = points.first;
    return points.every(
      (point) =>
          point.latitude == first.latitude &&
          point.longitude == first.longitude,
    );
  }

  bool _sameMarkers(
    List<RestaurantMapMarker> first,
    List<RestaurantMapMarker> second,
  ) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index += 1) {
      final left = first[index];
      final right = second[index];
      if (left.id != right.id ||
          left.name != right.name ||
          left.latitude != right.latitude ||
          left.longitude != right.longitude ||
          left.status != right.status) {
        return false;
      }
    }
    return true;
  }

  bool _sameMarkerOption(MarkerOption first, MarkerOption second) {
    return first.id == second.id &&
        first.latLng.latitude == second.latLng.latitude &&
        first.latLng.longitude == second.latLng.longitude &&
        first.styleId == second.styleId &&
        first.rank == second.rank &&
        first.text == second.text;
  }
}
