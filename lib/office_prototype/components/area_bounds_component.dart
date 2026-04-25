import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import '../models/office_layout.dart';

class AreaBoundsComponent extends PositionComponent {
  AreaBoundsComponent({
    required this.bounds,
    required this.label,
    required this.color,
    required super.priority,
  }) : super(position: bounds.position, size: bounds.size);

  final AreaBounds bounds;
  final String label;
  final Color color;

  @override
  void render(Canvas canvas) {
    final rect = size.toRect();
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      Paint()..color = color.withValues(alpha: 0.10),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      Paint()
        ..color = color.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: 16,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.x);
    painter.paint(canvas, const Offset(14, 10));
  }
}
