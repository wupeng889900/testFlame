import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/asset_catalog.dart';
import '../core/enums.dart';
import '../core/seat.dart';
import '../core/style_guide.dart';

enum FurnitureDepthMode { behindCharacters, inFrontOfCharacters }

class Furniture extends PositionComponent with HasGameReference<FlameGame> {
  final String spritePath;
  final List<Seat> seats;
  final String obstacleId;
  final FurnitureDepthMode depthMode;
  final int priorityOffset;
  final double angleDegrees;
  Sprite? sprite;

  Furniture({
    required this.spritePath,
    required Vector2 position,
    required Vector2 size,
    required this.seats,
    required this.obstacleId,
    this.depthMode = FurnitureDepthMode.inFrontOfCharacters,
    this.priorityOffset = 0,
    this.angleDegrees = 0,
  }) : super(
         position: position,
         size: size,
         anchor: Anchor.center,
         angle: angleDegrees * math.pi / 180,
       );

  @override
  Future<void> onLoad() async {
    try {
      for (final candidatePath in GameAssetCatalog.instance.propCandidates(
        spritePath,
      )) {
        try {
          sprite = await game.loadSprite(candidatePath);
          break;
        } catch (_) {
          continue;
        }
      }
      if (sprite == null) {
        throw StateError('Unable to load furniture sprite.');
      }
      sprite!.paint =
          Paint()
            ..colorFilter = ColorFilter.mode(
              SceneStyleGuide.tintColor.withValues(alpha: 0.10),
              BlendMode.srcATop,
            )
            ..filterQuality = FilterQuality.none;
    } catch (_) {
      // Placeholder for furniture
    }
  }

  @override
  void render(Canvas canvas) {
    if (_isOccupiedMeetingSeat) {
      return;
    }

    // Draw shadow
    _drawShadow(canvas);

    if (sprite == null) {
      final isDesk = spritePath.contains('desk');
      final isSofa = spritePath.contains('sofa');
      final isTable = spritePath.contains('table');
      final isChair = spritePath.contains('chair');

      final basePaint = Paint()..color = const Color(0xFF8B4513); // SaddleBrown
      final detailPaint = Paint()..color = const Color(0xFFA0522D); // Sienna

      if (isChair) {
        final seatRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.x * 0.18,
            size.y * 0.38,
            size.x * 0.64,
            size.y * 0.24,
          ),
          const Radius.circular(5),
        );
        final backRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            size.x * 0.22,
            size.y * 0.1,
            size.x * 0.56,
            size.y * 0.34,
          ),
          const Radius.circular(5),
        );
        canvas.drawRRect(backRect, detailPaint);
        canvas.drawRRect(seatRect, basePaint);
        canvas.drawLine(
          Offset(size.x * 0.28, size.y * 0.58),
          Offset(size.x * 0.18, size.y * 0.92),
          Paint()
            ..color = const Color(0xFF5B3A22)
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawLine(
          Offset(size.x * 0.72, size.y * 0.58),
          Offset(size.x * 0.82, size.y * 0.92),
          Paint()
            ..color = const Color(0xFF5B3A22)
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round,
        );
      } else if (isDesk) {
        // Draw wooden desk
        canvas.drawRect(size.toRect(), basePaint);
        // Draw monitor
        final monitorRect = Rect.fromLTWH(
          size.x * 0.2,
          size.y * 0.1,
          size.x * 0.6,
          size.y * 0.5,
        );
        canvas.drawRect(monitorRect, Paint()..color = Colors.black87);
        // Blue screen
        canvas.drawRect(
          monitorRect.deflate(2),
          Paint()..color = Colors.blue.withValues(alpha: 0.8),
        );
        // Keyboard area
        canvas.drawRect(
          Rect.fromLTWH(
            size.x * 0.25,
            size.y * 0.7,
            size.x * 0.5,
            size.y * 0.1,
          ),
          Paint()..color = Colors.grey,
        );
      } else if (isSofa) {
        // Draw brown sofa
        canvas.drawRRect(
          RRect.fromRectAndRadius(size.toRect(), const Radius.circular(8)),
          basePaint,
        );
        // Cushions
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(5, 5, size.x - 10, size.y * 0.6),
            const Radius.circular(4),
          ),
          detailPaint,
        );
      } else if (isTable) {
        // Large meeting table
        canvas.drawRRect(
          RRect.fromRectAndRadius(size.toRect(), const Radius.circular(10)),
          basePaint,
        );
        // Table top detail
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            size.toRect().deflate(10),
            const Radius.circular(5),
          ),
          detailPaint,
        );
      } else {
        canvas.drawRect(size.toRect(), basePaint);
      }
    } else {
      sprite!.renderRect(canvas, size.toRect());
    }
  }

  void _drawShadow(Canvas canvas) {
    final shadowPaint =
        Paint()
          ..color = Colors.black.withValues(alpha: 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    // Furniture shadow at the base
    // anchor is center, so 0,0 is center
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, size.y / 2 - 5),
        width: size.x * 0.9,
        height: 15,
      ),
      shadowPaint,
    );
  }

  Rect collisionWorldRect() {
    final rect = _collisionRectLocal();
    final topLeft = Offset(
      x - size.x / 2 + rect.left,
      y - size.y / 2 + rect.top,
    );
    return Rect.fromLTWH(topLeft.dx, topLeft.dy, rect.width, rect.height);
  }

  Rect navigationWorldRect() {
    final visualRect = Rect.fromCenter(
      center: Offset(x, y),
      width: size.x,
      height: size.y,
    );

    if (_isDeskChair) {
      return _deskChairNavigationWorldRect(visualRect);
    }
    if (spritePath.contains('meeting_table')) {
      return visualRect.deflate(8);
    }
    if (spritePath.contains('sofa') || spritePath.contains('coffee_table')) {
      return visualRect.deflate(4);
    }
    if (spritePath.contains('chair')) {
      return visualRect.deflate(8);
    }
    return collisionWorldRect();
  }

  bool get allowsAssignedSeatPassThrough =>
      _isStandaloneChair && !spritePath.contains('sofa');

  bool get shouldOccludeSeatedCharacters =>
      _isStandaloneChair && !spritePath.contains('sofa');

  bool get _isOccupiedMeetingSeat => seats.any((seat) {
    final user = seat.user;
    return seat.type == SeatType.meeting &&
        user != null &&
        !user.isMoving &&
        user.current == CharacterState.meeting;
  });

  Vector2 approachPointForSeat(Seat seat) {
    if (seat.type == SeatType.sofa) {
      return seat.position.clone();
    }

    final rect = navigationWorldRect();
    const double gap = 44.0;

    switch (seat.direction) {
      case 'up':
        return Vector2(seat.position.x, rect.bottom + gap);
      case 'down':
        return Vector2(seat.position.x, rect.top - gap);
      case 'left':
        return Vector2(rect.right + gap, seat.position.y);
      case 'right':
        return Vector2(rect.left - gap, seat.position.y);
      case null:
        return seat.position.clone();
    }

    return seat.position.clone();
  }

  Rect _collisionRectLocal() {
    if (_isDeskChair) {
      final seatBottom = _lowestSeatLocalY + _deskChairSeatForwardDepth;
      final bottom = math.max(size.y, seatBottom);
      return Rect.fromLTRB(size.x * 0.12, size.y * 0.42, size.x * 0.88, bottom);
    }
    if (_isStandaloneChair) {
      return Rect.fromLTWH(
        size.x * 0.14,
        size.y * 0.18,
        size.x * 0.72,
        size.y * 0.74,
      );
    }
    if (spritePath.contains('desk')) {
      return Rect.fromLTWH(
        size.x * 0.09,
        size.y * 0.76,
        size.x * 0.82,
        size.y * 0.24,
      );
    }
    if (spritePath.contains('sofa')) {
      return Rect.fromLTWH(
        size.x * 0.06,
        size.y * 0.66,
        size.x * 0.88,
        size.y * 0.34,
      );
    }
    if (spritePath.contains('table')) {
      return Rect.fromLTWH(
        size.x * 0.07,
        size.y * 0.58,
        size.x * 0.86,
        size.y * 0.42,
      );
    }
    return Rect.fromLTWH(
      size.x * 0.1,
      size.y * 0.7,
      size.x * 0.8,
      size.y * 0.3,
    );
  }

  Rect _deskChairNavigationWorldRect(Rect visualRect) {
    if (seats.isEmpty) {
      return visualRect.deflate(4);
    }

    final seatLeft = seats.map((seat) => seat.position.x).reduce(math.min);
    final seatRight = seats.map((seat) => seat.position.x).reduce(math.max);
    final seatBottom =
        seats.map((seat) => seat.position.y).reduce(math.max) +
        _deskChairSeatForwardDepth;

    return Rect.fromLTRB(
      math.min(visualRect.left + 4, seatLeft - _deskChairSeatHalfWidth),
      visualRect.top + 4,
      math.max(visualRect.right - 4, seatRight + _deskChairSeatHalfWidth),
      math.max(visualRect.bottom - 4, seatBottom),
    );
  }

  double get _lowestSeatLocalY {
    if (seats.isEmpty) {
      return size.y;
    }

    final localTop = y - size.y / 2;
    return seats.map((seat) => seat.position.y - localTop).reduce(math.max);
  }

  bool get _isDeskChair => spritePath.contains('desk_chair');
  bool get _isStandaloneChair =>
      spritePath.contains('chair') && !spritePath.contains('desk_chair');

  static const double _deskChairSeatHalfWidth = 52.0;
  static const double _deskChairSeatForwardDepth = 112.0;
}
