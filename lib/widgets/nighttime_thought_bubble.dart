import 'package:flutter/material.dart';

/// Compact nighttime thought bubble anchored on the LEFT side of the cat.
class NighttimeThoughtBubble extends StatelessWidget {
  final String text;

  const NighttimeThoughtBubble({super.key, required this.text});

  static const _fill = Color(0xFFFFFBF5);
  static const _edge = Color(0xFFE9D1BE);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 20,
      left: -80,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 165),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              margin: const EdgeInsets.only(left: 4, right: 9, bottom: 9),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: _fill,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: _edge, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFE8D8),
                      shape: BoxShape.circle,
                    ),
                    child: const Text('🐱', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      softWrap: true,
                      overflow: TextOverflow.visible,
                      style: const TextStyle(
                        fontSize: 10.5,
                        height: 1.12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF633C2C),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // A small, visible speech tail points from the bubble toward the cat.
            const Positioned(
              right: 1,
              bottom: 8,
              child: CustomPaint(
                size: Size(14, 14),
                painter: _BubbleTailPainter(fill: _fill, edge: _edge),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BubbleTailPainter extends CustomPainter {
  final Color fill;
  final Color edge;
  const _BubbleTailPainter({required this.fill, required this.edge});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(1, 1)
      ..quadraticBezierTo(4, 8, size.width - 1, size.height - 1)
      ..quadraticBezierTo(size.width - 4, 5, 1, 1)
      ..close();
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = edge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _BubbleTailPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.edge != edge;
}
