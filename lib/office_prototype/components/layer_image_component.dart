import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class LayerImageComponent extends PositionComponent
    with HasGameReference<FlameGame> {
  LayerImageComponent({
    required this.assetPath,
    required super.position,
    required super.size,
    required this.placeholderColor,
    required this.label,
    required super.priority,
  });

  final String assetPath;
  final Color placeholderColor;
  final String label;
  Sprite? _sprite;

  @override
  Future<void> onLoad() async {
    try {
      _sprite = await game.loadSprite(assetPath);
    } catch (_) {
      _sprite = null;
    }
  }

  @override
  void render(Canvas canvas) {
    if (_sprite != null) {
      _sprite!.renderRect(canvas, size.toRect());
      return;
    }

    if (placeholderColor == Colors.transparent) {
      return;
    }

    final rect = size.toRect();
    canvas.drawRect(rect, Paint()..color = placeholderColor);
    canvas.drawRect(
      rect,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xFF334155),
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.x);
    painter.paint(canvas, Offset(16, 16));
  }
}
