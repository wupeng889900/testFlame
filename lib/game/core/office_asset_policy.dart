import 'package:flutter/painting.dart';

class OfficeAssetPolicy {
  const OfficeAssetPolicy._();

  static const double sceneDpToMillimeters = 8.0;
  static const double physicalTolerance = 0.02;

  static const Map<String, OfficeImageLayoutRule> layoutRules = {
    'assets/atlas/场景布局左边+资源目录规划.png': OfficeImageLayoutRule(
      fit: BoxFit.contain,
      alignment: Alignment.center,
      role: 'reference style image',
    ),
    'assets/environment/office_background_cutout.png': OfficeImageLayoutRule(
      fit: BoxFit.contain,
      alignment: Alignment.center,
      role: 'office background',
    ),
    'assets/office_game/furniture/desks/desk_laptop.png': OfficeImageLayoutRule(
      fit: BoxFit.contain,
      alignment: Alignment.center,
      role: 'desk',
    ),
    'assets/office_game/furniture/meeting/meeting_table_7seat.png':
        OfficeImageLayoutRule(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          role: 'meeting table',
        ),
    'assets/office_game/furniture/lounge/sofa_3seat.png': OfficeImageLayoutRule(
      fit: BoxFit.contain,
      alignment: Alignment.center,
      role: 'sofa',
    ),
    'assets/office_game/furniture/lounge/coffee_table.png':
        OfficeImageLayoutRule(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          role: 'coffee table',
        ),
    'assets/office_game/furniture/decor/plant_large.png': OfficeImageLayoutRule(
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      role: 'plant',
    ),
    'assets/office_game/furniture/decor/water_dispenser.png':
        OfficeImageLayoutRule(
          fit: BoxFit.contain,
          alignment: Alignment.bottomCenter,
          role: 'water dispenser',
        ),
  };

  static const Set<String> firstScreenAssets = {
    'assets/AssetCatalog.json',
    'assets/office_game/manifest.json',
    'assets/atlas/场景布局左边+资源目录规划.png',
    'assets/environment/office_background_cutout.png',
    'assets/office_game/furniture/desks/desk_laptop.png',
    'assets/office_game/furniture/meeting/meeting_table_7seat.png',
    'assets/office_game/furniture/lounge/sofa_3seat.png',
    'assets/office_game/furniture/lounge/coffee_table.png',
    'assets/office_game/furniture/decor/plant_large.png',
    'assets/office_game/furniture/decor/water_dispenser.png',
    'assets/office_game/characters/programmer/idle/idle_down.png',
    'assets/office_game/characters/designer/idle/idle_down.png',
    'assets/office_game/characters/pm/idle/idle_down.png',
    'assets/office_game/characters/tester/idle/idle_down.png',
    'assets/office_game/characters/ops/idle/idle_down.png',
  };

  static const Set<String> delayedAssets = {
    'assets/atlas/家具切图.png',
    'assets/atlas/人物切图.png',
    'assets/office_game/furniture/decor/whiteboard.png',
    'assets/office_game/furniture/decor/plant_round.png',
    'assets/office_game/furniture/decor/plant_spiky.png',
    'assets/office_game/ui/bubble_chat.png',
  };

  static double sceneDpToPhysicalMillimeters(double sceneDp) {
    return sceneDp * sceneDpToMillimeters;
  }

  static double physicalMillimetersToSceneDp(double millimeters) {
    return millimeters / sceneDpToMillimeters;
  }

  static bool withinPhysicalTolerance({
    required double actualSceneDp,
    required double expectedMillimeters,
  }) {
    final expectedSceneDp = physicalMillimetersToSceneDp(expectedMillimeters);
    final delta = (actualSceneDp - expectedSceneDp).abs();
    return delta / expectedSceneDp <= physicalTolerance;
  }
}

class OfficeImageLayoutRule {
  final BoxFit fit;
  final Alignment alignment;
  final String role;

  const OfficeImageLayoutRule({
    required this.fit,
    required this.alignment,
    required this.role,
  });
}
