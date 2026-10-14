import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class GroomGame extends FlameGame {
  SpriteAnimationComponent? cat;

  late SpriteAnimation idleAnimation;
  late SpriteAnimation fur1IdleAnimation;
  late SpriteAnimation fur2IdleAnimation;
  late SpriteAnimation wetAnimation;
  late SpriteAnimation wet1Animation;
  late SpriteAnimation wet2Animation;
  late SpriteAnimation happyAnimation;
  late SpriteAnimation sadAnimation;

  final math.Random _random = math.Random();

  final List<SoapBubble> soapBubbles = [];
  final List<Vector2> _pendingSoapBubbles = [];
  bool _layoutReady = false;
  Vector2? _layoutSize;

  ShowerWater? _showerWater;
  BlowerWind? _blowerWind;

  bool _catWashed = false;
  bool _isWet = false;
  bool _isShowingHappy = false;
  bool _pendingSad = false;
  int _furStage = 0;

  DirtLayer? _dirtLayer;
  double _dirtOpacity = 1.0;
  double _dirtWashProgress = 0.0;
  bool _dirtHeavy = false;

  double _dryProgress = 0.0;

  bool get catWashed => _catWashed;

  /// True after showering until the blower finishes drying the cat.
  bool get isWet => _isWet;

  @override
  Color backgroundColor() {
    return Colors.transparent;
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();

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

    final wetSheet = await images.load(
      'cat_parts/wet/wetsheet.png',
    );

    wetAnimation = SpriteAnimation.fromFrameData(
      wetSheet,
      SpriteAnimationData.sequenced(
        amount: 60,
        stepTime: 0.08,
        textureSize: Vector2(96, 96),
        amountPerRow: 20,
        loop: true,
      ),
    );

    final wet1Sheet = await images.load(
      'cat_parts/groom/wet1/wet1sheet.png',
    );

    wet1Animation = SpriteAnimation.fromFrameData(
      wet1Sheet,
      SpriteAnimationData.sequenced(
        amount: 60,
        stepTime: 0.08,
        textureSize: Vector2(96, 96),
        amountPerRow: 20,
        loop: true,
      ),
    );

    final wet2Sheet = await images.load(
      'cat_parts/groom/wet2/wet2sheet.png',
    );

    wet2Animation = SpriteAnimation.fromFrameData(
      wet2Sheet,
      SpriteAnimationData.sequenced(
        amount: 60,
        stepTime: 0.08,
        textureSize: Vector2(96, 96),
        amountPerRow: 20,
        loop: true,
      ),
    );

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

    cat = SpriteAnimationComponent(
      animation: _currentIdleAnimation(),
      size: Vector2(110, 110),
      paint: Paint()..filterQuality = FilterQuality.none,
    );

    cat!.anchor = Anchor.center;

    cat!.position = Vector2(
      size.x / 2,
      size.y / 2 + 30,
    );

    add(cat!);

    // Status can be requested by the screen before Flame finishes loading.
    // Restore it now so Sad/Neglected is visible immediately on entry, not
    // only after the player starts a grooming action.
    if (_pendingSad) {
      _pendingSad = false;
      cat!.animation = sadAnimation;
    }

    _dirtLayer = DirtLayer(
      opacity: _dirtOpacity,
      heavy: _dirtHeavy,
      position: cat!.position.clone(),
    );
    add(_dirtLayer!);
  }

  @override
  void onGameResize(
    Vector2 size,
  ) {
    super.onGameResize(
      size,
    );

    // DragTarget callbacks can arrive before Flame has completed its first
    // layout. Mark the game ready here and flush any queued soap bubbles.
    _layoutReady = true;
    _layoutSize = size.clone();

    if (cat != null) {
      cat!.position = Vector2(
        size.x / 2,
        size.y / 2 + 30,
      );
      _dirtLayer?.position = cat!.position.clone();
    }

    if (_pendingSoapBubbles.isNotEmpty) {
      final pending = List<Vector2>.from(_pendingSoapBubbles);
      _pendingSoapBubbles.clear();

      for (final position in pending) {
        addSoapBubble(position.x, position.y);
      }
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

  SpriteAnimation _currentWetAnimation() {
    switch (_furStage.clamp(0, 2).toInt()) {
      case 1:
        return wet1Animation;
      case 2:
        return wet2Animation;
      default:
        return wetAnimation;
    }
  }

  void setFurStage(int stage) {
    _furStage = stage.clamp(0, 2).toInt();
    final currentCat = cat;
    if (currentCat == null) return;

    // Fur controls appearance, not mood. Do not replace a sad animation
    // just because the provider rebuilds with an updated fur stage.
    if (!_isWet && !_isShowingHappy && currentCat.animation != sadAnimation) {
      currentCat.animation = _currentIdleAnimation();
    }
  }

  void setDirt({
    required bool visible,
    bool heavy = false,
    double opacity = 1.0,
  }) {
    _dirtOpacity = visible ? opacity.clamp(0.0, 1.0).toDouble() : 0.0;
    _dirtHeavy = heavy;
    _dirtLayer?.setAppearance(
      opacity: _dirtOpacity,
      heavy: _dirtHeavy,
    );
    _dirtLayer?.setWashProgress(_dirtWashProgress);
  }

  void setDirtWashProgress(double progress) {
    _dirtWashProgress = progress.clamp(0.0, 1.0).toDouble();
    _dirtLayer?.setWashProgress(_dirtWashProgress);
  }

  void showSad() {
    if (cat == null) {
      _pendingSad = true;
      return;
    }
    _pendingSad = false;
    _isShowingHappy = false;
    if (cat!.animation != sadAnimation) {
      cat!.animation = sadAnimation;
    }
  }

  /// Selects the idle artwork for the supplied fur stage without applying
  /// care-status animation. Used by grooming while trimming is in progress.
  void showFurIdle(int stage, {bool force = false}) {
    _furStage = stage.clamp(0, 2).toInt();
    final currentCat = cat;
    if (currentCat == null || _isWet) return;
    _isShowingHappy = false;
    final target = _currentIdleAnimation();
    if (force || currentCat.animation != target) {
      currentCat.animation = target;
    }
  }

  void showIdle() {
    if (cat == null) return;
    _isShowingHappy = false;
    // A normal rebuild/status refresh must not erase the wet pose. The cat
    // stays visibly wet after the shower is released and until the blower
    // explicitly completes drying.
    if (_isWet) {
      if (cat!.animation != _currentWetAnimation()) {
        cat!.animation = _currentWetAnimation();
      }
      return;
    }
    if (cat!.animation != _currentIdleAnimation()) {
      cat!.animation = _currentIdleAnimation();
    }
  }

  // WET CAT

  void showWetCat() {
    if (cat == null) {
      return;
    }

    _isWet = true;
    _dryProgress = 0.0;

    if (!_isShowingHappy && cat!.animation != _currentWetAnimation()) {
      // Do not reassign the same animation on every drag update.
      // Reassigning it repeatedly resets the animation ticker to frame 0,
      // which makes the wet animation look frozen while the shower moves.
      cat!.animation = _currentWetAnimation();
    }
  }

  // HAPPY CAT FROM TOWEL

  Future<void> showHappyCat() async {
    if (cat == null) {
      return;
    }

    if (_isShowingHappy) {
      return;
    }

    _isShowingHappy = true;

    cat!.animation = happyAnimation;

    add(
      HappyEffect(
        position: cat!.position.clone(),
      ),
    );

    await Future.delayed(
      const Duration(
        milliseconds: 900,
      ),
    );

    if (cat != null) {
      if (_isWet) {
        cat!.animation = _currentWetAnimation();
      } else {
        cat!.animation = _currentIdleAnimation();
      }
    }

    _isShowingHappy = false;
  }

  // TOWEL

  void towelSwipe(
    Offset towelPosition,
  ) {
    final gameSize = _layoutSize;
    if (!_layoutReady || gameSize == null) {
      return;
    }

    final catCenter = Vector2(
      gameSize.x / 2,
      gameSize.y / 2 + 30,
    );

    final towelCenter = Vector2(
      towelPosition.dx,
      towelPosition.dy,
    );

    final distance = towelCenter.distanceTo(
      catCenter,
    );

    if (distance <= 75) {
      showHappyCat();
    }
  }

  // SOAP

  void addSoapBubble(
    double x,
    double y,
  ) {
    // A Flutter DragTarget can report movement before Flame has a valid
    // canvas layout. Queue the request instead of reading Game.size early.
    final gameSize = _layoutSize;
    if (!_layoutReady || gameSize == null) {
      _pendingSoapBubbles.add(Vector2(x, y));
      return;
    }
    if (gameSize.x <= 16 || gameSize.y <= 16) {
      return;
    }

    final maxX = math.max(
      8.0,
      gameSize.x - 8.0,
    );

    final maxY = math.max(
      8.0,
      gameSize.y - 8.0,
    );

    final bubbleX = x.clamp(
      8.0,
      maxX,
    );

    final bubbleY = y.clamp(
      8.0,
      maxY,
    );

    final radius = 4.5 + _random.nextDouble() * 4;

    final bubble = SoapBubble(
      position: Vector2(
        bubbleX,
        bubbleY,
      ),
      radius: radius,
      drift: (_random.nextDouble() - 0.5) * 1.5,
    );

    add(bubble);

    soapBubbles.add(
      bubble,
    );
  }

  void clearSoapBubbles() {
    for (final bubble in List<SoapBubble>.from(soapBubbles)) {
      bubble.removeFromParent();
    }

    soapBubbles.clear();
  }

  void _removeFinishedBubbles() {
    soapBubbles.removeWhere((bubble) => bubble.isFaded);
  }

  // SHOWER

  void startShower(
    Offset showerPosition,
  ) {
    stopShower();

    _catWashed = false;

    _showerWater = ShowerWater(
      showerPosition: Vector2(
        showerPosition.dx,
        showerPosition.dy,
      ),
    );

    add(
      _showerWater!,
    );

    _washBubbles(
      showerPosition,
    );
  }

  bool moveShower(
    Offset showerPosition,
  ) {
    if (_showerWater == null) {
      startShower(
        showerPosition,
      );
    } else {
      _showerWater!.updatePosition(
        Vector2(
          showerPosition.dx,
          showerPosition.dy,
        ),
      );
    }

    return _washBubbles(
      showerPosition,
    );
  }

  bool _washBubbles(
    Offset showerPosition,
  ) {
    _removeFinishedBubbles();

    final gameSize = _layoutSize;
    if (!_layoutReady || gameSize == null) {
      return false;
    }

    final catCenter = Vector2(
      gameSize.x / 2,
      gameSize.y / 2 + 30,
    );

    const waterOffsetX = 0.0;
    const waterOffsetY = 2.0;

    final waterX = showerPosition.dx + waterOffsetX;
    final waterTop = showerPosition.dy + waterOffsetY;
    final waterBottom = waterTop + 82;

    final catLeft = catCenter.x - 62;
    final catRight = catCenter.x + 62;
    final catTop = catCenter.y - 62;
    final catBottom = catCenter.y + 62;

    final waterTouchesCat = waterX + 16 >= catLeft &&
        waterX - 16 <= catRight &&
        waterBottom >= catTop &&
        waterTop <= catBottom;

    if (waterTouchesCat) {
      _catWashed = true;
      showWetCat();
    }

    // A bubble only fades while the water is actually passing over it.
    // Moving the shower away pauses the fade instead of letting bubbles
    // disappear by themselves.
    for (final bubble in soapBubbles) {
      final bubbleX = bubble.position.x;
      final bubbleY = bubble.position.y;

      final insideWater = bubbleX >= waterX - 16 &&
          bubbleX <= waterX + 16 &&
          bubbleY >= waterTop &&
          bubbleY <= waterBottom;

      bubble.setBeingWashed(insideWater);
    }

    return waterTouchesCat;
  }

  void stopShower() {
    _showerWater?.removeFromParent();
    _showerWater = null;

    // Releasing/moving away from the shower pauses bubble washing too.
    for (final bubble in soapBubbles) {
      bubble.setBeingWashed(false);
    }
  }

  // BLOWER

  void startBlower(
    Offset blowerPosition,
  ) {
    stopBlower();

    _dryProgress = 0.0;

    final direction = _blowerDirection(
      blowerPosition,
    );

    _blowerWind = BlowerWind(
      position: Vector2(
        blowerPosition.dx,
        blowerPosition.dy,
      ),
      direction: direction,
    );

    add(
      _blowerWind!,
    );
  }

  void moveBlower(
    Offset blowerPosition,
  ) {
    if (_blowerWind == null) {
      startBlower(
        blowerPosition,
      );
    }

    final direction = _blowerDirection(
      blowerPosition,
    );

    _blowerWind!.updatePosition(
      Vector2(
        blowerPosition.dx,
        blowerPosition.dy,
      ),
      direction,
    );

    _updateDrying(blowerPosition);
  }

  void _updateDrying(Offset blowerPosition) {
    if (cat == null || !_layoutReady || _layoutSize == null) {
      return;
    }

    final gameSize = _layoutSize!;
    final catCenter = Vector2(
      gameSize.x / 2,
      gameSize.y / 2 + 30,
    );
    final blowerCenter = Vector2(
      blowerPosition.dx,
      blowerPosition.dy,
    );

    // Only dry while the blower is being moved over the cat. Moving the tool
    // elsewhere must not silently clear the wet state.
    if (blowerCenter.distanceTo(catCenter) > 110) {
      return;
    }

    // Pointer move events can fire many times per second. A larger increment
    // made the wet pose disappear almost immediately on modern devices.
    // Require sustained blower movement over the cat before transitioning.
    _dryProgress += 0.0025;

    if (_dryProgress >= 1.0) {
      _dryProgress = 1.0;
      _isWet = false;
      _isShowingHappy = false;
      // Drying is the only action that clears the wet state. Return to the
      // normal idle animation only after the blower has stayed over the cat.
      cat!.animation = _currentIdleAnimation();
    }
  }

  int _blowerDirection(
    Offset blowerPosition,
  ) {
    final gameSize = _layoutSize;
    if (!_layoutReady || gameSize == null) {
      return 0;
    }

    final catCenterX = gameSize.x / 2;

    if (blowerPosition.dx > catCenterX) {
      return -1;
    }

    return 1;
  }

  void stopBlower() {
    _blowerWind?.removeFromParent();

    _blowerWind = null;
  }

  /// Stops transient grooming effects without changing the cat's saved state.
  /// This is used when a draggable tool is released or another tool starts,
  /// so water/wind can never remain active after the tool returns to its box.
  void stopTransientEffects() {
    stopShower();
    stopBlower();
  }
}

// SOAP BUBBLES

class DirtLayer extends PositionComponent {
  double opacity;
  bool heavy;
  double _washProgress = 0.0;
  double _time = 0;

  DirtLayer({
    required this.opacity,
    required this.heavy,
    required Vector2 position,
  }) : super(
          position: position,
          size: Vector2.all(96),
          anchor: Anchor.center,
        );

  void setAppearance({
    required double opacity,
    required bool heavy,
  }) {
    this.opacity = opacity.clamp(0.0, 1.0).toDouble();
    this.heavy = heavy;
  }

  void setWashProgress(double progress) {
    _washProgress = progress.clamp(0.0, 1.0).toDouble();
  }

  double _spotOpacity(double start, [double duration = 0.16]) {
    if (_washProgress <= start) return 1.0;
    final local = ((_washProgress - start) / duration).clamp(0.0, 1.0);
    // Smooth fade so each patch disappears gradually rather than all at once.
    final eased = local * local * (3.0 - 2.0 * local);
    return 1.0 - eased;
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (opacity <= 0) return;

    final sx = size.x / 96.0;
    final sy = size.y / 96.0;
    canvas.save();
    canvas.scale(sx, sy);

    final baseSpot = heavy ? const Color(0xD06A4027) : const Color(0xB05A3A2A);
    final baseSoft = heavy ? const Color(0xA05A3A2A) : const Color(0x7A5A3A2A);

    void oval(Offset center, double width, double height, double start) {
      final alpha = opacity * _spotOpacity(start);
      if (alpha <= 0) return;
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = baseSpot.withValues(alpha: alpha);
      canvas.drawOval(
        Rect.fromCenter(center: center, width: width, height: height),
        paint,
      );
    }

    void dot(Offset center, double radius, double start) {
      final alpha = opacity * _spotOpacity(start);
      if (alpha <= 0) return;
      final paint = Paint()
        ..style = PaintingStyle.fill
        ..color = baseSoft.withValues(alpha: alpha);
      canvas.drawCircle(center, radius, paint);
    }

    // Dirt patches wash away in separate small stages, like real soap/water
    // moving over the fur. The patches overlap slightly so the cat never
    // jumps from fully dirty to fully clean in one frame.
    oval(const Offset(27, 66), heavy ? 21 : 18, heavy ? 12 : 9, 0.05);
    oval(const Offset(66, 68), heavy ? 20 : 16, heavy ? 11 : 8, 0.22);
    oval(const Offset(48, 78), heavy ? 24 : 20, heavy ? 11 : 8, 0.40);

    const dots = [
      Offset(20, 54),
      Offset(73, 53),
      Offset(38, 60),
      Offset(57, 58),
      Offset(32, 82),
      Offset(69, 79),
    ];
    const dotStarts = [0.14, 0.30, 0.48, 0.62, 0.74, 0.86];
    for (var i = 0; i < dots.length; i++) {
      dot(dots[i], heavy ? 4.5 : 3.5, dotStarts[i]);
    }

    if (heavy) {
      dot(const Offset(24, 76), 3.8, 0.58);
      dot(const Offset(75, 75), 3.5, 0.70);

      final flyOpacity = opacity * _spotOpacity(0.78);
      if (flyOpacity <= 0) return;

      final flyT = _time * math.pi * 1.6;
      final flyCenter = Offset(
        62 + math.sin(flyT) * 28,
        18 + math.sin(flyT * 1.8) * 12,
      );
      final wing = Paint()
        ..color = const Color(0xB06E7E86).withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      final flyBody = Paint()
        ..color = const Color(0xFF202020).withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      canvas.drawOval(
        Rect.fromCenter(
          center: flyCenter.translate(-3.0, -1.0),
          width: 9,
          height: 5,
        ),
        wing,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: flyCenter.translate(3.0, -1.0),
          width: 9,
          height: 5,
        ),
        wing,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: flyCenter,
          width: 5,
          height: 10,
        ),
        flyBody,
      );
    }

    canvas.restore();
  }
}

class SoapBubble extends PositionComponent {
  final double radius;
  final double drift;

  // Each bubble has its own wash timing. This makes soap disappear in
  // small portions instead of every bubble vanishing together when water
  // touches the soap layer.
  final double _washDelay;
  final double _washDuration;

  double _time = 0;
  double _washTime = 0;
  double _opacity = 0.9;
  bool _beingWashed = false;

  bool get isFaded => _opacity <= 0;

  SoapBubble({
    required Vector2 position,
    required this.radius,
    required this.drift,
  })  : _washDelay = 0.10 + math.Random().nextDouble() * 0.85,
        _washDuration = 0.75 + math.Random().nextDouble() * 1.10,
        super(
          position: position,
          anchor: Anchor.center,
        );

  void startFade() {
    _beingWashed = true;
  }

  void setBeingWashed(bool value) {
    _beingWashed = value;
  }

  @override
  void update(
    double dt,
  ) {
    super.update(dt);

    _time += dt;

    position.x += math.sin(_time * 2) * drift * dt;

    if (_beingWashed && !isFaded) {
      _washTime += dt;

      if (_washTime > _washDelay) {
        final progress =
            ((_washTime - _washDelay) / _washDuration).clamp(0.0, 1.0);

        // Smooth individual-bubble fade. Different bubbles have different
        // delays/durations, so the soap layer is washed away progressively.
        final eased = progress * progress * (3.0 - 2.0 * progress);
        _opacity = 0.9 * (1.0 - eased);

        if (_opacity <= 0.01) {
          _opacity = 0;
          removeFromParent();
        }
      }
    }
  }

  @override
  void render(
    Canvas canvas,
  ) {
    super.render(canvas);

    final paint = Paint()
      ..color = Colors.white.withValues(
        alpha: _opacity * 0.9,
      );

    canvas.drawCircle(
      Offset.zero,
      radius,
      paint,
    );

    final highlightPaint = Paint()
      ..color = Colors.white.withValues(
        alpha: _opacity,
      );

    canvas.drawCircle(
      Offset(
        -radius * 0.3,
        -radius * 0.3,
      ),
      radius * 0.22,
      highlightPaint,
    );
  }
}

// HAPPY HEARTS

class HappyEffect extends PositionComponent {
  double _time = 0;

  HappyEffect({
    required Vector2 position,
  }) : super(
          position: position,
          anchor: Anchor.center,
        );

  @override
  void update(
    double dt,
  ) {
    super.update(dt);

    _time += dt;

    if (_time >= 0.9) {
      removeFromParent();
    }
  }

  @override
  void render(
    Canvas canvas,
  ) {
    super.render(canvas);

    final opacity = (1 - (_time / 0.9)).clamp(
      0.0,
      1.0,
    );

    _drawHeart(
      canvas,
      Offset(
        -18,
        -35 - (_time * 15),
      ),
      20,
      opacity,
    );

    _drawHeart(
      canvas,
      Offset(
        18,
        -28 - (_time * 12),
      ),
      16,
      opacity,
    );
  }

  void _drawHeart(
    Canvas canvas,
    Offset position,
    double size,
    double opacity,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: '♥',
        style: TextStyle(
          fontSize: size,
          color: Colors.pink.withValues(
            alpha: opacity,
          ),
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    textPainter.paint(
      canvas,
      position,
    );
  }
}

// SHOWER WATER

class ShowerWater extends Component {
  Vector2 _showerPosition;

  double _time = 0;

  ShowerWater({
    required Vector2 showerPosition,
  }) : _showerPosition = showerPosition.clone();

  void updatePosition(
    Vector2 showerPosition,
  ) {
    _showerPosition = showerPosition.clone();
  }

  @override
  void update(
    double dt,
  ) {
    super.update(dt);

    _time += dt;
  }

  @override
  void render(
    Canvas canvas,
  ) {
    super.render(canvas);

    const nozzleXOffset = 5.0;
    const nozzleYOffset = 1.0;

    final x = _showerPosition.x + nozzleXOffset;

    final y = _showerPosition.y + nozzleYOffset;

    const waterLength = 82.0;
    const topWidth = 16.0;
    const bottomWidth = 22.0;

    final waterBody = Path()
      ..moveTo(
        x - topWidth / 2,
        y,
      )
      ..lineTo(
        x + topWidth / 2,
        y,
      )
      ..lineTo(
        x + bottomWidth / 2,
        y + waterLength,
      )
      ..lineTo(
        x - bottomWidth / 2,
        y + waterLength,
      )
      ..close();

    final bodyPaint = Paint()
      ..color = Colors.lightBlueAccent.withValues(
        alpha: 0.10,
      )
      ..style = PaintingStyle.fill;

    canvas.drawPath(
      waterBody,
      bodyPaint,
    );

    for (int i = 0; i < 8; i++) {
      final startX = x - topWidth / 2 + (topWidth / 7) * i;

      final endX = x - bottomWidth / 2 + (bottomWidth / 7) * i;

      final path = Path();

      path.moveTo(
        startX,
        y,
      );

      for (int j = 1; j <= 24; j++) {
        final progress = j / 24;

        final flow = math.sin(
              _time * 9 + i * 0.55 + progress * 3,
            ) *
            0.45;

        final currentX = startX + (endX - startX) * progress + flow;

        final currentY = y + waterLength * progress;

        path.lineTo(
          currentX,
          currentY,
        );
      }

      final streamPaint = Paint()
        ..color = Colors.lightBlueAccent.withValues(
          alpha: 0.68,
        )
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawPath(
        path,
        streamPaint,
      );
    }

    for (int i = 0; i < 5; i++) {
      final progress = (_time * 1.4 + i * 0.18) % 1.0;

      final highlightX = x - bottomWidth / 2 + bottomWidth * (i / 4);

      final highlightY = y + waterLength * progress;

      final highlightPaint = Paint()
        ..color = Colors.white.withValues(
          alpha: 0.65,
        )
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(
        Offset(
          highlightX,
          highlightY,
        ),
        Offset(
          highlightX,
          highlightY + 7,
        ),
        highlightPaint,
      );
    }

    final floorY = y + waterLength;

    final splashPaint = Paint()
      ..color = Colors.lightBlueAccent.withValues(
        alpha: 0.45,
      )
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i < 5; i++) {
      final splashX = x - 9 + i * 4.5;

      final splashHeight = 2 +
          math
                  .sin(
                    _time * 5 + i,
                  )
                  .abs() *
              3;

      canvas.drawLine(
        Offset(
          splashX,
          floorY,
        ),
        Offset(
          splashX,
          floorY - splashHeight,
        ),
        splashPaint,
      );
    }
  }
}

// BLOWER WIND

class BlowerWind extends Component {
  Vector2 _position;
  int _direction;

  double _time = 0;

  BlowerWind({
    required Vector2 position,
    required int direction,
  })  : _position = position.clone(),
        _direction = direction;

  void updatePosition(
    Vector2 position,
    int direction,
  ) {
    _position = position.clone();

    _direction = direction;
  }

  @override
  void update(
    double dt,
  ) {
    super.update(dt);

    _time += dt;
  }

  @override
  void render(
    Canvas canvas,
  ) {
    super.render(canvas);

    canvas.save();

    canvas.translate(
      _position.x,
      _position.y,
    );

    // Keep blower wind distance.
    const nozzleDistance = 10.0;

    // Keep wind slightly upward.
    const windYOffset = -9.0;

    const nozzleWidth = 5.0;
    const endWidth = 15.0;
    const windLength = 42.0;

    for (int i = 0; i < 4; i++) {
      final startProgress = i / 3;

      final startY =
          -nozzleWidth / 2 + nozzleWidth * startProgress + windYOffset;

      final endY = -endWidth / 2 + endWidth * startProgress + windYOffset;

      final path = Path();

      path.moveTo(
        _direction * nozzleDistance,
        startY,
      );

      for (int j = 1; j <= 20; j++) {
        final progress = j / 20;

        final currentX = _direction * (nozzleDistance + windLength * progress);

        final baseY = startY + (endY - startY) * progress;

        final movement = math.sin(
              _time * 8 + i * 0.8 + progress * 5,
            ) *
            1.2;

        final currentY = baseY + movement;

        path.lineTo(
          currentX,
          currentY,
        );
      }

      final paint = Paint()
        ..color = Colors.white.withValues(
          alpha: 0.55,
        )
        ..strokeWidth = 1.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawPath(
        path,
        paint,
      );
    }

    // Moving air particles.

    for (int i = 0; i < 5; i++) {
      final progress = (_time * 1.5 + i * 0.2) % 1.0;

      final x = _direction * (nozzleDistance + windLength * progress);

      final y = math.sin(
                _time * 7 + i,
              ) *
              4 +
          windYOffset;

      final particlePaint = Paint()
        ..color = Colors.white.withValues(
          alpha: 0.45,
        );

      canvas.drawCircle(
        Offset(
          x,
          y,
        ),
        1.2,
        particlePaint,
      );
    }

    canvas.restore();
  }
}
