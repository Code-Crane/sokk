import 'package:flutter/material.dart';

abstract final class BrandAssets {
  static const logo = 'assets/branding/mukking_logo.png';
  static const defaultMascot = 'assets/mascot/mukking_default.png';
  static const heart = 'assets/mascot/mukking_heart.png';
  static const speech = 'assets/mascot/mukking_speech.png';
  static const food = 'assets/mascot/mukking_food.png';
  static const cheer = 'assets/mascot/mukking_cheer.png';
}

class MukkingMascot extends StatelessWidget {
  const MukkingMascot(
      {this.asset = BrandAssets.defaultMascot, this.size = 100, super.key});
  final String asset;
  final double size;
  @override
  Widget build(BuildContext context) => Image.asset(asset,
      width: size, height: size, fit: BoxFit.contain, semanticLabel: '먹킹');
}

/// Phase 1 scope: final Home and navigation. Legacy screen tokens stay intact.
abstract final class MukkingBrand {
  static const contentWidth = 480.0;
  static const green = Color(0xFF006044);
  static const darkGreen = Color(0xFF003E2D);
  static const orange = Color(0xFFF58232);
  static const background = Colors.white;
  static const surface = Colors.white;
  static const mint = Color(0xFFEAF5EF);
  static const warm = Color(0xFFFFF4E9);
  static const neutralSurface = Color(0xFFF2F4F2);
  static const text = Color(0xFF252B27);
  static const secondary = Color(0xFF727A74);
  static const border = Color(0xFFE5EAE6);
}
