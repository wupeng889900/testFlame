import 'enums.dart';
import 'seat.dart';

class CharacterTask {
  final SeatType seatType;
  final CharacterState targetState;
  final double duration;
  final String source;

  const CharacterTask({
    required this.seatType,
    required this.targetState,
    required this.duration,
    this.source = 'ai',
  });

  const CharacterTask.work({
    double duration = 20,
    String source = 'ai',
  }) : this(
         seatType: SeatType.desk,
         targetState: CharacterState.work,
         duration: duration,
         source: source,
       );

  const CharacterTask.rest({
    double duration = 14,
    String source = 'ai',
  }) : this(
         seatType: SeatType.sofa,
         targetState: CharacterState.rest,
         duration: duration,
         source: source,
       );

  const CharacterTask.meeting({
    double duration = 10,
    String source = 'ai',
  }) : this(
         seatType: SeatType.meeting,
         targetState: CharacterState.meeting,
         duration: duration,
         source: source,
       );

  String get label {
    switch (targetState) {
      case CharacterState.work:
        return '工作中';
      case CharacterState.rest:
        return '休息中';
      case CharacterState.meeting:
        return '讨论中';
      case CharacterState.walk:
        return '移动中';
      case CharacterState.idle:
        return '空闲中';
    }
  }
}
