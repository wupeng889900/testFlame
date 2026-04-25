import 'package:flame/components.dart';

class GameConstants {
  static const double spriteSize = 96.0;
  static final Vector2 characterSize = Vector2(spriteSize, spriteSize);
  static const double animationStepTime = 0.15;
  
  // Animation Rows
  static const int rowWalkDown = 0;
  static const int rowWalkUp = 1;
  static const int rowWalkLeft = 2;
  static const int rowWalkRight = 3;
  static const int rowIdle = 4;
  static const int rowTyping = 5;
  static const int rowSit = 6;
  static const int rowTalk = 7;
  static const int rowSleep = 8;
  
  // Character Speed
  static const double walkSpeed = 100.0;
}
