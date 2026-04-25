import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'game/office_simulation_game.dart';

class OfficePrototypePage extends StatelessWidget {
  const OfficePrototypePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(game: OfficeSimulationGame()),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => Navigator.of(context).pop(),
        child: const Icon(Icons.arrow_back),
      ),
    );
  }
}
