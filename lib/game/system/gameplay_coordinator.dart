import 'package:flame/components.dart';

import '../core/character_task.dart';
import '../core/seat.dart';
import '../entity/character.dart';
import 'ai_controller.dart';
import 'remote_controller.dart';

typedef SnapshotPayloadBuilder =
    Map<String, dynamic> Function(String networkStatus, String mcpStatus);
typedef EconomyAccumulator = void Function();
typedef TaskAssigner =
    bool Function(Character character, CharacterTask task, {bool force});

class GameplayCoordinator {
  final World world;
  final List<Character> characters;
  final Map<SeatType, List<Seat>> seats;
  final String websocketUrl;
  final bool enableRemoteSync;
  final bool enableMockRemoteCommands;
  final SnapshotPayloadBuilder buildSnapshotPayload;
  final EconomyAccumulator accumulateEconomy;
  final TaskAssigner? assignTask;

  late final AIController aiController;
  late final RemoteSyncController remoteController;

  String networkStatus = 'mock';
  String mcpStatus = 'ready';
  double _snapshotElapsed = 0;

  GameplayCoordinator({
    required this.world,
    required this.characters,
    required this.seats,
    required this.websocketUrl,
    this.enableRemoteSync = true,
    this.enableMockRemoteCommands = false,
    required this.buildSnapshotPayload,
    required this.accumulateEconomy,
    this.assignTask,
  });

  Future<void> onLoad() async {
    aiController = AIController(characters: characters, availableSeats: seats);
    world.add(aiController);

    if (!enableRemoteSync) {
      networkStatus = 'disabled';
      mcpStatus = 'disabled';
      return;
    }

    remoteController = RemoteSyncController(
      characterNames: characters.map((c) => c.name).toList(),
      websocketUrl: websocketUrl,
      enableMockFallback: enableMockRemoteCommands,
    );
    world.add(remoteController);

    remoteController.commandStream.listen(handleRemoteCommand);
    remoteController.statusStream.listen((status) {
      networkStatus = status;
      mcpStatus = status == 'live' ? 'attached' : 'mock-adapter';
    });
  }

  void update(double dt) {
    accumulateEconomy();
    if (!enableRemoteSync) {
      return;
    }

    _snapshotElapsed += dt;
    if (_snapshotElapsed < 2.0) {
      return;
    }
    _snapshotElapsed = 0;
    remoteController.sendSceneSnapshot(
      buildSnapshotPayload(networkStatus, mcpStatus),
    );
  }

  void handleRemoteCommand(RemoteCommand command) {
    Character? character;
    for (final candidate in characters) {
      if (candidate.name == command.characterName) {
        character = candidate;
        break;
      }
    }
    if (character == null) {
      return;
    }

    final task = _taskFromAction(command.action, duration: command.duration);
    if (task == null) {
      return;
    }
    final assigned = assignTask?.call(character, task, force: true) ?? false;
    if (!assigned) {
      aiController.assignTask(character, task, force: true);
    }
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
