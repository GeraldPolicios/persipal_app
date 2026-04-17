import 'package:flutter/material.dart';

class BounceButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const BounceButton({super.key, required this.child, required this.onTap});

  @override
  State<BounceButton> createState() => _BounceButtonState();
}

class _BounceButtonState extends State<BounceButton> {
  double scale = 1.0;

  void _down(TapDownDetails d) {
    setState(() => scale = 0.85);
  }

  void _up(TapUpDetails d) {
    Future.delayed(const Duration(milliseconds: 100), () {
      setState(() => scale = 1.0);
    });
  }

  void _cancel() {
    setState(() => scale = 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: _cancel,
      child: AnimatedScale(
        scale: scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
