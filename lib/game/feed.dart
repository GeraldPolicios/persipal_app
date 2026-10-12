import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class FeedGame extends FlameGame {
  SpriteAnimationComponent? cat;

  // GameWidget can receive an action before Flame finishes onLoad().
  // Keep the animation methods safe until the cat component exists.
  final Completer<void> _ready = Completer<void>();

  late SpriteAnimation idleAnimation;
  late SpriteAnimation fur1IdleAnimation;
  late SpriteAnimation fur2IdleAnimation;
  late SpriteAnimation eatingAnimation;
  late SpriteAnimation drinkingAnimation;

  int _furStage = 0;

  bool _isEating = false;
  bool _isDrinking = false;

  @override
  Color backgroundColor() {
    return Colors.transparent;
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();

    try {
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

      // Fur 1 idle
      final fur1Sheet = await images.load('cat_parts/groom/fur1/fur1sheet.png');
      fur1IdleAnimation = SpriteAnimation.fromFrameData(
        fur1Sheet,
        SpriteAnimationData.sequenced(
          amount: 60,
          stepTime: 0.06,
          textureSize: Vector2(96, 96),
          amountPerRow: 20,
          loop: true,
        ),
      );

      // Fur 2 idle
      final fur2Sheet = await images.load('cat_parts/groom/fur2/fur2sheet.png');
      fur2IdleAnimation = SpriteAnimation.fromFrameData(
        fur2Sheet,
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
        animation: _currentIdleAnimation(),
        size: Vector2(110, 110),
        paint: Paint()..filterQuality = FilterQuality.none,
      );

      cat!.anchor = Anchor.center;

      cat!.position = Vector2(
        size.x / 2,
        size.y / 2 + 17,
      );

      add(cat!);

      if (!_ready.isCompleted) {
        _ready.complete();
      }
    } catch (error, stackTrace) {
      if (!_ready.isCompleted) {
        _ready.completeError(error, stackTrace);
      }
      rethrow;
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);

    final currentCat = cat;
    if (currentCat != null) {
      currentCat.position = Vector2(
        size.x / 2,
        size.y / 2 + 17,
      );
    }
  }

  SpriteAnimation _currentIdleAnimation() {
    switch (_furStage.clamp(0, 2).toInt()) {
      case 1:
        return fur1IdleAnimation;
      case 2:
        return fur2IdleAnimation;
      default:
        return idleAnimation;
    }
  }

  void setFurStage(int stage) {
    _furStage = stage.clamp(0, 2).toInt();
    final currentCat = cat;
    if (currentCat != null && !_isEating && !_isDrinking) {
      currentCat.animation = _currentIdleAnimation();
    }
  }

  Future<void> playEating({VoidCallback? onHeadAtBowl}) async {
    await _ready.future;

    if (_isEating || _isDrinking) return;

    _isEating = true;

    try {
      // Assign the animation exactly once. Reassigning it during rebuilds
      // would restart the ticker and make the eating motion look frozen.
      final currentCat = cat;
      if (currentCat == null) return;
      currentCat.animation = eatingAnimation;

      // In this sheet the mouth reaches the bowl around frame 40.
      // 40 frames × 50 ms = 2 seconds from animation start.
      await Future.delayed(const Duration(milliseconds: 2000));
      onHeadAtBowl?.call();

      // Keep the complete 100-frame animation running (100 × 50 ms = 5 s).
      await Future.delayed(const Duration(milliseconds: 3000));
    } finally {
      final currentCat = cat;
      if (currentCat != null && currentCat.animation == eatingAnimation) {
        currentCat.animation = _currentIdleAnimation();
      }
      _isEating = false;
    }
  }

  Future<void> playDrinking({VoidCallback? onHeadAtBowl}) async {
    await _ready.future;

    if (_isEating || _isDrinking) return;

    _isDrinking = true;

    try {
      final currentCat = cat;
      if (currentCat == null) return;
      currentCat.animation = drinkingAnimation;

      // In this sheet the mouth reaches the water around frame 25.
      // 25 frames × 60 ms = 1.5 seconds from animation start.
      await Future.delayed(const Duration(milliseconds: 1500));
      onHeadAtBowl?.call();

      // Keep the complete 60-frame animation running (60 × 60 ms = 3.6 s).
      await Future.delayed(const Duration(milliseconds: 2100));
    } finally {
      final currentCat = cat;
      if (currentCat != null && currentCat.animation == drinkingAnimation) {
        currentCat.animation = _currentIdleAnimation();
      }
      _isDrinking = false;
    }
  }
}
