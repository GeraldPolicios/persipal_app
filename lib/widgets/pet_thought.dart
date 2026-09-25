import 'package:flutter/material.dart';

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
    final cloud = SizedBox(
      width: 72,
      height: 62,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Left cloud
          Positioned(
            left: 5,
            top: 18,
            child: _cloudCircle(24),
          ),

          // Middle cloud
          Positioned(
            left: 22,
            top: 0,
            child: _cloudCircle(32),
          ),

          // Right cloud
          Positioned(
            right: 5,
            top: 18,
            child: _cloudCircle(24),
          ),

          // Bottom cloud
          Positioned(
            left: 20,
            top: 28,
            child: _cloudCircle(30),
          ),

          // Emoji
          const Positioned(
            left: 33,
            top: 25,
            child: SizedBox(),
          ),

          Positioned.fill(
            child: Center(
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          ),

          // Bubble Tail
          Positioned(
            left: 18,
            bottom: 6,
            child: _tailCircle(10),
          ),

          Positioned(
            left: 8,
            bottom: -4,
            child: _tailCircle(6),
          ),
        ],
      ),
    );

    if (text == null) return cloud;

    // Short "why" explanation — reuses the same small rounded-chip look
    // already used by FeedThought/PlayThought, just compact enough to sit
    // under the existing cloud bubble without a new popup/dialog.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        cloud,
        Container(
          constraints: const BoxConstraints(maxWidth: 130),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                blurRadius: 6,
                color: Colors.black.withValues(alpha: 0.12),
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            text!,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7A3B1E),
            ),
          ),
        ),
      ],
    );
  }

  Widget _cloudCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            blurRadius: 10,
            color: Colors.black.withOpacity(.12),
            offset: const Offset(0, 3),
          ),
        ],
      ),
    );
  }

  Widget _tailCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            blurRadius: 6,
            color: Colors.black.withOpacity(.08),
          ),
        ],
      ),
    );
  }
}
