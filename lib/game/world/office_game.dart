import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import '../core/asset_catalog.dart';
import '../core/character_task.dart';
import '../core/enums.dart';
import '../entity/character.dart';
import '../entity/furniture.dart';
import '../core/seat.dart';
import '../system/gameplay_coordinator.dart';
import '../ui/hud.dart';
import 'scene_builder.dart';
import 'scene_config.dart';

class OfficeGame extends FlameGame
    with HasCollisionDetection, PanDetector, ScrollDetector, TapDetector {
  static const int _characterPriorityBase = 1000;
  static const int _furniturePriorityBase = 2000;
  late final GameplayCoordinator gameplayCoordinator;
  final List<Character> characters = [];
  final Map<SeatType, List<Seat>> seats = {
    SeatType.desk: [],
    SeatType.sofa: [],
    SeatType.meeting: [],
  };

  // Global game stats
  double totalProductivity = 0.0;
  double balance = 1000.0;
  double gameTime = 0.0;
  String lastCommandText = '点击区域派发任务';
  String get networkStatus => gameplayCoordinator.networkStatus;
  String get mcpStatus => gameplayCoordinator.mcpStatus;

  @override
  Future<void> onLoad() async {
    images.prefix = '';
    await GameAssetCatalog.instance.load();
    await OfficeSceneConfig.load();

    final sceneBuilder = OfficeSceneBuilder(game: this, world: world);
    await sceneBuilder.buildBackground();
    sceneBuilder.buildZones();
    sceneBuilder.buildFurnitureAndSeats(seats);
    sceneBuilder.buildCharacters(characters);
    await sceneBuilder.buildDecorations();

    gameplayCoordinator = GameplayCoordinator(
      world: world,
      characters: characters,
      seats: seats,
      websocketUrl: const String.fromEnvironment('OFFICE_WS_URL'),
      accumulateEconomy: _accumulateEconomy,
      buildSnapshotPayload: _buildSnapshotPayload,
    );
    await gameplayCoordinator.onLoad();

    camera.viewport.add(OfficeHUD());
    camera.viewfinder.zoom = 1.0;
    camera.viewfinder.anchor = Anchor.topLeft;
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    camera.viewfinder.position -= info.delta.global;
  }

  @override
  void onScroll(PointerScrollInfo info) {
    final zoomDelta = info.scrollDelta.global.y > 0 ? -0.1 : 0.1;
    camera.viewfinder.zoom = (camera.viewfinder.zoom + zoomDelta).clamp(
      0.5,
      2.0,
    );
  }

  void resetCamera() {
    camera.viewfinder.position = Vector2.zero();
    camera.viewfinder.zoom = 1.0;
    camera.viewfinder.anchor = Anchor.topLeft;
  }

  @override
  void onTapDown(TapDownInfo info) {
    final point = camera.globalToLocal(info.eventPosition.global);
    for (final zone in OfficeSceneConfig.zones) {
      if (_containsPoint(zone.position, zone.size, point)) {
        _assignZoneTask(zone.name);
        return;
      }
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    gameTime += dt;
    gameplayCoordinator.update(gameTime);
    _sortComponentsByY();
  }

  void _accumulateEconomy() {
    double currentProduction = 0;
    for (final character in characters) {
      currentProduction += character.productivityContribution;
      character.productivityContribution = 0;
    }

    if (currentProduction <= 0) {
      return;
    }
    totalProductivity += currentProduction;
    balance += currentProduction * 10;
  }

  bool _containsPoint(Vector2 position, Vector2 size, Vector2 point) {
    return point.x >= position.x &&
        point.y >= position.y &&
        point.x <= position.x + size.x &&
        point.y <= position.y + size.y;
  }

  void _assignZoneTask(String zoneName) {
    final task =
        zoneName.contains('工作')
            ? const CharacterTask.work(duration: 22, source: 'tap')
            : zoneName.contains('讨论')
            ? const CharacterTask.meeting(duration: 14, source: 'tap')
            : const CharacterTask.rest(duration: 16, source: 'tap');

    final candidates = characters.where((c) => c.readyForAssignment).toList();
    if (candidates.isEmpty) {
      lastCommandText = '暂时没有空闲角色';
      return;
    }

    candidates.sort((a, b) => a.energy.compareTo(b.energy));
    final selected =
        task.targetState == CharacterState.rest
            ? candidates.first
            : candidates.last;

    final assigned = gameplayCoordinator.aiController.assignTask(
      selected,
      task,
      force: true,
    );
    lastCommandText =
        assigned ? '${selected.name} -> ${task.label}' : '${task.label} 座位已满';
  }

  Map<String, dynamic> _buildSnapshotPayload(
    String networkStatus,
    String mcpStatus,
  ) {
    return {
      'type': 'scene_snapshot',
      'networkStatus': networkStatus,
      'mcpStatus': mcpStatus,
      'balance': balance,
      'productivity': totalProductivity,
      'characters':
          characters
              .map(
                (character) => {
                  'name': character.name,
                  'state': character.current?.name ?? 'idle',
                  'stateLabel': character.stateLabel,
                  'energy': character.energy,
                },
              )
              .toList(),
    };
  }

  void _sortComponentsByY() {
    for (final child in world.children) {
      if (child is PositionComponent &&
          (child is Character || child is Furniture)) {
        final bottomY = child.y + (1 - child.anchor.y) * child.height;
        if (child is Character) {
          // Keep characters above every static background/decor layer.
          child.priority = _characterPriorityBase + bottomY.toInt();
        } else if (child is Furniture) {
          final int base =
              child.depthMode == FurnitureDepthMode.behindCharacters
                  ? _characterPriorityBase - 220
                  : _furniturePriorityBase;
          child.priority = base + bottomY.toInt() + child.priorityOffset;
        }
      }
    }
  }
}
