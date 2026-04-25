import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../core/enums.dart';
import '../world/office_game.dart';

class OfficeHUD extends PositionComponent with HasGameReference<OfficeGame> {
  OfficeHUD() : super(position: Vector2(18, 18), size: Vector2(330, 190));

  @override
  void render(Canvas canvas) {
    final shadowPaint =
        Paint()
          ..color = Colors.black.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        size.toRect().shift(const Offset(3, 4)),
        const Radius.circular(10),
      ),
      shadowPaint,
    );

    final panelRect = RRect.fromRectAndRadius(
      size.toRect(),
      const Radius.circular(14),
    );
    canvas.drawRRect(panelRect, Paint()..color = const Color(0xF8FFFFFF));
    canvas.drawRRect(
      panelRect,
      Paint()
        ..color = const Color(0xFF2865A8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(0, 0, size.x, 42),
        topLeft: const Radius.circular(14),
        topRight: const Radius.circular(14),
      ),
      Paint()..color = const Color(0xFFE9F4FF),
    );

    final hours = (game.gameTime / 60).floor() % 24;
    final minutes = (game.gameTime % 60).floor();
    final seconds = ((game.gameTime % 1) * 60).floor();
    final timeStr =
        '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

    int working = 0;
    int resting = 0;
    int discussing = 0;
    for (final c in game.characters) {
      if (c.current == CharacterState.work) working++;
      if (c.current == CharacterState.rest) resting++;
      if (c.current == CharacterState.meeting) discussing++;
    }

    _drawText(
      canvas,
      '状态切换看板',
      const Offset(18, 12),
      isBold: true,
      color: const Color(0xFF123A72),
      fontSize: 18,
    );
    _drawText(
      canvas,
      '时间 $timeStr',
      const Offset(204, 16),
      color: const Color(0xFF4B6178),
      fontSize: 12,
    );

    _drawMetric(canvas, '工作中', working, const Color(0xFF2E74D8), 16, 56);
    _drawMetric(canvas, '讨论中', discussing, const Color(0xFF55A844), 118, 56);
    _drawMetric(canvas, '休息中', resting, const Color(0xFFF08422), 220, 56);

    _drawText(
      canvas,
      '资产 \$${game.balance.toStringAsFixed(0)}',
      const Offset(18, 116),
      color: const Color(0xFF21324A),
      fontSize: 14,
      isBold: true,
    );
    _drawText(
      canvas,
      '产出 ${game.totalProductivity.toStringAsFixed(1)}',
      const Offset(150, 116),
      color: const Color(0xFF21324A),
      fontSize: 14,
      isBold: true,
    );
    _drawText(
      canvas,
      game.lastCommandText,
      const Offset(18, 158),
      fontSize: 11,
      color: const Color(0xFF53677D),
    );

    final barRect = Rect.fromLTWH(18, 140, size.x - 36, 10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(barRect, const Radius.circular(4)),
      Paint()..color = const Color(0xFFE1E8F2),
    );
    final progressWidth =
        ((game.totalProductivity % 100) / 100) * barRect.width;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barRect.left, barRect.top, progressWidth, barRect.height),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF55A844),
    );
  }

  void _drawMetric(
    Canvas canvas,
    String label,
    int value,
    Color color,
    double x,
    double y,
  ) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, 88, 42),
      const Radius.circular(10),
    );
    canvas.drawRRect(rect, Paint()..color = color.withValues(alpha: 0.12));
    canvas.drawRRect(
      rect,
      Paint()
        ..color = color.withValues(alpha: 0.70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    _drawText(
      canvas,
      label,
      Offset(x + 10, y + 7),
      color: color,
      fontSize: 12,
      isBold: true,
    );
    _drawText(
      canvas,
      value.toString(),
      Offset(x + 58, y + 5),
      color: color,
      fontSize: 22,
      isBold: true,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    double fontSize = 14,
    Color color = const Color(0xFF21324A),
    bool isBold = false,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          fontFamily: 'LocalChinese',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, offset);
  }
}
