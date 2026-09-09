import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/pet_state.dart';
import '../models/virtual_cat_activity.dart';

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

  // ── Idle variation tuning ─────────────────────────────────────────────
  // How often (roughly) the cat plays a brief, natural-feeling "flourish"
  // on top of the continuous idle loop — jittered so it never feels
  // mechanical. A single short one-shot transform (via flutter_animate,
  // already an existing project dependency), not a second persistent
  // animation loop, so this never competes with the frame-cycle timer
  // below for CPU/GPU work.
  static const Duration _idleVariationMinGap = Duration(seconds: 5);
  static const Duration _idleVariationMaxGap = Duration(seconds: 10);

  final List<Image> _idleFrames = [];
  final Random _rng = Random();

  int _currentFrame = 0;

  bool _loaded = false;

  Timer? _animationTimer;
  Timer? _variationTimer;

  // Bumping this key replays the one-shot idle-variation transform (see
  // build()) without disturbing the continuous frame-cycle animation.
  int _variationKey = 0;
  bool _variationPlaying = false;

  /// Current coarse behavior state — see VirtualCatActivity's doc comment.
  /// Internal only for Phase 9.1 (nothing outside this widget needs it
  /// yet); a later phase can surface it via a callback if/when GameScreen
  /// needs to react to it.
  VirtualCatActivity get _activity => _variationPlaying
      ? VirtualCatActivity.idleVariation
      : VirtualCatActivity.idle;

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

      _scheduleNextIdleVariation();
    } catch (error) {
      debugPrint(
        'Failed to load idle cat frames: $error',
      );
    }
  }

  // ── Idle variation ─────────────────────────────────────────────────────
  // A single, self-rescheduling Timer (never Timer.periodic here, so the
  // gap can be randomized each time) that occasionally replays a brief
  // one-shot flourish on top of the continuous idle loop. Bounded and
  // always cancelled in dispose() — never an uncontrolled loop.

  void _scheduleNextIdleVariation() {
    final gapMs = _idleVariationMinGap.inMilliseconds +
        _rng.nextInt(
          (_idleVariationMaxGap - _idleVariationMinGap).inMilliseconds,
        );

    _variationTimer = Timer(Duration(milliseconds: gapMs), () {
      if (!mounted) return;

      // Only meaningful while genuinely idle — a mood override (happy/
      // sad/dirty/angry/neglected) or an active fur stage already shows
      // its own static picture, so a flourish would have nothing to play
      // on top of. Skip this cycle and just check again next time.
      final isPlainIdle =
          widget.state == PetState.idle && !widget.isDirty && widget.furStage == 0;

      if (isPlainIdle) {
        setState(() {
          _variationKey++;
          _variationPlaying = true;
        });

        Future.delayed(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          setState(() => _variationPlaying = false);
        });
      }

      _scheduleNextIdleVariation();
    });
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _variationTimer?.cancel();

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

      // Normal animated idle, with an occasional one-shot "flourish"
      // layered on top (see _scheduleNextIdleVariation). Keying on
      // _variationKey — which only changes when a flourish is triggered —
      // replays the transform without disturbing the 50ms frame-cycle
      // animation running underneath it every other rebuild.
      final frame = SizedBox(
        height: widget.height,
        child: _idleFrames[_currentFrame],
      );

      if (_activity != VirtualCatActivity.idleVariation) {
        return frame;
      }

      return frame
          .animate(key: ValueKey(_variationKey))
          .moveY(begin: 0, end: -6, duration: 260.ms, curve: Curves.easeOut)
          .then()
          .moveY(begin: -6, end: 0, duration: 320.ms, curve: Curves.easeIn);
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
