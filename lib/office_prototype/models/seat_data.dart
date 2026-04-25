import 'package:flame/components.dart';

import 'character_state.dart';

enum SeatArea { work, meeting, rest }

enum SeatDirection { up, down, left, right }

extension SeatDirectionName on SeatDirection {
  String get assetName {
    switch (this) {
      case SeatDirection.up:
        return 'up';
      case SeatDirection.down:
        return 'down';
      case SeatDirection.left:
        return 'left';
      case SeatDirection.right:
        return 'right';
    }
  }
}

extension SeatAreaName on SeatArea {
  String get label {
    switch (this) {
      case SeatArea.work:
        return '办公';
      case SeatArea.meeting:
        return '会议';
      case SeatArea.rest:
        return '休息';
    }
  }
}

SeatDirection seatDirectionFromJson(String value) {
  switch (value) {
    case 'up':
      return SeatDirection.up;
    case 'left':
      return SeatDirection.left;
    case 'right':
      return SeatDirection.right;
    case 'down':
    default:
      return SeatDirection.down;
  }
}

SeatArea seatAreaFromJson(String value) {
  switch (value) {
    case 'meeting':
      return SeatArea.meeting;
    case 'rest':
      return SeatArea.rest;
    case 'work':
    default:
      return SeatArea.work;
  }
}

class SeatData {
  SeatData({
    required this.id,
    required this.area,
    required this.position,
    required this.direction,
    required this.targetState,
    required this.backLayer,
    required this.frontLayer,
  });

  final String id;
  final SeatArea area;
  final Vector2 position;
  final SeatDirection direction;
  final CharacterState targetState;
  final String backLayer;
  final String frontLayer;
  String? occupiedBy;

  bool get isOccupied => occupiedBy != null;

  factory SeatData.fromJson(Map<String, dynamic> json) {
    return SeatData(
      id: json['id'] as String,
      area: seatAreaFromJson((json['type'] ?? json['area']) as String),
      position: Vector2(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
      ),
      direction: seatDirectionFromJson(json['direction'] as String),
      targetState: characterStateFromJson(json['targetState'] as String),
      backLayer: json['backLayer'] as String,
      frontLayer: json['frontLayer'] as String,
    );
  }
}
