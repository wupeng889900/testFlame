import 'package:flutter/material.dart';

import 'office_game_embed.dart';

void main() {
  runApp(const OfficeGameDemoApp());
}

class OfficeGameDemoApp extends StatelessWidget {
  const OfficeGameDemoApp({super.key});

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
      home: const OfficeGamePage(
        options: OfficeGameOptions(showEditorTools: true),
      ),
    );
  }
}
