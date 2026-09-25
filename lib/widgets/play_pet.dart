import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

  static const Map<String, String> _toyFolders = {
    'Yarn Ball': 'yarn_cat',
    'Tennis Ball': 'tennis_ball_cat',
    'Laser Dot': 'laser_cat',
    'Feather': 'feather_cat',
  };

  static const Map<String, int> _toyFrameCounts = {
    'Yarn Ball': yarnFrames,
    'Tennis Ball': tennisFrames,
    'Laser Dot': laserFrames,
    'Feather': featherFrames,
  };

  // Source PNGs are 832x1120 — far larger than this widget's ~110px
  // display height. Decoding all four ~300-frame toy sequences plus idle
  // at full resolution would blow well past Flutter's default 100MB
  // image-cache budget, causing ongoing eviction/re-decode stutter rather
  // than a one-time hitch. cacheHeight downsamples at decode time instead.
  int get _cacheHeight => (widget.height * 3).round();

  final List<Image> _idleImages = [];
  final Map<String, List<Image>> _toyImages = {};
  Image? _dirtyImage;

  bool _loaded = false;

  int _idleFrame = 0;
  int _playFrame = 0;

  int _idleTick = 0;

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _loadFrames();
  }

  Future<void> _loadFrames() async {
    try {
      for (var i = 1; i <= idleFrames; i++) {
        _idleImages.add(await _loadFrame(
          'assets/images/idle/frame_${i.toString().padLeft(4, '0')}.png',
        ));
      }

      for (final toy in _toyFolders.keys) {
        final folder = _toyFolders[toy]!;
        final count = _toyFrameCounts[toy]!;
        final frames = <Image>[];

        for (var i = 1; i <= count; i++) {
          frames.add(await _loadFrame(
            'assets/images/play_cat/$folder/frame_${i.toString().padLeft(4, '0')}.png',
          ));
        }

        _toyImages[toy] = frames;
      }

      _dirtyImage = await _loadFrame('assets/images/states/dirty_cat.png');

      if (!mounted) return;

      setState(() {
        _loaded = true;
      });

      _timer = Timer.periodic(
        const Duration(milliseconds: 16),
        (_) {
          if (!mounted || !_loaded) return;

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
    } catch (error) {
      debugPrint('Failed to load play cat frames: $error');
    }
  }

  Future<Image> _loadFrame(String assetPath) async {
    final bytes = await rootBundle.load(assetPath);

    return Image.memory(
      bytes.buffer.asUint8List(),
      cacheHeight: _cacheHeight,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.none,
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

    return _toyFrameCounts[widget.toy] ?? idleFrames;
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return SizedBox(
        height: widget.height,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final Image frame;

    if (widget.isDirty) {
      frame = _dirtyImage!;
    } else if (widget.isPlaying) {
      final toyFrames = _toyImages[widget.toy];
      frame = (toyFrames != null && _playFrame < toyFrames.length)
          ? toyFrames[_playFrame]
          : _idleImages[_idleFrame % _idleImages.length];
    } else {
      frame = _idleImages[_idleFrame];
    }

    return SizedBox(
      height: widget.height,
      child: frame,
    );
  }
}
