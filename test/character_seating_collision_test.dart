import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:office_sim/game/core/seat.dart';
import 'package:office_sim/game/entity/furniture.dart';

void main() {
  test('seat approach points stay outside the path avoidance bounds', () {
    final seats =
        ['up', 'down', 'left', 'right']
            .map(
              (direction) => Seat(
                position: Vector2(260, 392),
                type: SeatType.desk,
                direction: direction,
                obstacleId: 'desk_0',
              ),
            )
            .toList();
    final furniture = Furniture(
      spritePath: 'assets/office_game/furniture/desks/desk_chair_row2_01.png',
      position: Vector2(260, 335),
      size: Vector2(160, 186),
      seats: seats,
      obstacleId: 'desk_0',
    );

    for (final seat in seats) {
      final approachPoint = furniture.approachPointForSeat(seat);

      // Keep this in sync with Character._pathPadding. The approach point must
      // sit outside the inflated navigation rectangle, otherwise characters can
      // keep rerouting around the same chair they are trying to use.
      final pathAvoidanceBounds = furniture.navigationWorldRect().inflate(34);

      expect(
        pathAvoidanceBounds.contains(Offset(approachPoint.x, approachPoint.y)),
        isFalse,
        reason:
            '${seat.direction} approach point should be outside avoidance bounds',
      );
    }
  });

  test('desk chair bounds include the visible chair footprint', () {
    final seat = Seat(
      position: Vector2(260, 392),
      type: SeatType.desk,
      direction: 'up',
      obstacleId: 'desk_0',
    );
    final furniture = Furniture(
      spritePath: 'assets/office_game/furniture/desks/desk_chair_row2_01.png',
      position: Vector2(260, 335),
      size: Vector2(160, 186),
      seats: [seat],
      obstacleId: 'desk_0',
    );

    expect(
      furniture.navigationWorldRect().contains(const Offset(260, 490)),
      isTrue,
      reason: 'navigation should reserve the chair space in front of the desk',
    );
    expect(
      furniture.collisionWorldRect().contains(const Offset(260, 490)),
      isTrue,
      reason: 'collision should cover the visible chair footprint',
    );
    expect(
      furniture.approachPointForSeat(seat).y,
      greaterThan(504),
      reason: 'approach point should be below the chair footprint',
    );
  });

  test('standalone chair collision covers more than the bottom edge', () {
    final chair = Furniture(
      spritePath: 'assets/office_game/furniture/meeting/meeting_chair_up.png',
      position: Vector2(804, 646),
      size: Vector2(70, 90),
      seats: const [],
      obstacleId: 'meeting_0',
    );

    expect(chair.collisionWorldRect().contains(const Offset(804, 646)), isTrue);
  });

  test('only standalone chairs can be passed through for assigned seats', () {
    final meetingChair = Furniture(
      spritePath: 'assets/office_game/furniture/meeting/meeting_chair_up.png',
      position: Vector2(804, 646),
      size: Vector2(70, 90),
      seats: const [],
      obstacleId: 'meeting_0',
    );
    final deskWithChair = Furniture(
      spritePath: 'assets/office_game/furniture/desks/desk_chair_row2_01.png',
      position: Vector2(260, 335),
      size: Vector2(160, 186),
      seats: const [],
      obstacleId: 'desk_0',
    );
    final sofaChair = Furniture(
      spritePath: 'assets/office_game/furniture/lounge/sofa_chair_left.png',
      position: Vector2(1132, 456),
      size: Vector2(82, 194),
      seats: const [],
      obstacleId: 'sofa_2',
    );

    expect(meetingChair.allowsAssignedSeatPassThrough, isTrue);
    expect(deskWithChair.allowsAssignedSeatPassThrough, isFalse);
    expect(sofaChair.allowsAssignedSeatPassThrough, isFalse);
  });

  test(
    'only independent chair sprites occlude seated characters as furniture',
    () {
      final meetingChair = Furniture(
        spritePath: 'assets/office_game/furniture/meeting/meeting_chair_up.png',
        position: Vector2(804, 646),
        size: Vector2(70, 90),
        seats: const [],
        obstacleId: 'meeting_0',
      );
      final deskWithChair = Furniture(
        spritePath: 'assets/office_game/furniture/desks/desk_chair_row2_01.png',
        position: Vector2(260, 335),
        size: Vector2(160, 186),
        seats: const [],
        obstacleId: 'desk_0',
      );
      final sofaChair = Furniture(
        spritePath: 'assets/office_game/furniture/lounge/sofa_chair_left.png',
        position: Vector2(1132, 456),
        size: Vector2(82, 194),
        seats: const [],
        obstacleId: 'sofa_2',
      );

      expect(meetingChair.shouldOccludeSeatedCharacters, isTrue);
      expect(deskWithChair.shouldOccludeSeatedCharacters, isFalse);
      expect(sofaChair.shouldOccludeSeatedCharacters, isFalse);
    },
  );
}
