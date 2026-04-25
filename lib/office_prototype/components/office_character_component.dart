import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../models/character_data.dart';
import '../models/character_state.dart';
import '../models/seat_data.dart';

class OfficeCharacterComponent extends PositionComponent
    with HasGameReference<FlameGame> {
  OfficeCharacterComponent({required this.data, required super.priority})
    : super(
        position: data.position.clone(),
        size: Vector2(64, 112),
        anchor: Anchor.bottomCenter,
      );

  final CharacterData data;
  final double speed = 190;
  final Map<SeatDirection, Sprite> _idleSprites = {};
  final Map<SeatDirection, List<Sprite>> _walkSprites = {};
  final Map<String, Sprite> _sitSprites = {};

  SeatData? currentSeat;
  SeatData? targetSeat;
  Vector2? targetPosition;
  SeatDirection facing = SeatDirection.down;
  CharacterState arrivalState = CharacterState.idle;
  bool selected = false;
  double _walkTimer = 0;

  bool get isMoving => targetPosition != null;

  bool containsWorldPoint(Vector2 point) {
    final left = position.x - size.x / 2;
    final top = position.y - size.y;
    return point.x >= left &&
        point.x <= left + size.x &&
        point.y >= top &&
        point.y <= top + size.y;
  }

  @override
  Future<void> onLoad() async {
    await _loadIdleSprites();
    await _loadWalkSprites();
    await _loadSitSprites();
  }

  Future<void> _loadIdleSprites() async {
    for (final direction in SeatDirection.values) {
      final sprite = await _tryLoadSprite(
        '${data.assetBasePath}/idle_${direction.assetName}.png',
      );
      if (sprite != null) {
        _idleSprites[direction] = sprite;
      }
    }
  }

  Future<void> _loadWalkSprites() async {
    for (final direction in SeatDirection.values) {
      final first = await _tryLoadSprite(
        '${data.assetBasePath}/walk_${direction.assetName}_01.png',
      );
      final second = await _tryLoadSprite(
        '${data.assetBasePath}/walk_${direction.assetName}_02.png',
      );
      final frames = [first, second].whereType<Sprite>().toList();
      if (frames.isNotEmpty) {
        _walkSprites[direction] = frames;
      }
    }
  }

  Future<void> _loadSitSprites() async {
    for (final state in [
      CharacterState.working,
      CharacterState.discussing,
      CharacterState.resting,
    ]) {
      for (final direction in SeatDirection.values) {
        final key = _sitKey(state, direction);
        final sprite = await _tryLoadSprite(
          '${data.assetBasePath}/sit_${state.sitAssetKey}_${direction.assetName}.png',
        );
        if (sprite != null) {
          _sitSprites[key] = sprite;
        }
      }
    }
  }

  Future<Sprite?> _tryLoadSprite(String path) async {
    try {
      return await game.loadSprite(path);
    } catch (_) {
      return null;
    }
  }

  void assignToSeat(SeatData seat) {
    currentSeat?.occupiedBy = null;
    targetSeat?.occupiedBy = null;
    currentSeat = null;
    targetSeat = seat;
    targetSeat!.occupiedBy = data.id;
    targetPosition = seat.position.clone();
    arrivalState = seat.targetState;
    data.state = CharacterState.walking;
    facing = _directionTo(targetPosition! - position);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _walkTimer += dt;
    final target = targetPosition;
    if (target == null) {
      return;
    }

    final delta = target - position;
    final distance = delta.length;
    if (distance <= 3) {
      position = target;
      targetPosition = null;
      currentSeat = targetSeat;
      targetSeat = null;
      facing = currentSeat?.direction ?? facing;
      data.state = arrivalState;
      return;
    }

    final velocity = delta.normalized() * speed * dt;
    position += velocity.length > distance ? delta : velocity;
    facing = _directionTo(delta, previous: facing);
  }

  SeatDirection _directionTo(Vector2 delta, {SeatDirection? previous}) {
    final absX = delta.x.abs();
    final absY = delta.y.abs();
    final axisSwitchThreshold = 1.18;
    final lastFacing = previous;
    final wasHorizontal =
        lastFacing == SeatDirection.left || lastFacing == SeatDirection.right;

    if (lastFacing != null) {
      if (wasHorizontal && absY <= absX * axisSwitchThreshold) {
        return delta.x >= 0 ? SeatDirection.right : SeatDirection.left;
      }
      if (!wasHorizontal && absX <= absY * axisSwitchThreshold) {
        return delta.y >= 0 ? SeatDirection.down : SeatDirection.up;
      }
    }

    if (absX >= absY) {
      return delta.x >= 0 ? SeatDirection.right : SeatDirection.left;
    }
    return delta.y >= 0 ? SeatDirection.down : SeatDirection.up;
  }

  @override
  void render(Canvas canvas) {
    _drawShadow(canvas);

    final sprite = _currentSprite();
    if (sprite != null) {
      sprite.renderRect(canvas, size.toRect());
    } else {
      _drawPlaceholderCharacter(canvas);
    }

    if (selected) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.x / 2, size.y - 5),
          width: 56,
          height: 18,
        ),
        Paint()
          ..color = const Color(0xFFFFD166).withValues(alpha: 0.30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }

    _drawBubble(canvas);
    _drawName(canvas);
  }

  Sprite? _currentSprite() {
    if (data.state == CharacterState.walking) {
      final frames = _walkSprites[facing];
      if (frames == null || frames.isEmpty) {
        return null;
      }
      final index = ((_walkTimer / 0.18).floor()) % frames.length;
      return frames[index];
    }
    final seated = _sitSprites[_sitKey(data.state, facing)];
    if (seated != null) {
      return seated;
    }
    final idle = _idleSprites[facing] ?? _idleSprites[SeatDirection.down];
    if (idle != null) {
      return idle;
    }
    final idleFrames = _walkSprites[SeatDirection.down];
    return idleFrames == null || idleFrames.isEmpty ? null : idleFrames.first;
  }

  String _sitKey(CharacterState state, SeatDirection direction) {
    return '${state.sitAssetKey}_${direction.assetName}';
  }

  void _drawShadow(Canvas canvas) {
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y - 5),
        width: size.x * 0.8,
        height: 12,
      ),
      Paint()..color = Colors.black.withValues(alpha: 0.16),
    );
  }

  void _drawPlaceholderCharacter(Canvas canvas) {
    final bob =
        data.state == CharacterState.walking
            ? math.sin(_walkTimer * 16).abs() * 3
            : 0.0;
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.x / 2, size.y - 26 - bob),
        width: 30,
        height: 34,
      ),
      const Radius.circular(9),
    );
    final head = Rect.fromCenter(
      center: Offset(size.x / 2, size.y - 53 - bob),
      width: 22,
      height: 22,
    );
    canvas.drawRRect(body, Paint()..color = data.color);
    canvas.drawRRect(
      body,
      Paint()
        ..color = const Color(0xFF1F2937)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.drawOval(head, Paint()..color = const Color(0xFFE8C0A0));
    canvas.drawArc(
      head.translate(0, -3),
      math.pi,
      math.pi,
      true,
      Paint()..color = const Color(0xFF31323A),
    );

    final isSeated =
        data.state == CharacterState.working ||
        data.state == CharacterState.discussing ||
        data.state == CharacterState.resting;
    if (isSeated) {
      canvas.drawLine(
        Offset(size.x / 2 - 8, size.y - 16),
        Offset(size.x / 2 - 18, size.y - 7),
        Paint()
          ..color = const Color(0xFF374151)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        Offset(size.x / 2 + 8, size.y - 16),
        Offset(size.x / 2 + 18, size.y - 7),
        Paint()
          ..color = const Color(0xFF374151)
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _drawBubble(Canvas canvas) {
    if (data.state == CharacterState.idle ||
        data.state == CharacterState.walking) {
      return;
    }
    final text = switch (data.state) {
      CharacterState.working => 'PC',
      CharacterState.discussing => '...',
      CharacterState.resting => 'Z',
      CharacterState.idle => '',
      CharacterState.walking => '',
    };
    final bubble = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.x / 2 + 10, 0, 32, 24),
      const Radius.circular(12),
    );
    canvas.drawRRect(
      bubble,
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
    canvas.drawRRect(
      bubble,
      Paint()
        ..color = const Color(0xFF475569).withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke,
    );
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Color(0xFF27364A),
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 30);
    painter.paint(canvas, Offset(size.x / 2 + 20 - painter.width / 2, 4));
  }

  void _drawName(Canvas canvas) {
    final painter = TextPainter(
      text: TextSpan(
        text: '${data.name} ${data.state.label}',
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 100);
    final x = (size.x - painter.width) / 2;
    painter.paint(canvas, Offset(x, size.y + 2));
  }
}
