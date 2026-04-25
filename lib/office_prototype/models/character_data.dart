import 'package:flame/components.dart';
import 'package:flutter/material.dart';

import 'character_state.dart';

class CharacterData {
  CharacterData({
    required this.id,
    required this.name,
    required this.role,
    required this.position,
    required this.color,
    this.state = CharacterState.idle,
  });

  final String id;
  final String name;
  final String role;
  final Color color;
  final Vector2 position;
  CharacterState state;

  String get assetBasePath => 'assets/images/characters/$id';

  static List<CharacterData> defaults() {
    return [
      CharacterData(
        id: 'programmer',
        name: '程序员',
        role: 'programmer',
        position: Vector2(90, 680),
        color: const Color(0xFF4C7FD9),
      ),
      CharacterData(
        id: 'designer',
        name: '设计师',
        role: 'designer',
        position: Vector2(150, 680),
        color: const Color(0xFFD875A6),
      ),
      CharacterData(
        id: 'project_manager',
        name: '项目经理',
        role: 'project_manager',
        position: Vector2(210, 680),
        color: const Color(0xFFD69B42),
      ),
      CharacterData(
        id: 'tester',
        name: '测试',
        role: 'tester',
        position: Vector2(270, 680),
        color: const Color(0xFF5AA469),
      ),
      CharacterData(
        id: 'operator',
        name: '运营',
        role: 'operator',
        position: Vector2(330, 680),
        color: const Color(0xFF8D74C8),
      ),
    ];
  }
}
