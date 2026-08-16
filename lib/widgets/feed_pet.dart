import 'dart:async';
import 'package:flutter/material.dart';

class FeedPet extends StatefulWidget {
  const FeedPet({
    super.key,
    required this.isEating,
    required this.isDirty,
    this.height = 130,
  });

  final bool isDirty;
  final bool isEating;
  final double height;

  @override
  State<FeedPet> createState() => _FeedPetState();
}

class _FeedPetState extends State<FeedPet> {
  static const int idleFrames = 120;
  static const int eatingFrames = 302;

  int _idleFrame = 0;
  int _eatingFrame = 0;

  int _idleTick = 0;

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) {
        if (!mounted) return;

        // Stop all animations when dirty
        if (widget.isDirty) {
          return;
        }

        setState(() {
          if (widget.isEating) {
            // Eating animation: ~60 FPS
            _eatingFrame++;

            if (_eatingFrame >= eatingFrames) {
              _eatingFrame = 0;
            }
          } else {
            // Idle animation: slower
            // Advance only every 3 timer ticks
            _idleTick++;

            if (_idleTick >= 3) {
              _idleTick = 0;
              _idleFrame++;

              if (_idleFrame >= idleFrames) {
                _idleFrame = 0;
              }
            }
          }
        });
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FeedPet oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Dirty state changed
    if (oldWidget.isDirty != widget.isDirty) {
      _idleFrame = 0;
      _eatingFrame = 0;
    }

    // Eating state changed
    if (oldWidget.isEating != widget.isEating) {
      if (widget.isEating) {
        _eatingFrame = 0;
      } else {
        _idleFrame = 0;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String imagePath;

    if (widget.isDirty) {
      imagePath = 'assets/images/states/dirty_cat.png';
    } else if (widget.isEating) {
      imagePath =
          'assets/images/eating_cat/frame_${(_eatingFrame + 1).toString().padLeft(4, '0')}.png';
    } else {
      imagePath =
          'assets/images/idle/frame_${(_idleFrame + 1).toString().padLeft(4, '0')}.png';
    }

    return Image.asset(
      imagePath,
      height: widget.height,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
    );
  }
}
