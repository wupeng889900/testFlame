import 'package:flame/components.dart';
import '../entity/character.dart';

enum SeatType {
  desk,
  sofa,
  meeting,
}

class Seat {
  final Vector2 position;
  final SeatType type;
  final String? direction; // 'left', 'right', 'up', 'down'
  final String? obstacleId;
  bool occupied = false;
  Character? user;

  Seat({
    required this.position,
    required this.type,
    this.direction,
    this.obstacleId,
  });

  bool get isAvailable => !occupied;

  bool tryReserve(Character character) {
    if (occupied && user != character) {
      return false;
    }
    occupied = true;
    user = character;
    return true;
  }

  void release([Character? character]) {
    if (character != null && user != character) {
      return;
    }
    occupied = false;
    user = null;
  }
}
