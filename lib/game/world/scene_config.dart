import 'dart:convert';

import 'package:flame/components.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../core/office_asset_policy.dart';
import '../core/enums.dart';
import 'layout_file_loader_stub.dart'
    if (dart.library.io) 'layout_file_loader_io.dart';

const Set<String> _validSeatDirections = {'left', 'right', 'up', 'down'};

class _LoadedLayoutAsset {
  final String content;
  final bool fromProjectAsset;

  const _LoadedLayoutAsset(this.content, {required this.fromProjectAsset});
}

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

class WalkRouteConfig {
  final String name;
  final List<Vector2> points;

  const WalkRouteConfig({required this.name, required this.points});

  factory WalkRouteConfig.fromJson(Map<String, dynamic> json) {
    return WalkRouteConfig(
      name: json['name'] as String? ?? '主干道',
      points:
          (json['points'] as List<dynamic>? ?? const [])
              .map((item) => _vectorFromJson(item as Map<String, dynamic>))
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
  static Map<String, Map<CharacterState, Vector2>> characterStatePositions =
      _defaultCharacterStatePositions();
  static Map<String, Map<CharacterState, String>> characterStateDirections =
      _defaultCharacterStateDirections();
  static DecorationConfig decorations = _defaultDecorations();
  static List<WalkRouteConfig> walkRoutes = _defaultWalkRoutes();
  static bool loadedFromProjectAsset = false;

  static Future<void> load() async {
    final loaded = await _loadLayoutAsset();
    loadedFromProjectAsset = loaded.fromProjectAsset;
    final raw = loaded.content;
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
    characterStatePositions = _characterStatePositionsFromJson(
      json['characterStatePositions'] as Map<String, dynamic>?,
    );
    characterStateDirections = _characterStateDirectionsFromJson(
      json['characterStatePositions'] as Map<String, dynamic>?,
    );
    decorations = DecorationConfig.fromJson(
      json['decorations'] as Map<String, dynamic>,
    );
    walkRoutes =
        (json['walkRoutes'] as List<dynamic>? ?? const [])
            .map(
              (item) => WalkRouteConfig.fromJson(item as Map<String, dynamic>),
            )
            .where((route) => route.points.length >= 2)
            .toList();
  }

  static Future<_LoadedLayoutAsset> _loadLayoutAsset() async {
    final projectAsset = await tryLoadProjectAsset(layoutAsset);
    if (projectAsset != null) {
      return _LoadedLayoutAsset(projectAsset, fromProjectAsset: true);
    }

    if (!kIsWeb) {
      return _LoadedLayoutAsset(
        await rootBundle.loadString(layoutAsset, cache: false),
        fromProjectAsset: false,
      );
    }

    final cacheBuster = DateTime.now().microsecondsSinceEpoch;
    final assetUri = Uri.base.resolve('assets/$layoutAsset?v=$cacheBuster');
    try {
      final response = await http.get(assetUri);
      if (response.statusCode == 200) {
        return _LoadedLayoutAsset(
          utf8.decode(response.bodyBytes),
          fromProjectAsset: false,
        );
      }
      throw StateError('Layout asset HTTP ${response.statusCode}');
    } catch (_) {
      return _LoadedLayoutAsset(
        await rootBundle.loadString(layoutAsset, cache: false),
        fromProjectAsset: false,
      );
    }
  }

  static Future<bool> saveCharacterStatePositionsToProjectAsset() async {
    final projectAsset = await tryLoadProjectAsset(layoutAsset);
    if (projectAsset == null) {
      return false;
    }

    final json = jsonDecode(projectAsset) as Map<String, dynamic>;
    json['characterStatePositions'] = _characterStatePositionsToJson(
      characterStatePositions,
    );
    const encoder = JsonEncoder.withIndent('  ');
    return trySaveProjectAsset(layoutAsset, '${encoder.convert(json)}\n');
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
        position: Vector2(1288, 457),
        size: Vector2(
          OfficeAssetPolicy.physicalMillimetersToSceneDp(896),
          OfficeAssetPolicy.physicalMillimetersToSceneDp(1344),
        ),
        behindCharacters: true,
      ),
      FurniturePlacementConfig(
        spritePath: '$assetRoot/furniture/lounge/sofa_3seat.png',
        position: Vector2(1288, 255),
        size: Vector2(298, 142),
        seats: [
          SeatPlacementConfig(
            position: Vector2(1210, 286),
            direction: 'down',
            exactPosition: true,
          ),
          SeatPlacementConfig(
            position: Vector2(1288, 286),
            direction: 'down',
            exactPosition: true,
          ),
          SeatPlacementConfig(
            position: Vector2(1366, 286),
            direction: 'down',
            exactPosition: true,
          ),
        ],
        behindCharacters: true,
      ),
      FurniturePlacementConfig(
        spritePath: '$assetRoot/furniture/lounge/sofa_chair_left.png',
        position: Vector2(1132, 456),
        size: Vector2(82, 194),
        seats: [
          SeatPlacementConfig(
            position: Vector2(1132, 456),
            direction: 'right',
            exactPosition: true,
          ),
        ],
        behindCharacters: true,
      ),
      FurniturePlacementConfig(
        spritePath: '$assetRoot/furniture/lounge/sofa_bottom.png',
        position: Vector2(1288, 675),
        size: Vector2(226, 121),
        seats: [
          SeatPlacementConfig(
            position: Vector2(1244, 645),
            direction: 'up',
            exactPosition: true,
          ),
          SeatPlacementConfig(
            position: Vector2(1332, 645),
            direction: 'up',
            exactPosition: true,
          ),
        ],
        behindCharacters: true,
      ),
      FurniturePlacementConfig(
        spritePath: '$assetRoot/furniture/lounge/sofa_chair_right.png',
        position: Vector2(1444, 456),
        size: Vector2(82, 194),
        seats: [
          SeatPlacementConfig(
            position: Vector2(1444, 456),
            direction: 'left',
            exactPosition: true,
          ),
        ],
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

  static Map<String, Map<CharacterState, Vector2>>
  _defaultCharacterStatePositions() {
    return {
      '程序员': {
        CharacterState.work: Vector2(260, 418),
        CharacterState.meeting: Vector2(804, 268),
        CharacterState.rest: Vector2(1210, 286),
      },
      '设计师': {
        CharacterState.work: Vector2(445, 418),
        CharacterState.meeting: Vector2(916, 432),
        CharacterState.rest: Vector2(1288, 286),
      },
      '项目经理': {
        CharacterState.work: Vector2(260, 598),
        CharacterState.meeting: Vector2(804, 656),
        CharacterState.rest: Vector2(1366, 286),
      },
      '测试': {
        CharacterState.work: Vector2(445, 598),
        CharacterState.meeting: Vector2(692, 432),
        CharacterState.rest: Vector2(1132, 456),
      },
      '运营': {
        CharacterState.work: Vector2(260, 783),
        CharacterState.meeting: Vector2(692, 350),
        CharacterState.rest: Vector2(1244, 645),
      },
    };
  }

  static Map<String, Map<CharacterState, String>>
  _defaultCharacterStateDirections() {
    return {
      '程序员': {
        CharacterState.work: 'up',
        CharacterState.meeting: 'down',
        CharacterState.rest: 'down',
      },
      '设计师': {
        CharacterState.work: 'up',
        CharacterState.meeting: 'left',
        CharacterState.rest: 'down',
      },
      '项目经理': {
        CharacterState.work: 'up',
        CharacterState.meeting: 'up',
        CharacterState.rest: 'down',
      },
      '测试': {
        CharacterState.work: 'up',
        CharacterState.meeting: 'right',
        CharacterState.rest: 'right',
      },
      '运营': {
        CharacterState.work: 'up',
        CharacterState.meeting: 'right',
        CharacterState.rest: 'up',
      },
    };
  }

  static Map<String, Map<CharacterState, Vector2>>
  _characterStatePositionsFromJson(Map<String, dynamic>? json) {
    final result = _defaultCharacterStatePositions();
    if (json == null) {
      return result;
    }

    for (final entry in json.entries) {
      final states = entry.value;
      if (states is! Map<String, dynamic>) {
        continue;
      }
      final characterPositions = <CharacterState, Vector2>{
        ...?result[entry.key],
      };
      for (final stateEntry in states.entries) {
        final state = _characterStateFromJsonKey(stateEntry.key);
        final value = stateEntry.value;
        if (state == null || value is! Map<String, dynamic>) {
          continue;
        }
        characterPositions[state] = _vectorFromJson(value);
      }
      result[entry.key] = characterPositions;
    }
    return result;
  }

  static Map<String, Map<CharacterState, String>>
  _characterStateDirectionsFromJson(Map<String, dynamic>? json) {
    final result = _cloneCharacterStateDirections(
      _defaultCharacterStateDirections(),
    );
    if (json == null) {
      return result;
    }

    for (final entry in json.entries) {
      final states = entry.value;
      if (states is! Map<String, dynamic>) {
        continue;
      }
      final characterDirections = <CharacterState, String>{
        ...?result[entry.key],
      };
      for (final stateEntry in states.entries) {
        final state = _characterStateFromJsonKey(stateEntry.key);
        final value = stateEntry.value;
        if (state == null || value is! Map<String, dynamic>) {
          continue;
        }
        final direction = value['direction'];
        if (direction is String && _validSeatDirections.contains(direction)) {
          characterDirections[state] = direction;
        }
      }
      result[entry.key] = characterDirections;
    }
    return result;
  }

  static Map<String, dynamic> _characterStatePositionsToJson(
    Map<String, Map<CharacterState, Vector2>> positions,
  ) {
    return {
      for (final characterEntry in positions.entries)
        characterEntry.key: {
          for (final stateEntry in characterEntry.value.entries)
            _characterStateToJsonKey(stateEntry.key): {
              'x': stateEntry.value.x,
              'y': stateEntry.value.y,
              if (characterStateDirections[characterEntry.key]?[stateEntry
                      .key] !=
                  null)
                'direction':
                    characterStateDirections[characterEntry.key]![stateEntry
                        .key]!,
            },
        },
    };
  }

  static Map<String, Map<CharacterState, String>>
  _cloneCharacterStateDirections(
    Map<String, Map<CharacterState, String>> source,
  ) {
    return {
      for (final characterEntry in source.entries)
        characterEntry.key: {
          for (final stateEntry in characterEntry.value.entries)
            stateEntry.key: stateEntry.value,
        },
    };
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

  static List<WalkRouteConfig> _defaultWalkRoutes() {
    return [
      WalkRouteConfig(
        name: '左侧办公区主干道',
        points: [Vector2(590, 210), Vector2(590, 835)],
      ),
      WalkRouteConfig(
        name: '中右讨论休息区主干道',
        points: [Vector2(1035, 210), Vector2(1035, 835)],
      ),
      WalkRouteConfig(
        name: '顶部横向主干道',
        points: [
          Vector2(170, 210),
          Vector2(590, 210),
          Vector2(1035, 210),
          Vector2(1480, 210),
        ],
      ),
      WalkRouteConfig(
        name: '底部横向主干道',
        points: [
          Vector2(120, 835),
          Vector2(590, 835),
          Vector2(1035, 835),
          Vector2(1480, 835),
        ],
      ),
      WalkRouteConfig(
        name: '左侧斜向通道',
        points: [Vector2(170, 210), Vector2(120, 835)],
      ),
      WalkRouteConfig(
        name: '办公区上排通道',
        points: [Vector2(151, 413), Vector2(590, 412)],
      ),
      WalkRouteConfig(
        name: '办公区下排通道',
        points: [Vector2(135, 612), Vector2(590, 610)],
      ),
      WalkRouteConfig(
        name: '休息区环形通道',
        points: [
          Vector2(1035, 579),
          Vector2(1386, 568),
          Vector2(1380, 343),
          Vector2(1035, 335),
        ],
      ),
      WalkRouteConfig(
        name: '休息区中线通道',
        points: [Vector2(1205, 571), Vector2(1198, 340)],
      ),
      WalkRouteConfig(
        name: '右下沙发接入通道',
        points: [Vector2(1476, 835), Vector2(1386, 568)],
      ),
    ];
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

CharacterState? _characterStateFromJsonKey(String key) {
  switch (key) {
    case 'work':
    case 'working':
      return CharacterState.work;
    case 'meeting':
    case 'discussing':
      return CharacterState.meeting;
    case 'rest':
    case 'resting':
      return CharacterState.rest;
    default:
      return null;
  }
}

String _characterStateToJsonKey(CharacterState state) {
  switch (state) {
    case CharacterState.work:
      return 'work';
    case CharacterState.meeting:
      return 'meeting';
    case CharacterState.rest:
      return 'rest';
    case CharacterState.walk:
      return 'walk';
    case CharacterState.idle:
      return 'idle';
  }
}
