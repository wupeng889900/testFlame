import 'dart:math';
import 'package:flame/components.dart';
import '../entity/character.dart';
import '../core/character_task.dart';
import '../core/enums.dart';
import '../core/seat.dart';
import '../world/scene_config.dart';

class AIController extends Component {
  final List<Character> characters;
  final Map<SeatType, List<Seat>> availableSeats;
  final Random random = Random();
  bool autonomousTasksEnabled = true;

  AIController({required this.characters, required this.availableSeats});

  @override
  void update(double dt) {
    super.update(dt);
    if (!autonomousTasksEnabled) {
      return;
    }

    for (var character in characters) {
      if (character.readyForAssignment) {
        assignAutonomousTask(character);
      }
    }
  }

  void assignAutonomousTask(Character character) {
    if (!character.readyForAssignment) {
      return;
    }

    if (character.energy < 20.0) {
      assignTask(
        character,
        CharacterTask.rest(duration: 15.0 + random.nextDouble() * 10),
      );
      return;
    }

    if (character.energy > 80.0 && random.nextDouble() < 0.7) {
      assignTask(
        character,
        CharacterTask.work(duration: 20.0 + random.nextDouble() * 20),
      );
      return;
    }

    final roll = random.nextDouble();
    if (roll < 0.5) {
      assignTask(
        character,
        CharacterTask.work(duration: 15.0 + random.nextDouble() * 15),
      );
    } else if (roll < 0.8) {
      assignTask(
        character,
        CharacterTask.rest(duration: 10.0 + random.nextDouble() * 10),
      );
    } else {
      assignTask(
        character,
        CharacterTask.meeting(duration: 8.0 + random.nextDouble() * 12),
      );
    }
  }

  bool assignTask(
    Character character,
    CharacterTask task, {
    bool force = false,
  }) {
    final seats = availableSeats[task.seatType] ?? [];
    final freeSeats =
        seats
            .where((s) => s.isAvailable || (force && s.user == character))
            .toList();
    final preferredPosition =
        OfficeSceneConfig.characterStatePositions[character.name]?[task
            .targetState];
    final preferredDirection =
        OfficeSceneConfig.characterStateDirections[character.name]?[task
            .targetState];
    final orderedSeats = _preferredSeatsFor(
      character,
      seats,
      freeSeats,
      fixedToPreferredSeat:
          task.targetState == CharacterState.work ||
          task.targetState == CharacterState.meeting,
      preferredPosition: preferredPosition,
    );

    for (final seat in orderedSeats) {
      final targetPosition = _targetOverrideForSeat(seat, preferredPosition);
      if (character.assignTask(
        task,
        seat,
        force: force,
        targetPositionOverride: targetPosition,
        targetDirectionOverride: preferredDirection,
      )) {
        return true;
      }
    }
    character.idleFor(1.5 + random.nextDouble() * 2.5);
    return false;
  }

  List<Seat> _preferredSeatsFor(
    Character character,
    List<Seat> allSeats,
    List<Seat> freeSeats, {
    bool fixedToPreferredSeat = false,
    Vector2? preferredPosition,
  }) {
    if (freeSeats.isEmpty) {
      return const [];
    }

    if (fixedToPreferredSeat && preferredPosition != null) {
      final fixedSeat = _nearestSeatToPreferredPosition(
        allSeats,
        preferredPosition,
      );
      if (fixedSeat == null ||
          (!fixedSeat.isAvailable && fixedSeat.user != character)) {
        return const [];
      }
      return freeSeats.contains(fixedSeat) ? [fixedSeat] : const [];
    }

    final preferredIndex = _preferredSeatIndex(character.name, allSeats.length);
    final ordered = [...freeSeats];
    ordered.sort((a, b) {
      if (preferredPosition != null) {
        final distanceCompare = a.position
            .distanceTo(preferredPosition)
            .compareTo(b.position.distanceTo(preferredPosition));
        if (distanceCompare != 0) {
          return distanceCompare;
        }
      }
      final aIndex = allSeats.indexOf(a);
      final bIndex = allSeats.indexOf(b);
      final aScore = _circularSeatDistance(
        aIndex,
        preferredIndex,
        allSeats.length,
      );
      final bScore = _circularSeatDistance(
        bIndex,
        preferredIndex,
        allSeats.length,
      );
      if (aScore != bScore) {
        return aScore.compareTo(bScore);
      }
      return aIndex.compareTo(bIndex);
    });
    return ordered;
  }

  Seat? _nearestSeatToPreferredPosition(List<Seat> seats, Vector2 position) {
    if (seats.isEmpty) {
      return null;
    }
    return seats.reduce(
      (a, b) =>
          a.position.distanceTo(position) <= b.position.distanceTo(position)
              ? a
              : b,
    );
  }

  Vector2? _targetOverrideForSeat(Seat seat, Vector2? preferredPosition) {
    if (preferredPosition == null) {
      return null;
    }
    return seat.position.distanceTo(preferredPosition) <= 64.0
        ? preferredPosition.clone()
        : null;
  }

  int _preferredSeatIndex(String characterName, int seatCount) {
    if (seatCount <= 0) {
      return 0;
    }

    final characterIndex = switch (characterName) {
      '程序员' => 0,
      '设计师' => 1,
      '项目经理' => 2,
      '测试' => 3,
      '运营' => 4,
      _ => characterName.codeUnits.fold<int>(0, (sum, unit) => sum + unit),
    };
    return characterIndex % seatCount;
  }

  int _circularSeatDistance(int seatIndex, int preferredIndex, int seatCount) {
    if (seatIndex < 0 || seatCount <= 0) {
      return 1 << 20;
    }
    final forward = (seatIndex - preferredIndex + seatCount) % seatCount;
    final backward = (preferredIndex - seatIndex + seatCount) % seatCount;
    return min(forward, backward);
  }

  void forceTask(
    Character character,
    SeatType type,
    CharacterState targetState,
    double duration,
  ) {
    final task = CharacterTask(
      seatType: type,
      targetState: targetState,
      duration: duration,
      source: 'remote',
    );
    assignTask(character, task, force: true);
  }
}
