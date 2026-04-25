import 'dart:convert';

import 'package:flame/components.dart';
import 'package:flutter/services.dart';

import 'seat_data.dart';

class AreaBounds {
  const AreaBounds({
    required this.id,
    required this.position,
    required this.size,
  });

  final String id;
  final Vector2 position;
  final Vector2 size;

  factory AreaBounds.fromJson(String id, Map<String, dynamic> json) {
    return AreaBounds(
      id: id,
      position: Vector2(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
      ),
      size: Vector2(
        (json['width'] as num).toDouble(),
        (json['height'] as num).toDouble(),
      ),
    );
  }
}

class OfficeLayout {
  const OfficeLayout({
    required this.sceneSize,
    required this.backgroundPath,
    required this.furnitureBackPath,
    required this.furnitureFrontPath,
    required this.areaBounds,
    required this.seats,
  });

  final Vector2 sceneSize;
  final String backgroundPath;
  final String furnitureBackPath;
  final String furnitureFrontPath;
  final List<AreaBounds> areaBounds;
  final List<SeatData> seats;

  static const assetPath = 'assets/data/office_layout.json';

  static Future<OfficeLayout> load() async {
    final content = await rootBundle.loadString(assetPath);
    final json = jsonDecode(content) as Map<String, dynamic>;
    final scene = json['scene'] as Map<String, dynamic>;
    final bounds = json['triggerBounds'] as Map<String, dynamic>;
    final seats = json['seats'] as List<dynamic>;

    return OfficeLayout(
      sceneSize: Vector2(
        (scene['width'] as num).toDouble(),
        (scene['height'] as num).toDouble(),
      ),
      backgroundPath: scene['background'] as String,
      furnitureBackPath: scene['furnitureBack'] as String,
      furnitureFrontPath: scene['furnitureFront'] as String,
      areaBounds:
          bounds.entries
              .map(
                (entry) => AreaBounds.fromJson(
                  entry.key,
                  entry.value as Map<String, dynamic>,
                ),
              )
              .toList(),
      seats:
          seats
              .map((seat) => SeatData.fromJson(seat as Map<String, dynamic>))
              .toList(),
    );
  }
}
