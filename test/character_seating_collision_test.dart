import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:office_sim/game/core/seat.dart';
import 'package:office_sim/game/entity/furniture.dart';

void main() {
  test('seat approach points stay outside the path avoidance bounds', () {
    final furniture = Furniture(
      spritePath: 'assets/office_game/furniture/desks/desk_chair_row2_01.png',
      position: Vector2(260, 335),
      size: Vector2(160, 186),
      seats: const [],
      obstacleId: 'desk_0',
    );

    for (final direction in ['up', 'down', 'left', 'right']) {
      final seat = Seat(
        position: Vector2(260, 392),
        type: SeatType.desk,
        direction: direction,
        obstacleId: furniture.obstacleId,
      );
      final approachPoint = furniture.approachPointForSeat(seat);

      // Keep this in sync with Character._pathPadding. The approach point must
      // sit outside the inflated navigation rectangle, otherwise characters can
      // keep rerouting around the same chair they are trying to use.
      final pathAvoidanceBounds = furniture.navigationWorldRect().inflate(34);

      expect(
        pathAvoidanceBounds.contains(Offset(approachPoint.x, approachPoint.y)),
        isFalse,
        reason: '$direction approach point should be outside avoidance bounds',
      );
    }
  });
}
