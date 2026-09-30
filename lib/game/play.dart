import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class PlayGame extends FlameGame {
  late SpriteAnimationComponent cat;

  late SpriteAnimation idleAnimation;
  late SpriteAnimation tennisAnimation;
  late SpriteAnimation featherAnimation;
  late SpriteAnimation laserAnimation;
  late SpriteAnimation yarnAnimation;

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
    cat = SpriteAnimationComponent(
      animation: idleAnimation,
      size: Vector2(96, 96),
      paint: Paint()..filterQuality = FilterQuality.none,
    );

    cat.anchor = Anchor.center;

    cat.position = Vector2(
      size.x / 2,
      size.y / 2 + 25,
    );

    add(cat);
  }

  Future<void> playTennis() async {
    if (_isPlaying) return;

    _isPlaying = true;

    cat.animation = tennisAnimation;

    await Future.delayed(
      const Duration(milliseconds: 4800),
    );

    cat.animation = idleAnimation;

    _isPlaying = false;
  }

  Future<void> playFeather() async {
    if (_isPlaying) return;

    _isPlaying = true;

    cat.animation = featherAnimation;

    await Future.delayed(
      const Duration(milliseconds: 4800),
    );

    cat.animation = idleAnimation;

    _isPlaying = false;
  }

  Future<void> playLaser() async {
    if (_isPlaying) return;

    _isPlaying = true;

    cat.animation = laserAnimation;

    await Future.delayed(
      const Duration(milliseconds: 4800),
    );

    cat.animation = idleAnimation;

    _isPlaying = false;
  }

  Future<void> playYarn() async {
    if (_isPlaying) return;

    _isPlaying = true;

    cat.animation = yarnAnimation;

    await Future.delayed(
      const Duration(milliseconds: 4800),
    );

    cat.animation = idleAnimation;

    _isPlaying = false;
  }
}
