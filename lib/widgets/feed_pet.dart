import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FeedPet extends StatefulWidget {
  const FeedPet({
    super.key,
    required this.isEating,
    required this.isDirty,
    this.isBadFood = false,
    this.height = 130,
  });

  final bool isDirty;
  final bool isEating;

  /// True while the food currently being eaten is an incorrect/inappropriate
  /// one (e.g. Milk, per R4). Swaps the eating animation for a short,
  /// lazily-loaded "sad" reaction instead of the normal happy eating loop —
  /// see _loadSadFrames() below.
  final bool isBadFood;

  final double height;

  @override
  State<FeedPet> createState() => _FeedPetState();
}

class _FeedPetState extends State<FeedPet> {
  static const int idleFrames = 120;
  static const int eatingFrames = 302;

  // Short prefix of the 121-frame sad_cat/ sequence — enough to read as a
  // distinct "uncomfortable" reaction without eagerly paying the decode/
  // memory cost of the full sequence (see the earlier PlayPet memory
  // review) for a reaction most sessions will never trigger.
  static const int sadFrames = 40;

  // Source PNGs are 832x1120 — far larger than this widget's ~100px
  // display height. Decoding them at full resolution would blow well past
  // Flutter's default 100MB image-cache budget across 400+ frames, causing
  // ongoing eviction/re-decode stutter rather than a one-time hitch.
  // cacheHeight tells the decoder to downsample at decode time instead.
  int get _cacheHeight => (widget.height * 3).round();

  final List<Image> _idleImages = [];
  final List<Image> _eatingImages = [];
  final List<Image> _sadImages = [];
  Image? _dirtyImage;

  bool _loaded = false;

  // Loaded lazily — only once Milk is actually dropped in the bowl, not
  // during normal FeedScreen init (see didUpdateWidget/_loadSadFrames).
  bool _sadLoaded = false;
  bool _sadLoading = false;

  int _idleFrame = 0;
  int _eatingFrame = 0;
  int _sadFrame = 0;

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

      for (var i = 1; i <= eatingFrames; i++) {
        _eatingImages.add(await _loadFrame(
          'assets/images/eating_cat/frame_${i.toString().padLeft(4, '0')}.png',
        ));
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

          // Stop all animations when dirty
          if (widget.isDirty) {
            return;
          }

          setState(() {
            if (widget.isEating && widget.isBadFood && _sadLoaded) {
              _sadFrame++;

              if (_sadFrame >= _sadImages.length) {
                _sadFrame = 0;
              }
            } else if (widget.isEating) {
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
    } catch (error) {
      debugPrint('Failed to load feed cat frames: $error');
    }
  }

  // Lazy — only called the first time Milk is actually dropped (see
  // didUpdateWidget), not during initState's normal frame load.
  Future<void> _loadSadFrames() async {
    if (_sadLoaded || _sadLoading) return;
    _sadLoading = true;

    try {
      for (var i = 1; i <= sadFrames; i++) {
        _sadImages.add(await _loadFrame(
          'assets/images/sad_cat/sad_${i.toString().padLeft(4, '0')}.png',
        ));
      }

      if (!mounted) return;

      setState(() {
        _sadLoaded = true;
      });
    } catch (error) {
      debugPrint('Failed to load sad-reaction cat frames: $error');
    }
  }

  Future<Image> _loadFrame(String assetPath) async {
    final bytes = await rootBundle.load(assetPath);

    return Image.memory(
      bytes.buffer.asUint8List(),
      cacheHeight: _cacheHeight,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
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
        _sadFrame = 0;
      } else {
        _idleFrame = 0;
      }
    }

    // Milk (or any other bad-food reaction) just started — lazily load the
    // sad frames now rather than during normal init. A no-op once already
    // loaded/loading, and safe to call every rebuild until it succeeds.
    if (widget.isEating && widget.isBadFood && !_sadLoaded && !_sadLoading) {
      _loadSadFrames();
    }
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
    } else if (widget.isEating && widget.isBadFood && _sadLoaded) {
      frame = _sadImages[_sadFrame];
    } else if (widget.isEating && widget.isBadFood) {
      // Sad frames still loading (lazy) — hold on idle rather than the
      // wrong (happy) eating clip until the reaction is actually ready.
      frame = _idleImages[_idleFrame];
    } else if (widget.isEating) {
      frame = _eatingImages[_eatingFrame];
    } else {
      frame = _idleImages[_idleFrame];
    }

    return SizedBox(
      height: widget.height,
      child: frame,
    );
  }
}
