import 'dart:async';

import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';

class RestaurantCameraTarget {
  const RestaurantCameraTarget({
    required this.id,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final double latitude;
  final double longitude;
}

CameraUpdate stablePositionCameraUpdate(RestaurantCameraTarget target) {
  return CameraUpdate(
    position: LatLng(
      latitude: target.latitude,
      longitude: target.longitude,
    ),
  );
}

typedef CameraMoveExecutor = Future<void> Function(CameraUpdate update);

class RestaurantCameraCoordinator {
  RestaurantCameraCoordinator({
    required CameraMoveExecutor move,
    this.debounce = const Duration(milliseconds: 48),
  }) : _move = move;

  final CameraMoveExecutor _move;
  final Duration debounce;

  Timer? _timer;
  RestaurantCameraTarget? _pending;
  Completer<void>? _settledCompleter;
  bool _moving = false;
  bool _disposed = false;

  Future<void> request(RestaurantCameraTarget target) {
    if (_disposed) return Future.value();

    _pending = target;
    if (_settledCompleter == null || _settledCompleter!.isCompleted) {
      _settledCompleter = Completer<void>();
    }

    if (!_moving) {
      _timer?.cancel();
      _timer = Timer(debounce, _drain);
    }
    return _settledCompleter!.future;
  }

  Future<void> _drain() async {
    if (_disposed || _moving) return;
    final target = _pending;
    if (target == null) {
      _completeSettled();
      return;
    }

    _pending = null;
    _moving = true;
    try {
      await _move(stablePositionCameraUpdate(target));
    } finally {
      _moving = false;
    }

    if (_disposed) return;
    if (_pending != null) {
      _timer?.cancel();
      _timer = Timer(debounce, _drain);
    } else {
      _completeSettled();
    }
  }

  void _completeSettled() {
    final completer = _settledCompleter;
    if (completer != null && !completer.isCompleted) completer.complete();
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _pending = null;
    _completeSettled();
  }
}
