import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/world/office_game.dart';

void main() {
  runApp(const OfficeGameApp());
}

class OfficeGameApp extends StatelessWidget {
  const OfficeGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Office Game',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E74D8),
          primary: const Color(0xFF2E74D8),
          secondary: const Color(0xFF55A844),
          tertiary: const Color(0xFFF08422),
        ),
        useMaterial3: true,
        fontFamily: 'LocalChinese',
      ),
      home: const OfficeGamePage(),
    );
  }
}

class OfficeGamePage extends StatefulWidget {
  const OfficeGamePage({super.key});

  @override
  State<OfficeGamePage> createState() => _OfficeGamePageState();
}

class _OfficeGamePageState extends State<OfficeGamePage> {
  OfficeGame _game = OfficeGame();

  void _reloadGame() {
    setState(() {
      _game = OfficeGame();
    });
  }

  void _resetCamera() {
    _game.resetCamera();
  }

  @override
  void reassemble() {
    super.reassemble();
    _reloadGame();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF183247),
      body: Stack(
        children: [
          Positioned.fill(child: GameWidget(key: ValueKey(_game), game: _game)),
          Positioned(
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _GameActionButton(
                    tooltip: '重置视角',
                    icon: Icons.center_focus_strong,
                    onPressed: _resetCamera,
                  ),
                  const SizedBox(height: 12),
                  _GameActionButton(
                    tooltip: '重新开始',
                    icon: Icons.refresh,
                    onPressed: _reloadGame,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameActionButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _GameActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox.square(
        dimension: 46,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: const Color(0xE62E74D8),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Icon(icon, size: 22),
        ),
      ),
    );
  }
}
