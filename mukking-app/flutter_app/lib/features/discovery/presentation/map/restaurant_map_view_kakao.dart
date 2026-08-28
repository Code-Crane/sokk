import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';

import '../../domain/restaurant.dart';
import '../../domain/map_camera_center.dart';
import '../../domain/restaurant_map_marker.dart';
import '../../domain/user_location.dart';
import 'kakao_cluster_policy.dart';
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
    required this.onCameraIdle,
    this.expanded = false,
    this.focusCurrentLocationRequest = 0,
    this.initialCenter,
    super.key,
  });

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
  StreamSubscription<ClusterClickEvent>? _clusterClickSubscription;
  StreamSubscription<CameraMoveEndEvent>? _cameraMoveEndSubscription;
  Timer? _programmaticMoveTimer;
  Map<String, MarkerOption> _renderedRestaurantMarkers = const {};
  Map<String, MarkerOption> _renderedLocationMarkers = const {};
  bool _markerSyncRunning = false;
  bool _markerSyncPending = false;
  bool _didFitInitialContent = false;
  bool _mapUnavailable = false;
  bool _programmaticCameraMovePending = true;

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
    _clusterClickSubscription?.cancel();
    _cameraMoveEndSubscription?.cancel();
    _programmaticMoveTimer?.cancel();
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
    if (widget.initialCenter case final center?) {
      return LatLng(
        latitude: center.latitude,
        longitude: center.longitude,
      );
    }
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
      move: _moveCameraProgrammatically,
    );
    _labelClickSubscription = controller.onLabelClickedStream.listen((event) {
      if (isRestaurantMarkerTap(event.labelId, widget.markers)) {
        widget.onMarkerSelected(event.labelId);
      }
    });
    _clusterClickSubscription = controller.onClusterClickedStream.listen(
      (event) {
        unawaited(
          handleRestaurantClusterTap(
            event,
            moveCamera: _moveCameraProgrammatically,
            readZoomLevel: controller.getZoomLevel,
          ),
        );
      },
    );
    _cameraMoveEndSubscription = controller.onCameraMoveEndStream.listen(
      _onCameraMoveEnd,
    );
    widget.onCameraIdle(
      MapCameraIdleEvent(
        center: MapCameraCenter(
          latitude: _initialTarget.latitude,
          longitude: _initialTarget.longitude,
        ),
        userInitiated: false,
      ),
    );

    try {
      if (!kIsWeb) {
        await controller.addMarkerLayer(
          layerId: KakaoMapController.defaultLabelLayerId,
          zOrder: 1000,
          clickable: true,
        );
      }
      await _createRestaurantMarkerLayer(controller);
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
      final restaurantOptions = buildKakaoRestaurantMarkerOptions(
        markers: widget.markers,
        selectedRestaurantId: widget.selectedRestaurantId,
      );
      final restaurantPlan = buildKakaoMarkerSyncPlan(
        previous: _renderedRestaurantMarkers,
        next: restaurantOptions,
      );
      if (restaurantPlan.removedIds.isNotEmpty) {
        await controller.removeLodMarkers(
          layerId: kakaoRestaurantClusterLayerId,
          ids: restaurantPlan.removedIds,
        );
      }
      if (restaurantPlan.optionsToAdd.isNotEmpty) {
        await controller.addLodMarkers(
          options: restaurantPlan.optionsToAdd,
          layerId: kakaoRestaurantClusterLayerId,
        );
      }
      _renderedRestaurantMarkers = {
        for (final option in restaurantOptions) option.id: option,
      };

      final locationOption = buildKakaoCurrentLocationMarkerOption(
        widget.userLocation,
      );
      final locationOptions = [if (locationOption != null) locationOption];
      final locationPlan = buildKakaoMarkerSyncPlan(
        previous: _renderedLocationMarkers,
        next: locationOptions,
      );
      if (locationPlan.removedIds.isNotEmpty) {
        await controller.removeMarkers(ids: locationPlan.removedIds);
      }
      if (locationPlan.optionsToAdd.isNotEmpty) {
        await controller.addMarkers(
          markerOptions: locationPlan.optionsToAdd,
        );
      }
      _renderedLocationMarkers = {
        for (final option in locationOptions) option.id: option,
      };
    } catch (_) {
      if (mounted) setState(() => _mapUnavailable = true);
    }
  }

  Future<void> _createRestaurantMarkerLayer(
    KakaoMapController controller,
  ) async {
    if (kIsWeb) {
      await controller.addWebMarkerClusterer(
        clustererId: kakaoRestaurantClusterLayerId,
        gridSize: kakaoRestaurantClusterGridSize,
        averageCenter: true,
        minLevel: kakaoRestaurantMinClusterLevel,
        minClusterSize: kakaoRestaurantMinClusterSize,
        disableClickZoom: true,
        clickable: true,
        calculator: kakaoRestaurantClusterCalculator,
        styles: kakaoWebClusterStyles(
          Theme.of(context).colorScheme.primary,
        ),
      );
      return;
    }

    await controller.addLodMarkerLayer(
      options: const LodMarkerLayerOptions(
        layerId: kakaoRestaurantClusterLayerId,
        zOrder: 0,
        radius: kakaoRestaurantClusterRadius,
      ),
    );
    await controller.setLodMarkerLayerClickable(
      layerId: kakaoRestaurantClusterLayerId,
      clickable: true,
    );
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
    await _moveCameraProgrammatically(update);
  }

  Future<void> _moveCameraProgrammatically(CameraUpdate update) async {
    final controller = _controller;
    if (controller == null) return;
    _programmaticCameraMovePending = true;
    _programmaticMoveTimer?.cancel();
    _programmaticMoveTimer = Timer(
      const Duration(seconds: 1),
      () => _programmaticCameraMovePending = false,
    );
    await controller.moveCamera(
      cameraUpdate: update,
      animation: _cameraAnimation,
    );
  }

  void _onCameraMoveEnd(CameraMoveEndEvent event) {
    final wasProgrammatic = _programmaticCameraMovePending;
    _programmaticCameraMovePending = false;
    _programmaticMoveTimer?.cancel();
    widget.onCameraIdle(
      MapCameraIdleEvent(
        center: MapCameraCenter(
          latitude: event.latitude,
          longitude: event.longitude,
        ),
        userInitiated: !wasProgrammatic,
      ),
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
}
