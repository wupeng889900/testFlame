import 'package:flame/components.dart';

import '../core/character_task.dart';
import '../core/seat.dart';
import '../entity/character.dart';
import 'ai_controller.dart';
import 'remote_controller.dart';

typedef SnapshotPayloadBuilder =
    Map<String, dynamic> Function(String networkStatus, String mcpStatus);
typedef EconomyAccumulator = void Function();

class GameplayCoordinator {
  final World world;
  final List<Character> characters;
  final Map<SeatType, List<Seat>> seats;
  final String websocketUrl;
  final SnapshotPayloadBuilder buildSnapshotPayload;
  final EconomyAccumulator accumulateEconomy;

  late final AIController aiController;
  late final RemoteSyncController remoteController;

  String networkStatus = 'mock';
  String mcpStatus = 'ready';

  GameplayCoordinator({
    required this.world,
    required this.characters,
    required this.seats,
    required this.websocketUrl,
    required this.buildSnapshotPayload,
    required this.accumulateEconomy,
  });

  Future<void> onLoad() async {
    aiController = AIController(characters: characters, availableSeats: seats);
    world.add(aiController);

    remoteController = RemoteSyncController(
      characterNames: characters.map((c) => c.name).toList(),
      websocketUrl: websocketUrl,
    );
    world.add(remoteController);

    remoteController.commandStream.listen(handleRemoteCommand);
    remoteController.statusStream.listen((status) {
      networkStatus = status;
      mcpStatus = status == 'live' ? 'attached' : 'mock-adapter';
    });
  }

  void update(double gameTime) {
    accumulateEconomy();
    if ((gameTime * 2).floor() % 4 == 0) {
      remoteController.sendSceneSnapshot(
        buildSnapshotPayload(networkStatus, mcpStatus),
      );
    }
  }

  void handleRemoteCommand(RemoteCommand command) {
    final character = characters.firstWhere(
      (c) => c.name == command.characterName,
    );
    final task = _taskFromAction(command.action, duration: command.duration);
    if (task == null) {
      return;
    }
    aiController.assignTask(character, task, force: true);
  }

  CharacterTask? _taskFromAction(String action, {required double duration}) {
    switch (action) {
      case 'work':
        return CharacterTask.work(duration: duration, source: 'remote');
      case 'rest':
        return CharacterTask.rest(duration: duration, source: 'remote');
      case 'meeting':
        return CharacterTask.meeting(duration: duration, source: 'remote');
      default:
        return null;
    }
  }
}
