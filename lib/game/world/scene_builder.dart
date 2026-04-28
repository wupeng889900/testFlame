import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../core/asset_catalog.dart';
import '../core/seat.dart';
import '../entity/character.dart';
import '../entity/furniture.dart';
import 'scene_config.dart';

class OfficeSceneBuilder {
  final FlameGame game;
  final World world;

  const OfficeSceneBuilder({required this.game, required this.world});

  Future<void> buildBackground() async {
    world.add(
      RectangleComponent(
        position: Vector2.zero(),
        size: OfficeSceneConfig.sceneSize,
        anchor: Anchor.topLeft,
        paint: Paint()..color = const Color(0xFF416E86),
        priority: -120,
      ),
    );

    for (final candidatePath in GameAssetCatalog.instance.floorCandidates()) {
      try {
        final sprite = await game.loadSprite(candidatePath);
        world.add(
          SpriteComponent(
            sprite: sprite,
            position: Vector2.zero(),
            anchor: Anchor.topLeft,
            priority: -100,
            size: OfficeSceneConfig.sceneSize.clone(),
            paint:
                Paint()
                  ..color = Colors.white
                  ..filterQuality = FilterQuality.high,
          ),
        );
        break;
      } catch (_) {
        continue;
      }
    }
  }

  void buildZones() {}

  void buildFurnitureAndSeats(Map<SeatType, List<Seat>> seats) {
    _buildFurnitureGroup(OfficeSceneConfig.desks, SeatType.desk, seats);
    _buildFurnitureGroup(OfficeSceneConfig.sofas, SeatType.sofa, seats);
    _buildFurnitureGroup(
      OfficeSceneConfig.meetingFurniture,
      SeatType.meeting,
      seats,
    );
  }

  void _buildFurnitureGroup(
    List<FurniturePlacementConfig> placements,
    SeatType type,
    Map<SeatType, List<Seat>> seatStore,
  ) {
    for (var index = 0; index < placements.length; index++) {
      final placement = placements[index];
      final obstacleId = '${type.name}_$index';
      final placementSeats =
          placement.seats
              .map(
                (seat) => Seat(
                  position: _resolveSeatPosition(placement, seat),
                  type: type,
                  direction: seat.direction,
                  obstacleId: obstacleId,
                ),
              )
              .toList();

      seatStore[type]!.addAll(placementSeats);

      world.add(
        Furniture(
          spritePath: placement.spritePath,
          position: placement.position,
          size: placement.size,
          seats: placementSeats,
          obstacleId: obstacleId,
          angleDegrees: placement.angleDegrees,
          depthMode:
              placement.behindCharacters
                  ? FurnitureDepthMode.behindCharacters
                  : FurnitureDepthMode.inFrontOfCharacters,
          priorityOffset: placement.priorityOffset,
        ),
      );
    }
  }

  Vector2 _resolveSeatPosition(
    FurniturePlacementConfig placement,
    SeatPlacementConfig seat,
  ) {
    if (seat.exactPosition) {
      return seat.position.clone();
    }

    const double margin = 14.0;
    final localSeatOffset = seat.position - placement.position;
    final radians = placement.angleDegrees * math.pi / 180;
    final rotatedOffset =
        placement.angleDegrees == 0
            ? localSeatOffset
            : Vector2(
              localSeatOffset.x * math.cos(radians) -
                  localSeatOffset.y * math.sin(radians),
              localSeatOffset.x * math.sin(radians) +
                  localSeatOffset.y * math.cos(radians),
            );
    final effectiveSize =
        placement.angleDegrees.abs() % 180 == 90
            ? Vector2(placement.size.y, placement.size.x)
            : placement.size;
    final resolved = placement.position + rotatedOffset;
    final left = placement.position.x - effectiveSize.x / 2;
    final right = placement.position.x + effectiveSize.x / 2;
    final top = placement.position.y - effectiveSize.y / 2;
    final bottom = placement.position.y + effectiveSize.y / 2;

    switch (_rotateDirection(seat.direction, placement.angleDegrees)) {
      case 'up':
        resolved.y = bottom + margin;
        break;
      case 'down':
        resolved.y = top - margin;
        break;
      case 'left':
        resolved.x = right + margin;
        break;
      case 'right':
        resolved.x = left - margin;
        break;
    }

    return resolved;
  }

  String? _rotateDirection(String? direction, double angleDegrees) {
    if (direction == null) {
      return null;
    }

    final normalizedQuarterTurns = ((angleDegrees / 90).round() % 4 + 4) % 4;
    const order = ['up', 'right', 'down', 'left'];
    final currentIndex = order.indexOf(direction);
    if (currentIndex == -1) {
      return direction;
    }
    return order[(currentIndex + normalizedQuarterTurns) % order.length];
  }

  void buildCharacters(List<Character> characters) {
    for (final spawn in OfficeSceneConfig.characters) {
      final character = Character(
        name: spawn.name,
        spriteSheetPath: '',
        position: spawn.position,
        animationFrames: spawn.animationFrames,
        motionAtlasBasePath: spawn.motionAtlasBasePath,
      );
      characters.add(character);
      world.add(character);
    }
  }

  Future<void> buildDecorations() async {
    final decorations = OfficeSceneConfig.decorations;
    Future<void> addSprite({
      required String path,
      required Vector2 position,
      required Vector2 size,
      int priority = -40,
    }) async {
      final sprite = await game.loadSprite(path);
      world.add(
        SpriteComponent(
          sprite: sprite,
          position: position,
          size: size,
          anchor: Anchor.center,
          priority: priority,
          paint: Paint()..filterQuality = FilterQuality.none,
        ),
      );
    }

    try {
      await addSprite(
        path: decorations.waterDispenserSpritePath,
        position: decorations.waterDispenserPosition,
        size: decorations.waterDispenserSize,
      );
    } catch (_) {
      world.add(
        RectangleComponent(
          position: decorations.waterDispenserPosition,
          size: decorations.waterDispenserSize,
          paint: Paint()..color = Colors.lightBlueAccent.withValues(alpha: 0.5),
          priority: -40,
        )..anchor = Anchor.center,
      );
    }

    for (final pos in decorations.plantPositions) {
      try {
        final plantSprite = await game.loadSprite(decorations.plantSpritePath);
        world.add(
          SpriteComponent(
            sprite: plantSprite,
            position: pos,
            size: decorations.plantSize,
            anchor: Anchor.center,
            priority: -40,
            paint: Paint()..filterQuality = FilterQuality.none,
          ),
        );
      } catch (_) {
        world.add(
          CircleComponent(
            radius: 15,
            position: pos,
            paint: Paint()..color = Colors.green.withValues(alpha: 0.6),
            priority: -40,
          )..anchor = Anchor.center,
        );
      }
    }

    for (final item in decorations.extraSprites) {
      try {
        await addSprite(
          path: item.path,
          position: item.position,
          size: item.size,
          priority: item.priority,
        );
      } catch (_) {
        continue;
      }
    }
  }
}
