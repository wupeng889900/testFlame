import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/sprite.dart';
import 'package:flutter/material.dart';

import '../core/asset_catalog.dart';
import '../core/constants.dart';
import '../core/enums.dart';
import '../core/character_task.dart';
import '../core/seat.dart';
import '../core/style_guide.dart';
import '../entity/furniture.dart';
import '../ui/status_bubble.dart';
import '../world/scene_config.dart';

typedef CharacterExitRouteBuilder = List<Vector2>? Function(Vector2 start);

class Character extends SpriteAnimationGroupComponent<CharacterState>
    with HasGameReference<FlameGame> {
  final String name;
  final String spriteSheetPath;
  final List<String>? animationFrames;
  final String? motionAtlasBasePath;
  final CharacterExitRouteBuilder? exitRouteBuilder;

  Vector2? targetPosition;
  Seat? currentSeat;
  CharacterState nextState = CharacterState.idle;
  CharacterTask? _activeTask;
  bool _usePlaceholder = false;
  late final Map<int, SpriteAnimation> _walkAnimations;
  final Map<CharacterState, Sprite> _taskSprites = {};
  final List<Vector2> _routeQueue = [];
  int _currentWalkRow = GameConstants.rowWalkDown;

  // Dynamic stats
  double energy = 100.0;
  double productivityContribution = 0.0;
  double taskDuration = 0.0;
  double _taskTimer = 0.0;
  double _visualTime = 0.0;
  double _idleCooldownRemaining = 0.0;
  double _movementBlockRemaining = 0.0;
  double _movementNoProgressTime = 0.0;
  double _movementBestDistance = double.infinity;
  double _movementStillTime = 0.0;
  Vector2 _facing = Vector2(0, 1);
  final Vector2 _spawnPosition;
  final Vector2 _movementLastPosition = Vector2.zero();
  Vector2? _routeDestination;
  Vector2? _movementWatchTarget;
  Vector2? _seatPositionOverride;
  String? _seatDirectionOverride;
  bool _centerTaskSpriteOnPosition = false;

  late final _CharacterVisualProfile _profile =
      _CharacterVisualProfile.fromName(name);

  Character({
    required this.name,
    required this.spriteSheetPath,
    required Vector2 position,
    this.animationFrames,
    this.motionAtlasBasePath,
    this.exitRouteBuilder,
  }) : _spawnPosition = position.clone(),
       super(
         size: GameConstants.characterSize,
         anchor: Anchor.bottomCenter,
         position: position,
       );

  bool get isMoving => targetPosition != null || _routeQueue.isNotEmpty;
  bool get readyForAssignment =>
      current != null &&
      animations != null &&
      !isMoving &&
      _activeTask == null &&
      _idleCooldownRemaining <= 0;
  CharacterTask? get activeTask => _activeTask;
  bool get isIdleOnSofa =>
      currentSeat?.type == SeatType.sofa && !isMoving && _activeTask == null;
  bool get _isDeskSeated =>
      current == CharacterState.work &&
      currentSeat?.type == SeatType.desk &&
      !isMoving;
  bool get _renderProceduralTaskPose =>
      currentSeat != null &&
      !isMoving &&
      (current == CharacterState.work || current == CharacterState.rest) &&
      _currentTaskSprite == null;
  String? get _effectiveSeatDirection =>
      _seatDirectionOverride ?? currentSeat?.direction;
  String get stateLabel {
    if (current == CharacterState.walk) {
      return '移动中';
    }
    return _activeTask?.label ?? '空闲中';
  }

  double get taskProgress {
    if (taskDuration <= 0) {
      return 0;
    }
    return (_taskTimer / taskDuration).clamp(0.0, 1.0);
  }

  Vector2 get spawnPosition => _spawnPosition.clone();
  Vector2 get overheadUiAnchor {
    final baseY = current == CharacterState.rest ? 26.0 : 18.0;
    return Vector2(size.x / 2, baseY + _currentBob * 0.5);
  }

  Sprite? get _currentTaskSprite {
    if (current == CharacterState.work ||
        current == CharacterState.rest ||
        current == CharacterState.meeting) {
      return _taskSprites[current!];
    }
    return null;
  }

  @override
  Future<void> onLoad() async {
    add(StatusBubble(this));

    // Set filter quality to none for crisp pixel art rendering
    paint.filterQuality = FilterQuality.none;

    try {
      if (motionAtlasBasePath != null) {
        await _loadDirectionalMotionAtlas(motionAtlasBasePath!);
        _usePlaceholder = false;
        current = CharacterState.idle;
        return;
      }

      if (animationFrames != null && animationFrames!.isNotEmpty) {
        final List<Sprite> sprites = [];
        for (final framePath in animationFrames!) {
          final img = await game.images.load(framePath);
          sprites.add(Sprite(img));
        }

        final firstImg = await game.images.load(animationFrames!.first);
        const double scale = 1.5;
        size.setValues(firstImg.width * scale, firstImg.height * scale);

        final anim = SpriteAnimation.spriteList(sprites, stepTime: 0.2);
        animations = {
          CharacterState.idle: SpriteAnimation.spriteList([
            sprites.first,
          ], stepTime: 1),
          CharacterState.walk: anim,
          CharacterState.work: SpriteAnimation.spriteList([
            sprites.first,
          ], stepTime: 1),
          CharacterState.rest: SpriteAnimation.spriteList([
            sprites.first,
          ], stepTime: 1),
          CharacterState.meeting: SpriteAnimation.spriteList([
            sprites.first,
          ], stepTime: 1),
        };
        _walkAnimations = {
          GameConstants.rowWalkDown: anim,
          GameConstants.rowWalkUp: anim,
          GameConstants.rowWalkLeft: anim,
          GameConstants.rowWalkRight: anim,
        };
        _usePlaceholder = false;
        current = CharacterState.idle;
        return;
      }

      SpriteSheet? spriteSheet;
      for (final candidatePath in GameAssetCatalog.instance.characterCandidates(
        spriteSheetPath,
      )) {
        try {
          final image = await game.images.load(candidatePath);

          if (image.width < GameConstants.characterSize.x ||
              image.height < GameConstants.characterSize.y) {
            // Adjust component size to match sprite's actual size (at a readable scale)
            // Original sprites were 96x96 but were sheets.
            // These are single frames. Let's scale them up by 1.5x to match the world scale better.
            const double scale = 1.5;
            size.setValues(image.width * scale, image.height * scale);

            // Handle single frame sprite
            final singleSprite = Sprite(image);
            final anim = SpriteAnimation.spriteList([
              singleSprite,
            ], stepTime: 1);
            animations = {
              CharacterState.idle: anim,
              CharacterState.walk: anim,
              CharacterState.work: anim,
              CharacterState.rest: anim,
              CharacterState.meeting: anim,
            };
            _walkAnimations = {
              GameConstants.rowWalkDown: anim,
              GameConstants.rowWalkUp: anim,
              GameConstants.rowWalkLeft: anim,
              GameConstants.rowWalkRight: anim,
            };
            _usePlaceholder = false;
            current = CharacterState.idle;
            return;
          }

          spriteSheet = SpriteSheet(
            image: image,
            srcSize: GameConstants.characterSize,
          );
          break;
        } catch (_) {
          continue;
        }
      }
      if (spriteSheet == null) {
        throw StateError('Unable to load character sprite sheet.');
      }

      _walkAnimations = {
        GameConstants.rowWalkDown: _createWalkAnimation(
          spriteSheet,
          row: GameConstants.rowWalkDown,
        ),
        GameConstants.rowWalkUp: _createWalkAnimation(
          spriteSheet,
          row: GameConstants.rowWalkUp,
        ),
        GameConstants.rowWalkLeft: _createWalkAnimation(
          spriteSheet,
          row: GameConstants.rowWalkLeft,
        ),
        GameConstants.rowWalkRight: _createWalkAnimation(
          spriteSheet,
          row: GameConstants.rowWalkRight,
        ),
      };

      animations = {
        CharacterState.walk: _walkAnimations[GameConstants.rowWalkDown]!,
        CharacterState.idle: spriteSheet.createAnimation(
          row: GameConstants.rowIdle,
          stepTime: 0.3,
          to: 2,
        ),
        CharacterState.work: spriteSheet.createAnimation(
          row: GameConstants.rowSit,
          stepTime: 0.35,
          to: 2,
        ),
        CharacterState.rest: spriteSheet.createAnimation(
          row: GameConstants.rowSleep,
          stepTime: 0.5,
          to: 2,
        ),
        CharacterState.meeting: spriteSheet.createAnimation(
          row: GameConstants.rowTalk,
          stepTime: GameConstants.animationStepTime,
          to: 4,
        ),
      };
      _usePlaceholder = false;
    } catch (e, stack) {
      debugPrint('Error loading character $name: $e\n$stack');
      _usePlaceholder = true;
      _initPlaceholderAnimations();
    }
    if (animations != null && animations!.isNotEmpty) {
      current = CharacterState.idle;
    }
  }

  @override
  void render(Canvas canvas) {
    _drawGroundShadow(canvas);
    _drawGroundContact(canvas);
    if (_usePlaceholder || _renderProceduralTaskPose) {
      _drawStylizedCharacter(canvas);
    } else if (_currentTaskSprite != null) {
      _renderTaskSprite(canvas, _currentTaskSprite!);
    } else {
      super.render(canvas);
    }
  }

  void _renderTaskSprite(Canvas canvas, Sprite sprite) {
    final spriteSize = sprite.srcSize;
    final layout = _taskSpriteLayout();
    final scale = layout.scale;
    final width = spriteSize.x * scale;
    final height = spriteSize.y * scale;
    final rect =
        _centerTaskSpriteOnPosition
            ? Rect.fromLTWH(
              anchor.x * size.x - width / 2 + layout.offset.dx,
              anchor.y * size.y - height / 2 + layout.offset.dy,
              width,
              height,
            )
            : Rect.fromLTWH(
              (size.x - width) / 2 + layout.offset.dx,
              size.y - height + layout.offset.dy,
              width,
              height,
            );
    sprite.renderRect(canvas, rect);
  }

  _TaskSpriteLayout _taskSpriteLayout() {
    final seat = currentSeat;
    if (seat == null) {
      return const _TaskSpriteLayout(scale: 0.58, offset: Offset.zero);
    }

    final direction = _effectiveSeatDirection;
    if (seat.type == SeatType.desk) {
      if (direction == 'left') {
        return const _TaskSpriteLayout(scale: 0.56, offset: Offset(-12, -18));
      }
      if (direction == 'right') {
        return const _TaskSpriteLayout(scale: 0.56, offset: Offset(12, -18));
      }
      if (direction == 'up') {
        return const _TaskSpriteLayout(scale: 0.52, offset: Offset(0, 0));
      }
      return const _TaskSpriteLayout(scale: 0.55, offset: Offset(0, -22));
    }

    if (seat.type == SeatType.meeting) {
      if (_centerTaskSpriteOnPosition) {
        return const _TaskSpriteLayout(scale: 0.105, offset: Offset.zero);
      }
      if (direction == 'left') {
        return const _TaskSpriteLayout(scale: 0.54, offset: Offset(-10, -16));
      }
      if (direction == 'right') {
        return const _TaskSpriteLayout(scale: 0.54, offset: Offset(10, -16));
      }
      if (direction == 'up') {
        return const _TaskSpriteLayout(scale: 0.54, offset: Offset(0, -14));
      }
      return const _TaskSpriteLayout(scale: 0.54, offset: Offset(0, -10));
    }

    if (seat.type == SeatType.sofa) {
      if (direction == 'left') {
        return const _TaskSpriteLayout(scale: 0.57, offset: Offset(-10, -12));
      }
      if (direction == 'right') {
        return const _TaskSpriteLayout(scale: 0.57, offset: Offset(10, -12));
      }
      if (direction == 'up') {
        return const _TaskSpriteLayout(scale: 0.58, offset: Offset(0, -8));
      }
      return const _TaskSpriteLayout(scale: 0.58, offset: Offset(0, -16));
    }

    return const _TaskSpriteLayout(scale: 0.58, offset: Offset.zero);
  }

  void _drawGroundShadow(Canvas canvas) {
    final angle = SceneStyleGuide.shadowAngleDeg * math.pi / 180;
    final bob = _currentBob * 0.35;
    final center = Offset(
      size.x / 2 + math.cos(angle) * 7,
      size.y - 10 + bob + math.sin(angle) * 3,
    );

    canvas.drawOval(
      Rect.fromCenter(center: center, width: size.x * 0.52, height: 13),
      Paint()
        ..color = SceneStyleGuide.shadowColor.withValues(alpha: 0.24)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
  }

  void _drawGroundContact(Canvas canvas) {
    final center = Offset(size.x / 2, size.y - 9);
    canvas.drawOval(
      Rect.fromCenter(center: center, width: size.x * 0.34, height: 8),
      Paint()..color = _profile.accent.withValues(alpha: 0.12),
    );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: size.x * 0.28, height: 6),
      Paint()..color = Colors.white.withValues(alpha: 0.10),
    );
  }

  void _drawStylizedCharacter(Canvas canvas) {
    final bob = _currentBob;
    final isWalking = current == CharacterState.walk;
    final isWorking = current == CharacterState.work;
    final isDeskSeated = _isDeskSeated;
    final isResting = current == CharacterState.rest;
    final isMeeting = current == CharacterState.meeting;
    final isSeated = isResting || isDeskSeated;

    final centerX = size.x / 2 + _facing.x * 2.5;
    final baseY =
        size.y - 16 + bob + (isDeskSeated ? 5.0 : (isResting ? 3.0 : 0.0));
    final step = math.sin(_visualTime * 9.5);
    final swing =
        isWalking
            ? step * 8
            : (isMeeting ? math.sin(_visualTime * 5) * 4 : 0.0);
    final shoulderShift = _facing.x * 3;
    final torsoLean =
        isDeskSeated
            ? 4.5
            : (isWorking ? -4.0 : (isResting ? 8.0 : -_facing.y * 1.5));
    final torsoCenter = Offset(centerX, baseY - 24 + torsoLean);
    final torsoRect = Rect.fromCenter(
      center: torsoCenter,
      width: 28,
      height: 32,
    );
    final headCenter = Offset(centerX + _facing.x * 2, torsoRect.top - 11);
    final hipY = torsoRect.bottom - 2;
    final footBaseY = size.y - 11 + (isResting ? 1.5 : 0);
    final leftFootX = centerX - 7 + (isWalking ? swing * 0.55 : 0);
    final rightFootX = centerX + 7 - (isWalking ? swing * 0.55 : 0);

    final leftShoulder = Offset(
      torsoRect.left + 4 + shoulderShift,
      torsoRect.top + 9,
    );
    final rightShoulder = Offset(
      torsoRect.right - 4 + shoulderShift,
      torsoRect.top + 9,
    );
    final leftHand = Offset(
      centerX -
          14 +
          (isWalking ? swing : (isMeeting ? -4.0 : (isResting ? -5.0 : -1.0))),
      torsoRect.top + 24 + (isWorking ? 2 : (isResting ? 4 : 0)),
    );
    final rightHand = Offset(
      centerX +
          14 +
          (isWalking ? -swing : (isMeeting ? 5.0 : (isResting ? 4.0 : 1.0))),
      torsoRect.top + 24 + (isWorking ? 4 : (isResting ? 6 : 0)),
    );

    if (isSeated) {
      _drawSeatPoseLegs(canvas, centerX, hipY, footBaseY, relaxed: isResting);
    } else {
      _drawLimb(
        canvas,
        start: Offset(centerX - 5, hipY),
        end: Offset(leftFootX, footBaseY),
        color: _profile.pants,
      );
      _drawLimb(
        canvas,
        start: Offset(centerX + 5, hipY),
        end: Offset(rightFootX, footBaseY),
        color: _shiftLightness(_profile.pants, 0.04),
      );
    }

    _drawLimb(
      canvas,
      start: leftShoulder,
      end: leftHand,
      color: _shiftLightness(_profile.jacket, 0.05),
    );
    _drawLimb(
      canvas,
      start: rightShoulder,
      end: rightHand,
      color: _shiftLightness(_profile.jacket, -0.03),
    );

    _drawRoundedBody(
      canvas,
      rect: torsoRect,
      fill: _profile.jacket,
      outline: _profile.outline,
    );
    _drawShirtPanel(canvas, torsoRect);
    _drawHead(canvas, headCenter);
    _drawRoleAccent(canvas, torsoRect, headCenter);

    if (isWorking) {
      _drawLaptop(canvas, centerX, size.y - 22);
    } else if (isMeeting) {
      _drawTablet(canvas, centerX + 18, torsoRect.center.dy + 8);
    }
  }

  void _drawSeatPoseLegs(
    Canvas canvas,
    double centerX,
    double hipY,
    double footBaseY, {
    bool relaxed = false,
  }) {
    final leftFootX = relaxed ? centerX - 14 : centerX - 11;
    final rightFootX = relaxed ? centerX + 15 : centerX + 12;
    final leftFootY = relaxed ? footBaseY - 5 : footBaseY - 2;
    final rightFootY = relaxed ? footBaseY - 4 : footBaseY - 1;
    _drawLimb(
      canvas,
      start: Offset(centerX - 5, hipY),
      end: Offset(leftFootX, leftFootY),
      color: _profile.pants,
    );
    _drawLimb(
      canvas,
      start: Offset(centerX + 5, hipY),
      end: Offset(rightFootX, rightFootY),
      color: _shiftLightness(_profile.pants, 0.04),
    );
  }

  void _drawRoundedBody(
    Canvas canvas, {
    required Rect rect,
    required Color fill,
    required Color outline,
  }) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    canvas.drawRRect(rrect, Paint()..color = fill);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = outline
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    final highlight = Rect.fromLTWH(
      rect.left + 3,
      rect.top + 2,
      rect.width * 0.32,
      rect.height * 0.55,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(highlight, const Radius.circular(8)),
      Paint()..color = Colors.white.withValues(alpha: 0.12),
    );
  }

  void _drawShirtPanel(Canvas canvas, Rect torsoRect) {
    final panel = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(torsoRect.center.dx, torsoRect.center.dy + 1),
        width: 12,
        height: 22,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(panel, Paint()..color = _profile.shirt);
  }

  void _drawHead(Canvas canvas, Offset center) {
    final skin = Paint()..color = _profile.skin;
    final outline =
        Paint()
          ..color = _profile.outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1;

    canvas.drawOval(
      Rect.fromCenter(center: center, width: 22, height: 20),
      skin,
    );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 22, height: 20),
      outline,
    );

    final hairRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy - 2),
      width: 24,
      height: 16,
    );
    canvas.drawArc(
      hairRect,
      math.pi,
      math.pi,
      true,
      Paint()..color = _profile.hair,
    );

    final highlight = Rect.fromCenter(
      center: Offset(center.dx - 4, center.dy - 5),
      width: 7,
      height: 4,
    );
    canvas.drawOval(
      highlight,
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
  }

  void _drawRoleAccent(Canvas canvas, Rect torsoRect, Offset headCenter) {
    switch (_profile.role) {
      case _CharacterRole.lead:
        canvas.drawCircle(
          Offset(headCenter.dx + 8, headCenter.dy - 3),
          2.5,
          Paint()..color = _profile.accent,
        );
        break;
      case _CharacterRole.reviewer:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(torsoRect.center.dx + 6, torsoRect.top + 7),
              width: 7,
              height: 10,
            ),
            const Radius.circular(3),
          ),
          Paint()..color = _profile.accent.withValues(alpha: 0.9),
        );
        break;
      case _CharacterRole.imageMaker:
        canvas.drawCircle(
          Offset(torsoRect.center.dx - 8, torsoRect.center.dy),
          3,
          Paint()..color = _profile.accent.withValues(alpha: 0.85),
        );
        break;
      case _CharacterRole.designer:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(torsoRect.center.dx, torsoRect.center.dy - 1),
              width: 18,
              height: 5,
            ),
            const Radius.circular(3),
          ),
          Paint()..color = _profile.accent.withValues(alpha: 0.7),
        );
        break;
      case _CharacterRole.programmer:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(torsoRect.center.dx - 6, torsoRect.center.dy + 3),
              width: 8,
              height: 9,
            ),
            const Radius.circular(2),
          ),
          Paint()..color = _profile.accent.withValues(alpha: 0.8),
        );
        break;
    }
  }

  void _drawLaptop(Canvas canvas, double centerX, double baseY) {
    final keyboard = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(centerX, baseY), width: 23, height: 8),
      const Radius.circular(3),
    );
    canvas.drawRRect(keyboard, Paint()..color = const Color(0xFF6C6A73));
    canvas.drawRRect(
      keyboard,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.10)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _drawTablet(Canvas canvas, double centerX, double centerY) {
    final tablet = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(centerX, centerY), width: 12, height: 16),
      const Radius.circular(3),
    );
    canvas.drawRRect(tablet, Paint()..color = const Color(0xFF495464));
    canvas.drawRRect(
      tablet,
      Paint()
        ..color = _profile.accent.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _drawLimb(
    Canvas canvas, {
    required Offset start,
    required Offset end,
    required Color color,
  }) {
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = _profile.outline
        ..strokeWidth = 5.4
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      start,
      end,
      Paint()
        ..color = color
        ..strokeWidth = 4.0
        ..strokeCap = StrokeCap.round,
    );
  }

  SpriteAnimation _createWalkAnimation(
    SpriteSheet sheet, {
    int row = GameConstants.rowWalkDown,
  }) {
    return sheet.createAnimation(
      row: row,
      stepTime: GameConstants.animationStepTime,
      to: 4,
    );
  }

  void _initPlaceholderAnimations() {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 1, 1),
      Paint()..color = const Color(0x00000000),
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(1, 1);
    final sprite = Sprite(image);
    final anim = SpriteAnimation.spriteList([sprite], stepTime: 1);
    animations = {
      CharacterState.idle: anim,
      CharacterState.walk: anim,
      CharacterState.work: anim,
      CharacterState.rest: anim,
      CharacterState.meeting: anim,
    };
    _walkAnimations = {
      GameConstants.rowWalkDown: anim,
      GameConstants.rowWalkUp: anim,
      GameConstants.rowWalkLeft: anim,
      GameConstants.rowWalkRight: anim,
    };
  }

  Future<void> _loadDirectionalMotionAtlas(String basePath) async {
    Future<Sprite> loadSprite(String relativePath) async {
      final image = await game.images.load('$basePath/$relativePath');
      return Sprite(image);
    }

    Future<Sprite> loadFirstAvailable(List<String> relativePaths) async {
      Object? lastError;
      for (final relativePath in relativePaths) {
        try {
          return await loadSprite(relativePath);
        } catch (error) {
          lastError = error;
        }
      }
      throw StateError(
        'Unable to load any sprite from $relativePaths: $lastError',
      );
    }

    final walkDown = await Future.wait(
      List.generate(4, (i) => loadSprite('walk/walk_down_$i.png')),
    );
    final walkUp = await Future.wait(
      List.generate(4, (i) => loadSprite('walk/walk_up_$i.png')),
    );
    final walkLeft = await Future.wait(
      List.generate(4, (i) => loadSprite('walk/walk_left_$i.png')),
    );
    final walkRight = await Future.wait(
      List.generate(4, (i) => loadSprite('walk/walk_right_$i.png')),
    );

    final idleDown = await loadSprite('idle/idle_down.png');
    final idleLeft = await loadSprite('idle/idle_left.png');
    final idleRight = await loadSprite('idle/idle_right.png');
    final sitDeskFront = await loadFirstAvailable([
      'sit_desk/sit_desk_front.png',
      'sit_desk/sit_desk_right.png',
      'sit_desk/sit_desk_left.png',
    ]);
    final sitDeskLeft = await loadSprite('sit_desk/sit_desk_left.png');
    final sitDeskRight = await loadSprite('sit_desk/sit_desk_right.png');
    final sitSofaUp = await loadFirstAvailable([
      'sofa_states/sit_sofa_up.png',
      'sit_desk/sit_desk_front.png',
      'sit_desk/sit_desk_right.png',
      'sit_desk/sit_desk_left.png',
    ]);
    final sitSofaFront = await loadFirstAvailable([
      'sofa_states/sit_sofa_front.png',
      'sit_desk/sit_desk_front.png',
    ]);
    final talkUp = await loadSprite('meeting_states/talk_up.png');

    const double scale = 1.05;
    size.setValues(92 * scale, 132 * scale);

    _walkAnimations = {
      GameConstants.rowWalkDown: SpriteAnimation.spriteList(
        walkDown,
        stepTime: GameConstants.animationStepTime,
      ),
      GameConstants.rowWalkUp: SpriteAnimation.spriteList(
        walkUp,
        stepTime: GameConstants.animationStepTime,
      ),
      GameConstants.rowWalkLeft: SpriteAnimation.spriteList(
        walkLeft,
        stepTime: GameConstants.animationStepTime,
      ),
      GameConstants.rowWalkRight: SpriteAnimation.spriteList(
        walkRight,
        stepTime: GameConstants.animationStepTime,
      ),
    };

    animations = {
      CharacterState.walk: _walkAnimations[GameConstants.rowWalkDown]!,
      CharacterState.idle: SpriteAnimation.spriteList([idleDown], stepTime: 1),
      CharacterState.work: SpriteAnimation.spriteList([
        sitDeskFront,
      ], stepTime: 1),
      CharacterState.rest: SpriteAnimation.spriteList([idleRight], stepTime: 1),
      CharacterState.meeting: SpriteAnimation.spriteList([
        idleLeft,
      ], stepTime: 1),
    };

    _taskSprites[CharacterState.work] = sitSofaUp;
    _taskSprites[CharacterState.meeting] = talkUp;
    _taskSprites[CharacterState.rest] = sitSofaFront;

    // Preload directional seated variants for fast seat-direction switching.
    if (_effectiveSeatDirection == 'left') {
      _taskSprites[CharacterState.work] = sitDeskLeft;
    } else if (_effectiveSeatDirection == 'right') {
      _taskSprites[CharacterState.work] = sitDeskRight;
    }
  }

  double get _currentBob {
    if (_isDeskSeated) {
      return math.sin(_visualTime * 3.2) * 0.35;
    }
    if (current == CharacterState.walk) {
      return math.sin(_visualTime * 9.5).abs() * 2.3;
    }
    if (current == CharacterState.work) {
      return math.sin(_visualTime * 3.2) * 0.8;
    }
    if (current == CharacterState.meeting) {
      return math.sin(_visualTime * 4.4) * 1.0;
    }
    return math.sin(_visualTime * 2.4) * 0.6;
  }

  Color _shiftLightness(Color color, double delta) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness + delta).clamp(0.0, 1.0)).toColor();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _visualTime += dt;
    _idleCooldownRemaining = math.max(0.0, _idleCooldownRemaining - dt);
    _movementBlockRemaining = math.max(0.0, _movementBlockRemaining - dt);

    _updateEnergy(dt);

    if (!isMoving && _activeTask != null && current != CharacterState.walk) {
      _taskTimer += dt;
      if (_taskTimer >= taskDuration) {
        _finishTask();
      }
    }

    if (targetPosition != null) {
      if (_movementBlockRemaining > 0) {
        current = CharacterState.idle;
        return;
      }

      final direction = targetPosition! - position;
      final distance = direction.length;
      _trackMovementProgress(distance, dt);

      if (distance < 2.0) {
        position = targetPosition!.clone();
        _resetMovementProgress();
        if (_routeQueue.isNotEmpty) {
          targetPosition = _routeQueue.removeAt(0);
          current = CharacterState.walk;
        } else {
          if (_continueToSeatBeforeStateChange()) {
            return;
          }
          targetPosition = null;
          _routeDestination = null;
          current = nextState;
          _alignFacingToSeat();
        }
      } else {
        final velocity = direction.normalized() * GameConstants.walkSpeed;
        final stepDistance = math.min(GameConstants.walkSpeed * dt, distance);
        position += direction.normalized() * stepDistance;
        _clampToSceneBounds();
        current = CharacterState.walk;
        _facing = velocity.normalized();
        if (!_usePlaceholder) {
          _updateWalkDirection(velocity);
        }
      }
    }
  }

  void _updateEnergy(double dt) {
    switch (current) {
      case CharacterState.work:
        energy -= 2.0 * dt;
        productivityContribution += 1.0 * dt;
        break;
      case CharacterState.rest:
        energy += 5.0 * dt;
        break;
      case CharacterState.meeting:
        energy -= 1.0 * dt;
        productivityContribution += 0.5 * dt;
        break;
      case CharacterState.walk:
        energy -= 0.5 * dt;
        break;
      case CharacterState.idle:
        energy -= 0.1 * dt;
        break;
      case null:
        break;
    }
    energy = energy.clamp(0.0, 100.0);
  }

  void _alignFacingToSeat() {
    switch (_effectiveSeatDirection) {
      case 'left':
        _facing = Vector2(-1, 0);
        _applySeatTaskSpriteVariant();
        break;
      case 'right':
        _facing = Vector2(1, 0);
        _applySeatTaskSpriteVariant();
        break;
      case 'up':
        _facing = Vector2(0, -1);
        _applySeatTaskSpriteVariant();
        break;
      case 'down':
      case null:
        _facing = Vector2(0, 1);
        _applySeatTaskSpriteVariant();
        break;
    }
  }

  Future<void> _setTaskSpriteFromCandidates(
    CharacterState state,
    List<String> relativePaths,
  ) async {
    if (motionAtlasBasePath == null) {
      return;
    }
    for (final relativePath in relativePaths) {
      try {
        final image = await game.images.load(
          '$motionAtlasBasePath/$relativePath',
        );
        _taskSprites[state] = Sprite(image);
        _centerTaskSpriteOnPosition =
            state == CharacterState.meeting &&
            relativePath.startsWith('meeting_seated/');
        return;
      } catch (_) {
        continue;
      }
    }
  }

  void _applySeatTaskSpriteVariant() {
    if (motionAtlasBasePath == null || currentSeat == null) {
      return;
    }

    final direction = _effectiveSeatDirection;
    if (currentSeat!.type == SeatType.desk) {
      final paths =
          direction == 'left'
              ? ['sit_desk/sit_desk_left.png']
              : direction == 'right'
              ? ['sit_desk/sit_desk_right.png']
              : direction == 'up'
              ? ['sofa_states/sit_sofa_up.png', 'sit_desk/sit_desk_front.png']
              : [
                'sit_desk/sit_desk_front.png',
                'sit_desk/sit_desk_right.png',
                'sit_desk/sit_desk_left.png',
              ];
      _setTaskSpriteFromCandidates(CharacterState.work, paths);
      return;
    }

    if (currentSeat!.type == SeatType.sofa) {
      final paths =
          direction == 'left'
              ? ['sofa_states/sit_sofa_left.png', 'sit_desk/sit_desk_left.png']
              : direction == 'right'
              ? [
                'sofa_states/sit_sofa_right.png',
                'sit_desk/sit_desk_right.png',
              ]
              : direction == 'up'
              ? ['sofa_states/sit_sofa_up.png', 'sit_desk/sit_desk_front.png']
              : [
                'sofa_states/sit_sofa_front.png',
                'sit_desk/sit_desk_front.png',
                'sit_desk/sit_desk_left.png',
                'sit_desk/sit_desk_right.png',
              ];
      _setTaskSpriteFromCandidates(CharacterState.rest, paths);
      return;
    }

    if (currentSeat!.type == SeatType.meeting) {
      final directionKey =
          direction == 'left'
              ? 'left'
              : direction == 'right'
              ? 'right'
              : direction == 'down'
              ? 'down'
              : 'up';
      final fallbackPath =
          direction == 'left'
              ? 'meeting_states/talk_left.png'
              : direction == 'right'
              ? 'meeting_states/talk_right.png'
              : direction == 'down'
              ? 'sit_desk/sit_desk_front.png'
              : 'meeting_states/talk_up.png';
      _setTaskSpriteFromCandidates(CharacterState.meeting, [
        'meeting_seated/meeting_seated_$directionKey.png',
        'meeting_seated/meeting_seated_up.png',
        'meeting_seated/meeting_seated_down.png',
        'meeting_seated/meeting_seated_left.png',
        'meeting_seated/meeting_seated_right.png',
        fallbackPath,
      ]);
    }
  }

  void _updateWalkDirection(Vector2 velocity) {
    int row = GameConstants.rowWalkDown;
    if (velocity.x.abs() > velocity.y.abs()) {
      row =
          velocity.x > 0
              ? GameConstants.rowWalkRight
              : GameConstants.rowWalkLeft;
    } else {
      row =
          velocity.y > 0 ? GameConstants.rowWalkDown : GameConstants.rowWalkUp;
    }

    if (row != _currentWalkRow && animations != null) {
      _currentWalkRow = row;
      animations = Map<CharacterState, SpriteAnimation>.from(animations!)
        ..[CharacterState.walk] = _walkAnimations[row]!;
    }
  }

  void moveTo(Vector2 target, CharacterState onArrival) {
    _moveOutOfNavigationObstacle(target);
    _routeDestination = target.clone();
    final route = _buildPlannedRoute(position, target);
    _applyRoute(route);
    nextState = onArrival;
    _movementBlockRemaining = 0;
    current = CharacterState.walk;
  }

  void followCustomRoute(List<Vector2> waypoints, CharacterState onArrival) {
    final route =
        waypoints
            .where((point) => point.x.isFinite && point.y.isFinite)
            .map((point) => point.clone())
            .toList();
    if (route.isEmpty) {
      return;
    }

    cancelCurrentTask();
    _moveOutOfNavigationObstacle(route.last);
    _routeDestination = route.last.clone();
    _applyRoute(_dedupeRoute(route));
    nextState = onArrival;
    _movementBlockRemaining = 0;
    current = CharacterState.walk;
  }

  bool followCustomRouteToSeat(
    List<Vector2> waypoints,
    CharacterTask task,
    Seat seat, {
    bool force = true,
    Vector2? targetPositionOverride,
    String? targetDirectionOverride,
  }) {
    if (!force && !readyForAssignment) {
      return false;
    }

    final route =
        waypoints
            .where((point) => point.x.isFinite && point.y.isFinite)
            .map((point) => point.clone())
            .toList();
    if (route.isEmpty) {
      return false;
    }

    if (force) {
      cancelCurrentTask();
    }
    if (!seat.tryReserve(this)) {
      return false;
    }

    currentSeat?.release(this);
    currentSeat = seat;
    _seatPositionOverride = targetPositionOverride?.clone();
    _seatDirectionOverride = targetDirectionOverride;
    _activeTask = task;
    taskDuration = task.duration;
    _taskTimer = 0;
    _idleCooldownRemaining = 0;

    final destination = _seatTravelDestination(seat);
    if (route.last.distanceTo(destination) > 2.0) {
      route.add(destination.clone());
    }

    _moveOutOfNavigationObstacle(seat.position);
    _routeDestination = destination.clone();
    _applyRoute(_dedupeRoute(route));
    nextState = task.targetState;
    _movementBlockRemaining = 0;
    current = CharacterState.walk;
    return true;
  }

  bool followCustomRouteToIdleSeat(
    List<Vector2> waypoints,
    Seat seat, {
    bool force = false,
    Vector2? targetPositionOverride,
    String? targetDirectionOverride,
  }) {
    if (!force && !readyForAssignment) {
      return false;
    }

    final route =
        waypoints
            .where((point) => point.x.isFinite && point.y.isFinite)
            .map((point) => point.clone())
            .toList();
    if (route.isEmpty) {
      return false;
    }

    if (force) {
      cancelCurrentTask();
    }
    if (!seat.tryReserve(this)) {
      return false;
    }

    currentSeat?.release(this);
    currentSeat = seat;
    _seatPositionOverride = targetPositionOverride?.clone();
    _seatDirectionOverride = targetDirectionOverride;
    _activeTask = null;
    taskDuration = 0;
    _taskTimer = 0;
    _idleCooldownRemaining = 0;

    final destination = _seatTravelDestination(seat);
    if (route.last.distanceTo(destination) > 2.0) {
      route.add(destination.clone());
    }

    _moveOutOfNavigationObstacle(seat.position);
    _routeDestination = destination.clone();
    _applyRoute(_dedupeRoute(route));
    nextState = CharacterState.rest;
    _movementBlockRemaining = 0;
    current = CharacterState.walk;
    return true;
  }

  bool assignTask(
    CharacterTask task,
    Seat seat, {
    bool force = false,
    Vector2? targetPositionOverride,
    String? targetDirectionOverride,
  }) {
    if (!force && !readyForAssignment) {
      return false;
    }
    if (force) {
      cancelCurrentTask();
    }
    if (!seat.tryReserve(this)) {
      return false;
    }
    currentSeat?.release(this);
    currentSeat = seat;
    _seatPositionOverride = targetPositionOverride?.clone();
    _seatDirectionOverride = targetDirectionOverride;
    _activeTask = task;
    taskDuration = task.duration;
    _taskTimer = 0;
    _idleCooldownRemaining = 0;
    _moveToSeat(seat, task.targetState);
    return true;
  }

  bool assignIdleSeat(
    Seat seat, {
    bool force = false,
    Vector2? targetPositionOverride,
    String? targetDirectionOverride,
  }) {
    if (!force && !readyForAssignment) {
      return false;
    }
    if (force) {
      cancelCurrentTask();
    }
    if (!seat.tryReserve(this)) {
      return false;
    }
    currentSeat?.release(this);
    currentSeat = seat;
    _seatPositionOverride = targetPositionOverride?.clone();
    _seatDirectionOverride = targetDirectionOverride;
    _activeTask = null;
    taskDuration = 0;
    _taskTimer = 0;
    _idleCooldownRemaining = 0;
    _moveToSeat(seat, CharacterState.rest);
    return true;
  }

  void forcePlaceAt(Vector2 target) {
    targetPosition = null;
    _routeDestination = null;
    _routeQueue.clear();
    _activeTask = null;
    taskDuration = 0;
    _taskTimer = 0;
    _idleCooldownRemaining = 0;
    currentSeat?.release(this);
    currentSeat = null;
    _seatPositionOverride = null;
    _seatDirectionOverride = null;
    _centerTaskSpriteOnPosition = false;
    position.setFrom(target);
    _clampToSceneBounds();
    _resetMovementProgress();
    if (animations != null && current != null) {
      current = CharacterState.idle;
    }
  }

  void forcePlaceAtState(
    CharacterState state,
    Vector2 target, {
    String? direction,
  }) {
    forcePlaceAt(target);
    final seatType = _seatTypeForState(state);
    if (seatType == null) {
      return;
    }
    currentSeat = Seat(
      position: position.clone(),
      type: seatType,
      direction: direction,
    );
    _seatPositionOverride = position.clone();
    _seatDirectionOverride = direction;
    _centerTaskSpriteOnPosition = state == CharacterState.meeting;
    current = state;
    nextState = state;
    _alignFacingToSeat();
  }

  SeatType? _seatTypeForState(CharacterState state) {
    switch (state) {
      case CharacterState.work:
        return SeatType.desk;
      case CharacterState.meeting:
        return SeatType.meeting;
      case CharacterState.rest:
        return SeatType.sofa;
      case CharacterState.walk:
      case CharacterState.idle:
        return null;
    }
  }

  void idleFor(double duration) {
    _idleCooldownRemaining = math.max(_idleCooldownRemaining, duration);
    if (_activeTask == null && !isMoving) {
      current = CharacterState.idle;
    }
  }

  void cancelCurrentTask() {
    _standUpFromSeat();
    _activeTask = null;
    taskDuration = 0;
    _taskTimer = 0;
    targetPosition = null;
    _routeDestination = null;
    _seatPositionOverride = null;
    _seatDirectionOverride = null;
    _routeQueue.clear();
    nextState = CharacterState.idle;
    current = CharacterState.idle;
    currentSeat?.release(this);
    currentSeat = null;
    _seatPositionOverride = null;
    _seatDirectionOverride = null;
  }

  void _finishTask() {
    final exitStart = _standUpFromSeat();
    _activeTask = null;
    taskDuration = 0;
    _taskTimer = 0;
    _facing = Vector2(0, 1);
    _idleCooldownRemaining = 0.75;

    currentSeat?.release(this);
    currentSeat = null;

    final exitRoute =
        exitStart == null ? null : exitRouteBuilder?.call(position);
    if (exitRoute != null && exitRoute.isNotEmpty) {
      final route =
          exitRoute
              .where((point) => point.x.isFinite && point.y.isFinite)
              .map((point) => point.clone())
              .toList();
      if (route.isNotEmpty) {
        _routeDestination = route.last.clone();
        _applyRoute(_dedupeRoute(route));
        nextState = CharacterState.idle;
        _movementBlockRemaining = 0;
        current = CharacterState.walk;
        return;
      }
    }

    current = CharacterState.idle;
  }

  void _moveToSeat(Seat seat, CharacterState onArrival) {
    _moveOutOfNavigationObstacle(seat.position);
    final destination = _seatTravelDestination(seat);
    _routeDestination = destination.clone();
    final route = _buildPlannedRoute(position, destination);
    _applyRoute(route);
    nextState = onArrival;
    _movementBlockRemaining = 0;
    current = CharacterState.walk;
  }

  Vector2 _seatTravelDestination(Seat seat) {
    return _finalSeatPosition(seat);
  }

  Furniture? _furnitureForSeat(Seat seat) {
    final obstacleId = seat.obstacleId;
    if (obstacleId == null) {
      return null;
    }

    for (final furniture in game.world.children.whereType<Furniture>()) {
      if (furniture.obstacleId == obstacleId) {
        return furniture;
      }
    }
    return null;
  }

  bool _continueToSeatBeforeStateChange() {
    final seat = currentSeat;
    if (seat == null || nextState == CharacterState.idle) {
      return false;
    }

    final finalSeatPosition = _finalSeatPosition(seat);
    if (position.distanceTo(finalSeatPosition) <= _seatArrivalTolerance) {
      return false;
    }

    targetPosition = finalSeatPosition;
    _routeDestination = finalSeatPosition.clone();
    _resetMovementProgress();
    current = CharacterState.walk;
    return true;
  }

  Vector2 _finalSeatPosition(Seat seat) {
    return _seatPositionOverride?.clone() ?? seat.position.clone();
  }

  Vector2? _standUpFromSeat() {
    final seat = currentSeat;
    if (seat == null) {
      return null;
    }

    final furniture = _furnitureForSeat(seat);
    final standPoint = furniture?.approachPointForSeat(seat);
    if (standPoint == null) {
      return null;
    }

    return standPoint.clone();
  }

  void _moveOutOfNavigationObstacle(Vector2 destination) {}

  List<Vector2> _buildPlannedRoute(
    Vector2 start,
    Vector2 destination, {
    Furniture? priority,
    Set<String> ignoredObstacleIds = const {},
  }) {
    final highLevelPoints = _trafficPlanPoints(start, destination);
    final route = <Vector2>[];
    var current = start.clone();

    for (final point in highLevelPoints) {
      if (current.distanceTo(point) < 2.0) {
        continue;
      }
      final segment = _buildRoute(
        current,
        point,
        priority: priority,
        ignoredObstacleIds: ignoredObstacleIds,
      );
      route.addAll(segment);
      current = point.clone();
    }

    return route.isEmpty ? [destination.clone()] : route;
  }

  List<Vector2> _dedupeRoute(List<Vector2> route) {
    final result = <Vector2>[];
    for (final point in route) {
      if (result.isNotEmpty && result.last.distanceTo(point) < 2.0) {
        continue;
      }
      result.add(point.clone());
    }
    return result;
  }

  List<Vector2> _trafficPlanPoints(Vector2 start, Vector2 destination) {
    final points = <Vector2>[];
    final shouldUseLane =
        (start.x - destination.x).abs() > 180 ||
        (start.y - destination.y).abs() > 220;
    if (shouldUseLane) {
      final laneY = _trafficLaneY;
      final startCorridorX = _corridorXFor(start);
      final destinationCorridorX = _corridorXFor(destination);
      points
        ..add(Vector2(startCorridorX, start.y))
        ..add(Vector2(startCorridorX, laneY))
        ..add(Vector2(destinationCorridorX, laneY))
        ..add(Vector2(destinationCorridorX, destination.y));
    }
    points.add(destination.clone());
    return _dedupeRoute(points);
  }

  double _corridorXFor(Vector2 point) {
    if (point.x < 610.0) {
      return 590.0;
    }
    if (point.x > 1040.0) {
      return 1035.0;
    }
    return point.x < 820.0 ? 590.0 : 1035.0;
  }

  double get _trafficLaneY {
    final sceneHeight = OfficeSceneConfig.sceneSize.y;
    final lane = switch (name) {
      '程序员' => 820.0,
      '设计师' => 860.0,
      '项目经理' => 900.0,
      '测试' => 940.0,
      '运营' => 780.0,
      _ =>
        820.0 +
            (name.codeUnits.fold<int>(0, (sum, unit) => sum + unit) % 5) * 40.0,
    };
    return lane.clamp(height + 8.0, sceneHeight - 24.0);
  }

  void _applyRoute(List<Vector2> route) {
    _routeQueue.clear();
    final normalized =
        route.where((point) => position.distanceTo(point) >= 2.0).toList();
    if (normalized.isEmpty) {
      targetPosition = _routeDestination?.clone();
      if (targetPosition == null) {
        return;
      }
    } else {
      targetPosition = normalized.removeAt(0);
      _routeQueue.addAll(normalized);
    }
    _resetMovementProgress();
  }

  void _trackMovementProgress(double distance, double dt) {
    final target = targetPosition;
    if (target == null) {
      _resetMovementProgress();
      return;
    }

    if (_movementWatchTarget == null ||
        _movementWatchTarget!.distanceTo(target) > 0.5) {
      _movementWatchTarget = target.clone();
      _movementBestDistance = distance;
      _movementNoProgressTime = 0;
      _movementStillTime = 0;
      _movementLastPosition.setFrom(position);
      return;
    }

    final movedDistance = position.distanceTo(_movementLastPosition);
    if (movedDistance < 0.35) {
      _movementStillTime += dt;
    } else {
      _movementStillTime = 0;
      _movementLastPosition.setFrom(position);
    }

    if (distance < _movementBestDistance - 0.75) {
      _movementBestDistance = distance;
      _movementNoProgressTime = 0;
    } else {
      _movementNoProgressTime += dt;
    }

    if (_movementNoProgressTime >= 1.2 || _movementStillTime >= 0.45) {
      _resetMovementProgress();
    }
  }

  void _resetMovementProgress() {
    _movementWatchTarget = null;
    _movementBestDistance = double.infinity;
    _movementNoProgressTime = 0;
    _movementStillTime = 0;
    _movementLastPosition.setFrom(position);
  }

  List<Vector2> _buildRoute(
    Vector2 start,
    Vector2 destination, {
    Furniture? priority,
    Set<String> ignoredObstacleIds = const {},
  }) {
    return [destination.clone()];
  }

  void _clampToSceneBounds() {
    final halfWidth = width / 2;
    final sceneSize = OfficeSceneConfig.sceneSize;
    x = x.clamp(halfWidth, sceneSize.x - halfWidth);
    y = y.clamp(height, sceneSize.y);
  }

  static const double _seatArrivalTolerance = 4.0;
}

enum _CharacterRole { lead, reviewer, imageMaker, designer, programmer }

class _CharacterVisualProfile {
  final _CharacterRole role;
  final Color skin;
  final Color hair;
  final Color jacket;
  final Color shirt;
  final Color pants;
  final Color accent;
  final Color outline;

  const _CharacterVisualProfile({
    required this.role,
    required this.skin,
    required this.hair,
    required this.jacket,
    required this.shirt,
    required this.pants,
    required this.accent,
    required this.outline,
  });

  factory _CharacterVisualProfile.fromName(String name) {
    if (name.contains('项目经理')) {
      return const _CharacterVisualProfile(
        role: _CharacterRole.lead,
        skin: Color(0xFFE5C0A2),
        hair: Color(0xFF6A3E2B),
        jacket: Color(0xFF244261),
        shirt: Color(0xFFF3E8D9),
        pants: Color(0xFF283344),
        accent: Color(0xFFCE8B45),
        outline: Color(0xFF322922),
      );
    }
    if (name.contains('测试')) {
      return const _CharacterVisualProfile(
        role: _CharacterRole.reviewer,
        skin: Color(0xFFD8B492),
        hair: Color(0xFF5B463B),
        jacket: Color(0xFF4E7B57),
        shirt: Color(0xFFEAF4EC),
        pants: Color(0xFF344B42),
        accent: Color(0xFF8BC57E),
        outline: Color(0xFF322922),
      );
    }
    if (name.contains('运营')) {
      return const _CharacterVisualProfile(
        role: _CharacterRole.imageMaker,
        skin: Color(0xFFE1B48C),
        hair: Color(0xFF6A4B44),
        jacket: Color(0xFFE889A5),
        shirt: Color(0xFFF2E5D3),
        pants: Color(0xFF3E3A44),
        accent: Color(0xFFD86A91),
        outline: Color(0xFF322922),
      );
    }
    if (name.contains('设计师')) {
      return const _CharacterVisualProfile(
        role: _CharacterRole.designer,
        skin: Color(0xFFE6C2A7),
        hair: Color(0xFF57443E),
        jacket: Color(0xFF7AA68C),
        shirt: Color(0xFFEFF4E9),
        pants: Color(0xFF55645B),
        accent: Color(0xFF95C5A8),
        outline: Color(0xFF322922),
      );
    }
    return const _CharacterVisualProfile(
      role: _CharacterRole.programmer,
      skin: Color(0xFFD9B18C),
      hair: Color(0xFF2F2F38),
      jacket: Color(0xFF53647C),
      shirt: Color(0xFFE9EEF5),
      pants: Color(0xFF313846),
      accent: Color(0xFF86A9D6),
      outline: Color(0xFF322922),
    );
  }
}

class _TaskSpriteLayout {
  final double scale;
  final Offset offset;

  const _TaskSpriteLayout({required this.scale, required this.offset});
}
