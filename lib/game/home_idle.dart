import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class HomeIdleGame extends FlameGame {
  SpriteAnimationComponent? cat;

  late SpriteAnimation idleAnimation;

  @override
  Color backgroundColor() {
    return const Color(0x00000000);
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();

    final idleSheet = await images.load(
      'idle/idlesheet.png',
    );

    idleAnimation = SpriteAnimation.fromFrameData(
      idleSheet,
      SpriteAnimationData.sequenced(
        amount: 60,
        stepTime: 0.08,
        textureSize: Vector2(96, 96),
        amountPerRow: 20,
        loop: true,
      ),
    );

    cat = SpriteAnimationComponent(
      animation: idleAnimation,
      size: Vector2(96, 96),
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
