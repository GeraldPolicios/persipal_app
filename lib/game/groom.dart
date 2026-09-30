import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

class GroomGame extends FlameGame {
  SpriteAnimationComponent? cat;

  late SpriteAnimation idleAnimation;
  late SpriteAnimation wetAnimation;
  late SpriteAnimation happyAnimation;

  final Random _random = Random();

  final List<SoapBubble> soapBubbles = [];

  ShowerWater? _showerWater;
  BlowerWind? _blowerWind;

  bool _catWashed = false;
  bool _isWet = false;
  bool _isShowingHappy = false;

  double _dryProgress = 0.0;

  bool get catWashed => _catWashed;

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

    cat = SpriteAnimationComponent(
      animation: idleAnimation,
      size: Vector2(120, 120),
      paint: Paint()..filterQuality = FilterQuality.none,
    );

    cat!.anchor = Anchor.center;

    cat!.position = Vector2(
      size.x / 2,
      size.y / 2 + 15,
    );

    add(cat!);
  }

  @override
  void onGameResize(
    Vector2 canvasSize,
  ) {
    super.onGameResize(
      canvasSize,
    );

    if (cat != null) {
      cat!.position = Vector2(
        canvasSize.x / 2,
        canvasSize.y / 2 + 15,
      );
    }
  }

  // WET CAT

  void showWetCat() {
    if (cat == null) {
      return;
    }

    _isWet = true;
    _dryProgress = 0.0;

    if (!_isShowingHappy) {
      cat!.animation = wetAnimation;
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
        cat!.animation = wetAnimation;
      } else {
        cat!.animation = idleAnimation;
      }
    }

    _isShowingHappy = false;
  }

  // TOWEL

  void towelSwipe(
    Offset towelPosition,
  ) {
    final catCenter = Vector2(
      size.x / 2,
      size.y / 2 + 15,
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
    if (size.x <= 16 || size.y <= 16) {
      return;
    }

    final maxX = max(
      8.0,
      size.x - 8.0,
    );

    final maxY = max(
      8.0,
      size.y - 8.0,
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
    for (final bubble in soapBubbles) {
      bubble.removeFromParent();
    }

    soapBubbles.clear();
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

  void moveShower(
    Offset showerPosition,
  ) {
    if (_showerWater == null) {
      startShower(
        showerPosition,
      );

      return;
    }

    _showerWater!.updatePosition(
      Vector2(
        showerPosition.dx,
        showerPosition.dy,
      ),
    );

    _washBubbles(
      showerPosition,
    );
  }

  void _washBubbles(
    Offset showerPosition,
  ) {
    final catCenter = Vector2(
      size.x / 2,
      size.y / 2 + 15,
    );

    const waterOffsetX = 0.0;
    const waterOffsetY = 2.0;

    final waterX = showerPosition.dx + waterOffsetX;

    final waterTop = showerPosition.dy + waterOffsetY;

    final waterBottom = waterTop + 82;

    final catLeft = catCenter.x - 60;

    final catRight = catCenter.x + 60;

    final catTop = catCenter.y - 60;

    final catBottom = catCenter.y + 60;

    final waterTouchesCat = waterX + 14 >= catLeft &&
        waterX - 14 <= catRight &&
        waterBottom >= catTop &&
        waterTop <= catBottom;

    if (waterTouchesCat) {
      _catWashed = true;

      showWetCat();
    }

    for (final bubble in soapBubbles) {
      final bubbleX = bubble.position.x;
      final bubbleY = bubble.position.y;

      final insideWater = bubbleX >= waterX - 14 &&
          bubbleX <= waterX + 14 &&
          bubbleY >= waterTop &&
          bubbleY <= waterBottom;

      if (insideWater) {
        bubble.startFade();
      }
    }
  }

  void stopShower() {
    _showerWater?.removeFromParent();

    _showerWater = null;
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

    _updateDrying();
  }

  void _updateDrying() {
    if (cat == null) {
      return;
    }

    _dryProgress += 0.008;

    if (_dryProgress >= 1.0) {
      _dryProgress = 1.0;

      _isWet = false;

      cat!.animation = idleAnimation;
    }
  }

  int _blowerDirection(
    Offset blowerPosition,
  ) {
    final catCenterX = size.x / 2;

    if (blowerPosition.dx > catCenterX) {
      return -1;
    }

    return 1;
  }

  void stopBlower() {
    _blowerWind?.removeFromParent();

    _blowerWind = null;
  }
}

// SOAP BUBBLES

class SoapBubble extends PositionComponent {
  final double radius;
  final double drift;

  double _time = 0;
  double _opacity = 0.9;
  bool _fading = false;

  SoapBubble({
    required Vector2 position,
    required this.radius,
    required this.drift,
  }) : super(
          position: position,
          anchor: Anchor.center,
        );

  void startFade() {
    _fading = true;
  }

  @override
  void update(
    double dt,
  ) {
    super.update(dt);

    _time += dt;

    position.x += sin(_time * 2) * drift * dt;

    if (_fading) {
      _opacity -= dt * 0.55;

      if (_opacity <= 0) {
        _opacity = 0;

        removeFromParent();
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

        final flow = sin(
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
          sin(
                _time * 5 + i,
              ).abs() *
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

        final movement = sin(
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

      final y = sin(
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
