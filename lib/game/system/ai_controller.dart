import 'dart:math';
import 'package:flame/components.dart';
import '../entity/character.dart';
import '../core/character_task.dart';
import '../core/enums.dart';
import '../core/seat.dart';

class AIController extends Component {
  final List<Character> characters;
  final Map<SeatType, List<Seat>> availableSeats;
  final Random random = Random();

  AIController({required this.characters, required this.availableSeats});

  @override
  void update(double dt) {
    super.update(dt);

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
    final freeSeats = seats.where((s) => s.isAvailable).toList();

    if (freeSeats.isNotEmpty) {
      final seat = freeSeats[random.nextInt(freeSeats.length)];
      return character.assignTask(task, seat, force: force);
    }
    character.idleFor(1.5 + random.nextDouble() * 2.5);
    return false;
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
