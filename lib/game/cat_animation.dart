import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class CatAnimation extends FlameGame {
  SpriteAnimationComponent? cat;

  late SpriteAnimation sleepAnimation;
  late SpriteAnimation sleepyAnimation;
  late SpriteAnimation restAnimation;
  late SpriteAnimation wakeAnimation;
  late SpriteAnimation stretchAnimation;
  late SpriteAnimation lookAnimation;
  late SpriteAnimation sitAnimation;
  late SpriteAnimation idleAnimation;
  late SpriteAnimation fur1IdleAnimation;
  late SpriteAnimation fur2IdleAnimation;

  late SpriteAnimation sadAnimation;

  late SpriteAnimation standAnimation;
  late SpriteAnimation highFiveAnimation;
  late SpriteAnimation idleStandAnimation;
  late SpriteAnimation sitDownAnimation;
  late SpriteAnimation happyAnimation;
  late SpriteAnimation angryAnimation;

  final bool startSad;
  final double positionYOffset;

  CatAnimation({
    this.startSad = false,
    this.positionYOffset = 30,
  });

  bool _isSleeping = false;
  bool _isSleepy = false;
  bool _isResting = false;
  bool _isWaking = false;
  bool _isDoingTrick = false;
  bool _isStanding = false;
  int _furStage = 0;

  int _animationVersion = 0;
  int _reactionVersion = 0;

  // ==========================================================
  // PENDING REQUESTS
  //
  // These are needed when GameScreen requests an animation
  // before Flame has finished creating the cat component.
  // ==========================================================
  bool _pendingHappy = false;
  bool _pendingSleepy = false;
  bool _pendingSleeping = false;
  bool _pendingSad = false;

  bool get isWaking => _isWaking;
  bool get isStanding => _isStanding;
  bool get isBusy => _isDoingTrick;
  bool get isSleeping => _isSleeping;
  bool get isSleepy => _isSleepy;
  bool get isResting => _isResting;
  @override
  bool get isLoaded => cat != null;

  @override
  Color backgroundColor() {
    return Colors.transparent;
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // ========================================================
    // SLEEP
    // ========================================================
    final sleepSheet = await images.load(
      'cat_parts/sleep/sleepsprite.png',
    );

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

    // ========================================================
    // SLEEPY
    // ========================================================
    final sleepySheet = await images.load(
      'cat_parts/sleepy/sleepysheet.png',
    );

    sleepyAnimation = SpriteAnimation.fromFrameData(
      sleepySheet,
      SpriteAnimationData.sequenced(
        amount: 60,
        stepTime: 0.08,
        textureSize: Vector2(96, 96),
        amountPerRow: 20,
        loop: true,
      ),
    );

    // ========================================================
    // REST
    // ========================================================
    final restSheet = await images.load(
      'cat_parts/rest/restsheet.png',
    );

    restAnimation = SpriteAnimation.fromFrameData(
      restSheet,
      SpriteAnimationData.sequenced(
        amount: 60,
        stepTime: 0.08,
        textureSize: Vector2(96, 96),
        amountPerRow: 20,
        loop: false,
      ),
    );

    // ========================================================
    // WAKE
    // ========================================================
    final wakeSheet = await images.load(
      'cat_parts/wake/wakesprite.png',
    );

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

    // ========================================================
    // STRETCH
    // ========================================================
    final stretchSheet = await images.load(
      'cat_parts/stretch/stretchsheet.png',
    );

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

    // ========================================================
    // LOOK
    // ========================================================
    final lookSheet = await images.load(
      'cat_parts/look/looksheet.png',
    );

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

    // ========================================================
    // SIT
    // ========================================================
    final sitSheet = await images.load(
      'cat_parts/sit/sitsheet.png',
    );

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

    // ========================================================
    // IDLE
    // ========================================================
    final idleSheet = await images.load(
      'cat_parts/idle/idlesheet.png',
    );

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

    // ========================================================
    // FUR 1 IDLE
    // ========================================================
    final fur1Sheet = await images.load(
      'cat_parts/groom/fur1/fur1sheet.png',
    );

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

    // ========================================================
    // FUR 2 IDLE
    // ========================================================
    final fur2Sheet = await images.load(
      'cat_parts/groom/fur2/fur2sheet.png',
    );

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

    // ========================================================
    // SAD
    // ========================================================
    final sadSheet = await images.load(
      'cat_parts/sad/sadsheet.png',
    );

    sadAnimation = SpriteAnimation.fromFrameData(
      sadSheet,
      SpriteAnimationData.sequenced(
        amount: 60,
        stepTime: 0.08,
        textureSize: Vector2(96, 96),
        amountPerRow: 20,
        loop: true,
      ),
    );

    // ========================================================
    // STAND
    // ========================================================
    final standSheet = await images.load(
      'cat_parts/stand/standsheet.png',
    );

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

    // ========================================================
    // HIGH FIVE
    // ========================================================
    final highFiveSheet = await images.load(
      'cat_parts/highfive/highfivesheet.png',
    );

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

    // ========================================================
    // IDLE STAND
    // ========================================================
    final idleStandSheet = await images.load(
      'cat_parts/idlestand/idlestandsheet.png',
    );

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

    // ========================================================
    // SIT DOWN
    // ========================================================
    final sitDownSheet = await images.load(
      'cat_parts/sitdown/sitdownsheet.png',
    );

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

    // ========================================================
    // HAPPY
    // ========================================================
    final happySheet = await images.load(
      'cat_parts/happy/happysheet.png',
    );

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

    // ========================================================
    // ANGRY
    // ========================================================
    final angrySheet = await images.load(
      'cat_parts/angry/angrysheet.png',
    );

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

    // ========================================================
    // CREATE CAT
    // ========================================================
    cat = SpriteAnimationComponent(
      animation: _currentIdleAnimation(),
      size: Vector2(110, 110),
      paint: Paint()..filterQuality = FilterQuality.none,
    );

    cat!.anchor = Anchor.center;

    cat!.position = Vector2(
      size.x / 2,
      size.y / 2 + positionYOffset,
    );

    add(cat!);

    // ========================================================
    // RESTORE INITIAL STATE
    // ========================================================

    // Neglected / Sad has highest priority.
    if (startSad || _pendingSad) {
      _pendingSad = false;
      showSad(force: true);
      return;
    }

    if (_pendingSleeping) {
      _pendingSleeping = false;
      _pendingSleepy = false;
      _pendingHappy = false;
      showSleeping();
      return;
    }

    // ========================================================
    // RESTORE PENDING SLEEPY
    //
    // This is the important navigation/loading fix.
    //
    // GameScreen can call enterSleepy() before Flame has
    // finished creating cat.
    //
    // Instead of losing that request, _pendingSleepy keeps it
    // until Flame finishes loading.
    // ========================================================
    if (_pendingSleepy) {
      _pendingSleepy = false;
      _pendingHappy = false;

      enterSleepy(
        force: true,
      );

      return;
    }

    // ========================================================
    // RESTORE PENDING HAPPY
    // ========================================================
    if (_pendingHappy) {
      _pendingHappy = false;

      unawaited(
        doHappy(),
      );
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);

    if (cat != null) {
      cat!.position = Vector2(
        size.x / 2,
        size.y / 2 + positionYOffset,
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

    if (cat == null) {
      return;
    }

    if (!_isSleeping &&
        !_isSleepy &&
        !_isResting &&
        !_isWaking &&
        !_isDoingTrick) {
      cat!.animation = _currentIdleAnimation();
    }
  }

  // ==========================================================
  // IDLE
  // ==========================================================
  void showIdle() {
    showFurIdle(_furStage);
  }

  void showFurIdle(
    int stage, {
    bool force = false,
  }) {
    _furStage = stage.clamp(0, 2).toInt();

    if (cat == null) {
      return;
    }

    if (!force &&
        (_isSleeping ||
            _isSleepy ||
            _isResting ||
            _isWaking ||
            _isDoingTrick)) {
      return;
    }

    _isSleeping = false;
    _isSleepy = false;
    _isResting = false;
    _isWaking = false;
    _isDoingTrick = false;
    _isStanding = false;

    cat!.animation = _currentIdleAnimation();
  }

  // ==========================================================
  // SAD
  // ==========================================================
  void showSad({
    bool force = false,
  }) {
    if (cat == null) {
      _pendingSad = true;
      _pendingSleeping = false;
      _pendingSleepy = false;
      _pendingHappy = false;
      return;
    }

    if (!force && (_isSleepy || _isResting || _isWaking || _isDoingTrick)) {
      return;
    }

    _animationVersion++;
    _reactionVersion++;

    _isSleeping = false;
    _isSleepy = false;
    _isResting = false;
    _isWaking = false;
    _isDoingTrick = false;
    _isStanding = false;

    _pendingSleepy = false;
    _pendingHappy = false;
    _pendingSleeping = false;
    _pendingSad = false;

    cat!.animation = sadAnimation;
  }

  // ==========================================================
  // SLEEPY
  // ==========================================================
  void enterSleepy({
    bool force = false,
  }) {
    // ========================================================
    // FLAME HAS NOT CREATED CAT YET
    //
    // DO NOT THROW AWAY THE SLEEPY REQUEST.
    // ========================================================
    if (cat == null) {
      _pendingSleepy = true;
      _pendingSleeping = false;
      _pendingSad = false;
      _pendingHappy = false;
      return;
    }

    // Never replace actual Sleeping, Resting, or Waking.
    if (_isSleeping || _isResting || _isWaking) {
      return;
    }

    // Already Sleepy.
    if (_isSleepy && !force) {
      return;
    }

    // Invalidate currently running reactions.
    _animationVersion++;
    _reactionVersion++;

    // Sleepy is allowed to interrupt Happy/Angry.
    _isDoingTrick = false;
    _isStanding = false;

    _isSleeping = false;
    _isResting = false;
    _isWaking = false;

    _isSleepy = true;

    _pendingHappy = false;
    _pendingSleepy = false;
    _pendingSleeping = false;
    _pendingSad = false;

    cat!.animation = sleepyAnimation;
  }

  // ==========================================================
  // SLEEPY → REST → SLEEPING
  // ==========================================================
  Future<void> restAndSleep() async {
    if (cat == null) {
      return;
    }

    if (!_isSleepy || _isResting || _isWaking || _isDoingTrick) {
      return;
    }

    final version = ++_animationVersion;

    _isSleepy = false;
    _isResting = true;
    _isSleeping = false;

    cat!.animation = restAnimation;

    await Future.delayed(
      const Duration(
        milliseconds: 5000,
      ),
    );

    if (version != _animationVersion || !_isResting) {
      return;
    }

    _isResting = false;
    _isSleeping = true;

    cat!.animation = sleepAnimation;
  }

  // ==========================================================
  // SLEEPING
  // ==========================================================
  void showSleeping() {
    if (cat == null) {
      _pendingSleeping = true;
      _pendingSleepy = false;
      _pendingSad = false;
      _pendingHappy = false;
      return;
    }

    _animationVersion++;
    _reactionVersion++;

    _isSleeping = true;
    _isSleepy = false;
    _isResting = false;
    _isWaking = false;
    _isDoingTrick = false;
    _isStanding = false;

    _pendingSleepy = false;
    _pendingHappy = false;
    _pendingSleeping = false;
    _pendingSad = false;

    cat!.animation = sleepAnimation;
  }

  // ==========================================================
  // WAKE
  //
  // Existing wake behavior remains unchanged for now.
  // ==========================================================
  Future<void> wakeUp() async {
    if (cat == null) {
      return;
    }

    if (!_isSleeping || _isWaking || _isDoingTrick) {
      return;
    }

    final version = ++_animationVersion;

    _isSleeping = false;
    _isWaking = true;
    _pendingSleeping = false;

    cat!.animation = wakeAnimation;

    await Future.delayed(
      const Duration(
        milliseconds: 4800,
      ),
    );

    if (version != _animationVersion || !_isWaking) {
      return;
    }

    cat!.animation = stretchAnimation;

    await Future.delayed(
      const Duration(
        milliseconds: 3600,
      ),
    );

    if (version != _animationVersion || !_isWaking) {
      return;
    }

    cat!.animation = lookAnimation;

    await Future.delayed(
      const Duration(
        milliseconds: 3600,
      ),
    );

    if (version != _animationVersion || !_isWaking) {
      return;
    }

    cat!.animation = sitAnimation;

    await Future.delayed(
      const Duration(
        milliseconds: 3600,
      ),
    );

    if (version != _animationVersion || !_isWaking) {
      return;
    }

    cat!.animation = _currentIdleAnimation();

    _isStanding = false;
    _isWaking = false;
  }

  // ==========================================================
  // HIGH FIVE
  // ==========================================================
  Future<void> doHighFive() async {
    if (cat == null) {
      return;
    }

    if (_isDoingTrick ||
        _isWaking ||
        _isStanding ||
        _isSleeping ||
        _isSleepy ||
        _isResting) {
      return;
    }

    final version = ++_animationVersion;

    _isDoingTrick = true;

    cat!.animation = standAnimation;

    await Future.delayed(
      const Duration(
        milliseconds: 3600,
      ),
    );

    if (version != _animationVersion || !_isDoingTrick) {
      return;
    }

    _isStanding = true;

    cat!.animation = highFiveAnimation;

    await Future.delayed(
      const Duration(
        milliseconds: 5400,
      ),
    );

    if (version != _animationVersion || !_isDoingTrick) {
      return;
    }

    cat!.animation = idleStandAnimation;

    _isDoingTrick = false;
  }

  // ==========================================================
  // SIT DOWN
  // ==========================================================
  Future<void> sitDown() async {
    if (cat == null) {
      return;
    }

    if (_isDoingTrick || _isWaking || !_isStanding) {
      return;
    }

    final version = ++_animationVersion;

    _isDoingTrick = true;

    cat!.animation = sitDownAnimation;

    await Future.delayed(
      const Duration(
        milliseconds: 4800,
      ),
    );

    if (version != _animationVersion || !_isDoingTrick) {
      return;
    }

    cat!.animation = _currentIdleAnimation();

    _isStanding = false;
    _isDoingTrick = false;
  }

  // ==========================================================
  // HAPPY
  // ==========================================================
  Future<void> doHappy() async {
    // Flame hasn't finished loading.
    // Queue Happy instead of losing it.
    if (cat == null) {
      _pendingHappy = true;
      return;
    }

    if (_isWaking ||
        _isDoingTrick ||
        _isStanding ||
        _isSleeping ||
        _isSleepy ||
        _isResting) {
      return;
    }

    final animationVersion = ++_animationVersion;

    _reactionVersion++;

    final currentReactionVersion = _reactionVersion;

    _isDoingTrick = true;

    cat!.animation = happyAnimation;

    await Future.delayed(
      const Duration(
        milliseconds: 4800,
      ),
    );

    if (animationVersion != _animationVersion ||
        currentReactionVersion != _reactionVersion ||
        !_isDoingTrick) {
      return;
    }

    cat!.animation = _currentIdleAnimation();

    _isDoingTrick = false;
  }

  // ==========================================================
  // ANGRY
  // ==========================================================
  Future<void> doAngry() async {
    if (cat == null) {
      return;
    }

    if (_isWaking || _isStanding || _isSleeping || _isSleepy || _isResting) {
      return;
    }

    final animationVersion = ++_animationVersion;

    _reactionVersion++;

    final currentReactionVersion = _reactionVersion;

    _isDoingTrick = true;

    cat!.animation = angryAnimation;

    await Future.delayed(
      const Duration(
        milliseconds: 4800,
      ),
    );

    if (animationVersion != _animationVersion ||
        currentReactionVersion != _reactionVersion ||
        !_isDoingTrick) {
      return;
    }

    cat!.animation = _currentIdleAnimation();

    _isDoingTrick = false;
  }
}
