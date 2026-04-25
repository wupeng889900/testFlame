import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../components/area_bounds_component.dart';
import '../components/layer_image_component.dart';
import '../components/office_character_component.dart';
import '../components/seat_component.dart';
import '../models/character_data.dart';
import '../models/character_state.dart';
import '../models/office_layout.dart';
import '../models/seat_data.dart';

class OfficeSimulationGame extends FlameGame
    with TapDetector, PanDetector, ScrollDetector {
  static const int backgroundLayer = 0;
  static const int furnitureBackLayer = 100;
  static const int characterLayer = 500;
  static const int furnitureFrontLayer = 1000;
  static const int uiBubbleLayer = 1500;

  final List<OfficeCharacterComponent> characters = [];
  final List<SeatComponent> seatComponents = [];

  late OfficeLayout layout;
  int selectedCharacterIndex = 0;
  String lastMessage = '点击座位派发角色';

  OfficeCharacterComponent get selectedCharacter =>
      characters[selectedCharacterIndex.clamp(0, characters.length - 1)];

  @override
  Color backgroundColor() => const Color(0xFFE8EEF5);

  @override
  Future<void> onLoad() async {
    images.prefix = '';
    layout = await OfficeLayout.load();

    camera.viewfinder.anchor = Anchor.topLeft;
    camera.viewfinder.position = Vector2.zero();
    camera.viewfinder.zoom = 0.92;

    await _buildScene();
  }

  Future<void> _buildScene() async {
    world.add(
      LayerImageComponent(
        assetPath: layout.backgroundPath,
        position: Vector2.zero(),
        size: layout.sceneSize,
        placeholderColor: const Color(0xFFE9F0F7),
        label: 'Office Prototype Background',
        priority: backgroundLayer,
      ),
    );

    _addAreaBounds();
    _addFurnitureBack();
    _addSeats();
    _addCharacters();
    _addFurnitureFront();
    _addHud();
  }

  void _addAreaBounds() {
    for (final bounds in layout.areaBounds) {
      final config = _areaVisual(bounds.id);
      world.add(
        AreaBoundsComponent(
          bounds: bounds,
          label: config.label,
          color: config.color,
          priority: backgroundLayer + 5,
        ),
      );
    }
  }

  void _addFurnitureBack() {
    world.add(
      LayerImageComponent(
        assetPath: layout.furnitureBackPath,
        position: Vector2.zero(),
        size: layout.sceneSize,
        placeholderColor: Colors.transparent,
        label: 'furniture_back',
        priority: furnitureBackLayer,
      ),
    );

    world.addAll([
      _FurniturePlaceholder(
        position: Vector2(132, 98),
        size: Vector2(250, 90),
        color: const Color(0xFF7EA4BF),
        label: '5 desks',
        priority: furnitureBackLayer + 1,
      ),
      _FurniturePlaceholder(
        position: Vector2(650, 190),
        size: Vector2(180, 100),
        color: const Color(0xFFB7864A),
        label: 'meeting table',
        priority: furnitureBackLayer + 1,
      ),
      _FurniturePlaceholder(
        position: Vector2(700, 506),
        size: Vector2(300, 76),
        color: const Color(0xFF6EA67A),
        label: 'sofa',
        priority: furnitureBackLayer + 1,
      ),
    ]);
  }

  void _addSeats() {
    for (final seat in layout.seats) {
      final component = SeatComponent(
        data: seat,
        priority: furnitureBackLayer + 20,
      );
      seatComponents.add(component);
      world.add(component);
    }
  }

  void _addCharacters() {
    for (final data in CharacterData.defaults()) {
      final component = OfficeCharacterComponent(
        data: data,
        priority: characterLayer + data.position.y.toInt(),
      );
      characters.add(component);
      world.add(component);
    }
    characters.first.selected = true;
  }

  void _addFurnitureFront() {
    world.add(
      LayerImageComponent(
        assetPath: layout.furnitureFrontPath,
        position: Vector2.zero(),
        size: layout.sceneSize,
        placeholderColor: Colors.transparent,
        label: 'furniture_front',
        priority: furnitureFrontLayer,
      ),
    );
  }

  void _addHud() {
    camera.viewport.add(
      _OfficePrototypeHud(
        gameRef: this,
        position: Vector2(16, 16),
        priority: uiBubbleLayer,
      ),
    );
  }

  @override
  void onTapDown(TapDownInfo info) {
    final point = camera.globalToLocal(info.eventPosition.global);
    if (_selectCharacterAt(point)) {
      return;
    }

    for (final seat in seatComponents.reversed) {
      if (seat.containsWorldPoint(point)) {
        _assignSelectedCharacter(seat.data);
        return;
      }
    }
  }

  bool _selectCharacterAt(Vector2 point) {
    for (var i = characters.length - 1; i >= 0; i--) {
      final character = characters[i];
      if (character.containsWorldPoint(point)) {
        _setSelectedCharacter(i);
        lastMessage = '已选择 ${character.data.name}';
        return true;
      }
    }
    return false;
  }

  void _assignSelectedCharacter(SeatData seat) {
    if (seat.isOccupied && seat.occupiedBy != selectedCharacter.data.id) {
      lastMessage = '${seat.id} 已被占用';
      return;
    }

    selectedCharacter.assignToSeat(seat);
    lastMessage =
        '${selectedCharacter.data.name} -> ${seat.area.label}座位 ${seat.id}';
    _selectNextCharacter();
  }

  void _selectNextCharacter() {
    if (characters.isEmpty) {
      return;
    }
    final next = (selectedCharacterIndex + 1) % characters.length;
    _setSelectedCharacter(next);
  }

  void _setSelectedCharacter(int index) {
    selectedCharacterIndex = index;
    for (var i = 0; i < characters.length; i++) {
      characters[i].selected = i == selectedCharacterIndex;
    }
  }

  @override
  void onPanUpdate(DragUpdateInfo info) {
    camera.viewfinder.position -= info.delta.global / camera.viewfinder.zoom;
  }

  @override
  void onScroll(PointerScrollInfo info) {
    final delta = info.scrollDelta.global.y > 0 ? -0.08 : 0.08;
    camera.viewfinder.zoom = (camera.viewfinder.zoom + delta).clamp(0.55, 1.6);
  }

  @override
  void update(double dt) {
    super.update(dt);
    for (final character in characters) {
      character.priority = characterLayer + character.position.y.toInt();
    }
    for (final seat in seatComponents) {
      seat.highlighted =
          seat.data.occupiedBy == selectedCharacter.data.id ||
          !seat.data.isOccupied;
    }
  }

  _AreaVisual _areaVisual(String id) {
    switch (id) {
      case 'meeting_area':
        return const _AreaVisual('会议区', Color(0xFFB98234));
      case 'rest_area':
        return const _AreaVisual('休息区', Color(0xFF43865C));
      case 'work_area':
      default:
        return const _AreaVisual('办公区', Color(0xFF3779A8));
    }
  }
}

class _AreaVisual {
  const _AreaVisual(this.label, this.color);

  final String label;
  final Color color;
}

class _FurniturePlaceholder extends PositionComponent {
  _FurniturePlaceholder({
    required super.position,
    required super.size,
    required this.color,
    required this.label,
    required super.priority,
  });

  final Color color;
  final String label;

  @override
  void render(Canvas canvas) {
    final rect = RRect.fromRectAndRadius(
      size.toRect(),
      const Radius.circular(10),
    );
    canvas.drawRRect(rect, Paint()..color = color.withValues(alpha: 0.42));
    canvas.drawRRect(
      rect,
      Paint()
        ..color = color.withValues(alpha: 0.78)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xFF1F2937),
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.x);
    painter.paint(
      canvas,
      Offset((size.x - painter.width) / 2, (size.y - painter.height) / 2),
    );
  }
}

class _OfficePrototypeHud extends PositionComponent {
  _OfficePrototypeHud({
    required this.gameRef,
    required super.position,
    required super.priority,
  }) : super(size: Vector2(330, 104));

  final OfficeSimulationGame gameRef;

  @override
  void render(Canvas canvas) {
    final rect = RRect.fromRectAndRadius(
      size.toRect(),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = Colors.white.withValues(alpha: 0.92),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = const Color(0xFFCBD5E1)
        ..style = PaintingStyle.stroke,
    );

    final selected = gameRef.selectedCharacter.data;
    final lines = [
      '办公室模拟原型',
      '当前角色: ${selected.name} (${selected.role})',
      '状态: ${selected.state.label}',
      gameRef.lastMessage,
    ];
    var y = 10.0;
    for (final line in lines) {
      final painter = TextPainter(
        text: TextSpan(
          text: line,
          style: TextStyle(
            color: y == 10 ? const Color(0xFF0F172A) : const Color(0xFF334155),
            fontSize: y == 10 ? 15 : 12,
            fontWeight: y == 10 ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.x - 20);
      painter.paint(canvas, Offset(12, y));
      y += y == 10 ? 24 : 19;
    }
  }
}
