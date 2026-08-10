import 'dart:async';
import 'package:flutter/material.dart';

class PlayPet extends StatefulWidget {
  const PlayPet({
    super.key,
    required this.isPlaying,
    required this.toy,
    required this.isDirty,
    this.height = 110,
  });

  final bool isDirty;
  final bool isPlaying;
  final String? toy;
  final double height;

  @override
  State<PlayPet> createState() => _PlayPetState();
}

class _PlayPetState extends State<PlayPet> {
  static const int idleFrames = 120;

  static const int yarnFrames = 302;
  static const int tennisFrames = 301;
  static const int laserFrames = 302;
  static const int featherFrames = 302;

  int _idleFrame = 0;
  int _playFrame = 0;

  int _idleTick = 0;

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _timer = Timer.periodic(
      const Duration(milliseconds: 16),
      (_) {
        if (!mounted) return;

        // Dirty cat does not animate
        if (widget.isDirty) {
          return;
        }

        setState(() {
          if (widget.isPlaying) {
            _playFrame++;

            if (_playFrame >= _getMaxFrame()) {
              _playFrame = 0;
            }
          } else {
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
  void didUpdateWidget(covariant PlayPet oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Reset animation when dirty state changes
    if (oldWidget.isDirty != widget.isDirty) {
      _playFrame = 0;
      _idleFrame = 0;
    }

    if (oldWidget.isPlaying != widget.isPlaying) {
      if (widget.isPlaying) {
        _playFrame = 0;
      } else {
        _idleFrame = 0;
      }
    }

    if (oldWidget.toy != widget.toy) {
      _playFrame = 0;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();

    super.dispose();
  }

  int _getMaxFrame() {
    if (!widget.isPlaying) {
      return idleFrames;
    }

    switch (widget.toy) {
      case 'Yarn Ball':
        return yarnFrames;

      case 'Tennis Ball':
        return tennisFrames;

      case 'Laser Dot':
        return laserFrames;

      case 'Feather':
        return featherFrames;

      default:
        return idleFrames;
    }
  }

  String _getImagePath() {
    // ============================
    // DIRTY HAS HIGHEST PRIORITY
    // ============================

    if (widget.isDirty) {
      return 'assets/images/states/dirty_cat.png';
    }

    // ============================
    // IDLE
    // ============================

    if (!widget.isPlaying) {
      return 'assets/images/idle/frame_${(_idleFrame + 1).toString().padLeft(4, '0')}.png';
    }

    // ============================
    // PLAY ANIMATIONS
    // ============================

    switch (widget.toy) {
      case 'Yarn Ball':
        return 'assets/images/play_cat/yarn_cat/frame_${(_playFrame + 1).toString().padLeft(4, '0')}.png';

      case 'Tennis Ball':
        return 'assets/images/play_cat/tennis_ball_cat/frame_${(_playFrame + 1).toString().padLeft(4, '0')}.png';

      case 'Laser Dot':
        return 'assets/images/play_cat/laser_cat/frame_${(_playFrame + 1).toString().padLeft(4, '0')}.png';

      case 'Feather':
        return 'assets/images/play_cat/feather_cat/frame_${(_playFrame + 1).toString().padLeft(4, '0')}.png';

      default:
        return 'assets/images/idle/frame_0001.png';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _getImagePath(),
      height: widget.height,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.none,
    );
  }
}
