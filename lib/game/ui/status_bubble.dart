import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../entity/character.dart';
import '../core/enums.dart';

class StatusBubble extends PositionComponent with HasGameReference<FlameGame> {
  final Character character;
  final Map<CharacterState, Sprite> _stateSprites = {};
  Sprite? _ringSprite;
  double _visualTime = 0;

  StatusBubble(this.character)
    : super(
        size: Vector2(156, 124),
        anchor: Anchor.bottomCenter,
        position: character.overheadUiAnchor,
      );

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _ringSprite = await _tryLoadSprite(
      'assets/office_game/ui/selected_ring.png',
    );
    await _loadStateSprite(
      CharacterState.work,
      'assets/office_game/ui/bubble_active.png',
    );
    await _loadStateSprite(
      CharacterState.meeting,
      'assets/office_game/ui/bubble_chat.png',
    );
    await _loadStateSprite(
      CharacterState.rest,
      'assets/office_game/ui/bubble_sleep.png',
    );
  }

  @override
  void update(double dt) {
    super.update(dt);
    _visualTime += dt;
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
    final state = character.current;
    if (state == null) {
      return;
    }

    final bubbleSprite = _stateSprites[state];
    if (bubbleSprite == null) {
      _drawFallbackBubble(canvas);
      return;
    }

    final bob = math.sin(_visualTime * 2.6) * 2.4;
    final center = Offset(size.x / 2, 35 + bob);
    final ringRect = Rect.fromCenter(center: center, width: 76, height: 76);
    final bubbleRect = Rect.fromCenter(center: center, width: 84, height: 98);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + 24),
        width: 52,
        height: 14,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    if (_ringSprite != null) {
      _ringSprite!.renderRect(
        canvas,
        ringRect,
        overridePaint: Paint()..color = Colors.white.withValues(alpha: 0.78),
      );
    }

    canvas.drawCircle(
      Offset(center.dx - 30, center.dy - 22),
      4,
      Paint()..color = _stateColor().withValues(alpha: 0.22),
    );
    canvas.drawCircle(
      Offset(center.dx + 28, center.dy - 10),
      3,
      Paint()..color = Colors.white.withValues(alpha: 0.58),
    );
    canvas.drawCircle(
      Offset(center.dx + 24, center.dy + 24),
      2.5,
      Paint()..color = _stateColor().withValues(alpha: 0.32),
    );

    bubbleSprite.renderRect(canvas, bubbleRect);
    _drawBubbleLabel(canvas, center.dy + 40);
  }

  void _drawFallbackBubble(Canvas canvas) {
    final bubbleRect = Rect.fromCenter(
      center: Offset(size.x / 2, 28),
      width: 96,
      height: 36,
    );
    final bubbleRRect = RRect.fromRectAndRadius(
      bubbleRect,
      const Radius.circular(16),
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
    _drawBubbleLabel(canvas, bubbleRect.center.dy);
  }

  void _drawBubbleLabel(Canvas canvas, double centerY) {
    final stateText = character.stateLabel;
    if (stateText == '空闲中' || stateText == '移动中') return;

    final textPainter = TextPainter(
      text: TextSpan(
        text: stateText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          fontFamily: 'LocalChinese',
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout(maxWidth: 66);

    final textBg = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.x / 2 - textPainter.width / 2 - 10,
        centerY - textPainter.height / 2 - 4,
        textPainter.width + 20,
        textPainter.height + 8,
      ),
      const Radius.circular(12),
    );
    canvas.drawRRect(
      textBg,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.16)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawRRect(textBg, Paint()..color = _stateColor());
    canvas.drawRRect(
      textBg,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    textPainter.paint(
      canvas,
      Offset(
        size.x / 2 - textPainter.width / 2,
        centerY - textPainter.height / 2,
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
    final barTop = showBubble ? 82.0 : 54.0;
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

  Future<void> _loadStateSprite(CharacterState state, String path) async {
    final sprite = await _tryLoadSprite(path);
    if (sprite != null) {
      _stateSprites[state] = sprite;
    }
  }

  Future<Sprite?> _tryLoadSprite(String path) async {
    try {
      return await game.loadSprite(path);
    } catch (_) {
      return null;
    }
  }
}
