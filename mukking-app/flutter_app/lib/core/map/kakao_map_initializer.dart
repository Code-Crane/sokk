import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';

final kakaoMapReadyProvider = Provider<bool>((ref) => false);

Future<bool> initializeKakaoMap({
  required String nativeAppKey,
  required String javascriptKey,
}) async {
  final isNativeMobile = defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
  final hasRequiredKey = kIsWeb
      ? javascriptKey.isNotEmpty
      : isNativeMobile && nativeAppKey.isNotEmpty;
  if (!hasRequiredKey) return false;

  try {
    await KakaoMapsFlutter.init(
      nativeAppKey.isEmpty ? null : nativeAppKey,
      webAPIKey: javascriptKey.isEmpty ? null : javascriptKey,
    );
    return true;
  } catch (_) {
    return false;
  }
}
