import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class CatAnimation extends FlameGame {
  late SpriteAnimationComponent cat;

  late SpriteAnimation sleepAnimation;
  late SpriteAnimation wakeAnimation;
  late SpriteAnimation stretchAnimation;
  late SpriteAnimation lookAnimation;
  late SpriteAnimation sitAnimation;
  late SpriteAnimation idleAnimation;

  bool _isWaking = false;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Load sleep sprite sheet
    final sleepSheet = await images.load(
      'cat_parts/sleep/sleepsprite.png',
    );

    // Sleep animation
    sleepAnimation = SpriteAnimation.fromFrameData(
      sleepSheet,
      SpriteAnimationData.sequenced(
        // 121 sleep frames
        amount: 121,

        // Smooth 24 fps
        stepTime: 0.0417,

        // Each frame is 96 x 96
        textureSize: Vector2(96, 96),

        // 11 frames per row
        amountPerRow: 11,

        // Keep sleeping
        loop: true,
      ),
    );

    // Load wake sprite sheet
    final wakeSheet = await images.load(
      'cat_parts/wake/wakesprite.png',
    );

    // Wake animation
    wakeAnimation = SpriteAnimation.fromFrameData(
      wakeSheet,
      SpriteAnimationData.sequenced(
        // 60 wake frames
        amount: 60,

        // 60 x 0.08 = 4.8 seconds
        stepTime: 0.08,

        // Each frame is 96 x 96
        textureSize: Vector2(96, 96),

        // 20 frames per row
        amountPerRow: 20,

        // Play once
        loop: false,
      ),
    );

    // Load stretch sprite sheet
    final stretchSheet = await images.load(
      'cat_parts/stretch/stretchsheet.png',
    );

    // Stretch animation
    stretchAnimation = SpriteAnimation.fromFrameData(
      stretchSheet,
      SpriteAnimationData.sequenced(
        // 60 stretch frames
        amount: 60,

        // 60 x 0.06 = 3.6 seconds
        stepTime: 0.06,

        // Each frame is 96 x 96
        textureSize: Vector2(96, 96),

        // 20 frames per row
        amountPerRow: 20,

        // Play once
        loop: false,
      ),
    );

    // Load look sprite sheet
    final lookSheet = await images.load(
      'cat_parts/look/looksheet.png',
    );

    // Look left and right animation
    lookAnimation = SpriteAnimation.fromFrameData(
      lookSheet,
      SpriteAnimationData.sequenced(
        // 60 look frames
        amount: 60,

        // 60 x 0.06 = 3.6 seconds
        stepTime: 0.06,

        // Each frame is 96 x 96
        textureSize: Vector2(96, 96),

        // 20 frames per row
        amountPerRow: 20,

        // Play once
        loop: false,
      ),
    );

    // Load sit sprite sheet
    final sitSheet = await images.load(
      'cat_parts/sit/sitsheet.png',
    );

    // Sit animation
    sitAnimation = SpriteAnimation.fromFrameData(
      sitSheet,
      SpriteAnimationData.sequenced(
        // 60 sit frames
        amount: 60,

        // 60 x 0.06 = 3.6 seconds
        stepTime: 0.06,

        // Each frame is 96 x 96
        textureSize: Vector2(96, 96),

        // 20 frames per row
        amountPerRow: 20,

        // Play once
        loop: false,
      ),
    );

    // Load idle sprite sheet
    final idleSheet = await images.load(
      'cat_parts/idle/idlesheet.png',
    );

    // Idle animation
    idleAnimation = SpriteAnimation.fromFrameData(
      idleSheet,
      SpriteAnimationData.sequenced(
        // 60 idle frames
        amount: 60,

        // Smooth 24 fps
        stepTime: 0.06,

        // Each frame is 96 x 96
        textureSize: Vector2(96, 96),

        // 20 frames per row
        amountPerRow: 20,

        // Keep idle animation looping
        loop: true,
      ),
    );

    // Create cat
    cat = SpriteAnimationComponent(
      // Start with sleeping animation
      animation: sleepAnimation,

      // Keep the same size as one sprite frame
      size: Vector2(96, 96),

      // Center the cat
      anchor: Anchor.center,

      // Keep the cat in one fixed position
      position: Vector2(
        size.x / 2,
        size.y - 45,
      ),
    );

    add(cat);
  }

  // Sleep -> Wake -> Stretch -> Look -> Sit -> Idle
  Future<void> wakeUp() async {
    // Prevent the sequence from starting again
    if (_isWaking) return;

    _isWaking = true;

    // Sleep -> Wake
    cat.animation = wakeAnimation;

    // Wait for Wake to finish
    await Future.delayed(
      const Duration(milliseconds: 4800),
    );

    // Wake -> Stretch
    cat.animation = stretchAnimation;

    // Wait for Stretch to finish
    await Future.delayed(
      const Duration(milliseconds: 3600),
    );

    // Stretch -> Look
    cat.animation = lookAnimation;

    // Wait for Look to finish
    await Future.delayed(
      const Duration(milliseconds: 3600),
    );

    // Look -> Sit
    cat.animation = sitAnimation;

    // Wait for Sit to finish
    await Future.delayed(
      const Duration(milliseconds: 3600),
    );

    // Sit -> Idle
    cat.animation = idleAnimation;

    // Idle keeps looping
    _isWaking = false;
  }
}
