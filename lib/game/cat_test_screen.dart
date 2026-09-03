import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import 'cat_animation.dart';

class CatTestScreen extends StatelessWidget {
  const CatTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE6CC),
      body: GameWidget<CatAnimation>(
        game: CatAnimation(),
      ),
    );
  }
}
