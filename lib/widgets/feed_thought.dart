import 'package:flutter/material.dart';

import 'pet_action_thought.dart';

/// Feed-screen API retained for compatibility; visuals come from the shared widget.
class FeedThought extends StatelessWidget {
  final String emoji;
  final String text;

  const FeedThought({
    super.key,
    required this.emoji,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return PetActionThought(emoji: emoji, text: text);
  }
}
