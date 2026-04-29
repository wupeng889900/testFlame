import 'package:flutter/painting.dart';

class OfficeAssetPolicy {
  const OfficeAssetPolicy._();

  static const double sceneDpToMillimeters = 8.0;
  static const double physicalTolerance = 0.02;

  static const Map<String, OfficeImageLayoutRule> layoutRules = {
    'assets/environment/office_background_cutout.png': OfficeImageLayoutRule(
      fit: BoxFit.contain,
      alignment: Alignment.center,
      role: 'office background',
    ),
    'assets/office_game/furniture/desks/desk_chair_row2_01.png':
        OfficeImageLayoutRule(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          role: 'desk with chair',
        ),
    'assets/office_game/furniture/meeting/meeting_table_top.png':
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
    'assets/office_game/furniture/lounge/sofa_chair_left.png':
        OfficeImageLayoutRule(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          role: 'lounge chair left',
        ),
    'assets/office_game/furniture/lounge/sofa_chair_right.png':
        OfficeImageLayoutRule(
          fit: BoxFit.contain,
          alignment: Alignment.center,
          role: 'lounge chair right',
        ),
    'assets/office_game/furniture/decor/whiteboard.png': OfficeImageLayoutRule(
      fit: BoxFit.contain,
      alignment: Alignment.center,
      role: 'whiteboard',
    ),
  };

  static const Set<String> firstScreenAssets = {
    'assets/data/office_game_layout.json',
    'assets/environment/office_background_cutout.png',
    'assets/office_game/furniture/desks/desk_chair_row2_01.png',
    'assets/office_game/furniture/desks/desk_chair_row2_02.png',
    'assets/office_game/furniture/desks/desk_chair_row2_03.png',
    'assets/office_game/furniture/desks/desk_chair_row2_04.png',
    'assets/office_game/furniture/desks/desk_chair_row2_05.png',
    'assets/office_game/furniture/desks/desk_chair_row2_06.png',
    'assets/office_game/furniture/meeting/meeting_table_top.png',
    'assets/office_game/furniture/meeting/meeting_chair_down.png',
    'assets/office_game/furniture/meeting/meeting_chair_left.png',
    'assets/office_game/furniture/meeting/meeting_chair_right.png',
    'assets/office_game/furniture/meeting/meeting_chair_up.png',
    'assets/office_game/furniture/lounge/sofa_3seat.png',
    'assets/office_game/furniture/lounge/sofa_chair_left.png',
    'assets/office_game/furniture/lounge/sofa_chair_right.png',
    'assets/office_game/furniture/lounge/sofa_bottom.png',
    'assets/office_game/ui/bubble_active.png',
    'assets/office_game/ui/bubble_chat.png',
    'assets/office_game/ui/bubble_sleep.png',
    'assets/office_game/ui/selected_ring.png',
    'assets/office_game/furniture/chairs/office_chair_back.png',
    'assets/office_game/furniture/decor/whiteboard.png',
    'assets/office_game/characters/programmer/idle/idle_down.png',
    'assets/office_game/characters/designer/idle/idle_down.png',
    'assets/office_game/characters/pm/idle/idle_down.png',
    'assets/office_game/characters/tester/idle/idle_down.png',
    'assets/office_game/characters/ops/idle/idle_down.png',
  };

  static const Set<String> delayedAssets = {
    'assets/office_game/characters/programmer/meeting_seated/meeting_seated_right.png',
    'assets/office_game/characters/designer/meeting_seated/meeting_seated_left.png',
    'assets/office_game/characters/pm/meeting_seated/meeting_seated_up.png',
    'assets/office_game/characters/tester/meeting_seated/meeting_seated_left.png',
    'assets/office_game/characters/ops/meeting_seated/meeting_seated_right.png',
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
