import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../models/seat_data.dart';

class SeatComponent extends PositionComponent {
  SeatComponent({required this.data, required super.priority})
    : super(
        position: data.position,
        size: Vector2(54, 42),
        anchor: Anchor.center,
      );

  final SeatData data;
  bool highlighted = false;

  bool containsWorldPoint(Vector2 point) {
    final half = size / 2;
    return point.x >= position.x - half.x &&
        point.x <= position.x + half.x &&
        point.y >= position.y - half.y &&
        point.y <= position.y + half.y;
  }

  @override
  void render(Canvas canvas) {
    final baseColor = switch (data.area) {
      SeatArea.work => const Color(0xFF5BA6D6),
      SeatArea.meeting => const Color(0xFFD8A756),
      SeatArea.rest => const Color(0xFF6DB884),
    };
    final fill =
        data.isOccupied
            ? baseColor.withValues(alpha: 0.95)
            : baseColor.withValues(alpha: 0.42);
    final rect = Rect.fromCenter(
      center: Offset(size.x / 2, size.y / 2),
      width: size.x,
      height: size.y,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));
    canvas.drawRRect(rrect, Paint()..color = fill);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color =
            highlighted
                ? const Color(0xFFFFF2A8)
                : const Color(0xFF263241).withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = highlighted ? 3 : 1.5,
    );

    final directionMark = _directionOffset(data.direction);
    canvas.drawCircle(
      Offset(size.x / 2 + directionMark.x, size.y / 2 + directionMark.y),
      4,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );

    final painter = TextPainter(
      text: TextSpan(
        text: data.area.label,
        style: const TextStyle(
          color: Color(0xFF172033),
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.x);
    painter.paint(
      canvas,
      Offset((size.x - painter.width) / 2, (size.y - painter.height) / 2),
    );
  }

  Vector2 _directionOffset(SeatDirection direction) {
    switch (direction) {
      case SeatDirection.up:
        return Vector2(0, -15);
      case SeatDirection.down:
        return Vector2(0, 15);
      case SeatDirection.left:
        return Vector2(-20, 0);
      case SeatDirection.right:
        return Vector2(20, 0);
    }
  }
}
