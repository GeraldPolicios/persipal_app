import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class FeedGame extends FlameGame {
  late SpriteAnimationComponent cat;

  late SpriteAnimation idleAnimation;
  late SpriteAnimation eatingAnimation;
  late SpriteAnimation drinkingAnimation;

  bool _isEating = false;
  bool _isDrinking = false;

  @override
  Color backgroundColor() {
    return Colors.transparent;
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Idle
    final idleSheet = await images.load('cat_parts/idle/idlesheet.png');

    idleAnimation = SpriteAnimation.fromFrameData(
      idleSheet,
      SpriteAnimationData.sequenced(
        amount: 60,
        stepTime: 0.06,
        textureSize: Vector2(96, 96),
        amountPerRow: 20,
        loop: true,
      ),
    );

    // Eating
    final eatingSheet =
        await images.load('cat_parts/feed/eating/eatingsheet.png');

    eatingAnimation = SpriteAnimation.fromFrameData(
      eatingSheet,
      SpriteAnimationData.sequenced(
        amount: 100,
        stepTime: 0.05,
        textureSize: Vector2(96, 96),
        amountPerRow: 20,
        loop: false,
      ),
    );

    // Drinking
    final drinkingSheet =
        await images.load('cat_parts/feed/drink/drinksheet.png');

    drinkingAnimation = SpriteAnimation.fromFrameData(
      drinkingSheet,
      SpriteAnimationData.sequenced(
        amount: 60,
        stepTime: 0.06,
        textureSize: Vector2(96, 96),
        amountPerRow: 20,
        loop: false,
      ),
    );

    // Start with idle
    cat = SpriteAnimationComponent(
      animation: idleAnimation,
      size: Vector2(120, 120),
      paint: Paint()..filterQuality = FilterQuality.none,
    );

    cat.anchor = Anchor.center;

    cat.position = Vector2(
      size.x / 2,
      size.y / 2 + 15,
    );

    add(cat);
  }

  Future<void> playEating() async {
    if (_isEating || _isDrinking) return;

    _isEating = true;

    cat.animation = eatingAnimation;

    await Future.delayed(
      const Duration(milliseconds: 5000),
    );

    cat.animation = idleAnimation;

    _isEating = false;
  }

  Future<void> playDrinking() async {
    if (_isEating || _isDrinking) return;

    _isDrinking = true;

    cat.animation = drinkingAnimation;

    await Future.delayed(
      const Duration(milliseconds: 3600),
    );

    cat.animation = idleAnimation;

    _isDrinking = false;
  }
}
