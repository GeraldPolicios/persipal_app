import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class PlayGame extends FlameGame {
  SpriteAnimationComponent? cat;

  // GameWidget can receive a play action before Flame finishes onLoad().
  final Completer<void> _ready = Completer<void>();

  late SpriteAnimation idleAnimation;
  late SpriteAnimation fur1IdleAnimation;
  late SpriteAnimation fur2IdleAnimation;
  late SpriteAnimation tennisAnimation;
  late SpriteAnimation featherAnimation;
  late SpriteAnimation laserAnimation;
  late SpriteAnimation yarnAnimation;

  int _furStage = 0;

  bool _isPlaying = false;

  bool get isPlaying => _isPlaying;

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

    // Tennis Ball
    final tennisSheet =
        await images.load('cat_parts/play/tennis/tennissheet.png');

    tennisAnimation = SpriteAnimation.fromFrameData(
      tennisSheet,
      SpriteAnimationData.sequenced(
        amount: 80,
        stepTime: 0.06,
        textureSize: Vector2(96, 96),
        amountPerRow: 20,
        loop: false,
      ),
    );

    // Feather
    final featherSheet =
        await images.load('cat_parts/play/feather/feathersheet.png');

    featherAnimation = SpriteAnimation.fromFrameData(
      featherSheet,
      SpriteAnimationData.sequenced(
        amount: 80,
        stepTime: 0.06,
        textureSize: Vector2(96, 96),
        amountPerRow: 20,
        loop: false,
      ),
    );

    // Laser Dot
    final laserSheet = await images.load('cat_parts/play/laser/lasersheet.png');

    laserAnimation = SpriteAnimation.fromFrameData(
      laserSheet,
      SpriteAnimationData.sequenced(
        amount: 80,
        stepTime: 0.06,
        textureSize: Vector2(96, 96),
        amountPerRow: 20,
        loop: false,
      ),
    );

    // Yarn Ball
    final yarnSheet = await images.load('cat_parts/play/yarn/yarnsheet.png');

    yarnAnimation = SpriteAnimation.fromFrameData(
      yarnSheet,
      SpriteAnimationData.sequenced(
        amount: 80,
        stepTime: 0.06,
        textureSize: Vector2(96, 96),
        amountPerRow: 20,
        loop: false,
      ),
    );

    // Start with idle
    final newCat = SpriteAnimationComponent(
      animation: _currentIdleAnimation(),
      size: Vector2(110, 110),
      paint: Paint()..filterQuality = FilterQuality.none,
    );

    newCat.anchor = Anchor.center;
    newCat.position = Vector2(
      size.x / 2,
      size.y / 2 + 30,
    );

    cat = newCat;
    add(newCat);

    if (!_ready.isCompleted) {
      _ready.complete();
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);

    final currentCat = cat;
    if (currentCat == null) {
      return;
    }

    currentCat.position = Vector2(
      size.x / 2,
      size.y / 2 + 30,
    );
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
    if (currentCat != null && !_isPlaying) {
      currentCat.animation = _currentIdleAnimation();
    }
  }

  Future<void> playTennis() async {
    await _ready.future;

    if (_isPlaying) return;

    _isPlaying = true;

    final currentCat = cat;
    if (currentCat == null) {
      _isPlaying = false;
      return;
    }

    try {
      currentCat.animation = tennisAnimation;

      await Future.delayed(
        const Duration(milliseconds: 4800),
      );
    } finally {
      final latestCat = cat;
      if (latestCat != null && latestCat.animation == tennisAnimation) {
        latestCat.animation = _currentIdleAnimation();
      }
      _isPlaying = false;
    }
  }

  Future<void> playFeather() async {
    await _ready.future;

    if (_isPlaying) return;

    _isPlaying = true;

    final currentCat = cat;
    if (currentCat == null) {
      _isPlaying = false;
      return;
    }

    try {
      currentCat.animation = featherAnimation;

      await Future.delayed(
        const Duration(milliseconds: 4800),
      );
    } finally {
      final latestCat = cat;
      if (latestCat != null && latestCat.animation == featherAnimation) {
        latestCat.animation = _currentIdleAnimation();
      }
      _isPlaying = false;
    }
  }

  Future<void> playLaser() async {
    await _ready.future;

    if (_isPlaying) return;

    _isPlaying = true;

    final currentCat = cat;
    if (currentCat == null) {
      _isPlaying = false;
      return;
    }

    try {
      currentCat.animation = laserAnimation;

      await Future.delayed(
        const Duration(milliseconds: 4800),
      );
    } finally {
      final latestCat = cat;
      if (latestCat != null && latestCat.animation == laserAnimation) {
        latestCat.animation = _currentIdleAnimation();
      }
      _isPlaying = false;
    }
  }

  Future<void> playYarn() async {
    await _ready.future;

    if (_isPlaying) return;

    _isPlaying = true;

    final currentCat = cat;
    if (currentCat == null) {
      _isPlaying = false;
      return;
    }

    try {
      currentCat.animation = yarnAnimation;

      await Future.delayed(
        const Duration(milliseconds: 4800),
      );
    } finally {
      final latestCat = cat;
      if (latestCat != null && latestCat.animation == yarnAnimation) {
        latestCat.animation = _currentIdleAnimation();
      }
      _isPlaying = false;
    }
  }
}
