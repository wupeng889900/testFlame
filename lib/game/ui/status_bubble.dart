import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../entity/character.dart';
import '../core/enums.dart';

class StatusBubble extends PositionComponent {
  final Character character;

  StatusBubble(this.character)
    : super(
        size: Vector2(148, 100),
        anchor: Anchor.bottomCenter,
        position: character.overheadUiAnchor,
      );

  @override
  void update(double dt) {
    super.update(dt);
    position.setFrom(character.overheadUiAnchor);
  }

  @override
  void render(Canvas canvas) {
    final state = character.current;
    final showBubble =
        state != CharacterState.walk && state != CharacterState.idle;
    if (showBubble) {
      _drawBubble(canvas);
    }
    _drawEnergyBar(canvas, showBubble: showBubble);
    _drawNameChip(canvas);
  }

  void _drawNameChip(Canvas canvas) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: character.name,
        style: const TextStyle(
          color: Color(0xFF21324A),
          fontSize: 10,
          fontWeight: FontWeight.bold,
          fontFamily: 'LocalChinese',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: 120);

    final padding = const Offset(8, 4);
    final chipTop = size.y - textPainter.height - padding.dy * 2 - 6;
    final chipRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.x / 2 - textPainter.width / 2 - padding.dx,
        chipTop,
        textPainter.width + padding.dx * 2,
        textPainter.height + padding.dy * 2,
      ),
      const Radius.circular(10),
    );

    canvas.drawRRect(
      chipRect,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawRRect(
      chipRect,
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
    canvas.drawRRect(
      chipRect,
      Paint()
        ..color = _stateColor().withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    textPainter.paint(
      canvas,
      Offset(size.x / 2 - textPainter.width / 2, chipTop + padding.dy),
    );
  }

  void _drawBubble(Canvas canvas) {
    final bubbleRect = Rect.fromCenter(
      center: Offset(size.x / 2, 24),
      width: 96,
      height: 36,
    );
    final bubbleRRect = RRect.fromRectAndRadius(
      bubbleRect,
      const Radius.circular(16),
    );
    final shadowRect = bubbleRect.shift(const Offset(0, 4));

    canvas.drawRRect(
      RRect.fromRectAndRadius(shadowRect, const Radius.circular(16)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.24)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    canvas.drawRRect(
      bubbleRRect,
      Paint()..color = Colors.white.withValues(alpha: 0.96),
    );
    canvas.drawRRect(
      bubbleRRect,
      Paint()
        ..color = _stateColor().withValues(alpha: 0.70)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          bubbleRect.left + 6,
          bubbleRect.top + 4,
          bubbleRect.width - 12,
          10,
        ),
        const Radius.circular(10),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.08),
    );

    final tailPath =
        Path()
          ..moveTo(size.x / 2 - 7, bubbleRect.bottom - 1)
          ..lineTo(size.x / 2 + 7, bubbleRect.bottom - 1)
          ..lineTo(size.x / 2, bubbleRect.bottom + 10)
          ..close();
    canvas.drawPath(
      tailPath.shift(const Offset(0, 3)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawPath(
      tailPath,
      Paint()..color = Colors.white.withValues(alpha: 0.96),
    );

    _drawBubbleContent(canvas);
  }

  void _drawBubbleContent(Canvas canvas) {
    final stateText = character.stateLabel;
    if (stateText == '空闲中' || stateText == '移动中') return;

    final iconPainter = TextPainter(
      text: TextSpan(text: _stateIcon(), style: const TextStyle(fontSize: 14)),
      textDirection: TextDirection.ltr,
    );
    final textPainter = TextPainter(
      text: TextSpan(
        text: stateText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          fontFamily: 'LocalChinese',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    iconPainter.layout();
    textPainter.layout(maxWidth: 56);

    final totalWidth = iconPainter.width + 6 + textPainter.width;
    final startX = size.x / 2 - totalWidth / 2;
    final baselineY = 17.5;

    iconPainter.paint(
      canvas,
      Offset(startX, baselineY - iconPainter.height / 2),
    );
    final textBg = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        startX + iconPainter.width + 2,
        baselineY - textPainter.height / 2 - 2,
        textPainter.width + 8,
        textPainter.height + 4,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(textBg, Paint()..color = _stateColor());
    textPainter.paint(
      canvas,
      Offset(
        startX + iconPainter.width + 6,
        baselineY - textPainter.height / 2,
      ),
    );
  }

  Color _stateColor() {
    switch (character.current) {
      case CharacterState.work:
        return const Color(0xFF2E74D8);
      case CharacterState.rest:
        return const Color(0xFFF08422);
      case CharacterState.meeting:
        return const Color(0xFF55A844);
      default:
        return const Color(0xFF6A7C8F);
    }
  }

  void _drawEnergyBar(Canvas canvas, {required bool showBubble}) {
    final barWidth = 72.0;
    final barHeight = 5.0;
    final barTop = showBubble ? 58.0 : 50.0;
    final barRect = Rect.fromLTWH(
      size.x / 2 - barWidth / 2,
      barTop,
      barWidth,
      barHeight,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(barRect, const Radius.circular(3)),
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );

    final progressWidth = (character.energy / 100.0) * barWidth;
    final progressColor =
        character.energy > 50
            ? Colors.green
            : (character.energy > 20 ? Colors.orange : Colors.red);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barRect.left, barRect.top, progressWidth, barHeight),
        const Radius.circular(3),
      ),
      Paint()..color = progressColor,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barRect.left, barRect.top, progressWidth, barHeight / 2),
        const Radius.circular(3),
      ),
      Paint()..color = Colors.white.withValues(alpha: 0.18),
    );
  }

  String _stateIcon() {
    switch (character.current) {
      case CharacterState.work:
        return '💻';
      case CharacterState.rest:
        return '☕';
      case CharacterState.meeting:
        return '🤝';
      default:
        return '';
    }
  }
}
