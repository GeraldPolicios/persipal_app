import 'package:flutter/material.dart';

import 'pet_action_thought.dart';

/// Game-screen thought bubble. A null text means show only the thought emoji.
class PetThought extends StatelessWidget {
  final String emoji;
  final String? text;

  const PetThought({
    super.key,
    required this.emoji,
    this.text,
  });

  @override
  Widget build(BuildContext context) {
    if (text != null && text!.trim().isNotEmpty) {
      return PetActionThought(emoji: emoji, text: text!);
    }

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 350),
      tween: Tween(begin: 0.9, end: 1.0),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 22)),
          ),
          CustomPaint(
            size: const Size(14, 8),
            painter: _PetThoughtTail(),
          ),
        ],
      ),
    );
  }
}

/// Play-screen API retained for compatibility; visuals come from the shared widget.
class PlayThought extends StatelessWidget {
  final String emoji;
  final String text;

  const PlayThought({
    super.key,
    required this.emoji,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return PetActionThought(emoji: emoji, text: text);
  }
}

class _PetThoughtTail extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
