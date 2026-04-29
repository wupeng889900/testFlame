import 'dart:convert';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/asset_catalog.dart';
import '../core/character_task.dart';
import '../core/enums.dart';
import '../entity/character.dart';
import '../entity/furniture.dart';
import '../core/seat.dart';
import '../system/gameplay_coordinator.dart';
import 'scene_builder.dart';
import 'scene_config.dart';

class OfficeGameOptions {
  final bool showEditorTools;
  final bool enableRemoteSync;
  final bool enableMockRemoteCommands;
  final String websocketUrl;

  const OfficeGameOptions({
    this.showEditorTools = false,
    this.enableRemoteSync = true,
    this.enableMockRemoteCommands = false,
    this.websocketUrl = const String.fromEnvironment('OFFICE_WS_URL'),
  });
}

class OfficeGame extends FlameGame
    with PanDetector, ScrollDetector, TapDetector {
  static const String _walkRoutesStorageKey = 'office_walk_routes_v1';
  static const String _characterStatePositionsStorageKey =
      'office_character_state_positions_v1';
  static const Set<String> _seatDirections = {'left', 'right', 'up', 'down'};
  static const int _characterPriorityBase = 1000;
  static const int _furniturePriorityBase = 2000;
  static const double _walkRouteMergeDistance = 36.0;
  final OfficeGameOptions options;
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
  bool walkRouteEditing = false;
  bool characterPositionEditing = false;
  String? selectedCharacterName;
  CharacterState selectedPositionState = CharacterState.work;
  final List<List<Vector2>> walkRoutes = [];
  final List<Vector2> walkRouteDraft = [];
  Map<String, Map<CharacterState, Vector2>> _initialCharacterStatePositions =
      {};
  Map<String, Map<CharacterState, String>> _initialCharacterStateDirections =
      {};
  bool _sceneLoaded = false;
  late final _WalkRouteOverlayComponent _walkRouteOverlay;

  OfficeGame({this.options = const OfficeGameOptions()});

  @override
  Future<void> onLoad() async {
    images.prefix = '';
    await GameAssetCatalog.instance.load();
    await OfficeSceneConfig.load();
    _initialCharacterStatePositions = _cloneCharacterStatePositions(
      OfficeSceneConfig.characterStatePositions,
    );
    _initialCharacterStateDirections = _cloneCharacterStateDirections(
      OfficeSceneConfig.characterStateDirections,
    );
    if (!OfficeSceneConfig.loadedFromProjectAsset) {
      await _loadSavedCharacterStatePositions();
    }

    final sceneBuilder = OfficeSceneBuilder(
      game: this,
      world: world,
      exitRouteBuilder: _routeToNearestWalkRouteLine,
    );
    await sceneBuilder.buildBackground();
    sceneBuilder.buildZones();
    sceneBuilder.buildFurnitureAndSeats(seats);
    sceneBuilder.buildCharacters(characters);
    await sceneBuilder.buildDecorations();
    await _loadWalkRoutes();
    _walkRouteOverlay = _WalkRouteOverlayComponent(this);
    world.add(_walkRouteOverlay);

    gameplayCoordinator = GameplayCoordinator(
      world: world,
      characters: characters,
      seats: seats,
      websocketUrl: options.websocketUrl,
      enableRemoteSync: options.enableRemoteSync,
      enableMockRemoteCommands: options.enableMockRemoteCommands,
      accumulateEconomy: _accumulateEconomy,
      buildSnapshotPayload: _buildSnapshotPayload,
      assignTask: _assignCharacterToTaskViaWalkRoutes,
    );
    await gameplayCoordinator.onLoad();
    gameplayCoordinator.aiController.autonomousTasksEnabled =
        walkRoutes.isEmpty;

    camera.viewfinder.anchor = Anchor.topLeft;
    _sceneLoaded = true;
    _applyResponsiveCamera();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (_sceneLoaded) {
      _applyResponsiveCamera();
    }
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    camera.viewfinder.position -= info.delta.global / camera.viewfinder.zoom;
    _clampCameraToScene();
  }

  @override
  void onScroll(PointerScrollInfo info) {
    final zoomDelta = info.scrollDelta.global.y > 0 ? -0.1 : 0.1;
    camera.viewfinder.zoom = (camera.viewfinder.zoom + zoomDelta).clamp(
      0.5,
      2.0,
    );
    _clampCameraToScene();
  }

  void resetCamera() {
    _applyResponsiveCamera();
  }

  int get savedWalkRouteCount => walkRoutes.length;
  int get walkRouteDraftPointCount => walkRouteDraft.length;
  List<String> get characterNames =>
      characters.map((character) => character.name).toList(growable: false);

  Vector2? characterStatePosition(String name, CharacterState state) =>
      OfficeSceneConfig.characterStatePositions[name]?[state]?.clone();

  String? characterStateDirection(String name, CharacterState state) =>
      OfficeSceneConfig.characterStateDirections[name]?[state];

  void setWalkRouteEditing(bool value) {
    walkRouteEditing = value;
    if (value) {
      characterPositionEditing = false;
    }
    lastCommandText = value ? '画走廊路线：点击地图添加路线点' : '点击区域派发任务';
  }

  void setCharacterPositionEditing(bool value, {String? selectedName}) {
    characterPositionEditing = value;
    if (value) {
      walkRouteEditing = false;
      final names = characterNames;
      selectedCharacterName =
          selectedName ??
          selectedCharacterName ??
          (names.isEmpty ? null : names.first);
      if (selectedCharacterName != null) {
        previewCharacterStatePosition(
          selectedCharacterName!,
          selectedPositionState,
        );
      }
      lastCommandText = '状态位置：选择角色和状态后点击地图或方向微调';
    } else {
      lastCommandText = '点击区域派发任务';
    }
  }

  void selectCharacterForPositionEdit(String? name) {
    if (name == null || _characterByName(name) == null) {
      return;
    }
    selectedCharacterName = name;
    previewCharacterStatePosition(name, selectedPositionState);
    lastCommandText = '正在调整 $name';
  }

  void selectPositionState(CharacterState state) {
    selectedPositionState = state;
    if (selectedCharacterName != null) {
      previewCharacterStatePosition(selectedCharacterName!, state);
    }
    lastCommandText = '正在调整 ${_stateLabel(state)} 位置';
  }

  void previewCharacterStatePosition(String name, CharacterState state) {
    final character = _characterByName(name);
    final position = characterStatePosition(name, state);
    if (character == null || position == null) {
      return;
    }
    character.forcePlaceAtState(
      state,
      position,
      direction: characterStateDirection(name, state),
    );
  }

  Future<void> nudgeCharacterStatePosition(
    String name,
    CharacterState state,
    Vector2 delta,
  ) async {
    final current = characterStatePosition(name, state);
    if (current == null) {
      return;
    }
    await moveCharacterStatePosition(name, state, current + delta);
  }

  Future<void> moveCharacterStatePosition(
    String name,
    CharacterState state,
    Vector2 point,
  ) async {
    final character = _characterByName(name);
    if (character == null) {
      return;
    }
    final clamped = _clampPointToScene(point);
    OfficeSceneConfig.characterStatePositions.putIfAbsent(
          name,
          () => {},
        )[state] =
        clamped.clone();
    final direction = characterStateDirection(name, state);
    character.forcePlaceAtState(state, clamped, direction: direction);
    selectedCharacterName = name;
    selectedPositionState = state;
    lastCommandText =
        '$name ${_stateLabel(state)} ${clamped.x.round()}, ${clamped.y.round()}';
    await _saveCharacterStatePositions();
  }

  Future<void> setCharacterStateDirection(
    String name,
    CharacterState state,
    String direction,
  ) async {
    if (!_seatDirections.contains(direction)) {
      return;
    }
    final character = _characterByName(name);
    final position = characterStatePosition(name, state);
    if (character == null || position == null) {
      return;
    }
    OfficeSceneConfig.characterStateDirections.putIfAbsent(
          name,
          () => {},
        )[state] =
        direction;
    character.forcePlaceAtState(state, position, direction: direction);
    selectedCharacterName = name;
    selectedPositionState = state;
    lastCommandText =
        '$name ${_stateLabel(state)} ${_directionLabel(direction)}';
    await _saveCharacterStatePositions();
  }

  Future<void> resetCharacterStatePositions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_characterStatePositionsStorageKey);
    OfficeSceneConfig.characterStatePositions = _cloneCharacterStatePositions(
      _initialCharacterStatePositions,
    );
    OfficeSceneConfig.characterStateDirections = _cloneCharacterStateDirections(
      _initialCharacterStateDirections,
    );
    lastCommandText = '已重置状态位置';
  }

  Future<bool> saveCharacterStatePositionsToJson() async {
    final saved =
        await OfficeSceneConfig.saveCharacterStatePositionsToProjectAsset();
    if (saved) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_characterStatePositionsStorageKey);
    }
    lastCommandText =
        saved ? '已保存到 office_game_layout.json' : '当前运行环境不能直接写项目 JSON';
    return saved;
  }

  void undoWalkRoutePoint() {
    if (walkRouteDraft.isEmpty) {
      return;
    }
    walkRouteDraft.removeLast();
    lastCommandText = '已撤销一个路线点';
  }

  void clearWalkRouteDraft() {
    walkRouteDraft.clear();
    lastCommandText = '已清空当前画线';
  }

  Future<bool> saveWalkRouteDraft() async {
    if (walkRouteDraft.length < 2) {
      lastCommandText = '至少画两个点才能保存路线';
      return false;
    }
    walkRoutes.add(walkRouteDraft.map((point) => point.clone()).toList());
    final mergedRoutes = _mergeNearbyWalkRoutePoints(walkRoutes);
    walkRoutes
      ..clear()
      ..addAll(mergedRoutes);
    walkRouteDraft.clear();
    await _saveWalkRoutes();
    gameplayCoordinator.aiController.autonomousTasksEnabled = false;
    lastCommandText = '已保存走廊路线 ${walkRoutes.length}';
    return true;
  }

  Future<void> clearSavedWalkRoutes() async {
    walkRoutes.clear();
    walkRouteDraft.clear();
    await _saveWalkRoutes();
    gameplayCoordinator.aiController.autonomousTasksEnabled = true;
    lastCommandText = '已清空所有走廊路线';
  }

  void _applyResponsiveCamera() {
    final viewportSize = size;
    if (viewportSize.x <= 0 || viewportSize.y <= 0) {
      return;
    }

    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.zoom = _initialZoomFor(viewportSize);
    camera.viewfinder.position = _centeredCameraPosition(viewportSize);
    _clampCameraToScene();
  }

  double _initialZoomFor(Vector2 viewportSize) {
    final sceneSize = OfficeSceneConfig.sceneSize;
    final usableWidth = math.max(1.0, viewportSize.x);
    final usableHeight = math.max(1.0, viewportSize.y);
    final widthZoom = usableWidth / sceneSize.x;
    final heightZoom = usableHeight / sceneSize.y;
    return math.min(widthZoom, heightZoom).clamp(0.01, 1.0);
  }

  Vector2 _centeredCameraPosition(Vector2 viewportSize) {
    final sceneSize = OfficeSceneConfig.sceneSize;
    final visibleSize = viewportSize / camera.viewfinder.zoom;
    final x = (sceneSize.x - visibleSize.x) / 2;
    final y = (sceneSize.y - visibleSize.y) / 2;
    return Vector2(x, y);
  }

  void _clampCameraToScene() {
    final viewportSize = size;
    if (viewportSize.x <= 0 || viewportSize.y <= 0) {
      return;
    }

    final sceneSize = OfficeSceneConfig.sceneSize;
    final visibleSize = viewportSize / camera.viewfinder.zoom;
    camera.viewfinder.position = Vector2(
      _clampAxis(camera.viewfinder.position.x, sceneSize.x, visibleSize.x),
      _clampAxis(camera.viewfinder.position.y, sceneSize.y, visibleSize.y),
    );
  }

  double _clampAxis(double value, double sceneLength, double visibleLength) {
    if (visibleLength >= sceneLength) {
      return (sceneLength - visibleLength) / 2;
    }
    return value.clamp(0.0, sceneLength - visibleLength);
  }

  Vector2 _clampPointToScene(Vector2 point) {
    final sceneSize = OfficeSceneConfig.sceneSize;
    return Vector2(
      point.x.clamp(0.0, sceneSize.x),
      point.y.clamp(0.0, sceneSize.y),
    );
  }

  Future<void> _loadWalkRoutes() async {
    _loadInitialWalkRoutes();
    await _saveWalkRoutes();
  }

  void _loadInitialWalkRoutes() {
    walkRoutes
      ..clear()
      ..addAll(_mergeNearbyWalkRoutePoints(_defaultWalkRoutesFromConfig()));
  }

  List<List<Vector2>> _defaultWalkRoutesFromConfig() {
    return OfficeSceneConfig.walkRoutes
        .where((route) => route.points.length >= 2)
        .map((route) => route.points.map((point) => point.clone()).toList())
        .toList();
  }

  List<List<Vector2>> _mergeNearbyWalkRoutePoints(List<List<Vector2>> routes) {
    final canonicalPoints = <Vector2>[];

    Vector2 canonicalFor(Vector2 point) {
      for (final existing in canonicalPoints) {
        if (existing.distanceTo(point) <= _walkRouteMergeDistance) {
          return existing;
        }
      }

      final canonical = point.clone();
      canonicalPoints.add(canonical);
      return canonical;
    }

    final uniqueRouteKeys = <String>{};
    return routes
        .map((route) {
          final mergedRoute = <Vector2>[];
          for (final point in route) {
            final mergedPoint = canonicalFor(_clampPointToScene(point));
            if (mergedRoute.isNotEmpty &&
                mergedRoute.last.distanceTo(mergedPoint) < 2.0) {
              continue;
            }
            mergedRoute.add(mergedPoint.clone());
          }
          return mergedRoute;
        })
        .where((route) => route.length >= 2)
        .where((route) => uniqueRouteKeys.add(_walkRouteKey(route)))
        .toList();
  }

  String _walkRouteKey(List<Vector2> route) {
    final forward = route.map(_walkPointKey).join('|');
    final reverse = route.reversed.map(_walkPointKey).join('|');
    return forward.compareTo(reverse) <= 0 ? forward : reverse;
  }

  String _walkPointKey(Vector2 point) {
    return '${point.x.round()},${point.y.round()}';
  }

  Future<void> _saveWalkRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    final payload =
        walkRoutes
            .map(
              (route) =>
                  route.map((point) => {'x': point.x, 'y': point.y}).toList(),
            )
            .toList();
    await prefs.setString(_walkRoutesStorageKey, jsonEncode(payload));
  }

  Future<void> _loadSavedCharacterStatePositions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_characterStatePositionsStorageKey);
    if (raw == null || raw.isEmpty) {
      return;
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return;
    }

    for (final entry in decoded.entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) {
        continue;
      }
      final positions = OfficeSceneConfig.characterStatePositions.putIfAbsent(
        entry.key,
        () => {},
      );
      final directions = OfficeSceneConfig.characterStateDirections.putIfAbsent(
        entry.key,
        () => {},
      );
      for (final stateEntry in value.entries) {
        final state = _stateFromKey(stateEntry.key);
        final point = stateEntry.value;
        if (state == null || point is! Map<String, dynamic>) {
          continue;
        }
        final x = point['x'];
        final y = point['y'];
        if (x is num && y is num) {
          positions[state] = Vector2(x.toDouble(), y.toDouble());
        }
        final direction = point['direction'];
        if (direction is String && _seatDirections.contains(direction)) {
          directions[state] = direction;
        }
      }
    }
  }

  Future<void> _saveCharacterStatePositions() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      for (final entry in OfficeSceneConfig.characterStatePositions.entries)
        entry.key: {
          for (final stateEntry in entry.value.entries)
            _stateKey(stateEntry.key): {
              'x': stateEntry.value.x,
              'y': stateEntry.value.y,
              if (OfficeSceneConfig.characterStateDirections[entry
                      .key]?[stateEntry.key] !=
                  null)
                'direction':
                    OfficeSceneConfig.characterStateDirections[entry
                        .key]![stateEntry.key]!,
            },
        },
    };
    await prefs.setString(
      _characterStatePositionsStorageKey,
      jsonEncode(payload),
    );
  }

  @override
  void onTapDown(TapDownInfo info) {
    final point = camera.globalToLocal(info.eventPosition.global);
    if (characterPositionEditing && selectedCharacterName != null) {
      moveCharacterStatePosition(
        selectedCharacterName!,
        selectedPositionState,
        point,
      );
      return;
    }

    if (walkRouteEditing) {
      walkRouteDraft.add(_clampPointToScene(point));
      lastCommandText = '当前走廊路线点 ${walkRouteDraft.length}';
      return;
    }

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
    gameplayCoordinator.update(dt);
    _settleIdleCharactersOnSofas();
    _sortComponentsByY();
  }

  void _settleIdleCharactersOnSofas() {
    if (characterPositionEditing) {
      return;
    }

    for (final character in characters) {
      if (!character.readyForAssignment || character.isIdleOnSofa) {
        continue;
      }

      final sofaSeat = _nearestAvailableSofaSeat(character);
      if (sofaSeat == null) {
        continue;
      }

      final preferredPosition =
          OfficeSceneConfig.characterStatePositions[character
              .name]?[CharacterState.rest];
      final preferredDirection =
          OfficeSceneConfig.characterStateDirections[character
              .name]?[CharacterState.rest];
      final targetPosition = _targetOverrideForSeat(
        sofaSeat,
        preferredPosition,
      );
      final route = _routeFromWalkRoutesToSeat(
        character.position,
        sofaSeat,
        destinationOverride: targetPosition,
      );
      final assigned =
          route != null
              ? character.followCustomRouteToIdleSeat(
                route.points,
                sofaSeat,
                targetPositionOverride: targetPosition,
                targetDirectionOverride: preferredDirection,
              )
              : character.assignIdleSeat(
                sofaSeat,
                targetPositionOverride: targetPosition,
                targetDirectionOverride: preferredDirection,
              );
      if (assigned) {
        lastCommandText = '${character.name} 空闲入座沙发';
      }
    }
  }

  Seat? _nearestAvailableSofaSeat(Character character) {
    final sofaSeats =
        (seats[SeatType.sofa] ?? const <Seat>[])
            .where((seat) => seat.isAvailable || seat.user == character)
            .toList();
    if (sofaSeats.isEmpty) {
      return null;
    }

    final preferredPosition =
        OfficeSceneConfig.characterStatePositions[character
            .name]?[CharacterState.rest];
    sofaSeats.sort((a, b) {
      if (preferredPosition != null) {
        return a.position
            .distanceTo(preferredPosition)
            .compareTo(b.position.distanceTo(preferredPosition));
      }
      return character.position
          .distanceTo(a.position)
          .compareTo(character.position.distanceTo(b.position));
    });
    return sofaSeats.first;
  }

  _WalkSeatRoute? _routeFromWalkRoutesToSeat(
    Vector2 start,
    Seat seat, {
    Vector2? destinationOverride,
  }) {
    final destination =
        destinationOverride?.clone() ??
        _approachPointForSeat(seat) ??
        seat.position;
    return _routeBetweenWalkRoutePoints(start, destination);
  }

  List<Vector2>? _routeToNearestWalkRouteLine(Vector2 start) {
    final routes = walkRoutes.where((route) => route.length >= 2).toList();
    if (routes.isEmpty) {
      return null;
    }

    final projection = _nearestWalkRouteProjection(routes, start);
    if (projection == null || projection.distanceToPoint < 2.0) {
      return null;
    }
    return [projection.point.clone()];
  }

  Vector2? _approachPointForSeat(Seat seat) {
    final obstacleId = seat.obstacleId;
    if (obstacleId == null) {
      return null;
    }

    for (final furniture in world.children.whereType<Furniture>()) {
      if (furniture.obstacleId == obstacleId) {
        return furniture.approachPointForSeat(seat);
      }
    }
    return null;
  }

  Character? _characterByName(String name) {
    for (final character in characters) {
      if (character.name == name) {
        return character;
      }
    }
    return null;
  }

  _WalkSeatRoute? _routeBetweenWalkRoutePoints(
    Vector2 start,
    Vector2 destination,
  ) {
    final routes = walkRoutes.where((route) => route.length >= 2).toList();
    if (routes.isEmpty) {
      return null;
    }

    final startProjection = _nearestWalkRouteProjection(routes, start);
    final destinationProjection = _nearestWalkRouteProjection(
      routes,
      destination,
    );
    if (startProjection == null || destinationProjection == null) {
      return null;
    }

    final graph = _WalkRouteGraph(
      routes,
      extraPoints: [startProjection.point, destinationProjection.point],
    );
    final points = graph.shortestPath(
      startProjection.point,
      destinationProjection.point,
    );
    if (points == null || points.length < 2) {
      return null;
    }

    final routePoints = _dedupeRoutePoints([
      if (startProjection.distanceToPoint >= 2.0) startProjection.point,
      ...points,
      if (destinationProjection.distanceToPoint >= 2.0)
        destinationProjection.point,
      destination,
    ]);

    final score =
        startProjection.distanceToPoint +
        graph.pathLength(points) +
        destinationProjection.distanceToPoint;
    return _WalkSeatRoute(points: routePoints, score: score);
  }

  List<Vector2> _dedupeRoutePoints(List<Vector2> points) {
    final result = <Vector2>[];
    for (final point in points) {
      if (result.isNotEmpty && result.last.distanceTo(point) < 2.0) {
        continue;
      }
      result.add(point.clone());
    }
    return result;
  }

  _WalkRouteProjection? _nearestWalkRouteProjection(
    List<List<Vector2>> routes,
    Vector2 point,
  ) {
    _WalkRouteProjection? best;

    for (final route in routes) {
      for (var i = 0; i < route.length - 1; i++) {
        final start = route[i];
        final end = route[i + 1];
        final segment = end - start;
        final segmentLength = segment.length;
        if (segmentLength <= 0) {
          continue;
        }

        final t = ((point - start).dot(segment) /
                (segmentLength * segmentLength))
            .clamp(0.0, 1.0);
        final projected = start + segment * t;
        final distance = projected.distanceTo(point);
        if (best == null || distance < best.distanceToPoint) {
          best = _WalkRouteProjection(
            point: projected,
            distanceToPoint: distance,
          );
        }
      }
    }

    return best;
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

    final assigned =
        _assignCharacterToTaskViaWalkRoutes(selected, task, force: true) ||
        gameplayCoordinator.aiController.assignTask(
          selected,
          task,
          force: true,
        );
    lastCommandText =
        assigned ? '${selected.name} -> ${task.label}' : '${task.label} 座位已满';
  }

  bool _assignCharacterToTaskViaWalkRoutes(
    Character character,
    CharacterTask task, {
    bool force = false,
  }) {
    if (walkRoutes.isEmpty) {
      return false;
    }

    final preferredPosition =
        OfficeSceneConfig.characterStatePositions[character.name]?[task
            .targetState];
    final preferredDirection =
        OfficeSceneConfig.characterStateDirections[character.name]?[task
            .targetState];
    final fixedSeat =
        _usesFixedPreferredSeat(task.targetState) && preferredPosition != null
            ? _nearestSeatToPreferredPosition(task.seatType, preferredPosition)
            : null;
    if (fixedSeat != null &&
        !fixedSeat.isAvailable &&
        fixedSeat.user != character) {
      return false;
    }
    final freeSeats =
        (seats[task.seatType] ?? const <Seat>[])
            .where(
              (seat) =>
                  (fixedSeat == null || seat == fixedSeat) &&
                  (seat.isAvailable || (force && seat.user == character)),
            )
            .map((seat) {
              final targetPosition = _targetOverrideForSeat(
                seat,
                preferredPosition,
              );
              return _WalkSeatCandidate(
                seat: seat,
                route: _routeFromWalkRoutesToSeat(
                  character.position,
                  seat,
                  destinationOverride: targetPosition,
                ),
                targetPosition: targetPosition,
              );
            })
            .where((candidate) => candidate.route != null)
            .toList();
    freeSeats.sort((a, b) {
      final routeCompare = a.route!.score.compareTo(b.route!.score);
      if (preferredPosition == null || routeCompare != 0) {
        return routeCompare;
      }
      return a.seat.position
          .distanceTo(preferredPosition)
          .compareTo(b.seat.position.distanceTo(preferredPosition));
    });

    for (final candidate in freeSeats) {
      if (character.followCustomRouteToSeat(
        candidate.route!.points,
        task,
        candidate.seat,
        force: force,
        targetPositionOverride: candidate.targetPosition,
        targetDirectionOverride: preferredDirection,
      )) {
        return true;
      }
    }
    return false;
  }

  Seat? _nearestSeatToPreferredPosition(SeatType type, Vector2 position) {
    final typedSeats = seats[type] ?? const <Seat>[];
    if (typedSeats.isEmpty) {
      return null;
    }
    return typedSeats.reduce(
      (a, b) =>
          a.position.distanceTo(position) <= b.position.distanceTo(position)
              ? a
              : b,
    );
  }

  bool _usesFixedPreferredSeat(CharacterState state) =>
      state == CharacterState.work || state == CharacterState.meeting;

  Vector2? _targetOverrideForSeat(Seat seat, Vector2? preferredPosition) {
    if (preferredPosition == null) {
      return null;
    }
    return seat.position.distanceTo(preferredPosition) <= 64.0
        ? preferredPosition.clone()
        : null;
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
              child.shouldOccludeSeatedCharacters
                  ? _characterPriorityBase + 60
                  : child.depthMode == FurnitureDepthMode.behindCharacters
                  ? _characterPriorityBase - 220
                  : _furniturePriorityBase;
          child.priority = base + bottomY.toInt() + child.priorityOffset;
        }
      }
    }
  }

  Map<String, Map<CharacterState, Vector2>> _cloneCharacterStatePositions(
    Map<String, Map<CharacterState, Vector2>> source,
  ) {
    return {
      for (final characterEntry in source.entries)
        characterEntry.key: {
          for (final stateEntry in characterEntry.value.entries)
            stateEntry.key: stateEntry.value.clone(),
        },
    };
  }

  Map<String, Map<CharacterState, String>> _cloneCharacterStateDirections(
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

  CharacterState? _stateFromKey(String key) {
    switch (key) {
      case 'work':
        return CharacterState.work;
      case 'meeting':
        return CharacterState.meeting;
      case 'rest':
        return CharacterState.rest;
      default:
        return null;
    }
  }

  String _stateKey(CharacterState state) {
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

  String _stateLabel(CharacterState state) {
    switch (state) {
      case CharacterState.work:
        return '工作中';
      case CharacterState.meeting:
        return '讨论中';
      case CharacterState.rest:
        return '休息中';
      case CharacterState.walk:
        return '移动中';
      case CharacterState.idle:
        return '空闲中';
    }
  }

  String _directionLabel(String direction) {
    switch (direction) {
      case 'left':
        return '朝左';
      case 'right':
        return '朝右';
      case 'up':
        return '朝上';
      case 'down':
        return '朝下';
      default:
        return direction;
    }
  }
}

class _WalkSeatCandidate {
  final Seat seat;
  final _WalkSeatRoute? route;
  final Vector2? targetPosition;

  const _WalkSeatCandidate({
    required this.seat,
    required this.route,
    this.targetPosition,
  });
}

class _WalkSeatRoute {
  final List<Vector2> points;
  final double score;

  const _WalkSeatRoute({required this.points, required this.score});
}

class _WalkRouteProjection {
  final Vector2 point;
  final double distanceToPoint;

  const _WalkRouteProjection({
    required this.point,
    required this.distanceToPoint,
  });
}

class _WalkRouteGraph {
  static const double _nodeMergeDistance = 10.0;
  static const double _pointOnSegmentTolerance = 4.0;
  static const double _intersectionTolerance = 0.001;

  final List<Vector2> _nodes = [];
  final Map<int, List<_WalkGraphEdge>> _edges = {};
  late final List<_WalkSegment> _segments;

  _WalkRouteGraph(
    List<List<Vector2>> routes, {
    List<Vector2> extraPoints = const [],
  }) {
    _segments = [
      for (final route in routes)
        for (var i = 0; i < route.length - 1; i++)
          if (route[i].distanceTo(route[i + 1]) > 1.0)
            _WalkSegment(route[i].clone(), route[i + 1].clone()),
    ];

    for (final segment in _segments) {
      _nodeIdFor(segment.start);
      _nodeIdFor(segment.end);
    }
    for (var i = 0; i < _segments.length; i++) {
      for (var j = i + 1; j < _segments.length; j++) {
        final intersection = _segmentIntersection(_segments[i], _segments[j]);
        if (intersection != null) {
          _nodeIdFor(intersection);
        }
      }
    }
    for (final point in extraPoints) {
      _nodeIdFor(point);
    }

    for (final segment in _segments) {
      final segmentNodes = [
        for (var i = 0; i < _nodes.length; i++)
          if (_isPointOnSegment(_nodes[i], segment))
            _WalkSegmentNode(
              id: i,
              t: _segmentT(segment, _nodes[i]),
              point: _nodes[i],
            ),
      ]..sort((a, b) => a.t.compareTo(b.t));

      for (var i = 0; i < segmentNodes.length - 1; i++) {
        final a = segmentNodes[i];
        final b = segmentNodes[i + 1];
        final distance = a.point.distanceTo(b.point);
        if (a.id != b.id && distance > 1.0) {
          _connect(a.id, b.id, distance);
        }
      }
    }
  }

  List<Vector2>? shortestPath(Vector2 start, Vector2 end) {
    final startId = _nearestNodeId(start);
    final endId = _nearestNodeId(end);
    if (startId == null || endId == null) {
      return null;
    }
    if (startId == endId) {
      return [_nodes[startId].clone(), _nodes[endId].clone()];
    }

    final distances = <int, double>{startId: 0};
    final previous = <int, int>{};
    final visited = <int>{};

    while (visited.length < _nodes.length) {
      int? current;
      var bestDistance = double.infinity;
      for (var i = 0; i < _nodes.length; i++) {
        final distance = distances[i] ?? double.infinity;
        if (!visited.contains(i) && distance < bestDistance) {
          current = i;
          bestDistance = distance;
        }
      }

      if (current == null || current == endId) {
        break;
      }
      visited.add(current);

      for (final edge in _edges[current] ?? const <_WalkGraphEdge>[]) {
        final nextDistance = bestDistance + edge.distance;
        if (nextDistance < (distances[edge.to] ?? double.infinity)) {
          distances[edge.to] = nextDistance;
          previous[edge.to] = current;
        }
      }
    }

    if (!distances.containsKey(endId)) {
      return null;
    }

    final ids = <int>[endId];
    while (ids.last != startId) {
      final parent = previous[ids.last];
      if (parent == null) {
        return null;
      }
      ids.add(parent);
    }

    return ids.reversed.map((id) => _nodes[id].clone()).toList();
  }

  double pathLength(List<Vector2> points) {
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      total += points[i].distanceTo(points[i + 1]);
    }
    return total;
  }

  int _nodeIdFor(Vector2 point) {
    for (var i = 0; i < _nodes.length; i++) {
      if (_nodes[i].distanceTo(point) <= _nodeMergeDistance) {
        return i;
      }
    }
    _nodes.add(point.clone());
    return _nodes.length - 1;
  }

  int? _nearestNodeId(Vector2 point) {
    int? bestId;
    var bestDistance = double.infinity;
    for (var i = 0; i < _nodes.length; i++) {
      final distance = _nodes[i].distanceTo(point);
      if (distance < bestDistance) {
        bestId = i;
        bestDistance = distance;
      }
    }
    return bestId;
  }

  void _connect(int a, int b, double distance) {
    _edges
        .putIfAbsent(a, () => [])
        .add(_WalkGraphEdge(to: b, distance: distance));
    _edges
        .putIfAbsent(b, () => [])
        .add(_WalkGraphEdge(to: a, distance: distance));
  }

  bool _isPointOnSegment(Vector2 point, _WalkSegment segment) {
    if (_distanceToSegment(point, segment) > _pointOnSegmentTolerance) {
      return false;
    }
    final t = _segmentT(segment, point);
    return t >= -_intersectionTolerance && t <= 1.0 + _intersectionTolerance;
  }

  double _segmentT(_WalkSegment segment, Vector2 point) {
    final line = segment.end - segment.start;
    final lengthSquared = line.length2;
    if (lengthSquared <= 0) {
      return 0;
    }
    return (point - segment.start).dot(line) / lengthSquared;
  }

  double _distanceToSegment(Vector2 point, _WalkSegment segment) {
    final line = segment.end - segment.start;
    final lengthSquared = line.length2;
    if (lengthSquared <= 0) {
      return point.distanceTo(segment.start);
    }
    final t = ((point - segment.start).dot(line) / lengthSquared).clamp(
      0.0,
      1.0,
    );
    return point.distanceTo(segment.start + line * t);
  }

  Vector2? _segmentIntersection(_WalkSegment a, _WalkSegment b) {
    final p = a.start;
    final r = a.end - a.start;
    final q = b.start;
    final s = b.end - b.start;
    final denominator = _cross(r, s);
    if (denominator.abs() <= _intersectionTolerance) {
      return null;
    }

    final qp = q - p;
    final t = _cross(qp, s) / denominator;
    final u = _cross(qp, r) / denominator;
    if (t < -_intersectionTolerance ||
        t > 1.0 + _intersectionTolerance ||
        u < -_intersectionTolerance ||
        u > 1.0 + _intersectionTolerance) {
      return null;
    }

    return p + r * t.clamp(0.0, 1.0);
  }

  double _cross(Vector2 a, Vector2 b) => a.x * b.y - a.y * b.x;
}

class _WalkSegment {
  final Vector2 start;
  final Vector2 end;

  const _WalkSegment(this.start, this.end);
}

class _WalkSegmentNode {
  final int id;
  final double t;
  final Vector2 point;

  const _WalkSegmentNode({
    required this.id,
    required this.t,
    required this.point,
  });
}

class _WalkGraphEdge {
  final int to;
  final double distance;

  const _WalkGraphEdge({required this.to, required this.distance});
}

class _WalkRouteOverlayComponent extends Component {
  final OfficeGame game;
  final Paint _savedLinePaint =
      Paint()
        ..color = const Color(0x9939D98A)
        ..strokeWidth = 5
        ..style = PaintingStyle.stroke;
  final Paint _draftLinePaint =
      Paint()
        ..color = const Color(0xFFFFD166)
        ..strokeWidth = 6
        ..style = PaintingStyle.stroke;
  final Paint _pointPaint =
      Paint()
        ..color = const Color(0xFFE94F37)
        ..style = PaintingStyle.fill;
  final Paint _ringPaint =
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;

  _WalkRouteOverlayComponent(this.game) {
    priority = 5000;
  }

  @override
  void render(Canvas canvas) {
    if (!game.walkRouteEditing) {
      return;
    }

    for (final route in game.walkRoutes) {
      _drawRoute(canvas, route, _savedLinePaint, drawPoints: false);
    }

    if (game.walkRouteDraft.isNotEmpty) {
      _drawRoute(canvas, game.walkRouteDraft, _draftLinePaint);
    }
  }

  void _drawRoute(
    Canvas canvas,
    List<Vector2> points,
    Paint linePaint, {
    bool drawPoints = true,
  }) {
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      if (i > 0) {
        final previous = points[i - 1];
        canvas.drawLine(
          Offset(previous.x, previous.y),
          Offset(point.x, point.y),
          linePaint,
        );
      }
      if (drawPoints) {
        canvas.drawCircle(Offset(point.x, point.y), 8, _pointPaint);
        canvas.drawCircle(Offset(point.x, point.y), 10, _ringPaint);
      }
    }
  }
}
