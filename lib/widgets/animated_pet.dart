import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/pet_state.dart';

class AnimatedPet extends StatefulWidget {
  const AnimatedPet({
    super.key,
    required this.state,
    required this.furStage,
    required this.isDirty,
    this.height = 120,
  });

  final PetState state;

  final bool isDirty;
  // Keep this for now because GameScreen still sends it.
  // We will use it later for the separate fur PNG layer.
  final int furStage;

  final double height;

  @override
  State<AnimatedPet> createState() => _AnimatedPetState();
}

class _AnimatedPetState extends State<AnimatedPet> {
  static const int idleFrames = 120;

  final List<Image> _idleFrames = [];

  int _currentFrame = 0;

  bool _loaded = false;

  Timer? _animationTimer;

  @override
  void initState() {
    super.initState();

    _loadIdleFrames();
  }

  Future<void> _loadIdleFrames() async {
    try {
      for (int i = 1; i <= idleFrames; i++) {
        final bytes = await rootBundle.load(
          'assets/images/idle/frame_${i.toString().padLeft(4, '0')}.png',
        );

        _idleFrames.add(
          Image.memory(
            bytes.buffer.asUint8List(),
            fit: BoxFit.contain,
            gaplessPlayback: true,
            filterQuality: FilterQuality.high,
          ),
        );
      }

      if (!mounted) return;

      setState(() {
        _loaded = true;
      });

      _animationTimer = Timer.periodic(
        const Duration(milliseconds: 50),
        (_) {
          if (!mounted || !_loaded) return;

          // Only animate while the cat is idle.
          if (widget.state != PetState.idle) return;

          setState(() {
            _currentFrame = (_currentFrame + 1) % _idleFrames.length;
          });
        },
      );
    } catch (error) {
      debugPrint(
        'Failed to load idle cat frames: $error',
      );
    }
  }

  @override
  void dispose() {
    _animationTimer?.cancel();

    super.dispose();
  }

  String _getStateImage() {
    switch (widget.state) {
      case PetState.happy:
        return 'assets/images/states/happy_cat.png';

      case PetState.sad:
        return 'assets/images/states/sad_cat.png';

      case PetState.angry:
        return 'assets/images/states/angry_cat.png';

      case PetState.clean:
        return 'assets/images/states/clean_cat.png';

      case PetState.dirty:
        return 'assets/images/states/dirty_cat.png';

      case PetState.neglected:
        return 'assets/images/states/dirty_cat1.png';

      case PetState.idle:
        return '';
    }
  }

  String _getFurImage() {
    switch (widget.furStage) {
      case 1:
        return 'assets/images/states/fur1.png';

      case 2:
        return 'assets/images/states/fur2.png';

      case 3:
        return 'assets/images/states/fur3.png';

      default:
        return '';
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
    if (widget.state == PetState.neglected) {
      return Image.asset(
        'assets/images/states/dirty_cat1.png',
        height: widget.height,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
      );
    }
    // =============================
// DIRTY CAT HAS HIGHEST PRIORITY
// =============================
    if (widget.isDirty) {
      return Image.asset(
        'assets/images/states/dirty_cat.png',
        height: widget.height,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        filterQuality: FilterQuality.high,
      );
    }

// =============================
// IDLE / FUR
// =============================
    if (widget.state == PetState.idle) {
      // Fur stage has priority over idle animation
      if (widget.furStage > 0) {
        return Image.asset(
          _getFurImage(),
          height: widget.height,
          fit: BoxFit.contain,
        );
      }

      // Normal animated idle
      return SizedBox(
        height: widget.height,
        child: _idleFrames[_currentFrame],
      );
    }

    // HAPPY, SAD, ANGRY, CLEAN, DIRTY = single PNG.
    return Image.asset(
      _getStateImage(),
      height: widget.height,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      filterQuality: FilterQuality.high,
    );
  }
}
