import 'dart:convert';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../core/office_asset_policy.dart';
import 'layout_file_loader_stub.dart'
    if (dart.library.io) 'layout_file_loader_io.dart';

class CharacterSpawnConfig {
  final String name;
  final String spriteBaseName;
  final Vector2 position;
  final List<String>? animationFrames;
  final String? motionAtlasBasePath;

  const CharacterSpawnConfig({
    required this.name,
    required this.spriteBaseName,
    required this.position,
    this.animationFrames,
    this.motionAtlasBasePath,
  });

  factory CharacterSpawnConfig.fromJson(Map<String, dynamic> json) {
    return CharacterSpawnConfig(
      name: json['name'] as String,
      spriteBaseName: json['spriteBaseName'] as String,
      position: _vectorFromJson(json['position'] as Map<String, dynamic>),
      animationFrames:
          (json['animationFrames'] as List<dynamic>?)
              ?.map((item) => item as String)
              .toList(),
      motionAtlasBasePath: json['motionAtlasBasePath'] as String?,
    );
  }
}

class ZoneConfig {
  final String name;
  final Vector2 position;
  final Vector2 size;
  final Color color;

  const ZoneConfig({
    required this.name,
    required this.position,
    required this.size,
    required this.color,
  });

  factory ZoneConfig.fromJson(Map<String, dynamic> json) {
    return ZoneConfig(
      name: json['name'] as String,
      position: _vectorFromJson(json['position'] as Map<String, dynamic>),
      size: _vectorFromJson(json['size'] as Map<String, dynamic>),
      color: _colorFromHex(json['color'] as String),
    );
  }
}

class SeatPlacementConfig {
  final Vector2 position;
  final String? direction;
  final bool exactPosition;

  const SeatPlacementConfig({
    required this.position,
    this.direction,
    this.exactPosition = false,
  });

  factory SeatPlacementConfig.fromJson(Map<String, dynamic> json) {
    return SeatPlacementConfig(
      position: _vectorFromJson(json['position'] as Map<String, dynamic>),
      direction: json['direction'] as String?,
      exactPosition: json['exactPosition'] as bool? ?? false,
    );
  }
}

class FurniturePlacementConfig {
  final String spritePath;
  final Vector2 position;
  final Vector2 size;
  final List<SeatPlacementConfig> seats;
  final bool behindCharacters;
  final int priorityOffset;
  final double angleDegrees;

  const FurniturePlacementConfig({
    required this.spritePath,
    required this.position,
    required this.size,
    this.seats = const [],
    this.behindCharacters = false,
    this.priorityOffset = 0,
    this.angleDegrees = 0,
  });

  factory FurniturePlacementConfig.fromJson(Map<String, dynamic> json) {
    return FurniturePlacementConfig(
      spritePath: json['spritePath'] as String,
      position: _vectorFromJson(json['position'] as Map<String, dynamic>),
      size: _vectorFromJson(json['size'] as Map<String, dynamic>),
      seats:
          (json['seats'] as List<dynamic>? ?? const [])
              .map(
                (item) =>
                    SeatPlacementConfig.fromJson(item as Map<String, dynamic>),
              )
              .toList(),
      behindCharacters: json['behindCharacters'] as bool? ?? false,
      priorityOffset: json['priorityOffset'] as int? ?? 0,
      angleDegrees: (json['angleDegrees'] as num?)?.toDouble() ?? 0,
    );
  }
}

class DecorationSpriteConfig {
  final String path;
  final Vector2 position;
  final Vector2 size;
  final int priority;

  const DecorationSpriteConfig({
    required this.path,
    required this.position,
    required this.size,
    this.priority = -39,
  });

  factory DecorationSpriteConfig.fromJson(Map<String, dynamic> json) {
    return DecorationSpriteConfig(
      path: json['path'] as String,
      position: _vectorFromJson(json['position'] as Map<String, dynamic>),
      size: _vectorFromJson(json['size'] as Map<String, dynamic>),
      priority: json['priority'] as int? ?? -39,
    );
  }
}

class DecorationConfig {
  final String waterDispenserSpritePath;
  final Vector2 waterDispenserPosition;
  final Vector2 waterDispenserSize;
  final String plantSpritePath;
  final Vector2 plantSize;
  final List<Vector2> plantPositions;
  final List<DecorationSpriteConfig> extraSprites;

  const DecorationConfig({
    required this.waterDispenserSpritePath,
    required this.waterDispenserPosition,
    required this.waterDispenserSize,
    required this.plantSpritePath,
    required this.plantSize,
    required this.plantPositions,
    this.extraSprites = const [],
  });

  factory DecorationConfig.fromJson(Map<String, dynamic> json) {
    return DecorationConfig(
      waterDispenserSpritePath: json['waterDispenserSpritePath'] as String,
      waterDispenserPosition: _vectorFromJson(
        json['waterDispenserPosition'] as Map<String, dynamic>,
      ),
      waterDispenserSize: _vectorFromJson(
        json['waterDispenserSize'] as Map<String, dynamic>,
      ),
      plantSpritePath: json['plantSpritePath'] as String,
      plantSize: _vectorFromJson(json['plantSize'] as Map<String, dynamic>),
      plantPositions:
          (json['plantPositions'] as List<dynamic>)
              .map((item) => _vectorFromJson(item as Map<String, dynamic>))
              .toList(),
      extraSprites:
          (json['extraSprites'] as List<dynamic>? ?? const [])
              .map(
                (item) => DecorationSpriteConfig.fromJson(
                  item as Map<String, dynamic>,
                ),
              )
              .toList(),
    );
  }
}

class OfficeSceneConfig {
  static const String layoutAsset = 'assets/data/office_game_layout.json';
  static const String floorAsset =
      'assets/environment/office_background_cutout.png';
  static const String floorFallbackAsset = 'assets/environment/floor.png';
  static const String assetRoot = 'assets/office_game';

  static Vector2 sceneSize = Vector2(1600, 1000);
  static List<ZoneConfig> zones = _defaultZones();
  static List<FurniturePlacementConfig> desks = _defaultDesks();
  static List<FurniturePlacementConfig> sofas = _defaultSofas();
  static List<FurniturePlacementConfig> meetingFurniture =
      _defaultMeetingFurniture();
  static List<CharacterSpawnConfig> characters = _defaultCharacters();
  static DecorationConfig decorations = _defaultDecorations();

  static Future<void> load() async {
    final raw = await _loadLayoutAsset();
    final json = jsonDecode(raw) as Map<String, dynamic>;

    sceneSize = _vectorFromJson(json['sceneSize'] as Map<String, dynamic>);
    zones =
        (json['zones'] as List<dynamic>)
            .map((item) => ZoneConfig.fromJson(item as Map<String, dynamic>))
            .toList();
    desks =
        (json['desks'] as List<dynamic>)
            .map(
              (item) => FurniturePlacementConfig.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList();
    sofas =
        (json['sofas'] as List<dynamic>)
            .map(
              (item) => FurniturePlacementConfig.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList();
    meetingFurniture =
        (json['meetingFurniture'] as List<dynamic>)
            .map(
              (item) => FurniturePlacementConfig.fromJson(
                item as Map<String, dynamic>,
              ),
            )
            .toList();
    characters =
        (json['characters'] as List<dynamic>)
            .map(
              (item) =>
                  CharacterSpawnConfig.fromJson(item as Map<String, dynamic>),
            )
            .toList();
    decorations = DecorationConfig.fromJson(
      json['decorations'] as Map<String, dynamic>,
    );
  }

  static Future<String> _loadLayoutAsset() async {
    final projectAsset = await tryLoadProjectAsset(layoutAsset);
    if (projectAsset != null) {
      return projectAsset;
    }

    if (!kIsWeb) {
      return rootBundle.loadString(layoutAsset, cache: false);
    }

    final cacheBuster = DateTime.now().microsecondsSinceEpoch;
    final assetUri = Uri.base.resolve('assets/$layoutAsset?v=$cacheBuster');
    try {
      final response = await http.get(assetUri);
      if (response.statusCode == 200) {
        return utf8.decode(response.bodyBytes);
      }
      throw StateError('Layout asset HTTP ${response.statusCode}');
    } catch (_) {
      return rootBundle.loadString(layoutAsset, cache: false);
    }
  }

  static List<ZoneConfig> _defaultZones() {
    return [
      ZoneConfig(
        name: '工作区 (办公桌)',
        position: Vector2(145, 292),
        size: Vector2(390, 520),
        color: const Color(0xFF2E74D8),
      ),
      ZoneConfig(
        name: '讨论区 (会议桌)',
        position: Vector2(615, 300),
        size: Vector2(370, 510),
        color: const Color(0xFF55A844),
      ),
      ZoneConfig(
        name: '休息区 (沙发)',
        position: Vector2(1055, 292),
        size: Vector2(390, 525),
        color: const Color(0xFFF08422),
      ),
    ];
  }

  static List<FurniturePlacementConfig> _defaultDesks() {
    return [
      _desk('$assetRoot/furniture/desks/desk_laptop.png', 160, 200, 180, 236),
      _desk(
        '$assetRoot/furniture/desks/desk_monitor_drawer.png',
        340,
        200,
        360,
        236,
      ),
      _desk(
        '$assetRoot/furniture/desks/desk_laptop_books.png',
        520,
        200,
        540,
        236,
      ),
      _desk(
        '$assetRoot/furniture/desks/desk_monitor_notes.png',
        160,
        420,
        180,
        456,
      ),
      _desk(
        '$assetRoot/furniture/desks/desk_bookshelf.png',
        340,
        420,
        360,
        456,
      ),
    ];
  }

  static FurniturePlacementConfig _desk(
    String spritePath,
    double deskX,
    double deskY,
    double seatX,
    double seatY,
  ) {
    return FurniturePlacementConfig(
      spritePath: spritePath,
      position: Vector2(deskX, deskY),
      size: Vector2(
        OfficeAssetPolicy.physicalMillimetersToSceneDp(1200),
        OfficeAssetPolicy.physicalMillimetersToSceneDp(904),
      ),
      seats: [
        SeatPlacementConfig(position: Vector2(seatX, seatY), direction: 'up'),
      ],
      behindCharacters: true,
      angleDegrees: 0,
    );
  }

  static List<FurniturePlacementConfig> _defaultSofas() {
    return [
      FurniturePlacementConfig(
        spritePath: '$assetRoot/furniture/lounge/coffee_table.png',
        position: Vector2(1292, 360),
        size: Vector2(
          OfficeAssetPolicy.physicalMillimetersToSceneDp(1200),
          OfficeAssetPolicy.physicalMillimetersToSceneDp(704),
        ),
        behindCharacters: true,
      ),
      FurniturePlacementConfig(
        spritePath: '$assetRoot/furniture/lounge/sofa_3seat.png',
        position: Vector2(1290, 330),
        size: Vector2(315, 190),
        seats: [
          SeatPlacementConfig(position: Vector2(1210, 230), direction: 'down'),
          SeatPlacementConfig(position: Vector2(1380, 230), direction: 'down'),
          SeatPlacementConfig(position: Vector2(1290, 336), direction: 'down'),
          SeatPlacementConfig(position: Vector2(1210, 430), direction: 'up'),
          SeatPlacementConfig(position: Vector2(1380, 430), direction: 'up'),
        ],
        behindCharacters: true,
      ),
      FurniturePlacementConfig(
        spritePath: '$assetRoot/furniture/lounge/sofa_1seat.png',
        position: Vector2(1210, 200),
        size: Vector2(135, 120),
        behindCharacters: true,
      ),
      FurniturePlacementConfig(
        spritePath: '$assetRoot/furniture/lounge/sofa_1seat.png',
        position: Vector2(1380, 200),
        size: Vector2(135, 120),
        behindCharacters: true,
      ),
      FurniturePlacementConfig(
        spritePath: '$assetRoot/furniture/lounge/sofa_1seat.png',
        position: Vector2(1210, 460),
        size: Vector2(135, 120),
        behindCharacters: true,
      ),
      FurniturePlacementConfig(
        spritePath: '$assetRoot/furniture/lounge/sofa_1seat.png',
        position: Vector2(1380, 460),
        size: Vector2(135, 120),
        behindCharacters: true,
      ),
    ];
  }

  static List<FurniturePlacementConfig> _defaultMeetingFurniture() {
    return [
      FurniturePlacementConfig(
        spritePath: '$assetRoot/furniture/meeting/meeting_table_7seat.png',
        position: Vector2(840, 320),
        size: Vector2(520, 230),
        seats: [
          SeatPlacementConfig(position: Vector2(800, 192), direction: 'down'),
          SeatPlacementConfig(position: Vector2(686, 245), direction: 'right'),
          SeatPlacementConfig(position: Vector2(686, 340), direction: 'right'),
          SeatPlacementConfig(position: Vector2(760, 438), direction: 'up'),
          SeatPlacementConfig(position: Vector2(900, 438), direction: 'up'),
          SeatPlacementConfig(position: Vector2(995, 340), direction: 'left'),
          SeatPlacementConfig(position: Vector2(995, 245), direction: 'left'),
        ],
        behindCharacters: true,
        priorityOffset: -30,
        angleDegrees: 0,
      ),
    ];
  }

  static List<CharacterSpawnConfig> _defaultCharacters() {
    return [
      CharacterSpawnConfig(
        name: '程序员',
        spriteBaseName: 'programmer',
        position: Vector2(180, 220),
        motionAtlasBasePath: '$assetRoot/characters/programmer',
      ),
      CharacterSpawnConfig(
        name: '设计师',
        spriteBaseName: 'designer',
        position: Vector2(360, 220),
        motionAtlasBasePath: '$assetRoot/characters/designer',
      ),
      CharacterSpawnConfig(
        name: '项目经理',
        spriteBaseName: 'pm',
        position: Vector2(540, 220),
        motionAtlasBasePath: '$assetRoot/characters/pm',
      ),
      CharacterSpawnConfig(
        name: '测试',
        spriteBaseName: 'tester',
        position: Vector2(180, 440),
        motionAtlasBasePath: '$assetRoot/characters/tester',
      ),
      CharacterSpawnConfig(
        name: '运营',
        spriteBaseName: 'ops',
        position: Vector2(360, 440),
        motionAtlasBasePath: '$assetRoot/characters/ops',
      ),
    ];
  }

  static DecorationConfig _defaultDecorations() {
    return DecorationConfig(
      waterDispenserSpritePath:
          '$assetRoot/furniture/decor/water_dispenser.png',
      waterDispenserPosition: Vector2(600, 585),
      waterDispenserSize: Vector2(72, 132),
      plantSpritePath: '$assetRoot/furniture/decor/plant_large.png',
      plantSize: Vector2(76, 136),
      plantPositions: [Vector2(70, 180), Vector2(1490, 170), Vector2(70, 560)],
      extraSprites: [
        DecorationSpriteConfig(
          path: '$assetRoot/furniture/decor/whiteboard.png',
          position: Vector2(840, 170),
          size: Vector2(176, 118),
        ),
        DecorationSpriteConfig(
          path: '$assetRoot/furniture/decor/plant_round.png',
          position: Vector2(1520, 350),
          size: Vector2(84, 110),
        ),
        DecorationSpriteConfig(
          path: '$assetRoot/furniture/decor/plant_spiky.png',
          position: Vector2(1160, 580),
          size: Vector2(84, 118),
        ),
        DecorationSpriteConfig(
          path: '$assetRoot/furniture/desks/desk_bookshelf.png',
          position: Vector2(100, 700),
          size: Vector2(210, 120),
        ),
      ],
    );
  }
}

Vector2 _vectorFromJson(Map<String, dynamic> json) {
  return Vector2((json['x'] as num).toDouble(), (json['y'] as num).toDouble());
}

Color _colorFromHex(String value) {
  final normalized = value.replaceFirst('#', '');
  final hex = normalized.length == 6 ? 'FF$normalized' : normalized;
  return Color(int.parse(hex, radix: 16));
}
