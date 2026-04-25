import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/collisions.dart';
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

class Character extends SpriteAnimationGroupComponent<CharacterState>
    with HasGameReference<FlameGame>, CollisionCallbacks {
  final String name;
  final String spriteSheetPath;
  final List<String>? animationFrames;
  final String? motionAtlasBasePath;

  Vector2? targetPosition;
  Seat? currentSeat;
  CharacterState nextState = CharacterState.idle;
  CharacterTask? _activeTask;
  bool _usePlaceholder = false;
  late final Map<int, SpriteAnimation> _walkAnimations;
  final Map<CharacterState, Sprite> _taskSprites = {};
  int _currentWalkRow = GameConstants.rowWalkDown;

  // Dynamic stats
  double energy = 100.0;
  double productivityContribution = 0.0;
  double taskDuration = 0.0;
  double _taskTimer = 0.0;
  double _visualTime = 0.0;
  double _idleCooldownRemaining = 0.0;
  double _movementBlockRemaining = 0.0;
  Vector2 _facing = Vector2(0, 1);
  final Vector2 _spawnPosition;
  final Vector2 _previousPosition = Vector2.zero();

  late final _CharacterVisualProfile _profile =
      _CharacterVisualProfile.fromName(name);

  Character({
    required this.name,
    required this.spriteSheetPath,
    required Vector2 position,
    this.animationFrames,
    this.motionAtlasBasePath,
  }) : _spawnPosition = position.clone(),
       super(
         size: GameConstants.characterSize,
         anchor: Anchor.bottomCenter,
         position: position,
       );

  bool get isMoving => targetPosition != null;
  bool get readyForAssignment =>
      !isMoving && _activeTask == null && _idleCooldownRemaining <= 0;
  CharacterTask? get activeTask => _activeTask;
  bool get _isDeskSeated =>
      current == CharacterState.work &&
      currentSeat?.type == SeatType.desk &&
      !isMoving;
  bool get _renderProceduralTaskPose =>
      currentSeat != null &&
      !isMoving &&
      (current == CharacterState.work || current == CharacterState.rest) &&
      _currentTaskSprite == null;
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

    add(
      RectangleHitbox(
        position: Vector2(size.x * 0.33, size.y * 0.74),
        size: Vector2(size.x * 0.34, size.y * 0.18),
        collisionType: CollisionType.active,
      ),
    );
  }

  @override
  void onCollisionStart(
    Set<Vector2> intersectionPoints,
    PositionComponent other,
  ) {
    super.onCollisionStart(intersectionPoints, other);
    if (other is Character) {
      _handleCharacterCollision(other);
      return;
    }
    if (other is Furniture) {
      _handleFurnitureCollision(other);
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
    final rect = Rect.fromLTWH(
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

    final direction = seat.direction;
    if (seat.type == SeatType.desk) {
      if (direction == 'left') {
        return const _TaskSpriteLayout(
          scale: 0.56,
          offset: Offset(-12, -18),
        );
      }
      if (direction == 'right') {
        return const _TaskSpriteLayout(
          scale: 0.56,
          offset: Offset(12, -18),
        );
      }
      return const _TaskSpriteLayout(
        scale: 0.55,
        offset: Offset(0, -22),
      );
    }

    if (seat.type == SeatType.meeting) {
      if (direction == 'left') {
        return const _TaskSpriteLayout(
          scale: 0.54,
          offset: Offset(-10, -16),
        );
      }
      if (direction == 'right') {
        return const _TaskSpriteLayout(
          scale: 0.54,
          offset: Offset(10, -16),
        );
      }
      if (direction == 'up') {
        return const _TaskSpriteLayout(
          scale: 0.54,
          offset: Offset(0, -14),
        );
      }
      return const _TaskSpriteLayout(
        scale: 0.54,
        offset: Offset(0, -10),
      );
    }

    if (seat.type == SeatType.sofa) {
      if (direction == 'left') {
        return const _TaskSpriteLayout(
          scale: 0.57,
          offset: Offset(-10, -12),
        );
      }
      if (direction == 'right') {
        return const _TaskSpriteLayout(
          scale: 0.57,
          offset: Offset(10, -12),
        );
      }
      if (direction == 'up') {
        return const _TaskSpriteLayout(
          scale: 0.58,
          offset: Offset(0, -8),
        );
      }
      return const _TaskSpriteLayout(
        scale: 0.58,
        offset: Offset(0, -16),
      );
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
    final idleUp = await loadSprite('idle/idle_up.png');
    final idleLeft = await loadSprite('idle/idle_left.png');
    final idleRight = await loadSprite('idle/idle_right.png');
    final sitDeskFront = await loadFirstAvailable([
      'sit_desk/sit_desk_front.png',
      'sit_desk/sit_desk_right.png',
      'sit_desk/sit_desk_left.png',
    ]);
    final sitDeskLeft = await loadSprite('sit_desk/sit_desk_left.png');
    final sitDeskRight = await loadSprite('sit_desk/sit_desk_right.png');
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
      CharacterState.work: SpriteAnimation.spriteList([idleUp], stepTime: 1),
      CharacterState.rest: SpriteAnimation.spriteList([idleRight], stepTime: 1),
      CharacterState.meeting: SpriteAnimation.spriteList([
        idleLeft,
      ], stepTime: 1),
    };

    _taskSprites[CharacterState.work] = sitDeskFront;
    _taskSprites[CharacterState.meeting] = talkUp;
    _taskSprites[CharacterState.rest] = sitDeskFront;

    // Preload directional seated variants for fast seat-direction switching.
    if (currentSeat?.direction == 'left') {
      _taskSprites[CharacterState.work] = sitDeskLeft;
    } else if (currentSeat?.direction == 'right') {
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

      if (distance < 2.0) {
        position = targetPosition!.clone();
        targetPosition = null;
        current = nextState;
        _alignFacingToSeat();
      } else {
        _previousPosition.setFrom(position);
        final velocity = direction.normalized() * GameConstants.walkSpeed;
        position += velocity * dt;
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
    switch (currentSeat?.direction) {
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

  Future<void> _setTaskSprite(CharacterState state, String relativePath) async {
    await _setTaskSpriteFromCandidates(state, [relativePath]);
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

    final direction = currentSeat!.direction;
    if (currentSeat!.type == SeatType.desk) {
      final paths =
          direction == 'left'
              ? ['sit_desk/sit_desk_left.png']
              : direction == 'right'
              ? ['sit_desk/sit_desk_right.png']
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
              ? ['sit_desk/sit_desk_left.png']
              : direction == 'right'
              ? ['sit_desk/sit_desk_right.png']
              : direction == 'up'
              ? ['sit_desk/sit_desk_front.png']
              : [
                'sit_desk/sit_desk_front.png',
                'sit_desk/sit_desk_left.png',
                'sit_desk/sit_desk_right.png',
              ];
      _setTaskSpriteFromCandidates(CharacterState.rest, paths);
      return;
    }

    if (currentSeat!.type == SeatType.meeting) {
      final path =
          direction == 'left'
              ? 'meeting_states/talk_left.png'
              : direction == 'right'
              ? 'meeting_states/talk_right.png'
              : 'meeting_states/talk_up.png';
      _setTaskSprite(CharacterState.meeting, path);
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
    targetPosition = target;
    nextState = onArrival;
    _movementBlockRemaining = 0;
    current = CharacterState.walk;
  }

  bool assignTask(CharacterTask task, Seat seat, {bool force = false}) {
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
    _activeTask = task;
    taskDuration = task.duration;
    _taskTimer = 0;
    _idleCooldownRemaining = 0;
    moveTo(seat.position, task.targetState);
    return true;
  }

  void idleFor(double duration) {
    _idleCooldownRemaining = math.max(_idleCooldownRemaining, duration);
    if (_activeTask == null && !isMoving) {
      current = CharacterState.idle;
    }
  }

  void cancelCurrentTask() {
    _activeTask = null;
    taskDuration = 0;
    _taskTimer = 0;
    targetPosition = null;
    nextState = CharacterState.idle;
    current = CharacterState.idle;
    currentSeat?.release(this);
    currentSeat = null;
  }

  void _finishTask() {
    current = CharacterState.idle;
    _activeTask = null;
    taskDuration = 0;
    _taskTimer = 0;
    _facing = Vector2(0, 1);
    _idleCooldownRemaining = 0.75;

    if (currentSeat != null) {
      currentSeat!.release(this);
      currentSeat = null;
    }
  }

  void _handleCharacterCollision(Character other) {
    if (!isMoving || identical(other, this) || currentSeat != null) {
      return;
    }

    position.setFrom(_previousPosition);
    _clampToSceneBounds();
    _movementBlockRemaining = 0.10 + (name.hashCode.abs() % 5) * 0.03;

    if (current == CharacterState.walk) {
      current = CharacterState.idle;
    }
  }

  void _handleFurnitureCollision(Furniture furniture) {
    if (!isMoving) {
      return;
    }

    final seat = currentSeat;
    if (_canPassThroughAssignedFurniture(furniture, seat)) {
      return;
    }

    position.setFrom(_previousPosition);
    _clampToSceneBounds();
    _movementBlockRemaining = 0.08;

    if (current == CharacterState.walk) {
      current = CharacterState.idle;
    }
  }

  bool _canPassThroughAssignedFurniture(Furniture furniture, Seat? seat) {
    if (seat == null || seat.obstacleId != furniture.obstacleId) {
      return false;
    }

    final target = targetPosition;
    if (target == null) {
      return false;
    }

    return position.distanceTo(target) <= 18;
  }

  void _clampToSceneBounds() {
    final halfWidth = width / 2;
    final sceneSize = OfficeSceneConfig.sceneSize;
    x = x.clamp(halfWidth, sceneSize.x - halfWidth);
    y = y.clamp(height, sceneSize.y);
  }
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
