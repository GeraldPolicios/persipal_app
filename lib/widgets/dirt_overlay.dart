import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Visual dirt that sits above the existing cat artwork.
///
/// Regular dirt is light/cute. Neglected dirt is heavier and includes a
/// continuously moving fly. The widget never changes the cat artwork.
class DirtOverlay extends StatefulWidget {
  final double size;
  final bool showFly;
  final bool heavy;
  final double opacity;

  const DirtOverlay({
    super.key,
    this.size = 96,
    this.showFly = false,
    this.heavy = false,
    this.opacity = 1.0,
  });

  @override
  State<DirtOverlay> createState() => _DirtOverlayState();
}

class _DirtOverlayState extends State<DirtOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flyController;

  @override
  void initState() {
    super.initState();
    _flyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    );
    if (widget.showFly) {
      _flyController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant DirtOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showFly && !oldWidget.showFly) {
      _flyController.repeat();
    } else if (!widget.showFly && oldWidget.showFly) {
      _flyController.stop();
    }
  }

  @override
  void dispose() {
    _flyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final opacity = widget.opacity.clamp(0.0, 1.0).toDouble();

    return IgnorePointer(
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: opacity,
                child: CustomPaint(
                  painter: _DirtPainter(heavy: widget.heavy),
                ),
              ),
            ),
            if (widget.showFly)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _flyController,
                  builder: (context, child) {
                    final t = _flyController.value * math.pi * 2;
                    final dx = math.sin(t) * widget.size * 0.16;
                    final dy = math.sin(t * 2.0) * widget.size * 0.10;
                    return Transform.translate(
                      offset: Offset(
                        widget.size * 0.56 + dx,
                        widget.size * 0.10 + dy,
                      ),
                      child: child,
                    );
                  },
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: _FlyBadge(size: widget.size * 0.12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FlyBadge extends StatelessWidget {
  final double size;

  const _FlyBadge({required this.size});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.45,
      height: size * 1.45,
      child: CustomPaint(
        painter: _FlyPainter(),
      ),
    );
  }
}

class _DirtPainter extends CustomPainter {
  final bool heavy;

  const _DirtPainter({required this.heavy});

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 96.0;
    final sy = size.height / 96.0;

    canvas.save();
    canvas.scale(sx, sy);

    final spot = Paint()..style = PaintingStyle.fill;
    final soft = Paint()..style = PaintingStyle.fill;

    // These patches deliberately stay away from the eyes and mouth.
    spot.color = heavy ? const Color(0xE06A4027) : const Color(0xC05A3A2A);

    final patches = <(Offset, double, double)>[
      (const Offset(27, 66), heavy ? 21 : 18, heavy ? 12 : 9),
      (const Offset(66, 68), heavy ? 20 : 16, heavy ? 11 : 8),
      (const Offset(48, 78), heavy ? 24 : 20, heavy ? 11 : 8),
    ];

    for (final patch in patches) {
      canvas.drawOval(
        Rect.fromCenter(
          center: patch.$1,
          width: patch.$2,
          height: patch.$3,
        ),
        spot,
      );
    }

    soft.color = heavy ? const Color(0xA85A3A2A) : const Color(0x955A3A2A);

    final dots = <(Offset, double)>[
      (const Offset(20, 54), 5),
      (const Offset(73, 53), 4.5),
      (const Offset(38, 60), 3.5),
      (const Offset(57, 58), 4),
      (const Offset(32, 82), 3.2),
      (const Offset(69, 79), 3.1),
      (const Offset(14, 70), 1.8),
      (const Offset(81, 70), 2.0),
      (const Offset(58, 86), 1.7),
    ];

    for (final dot in dots) {
      canvas.drawCircle(dot.$1, dot.$2, soft);
    }

    if (heavy) {
      soft.color = const Color(0xB06A4027);
      canvas.drawCircle(const Offset(24, 76), 3.8, soft);
      canvas.drawCircle(const Offset(75, 75), 3.5, soft);
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(52, 63),
          width: 13,
          height: 6,
        ),
        soft,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DirtPainter oldDelegate) =>
      oldDelegate.heavy != heavy;
}

class _FlyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);

    final wing = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xB06E7E86);
    final body = Paint()
      ..style = PaintingStyle.fill
      ..color = const Color(0xFF202020);
    final leg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF202020);

    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(-size.width * 0.22, -size.height * 0.12),
        width: size.width * 0.60,
        height: size.height * 0.38,
      ),
      wing,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(size.width * 0.22, -size.height * 0.12),
        width: size.width * 0.60,
        height: size.height * 0.38,
      ),
      wing,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(0, size.height * 0.06),
        width: size.width * 0.28,
        height: size.height * 0.52,
      ),
      body,
    );

    canvas.drawLine(
      c.translate(-size.width * 0.10, size.height * 0.17),
      c.translate(-size.width * 0.38, size.height * 0.34),
      leg,
    );
    canvas.drawLine(
      c.translate(size.width * 0.10, size.height * 0.17),
      c.translate(size.width * 0.38, size.height * 0.34),
      leg,
    );
  }

  @override
  bool shouldRepaint(covariant _FlyPainter oldDelegate) => false;
}
