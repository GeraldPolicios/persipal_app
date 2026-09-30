import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class CatAnimation extends FlameGame {
  SpriteAnimationComponent? cat;

  late SpriteAnimation sleepAnimation;
  late SpriteAnimation wakeAnimation;
  late SpriteAnimation stretchAnimation;
  late SpriteAnimation lookAnimation;
  late SpriteAnimation sitAnimation;
  late SpriteAnimation idleAnimation;

  late SpriteAnimation standAnimation;
  late SpriteAnimation highFiveAnimation;
  late SpriteAnimation idleStandAnimation;
  late SpriteAnimation sitDownAnimation;
  late SpriteAnimation happyAnimation;
  late SpriteAnimation angryAnimation;

  bool _isSleeping = true;
  bool _isWaking = false;
  bool _isDoingTrick = false;
  bool _isStanding = false;

  int _reactionVersion = 0;

  bool get isWaking => _isWaking;
  bool get isBusy => _isDoingTrick;
  bool get isSleeping => _isSleeping;

  // Make the Flame background transparent
  @override
  Color backgroundColor() {
    return Colors.transparent;
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();

    // Sleep
    final sleepSheet = await images.load('cat_parts/sleep/sleepsprite.png');

    sleepAnimation = SpriteAnimation.fromFrameData(
      sleepSheet,
      SpriteAnimationData.sequenced(
        amount: 121,
        stepTime: 0.0417,
        textureSize: Vector2(96, 96),
        amountPerRow: 11,
        loop: true,
      ),
    );

    // Wake
    final wakeSheet = await images.load('cat_parts/wake/wakesprite.png');

    wakeAnimation = SpriteAnimation.fromFrameData(
      wakeSheet,
      SpriteAnimationData.sequenced(
        amount: 60,
        stepTime: 0.08,
        textureSize: Vector2(96, 96),
        amountPerRow: 20,
        loop: false,
      ),
    );

    // Stretch
    final stretchSheet =
        await images.load('cat_parts/stretch/stretchsheet.png');

    stretchAnimation = SpriteAnimation.fromFrameData(
      stretchSheet,
      SpriteAnimationData.sequenced(
        amount: 60,
        stepTime: 0.06,
        textureSize: Vector2(96, 96),
        amountPerRow: 20,
        loop: false,
      ),
    );

    // Look
    final lookSheet = await images.load('cat_parts/look/looksheet.png');

    lookAnimation = SpriteAnimation.fromFrameData(
      lookSheet,
      SpriteAnimationData.sequenced(
        amount: 60,
        stepTime: 0.06,
        textureSize: Vector2(96, 96),
        amountPerRow: 20,
        loop: false,
      ),
    );

    // Sit after waking
    final sitSheet = await images.load('cat_parts/sit/sitsheet.png');

    sitAnimation = SpriteAnimation.fromFrameData(
      sitSheet,
      SpriteAnimationData.sequenced(
        amount: 60,
        stepTime: 0.06,
        textureSize: Vector2(96, 96),
        amountPerRow: 20,
        loop: false,
      ),
    );

    // Sitting Idle
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

    // Stand
    final standSheet = await images.load('cat_parts/stand/standsheet.png');

    standAnimation = SpriteAnimation.fromFrameData(
      standSheet,
      SpriteAnimationData.sequenced(
        amount: 60,
        stepTime: 0.06,
        textureSize: Vector2(96, 96),
        amountPerRow: 20,
        loop: false,
      ),
    );

    // High Five
    final highFiveSheet =
        await images.load('cat_parts/highfive/highfivesheet.png');

    highFiveAnimation = SpriteAnimation.fromFrameData(
      highFiveSheet,
      SpriteAnimationData.sequenced(
        amount: 60,
        stepTime: 0.09,
        textureSize: Vector2(96, 96),
        amountPerRow: 20,
        loop: false,
      ),
    );

    // Standing Idle
    final idleStandSheet =
        await images.load('cat_parts/idlestand/idlestandsheet.png');

    idleStandAnimation = SpriteAnimation.fromFrameData(
      idleStandSheet,
      SpriteAnimationData.sequenced(
        amount: 60,
        stepTime: 0.09,
        textureSize: Vector2(96, 96),
        amountPerRow: 20,
        loop: true,
      ),
    );

    // Sit Down
    final sitDownSheet =
        await images.load('cat_parts/sitdown/sitdownsheet.png');

    sitDownAnimation = SpriteAnimation.fromFrameData(
      sitDownSheet,
      SpriteAnimationData.sequenced(
        amount: 60,
        stepTime: 0.08,
        textureSize: Vector2(96, 96),
        amountPerRow: 20,
        loop: false,
      ),
    );

    // Happy
    final happySheet = await images.load('cat_parts/happy/happysheet.png');

    happyAnimation = SpriteAnimation.fromFrameData(
      happySheet,
      SpriteAnimationData.sequenced(
        amount: 60,
        stepTime: 0.08,
        textureSize: Vector2(96, 96),
        amountPerRow: 20,
        loop: false,
      ),
    );

    // Angry
    final angrySheet = await images.load('cat_parts/angry/angrysheet.png');

    angryAnimation = SpriteAnimation.fromFrameData(
      angrySheet,
      SpriteAnimationData.sequenced(
        amount: 60,
        stepTime: 0.08,
        textureSize: Vector2(96, 96),
        amountPerRow: 20,
        loop: false,
      ),
    );

    // Start with sleeping cat
    cat = SpriteAnimationComponent(
      animation: sleepAnimation,
      size: Vector2(96, 96),
      paint: Paint()..filterQuality = FilterQuality.none,
    );

    cat!.anchor = Anchor.center;

    // Cat position
    // X = center
    // Y = center + 25 moves the cat downward
    cat!.position = Vector2(
      size.x / 2,
      size.y / 2 + 25,
    );

    add(cat!);
  }

  @override
  void onGameResize(Vector2 canvasSize) {
    super.onGameResize(canvasSize);

    if (cat != null) {
      cat!.position = Vector2(
        canvasSize.x / 2,
        canvasSize.y / 2 + 25,
      );
    }
  }

  // Wake up sequence
  Future<void> wakeUp() async {
    if (!_isSleeping || _isWaking || _isDoingTrick) return;

    _isSleeping = false;
    _isWaking = true;

    // Sleep → Wake
    cat!.animation = wakeAnimation;

    await Future.delayed(
      const Duration(milliseconds: 4800),
    );

    // Wake → Stretch
    cat!.animation = stretchAnimation;

    await Future.delayed(
      const Duration(milliseconds: 3600),
    );

    // Stretch → Look
    cat!.animation = lookAnimation;

    await Future.delayed(
      const Duration(milliseconds: 3600),
    );

    // Look → Sit
    cat!.animation = sitAnimation;

    await Future.delayed(
      const Duration(milliseconds: 3600),
    );

    // Sit → Sitting Idle
    cat!.animation = idleAnimation;

    _isStanding = false;
    _isWaking = false;
  }

  // Sitting Idle → Stand → High Five → Standing Idle
  Future<void> doHighFive() async {
    if (_isDoingTrick || _isWaking || _isStanding) return;

    _isDoingTrick = true;

    // Sitting Idle → Stand
    cat!.animation = standAnimation;

    await Future.delayed(
      const Duration(milliseconds: 3600),
    );

    _isStanding = true;

    // Stand → High Five
    cat!.animation = highFiveAnimation;

    await Future.delayed(
      const Duration(milliseconds: 5400),
    );

    // High Five → Standing Idle
    cat!.animation = idleStandAnimation;

    _isDoingTrick = false;
  }

  // Standing Idle → Sit Down → Sitting Idle
  Future<void> sitDown() async {
    if (_isDoingTrick || _isWaking || !_isStanding) return;

    _isDoingTrick = true;

    // Standing Idle → Sit Down
    cat!.animation = sitDownAnimation;

    await Future.delayed(
      const Duration(milliseconds: 4800),
    );

    // Sit Down → Sitting Idle
    cat!.animation = idleAnimation;

    _isStanding = false;
    _isDoingTrick = false;
  }

  // Happy reaction
  Future<void> doHappy() async {
    if (_isWaking || _isDoingTrick || _isStanding) return;

    _isDoingTrick = true;
    _reactionVersion++;

    final currentVersion = _reactionVersion;

    // Sitting Idle → Happy
    cat!.animation = happyAnimation;

    await Future.delayed(
      const Duration(milliseconds: 4800),
    );

    // Only return to Idle if Angry has not started
    if (currentVersion != _reactionVersion) return;

    // Happy → Sitting Idle
    cat!.animation = idleAnimation;

    _isDoingTrick = false;
  }

  // Angry reaction
  Future<void> doAngry() async {
    if (_isWaking || _isStanding) return;

    _reactionVersion++;
    _isDoingTrick = true;

    // Happy → Angry
    cat!.animation = angryAnimation;

    await Future.delayed(
      const Duration(milliseconds: 4800),
    );

    // Angry → Sitting Idle
    cat!.animation = idleAnimation;

    _isDoingTrick = false;
  }
}
