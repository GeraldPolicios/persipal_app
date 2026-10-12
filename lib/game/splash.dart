import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class SplashGame extends FlameGame {
  SpriteAnimationComponent? cat;

  @override
  Color backgroundColor() {
    return const Color(0x00000000);
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final splashSheet = await images.load(
      'splash/splashsheet.png',
    );

    final splashAnimation = SpriteAnimation.fromFrameData(
      splashSheet,
      SpriteAnimationData.sequenced(
        amount: 60,
        stepTime: 0.08,
        textureSize: Vector2(480, 480),
        amountPerRow: 10,
        loop: true,
      ),
    );
    cat = SpriteAnimationComponent(
      animation: splashAnimation,
      size: Vector2(270, 270),
      paint: Paint()..filterQuality = FilterQuality.none,
    );

    cat!.anchor = Anchor.center;

    cat!.position = Vector2(
      size.x / 2,
      size.y / 2,
    );

    add(cat!);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);

    if (cat != null) {
      cat!.position = Vector2(
        size.x / 2,
        size.y / 2,
      );
    }
  }
}
