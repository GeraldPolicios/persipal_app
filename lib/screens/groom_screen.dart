import 'dart:math';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:provider/provider.dart';

import '../services/activity_service.dart';
import '../services/reward_service.dart';
import '../services/global_music_service.dart';
import '../game/groom.dart';
import '../game/cat_animation.dart';
import '../providers/virtual_pet_provider.dart';
import '../widgets/realtime_clock.dart';
import '../widgets/shop_scene_background.dart';

import '../utils/day_period.dart';
import '../utils/nighttime_mode.dart';

class _BlowerPose {
  final bool flipped;

  const _BlowerPose({
    required this.flipped,
  });
}

class GroomScreen extends StatefulWidget {
  final int cleanliness;
  final Function(String) onAction;
  final bool isDirty;

  const GroomScreen({
    super.key,
    required this.cleanliness,
    required this.onAction,
    required this.isDirty,
  });

  @override
  State<GroomScreen> createState() => _GroomScreenState();
}

class _GroomScreenState extends State<GroomScreen> {
  final _service = ActivityService.instance;

  late int cleanliness;
  late bool isDirty;

  late final GroomGame _groomGame;
  late final CatAnimation _sadCatGame;
  late final CatAnimation _sleepyCatGame;

  final GlobalKey _gameKey = GlobalKey();
  final GlobalKey _roomKey = GlobalKey();

  int _groomProgress = 0;

  final bool _hovering = false;

  bool _trimMode = false;
  bool _soapDragging = false;
  bool _showerDragging = false;
  bool _showerOverCat = false;
  double _showerCleanProgress = 0.0;
  Offset? _lastShowerCenter;
  Timer? _showerCleaningTimer;
  bool _blowerDragging = false;
  bool _towelDragging = false;
  bool _brushDragging = false;
  bool _trimDragging = false;

  Offset? _lastBrushPosition;
  Offset? _lastTrimPosition;
  int _currentFurStage = 0;

  bool _trimFinished = false;
  double? _trimPassStartX;
  double _trimPassMovement = 0;
  String _feedbackText = '';

  int _sparkleCount = 0;
  final Random _furRandom = Random();
  final List<_LiveFurParticle> _liveFurParticles = [];
  Timer? _furParticleTimer;
  Offset? _lastFurSpawnPosition;

  Offset? _lastSoapPosition;

  Offset? _lastTowelPosition;

  // Tool audio is active only during actual swipe movement. Holding the tool
  // still pauses its sound after a short inactivity window.
  Timer? _groomingSoundIdleTimer;
  Offset? _lastGroomingSoundPosition;
  String? _currentGroomingSoundFilename;
  bool _groomingSoundPlaying = false;

  final ValueNotifier<_BlowerPose> _blowerPose = ValueNotifier<_BlowerPose>(
    const _BlowerPose(
      flipped: false,
    ),
  );

  final List<Map<String, dynamic>> _tools = const [
    {
      'emoji': '🧼',
      'name': 'Soap',
      'color': Color(0xFFE1F5FE),
    },
    {
      'emoji': '🚿',
      'name': 'Shower',
      'color': Color(0xFFB3E5FC),
    },
    {
      'image': 'blower.png',
      'name': 'Blower',
      'color': Color(0xFFE1BEE7),
    },
    {
      'image': 'towel.png',
      'name': 'Towel',
      'color': Color(0xFFD7CCC8),
    },
    {
      'emoji': '✂️',
      'name': 'Trim',
      'color': Color(0xFFFFCDD2),
    },
    {
      'emoji': '🪮',
      'name': 'Brush',
      'color': Color(0xFFFFE0B2),
    },
  ];

  @override
  void initState() {
    super.initState();

    _groomGame = GroomGame();
    _sadCatGame = CatAnimation(startSad: true);
    _sleepyCatGame = CatAnimation();

    cleanliness = widget.cleanliness;
    isDirty = widget.isDirty;

    _currentFurStage = context.read<VirtualPetProvider>().furStage;
    dayPeriodNotifier.addListener(_onDayPeriodChanged);
  }

  bool _isGroomingBlockedByHunger(VirtualPetProvider pet) {
    // Match the PlayScreen's critical-hunger rule, but keep Neglected
    // groomable so grooming can be used to break the neglected condition.
    return pet.isCriticalHunger && !pet.isNeglected;
  }

  bool _isNightCareNeeded(VirtualPetProvider pet, {required bool trimming}) {
    // Nighttime is a strict no-grooming period. Keep the existing daytime
    // eligibility rules unchanged, but block every tool consistently at night.
    if (NighttimeMode.isNighttime()) return false;
    return true;
  }

  Future<void> _showNightRestBlocked() async {
    if (!mounted) return;
    setState(
        () => _feedbackText = '🌙 Im resting now. See you in the morning!');
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _feedbackText = '');
  }

  Future<void> _showHungryBlocked() async {
    if (!mounted) return;

    setState(() {
      _feedbackText = '🍗 Im too hungry! Feed me first!';
    });

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() {
      _feedbackText = '';
    });
  }

  Future<void> _showSleepyBlocked() async {
    if (!mounted) return;

    setState(() {
      _feedbackText = '😴 Zzz... Im sleepy!';
    });

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() {
      _feedbackText = '';
    });
  }

  Future<void> _groom(String tool) async {
    final pet = context.read<VirtualPetProvider>();
    final oldCleanliness = pet.cleanliness;
    if (!_isNightCareNeeded(pet, trimming: tool == 'Trim')) {
      await _showNightRestBlocked();
      return;
    }

    // Once the cat is fully clean, Trim is the only usable grooming tool.
    if (pet.cleanliness >= 100 && tool != 'Trim') {
      if (mounted) {
        setState(() {
          _feedbackText = 'Already clean! Trim the fur ✂️';
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _feedbackText = '');
        });
      }
      return;
    }

    // Prevent cleaning tools from repeating the wash/clean effect.
    const cleaningTools = {'Soap', 'Shower', 'Towel', 'Brush'};
    if (pet.cleanliness >= 100 && cleaningTools.contains(tool)) {
      if (mounted) {
        setState(() {
          _feedbackText =
              'Already clean! You can trim or choose another action ✨';
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => _feedbackText = '');
        });
      }
      return;
    }

    if (_isGroomingBlockedByHunger(pet)) {
      await _showHungryBlocked();
      return;
    }

    if (pet.isSleeping && !pet.isNeglected) {
      return;
    }

    if (pet.isSleepy && !pet.isNeglected) {
      await _showSleepyBlocked();
      return;
    }

    setState(() {
      _groomProgress += 1;

      if (tool == 'Shower' || tool == 'Soap') {
        _groomProgress += 1;
      }

      if (tool == 'Brush') {
        _groomProgress += 1;
      }

      if (_groomProgress >= 10) {
        cleanliness = 100;
        isDirty = false;

        _feedbackText = 'Squeaky clean ✨';
      } else if (_groomProgress >= 5) {
        cleanliness = 60;

        _feedbackText = 'Getting better 🧼';
      } else {
        cleanliness = (cleanliness + 10).clamp(0, 100);

        _feedbackText = 'Grooming… 😽';
      }

      cleanliness = cleanliness.clamp(0, 100);

      if (tool == 'Brush' || tool == 'Trim') {
        _sparkleCount = 5;
      } else {
        _sparkleCount = 0;
      }
    });

    final cleanlinessDelta = cleanliness - oldCleanliness;

    if (tool == 'Brush') {}

    await pet.groom(
      cleanlinessDelta: cleanlinessDelta,
      happinessDelta: 5,
    );

    if (!mounted) return;

    setState(() {
      cleanliness = pet.cleanliness;
      isDirty = pet.isDirty;
    });

    if (!pet.isNeglected) {
      _groomGame.showIdle();
    }

    _service.logActivity(
      icon: Icons.content_cut,
      iconColor: const Color(0xFF7B68EE),
      title: 'Groomed cat — $tool',
    );

    Future.delayed(
      const Duration(milliseconds: 700),
      () {
        if (!mounted) {
          return;
        }

        setState(() {
          _sparkleCount = 0;
          _feedbackText = '';
        });
      },
    );
  }

  Offset? _gameLocalPosition(
    Offset globalPosition,
  ) {
    final renderObject = _gameKey.currentContext?.findRenderObject();

    if (renderObject is RenderBox) {
      return renderObject.globalToLocal(
        globalPosition,
      );
    }

    return null;
  }

  // REAL-TIME LOOSE FUR

  void _startLiveFurParticles() {
    _furParticleTimer ??= Timer.periodic(
      const Duration(milliseconds: 33),
      (_) {
        if (!mounted) return;

        final now = DateTime.now();
        _liveFurParticles.removeWhere(
          (particle) => now.difference(particle.createdAt).inMilliseconds > 850,
        );

        if (_liveFurParticles.isEmpty) {
          _furParticleTimer?.cancel();
          _furParticleTimer = null;
        }

        setState(() {});
      },
    );
  }

  void _spawnLiveFurParticle(
    Offset position, {
    bool dense = false,
  }) {
    final last = _lastFurSpawnPosition;
    final minimumDistance = dense ? 7.0 : 11.0;

    if (last != null && (position - last).distance < minimumDistance) {
      return;
    }

    _lastFurSpawnPosition = position;

    // These are the same warm/dark tones visible in the calico Persian cat.
    // Each swipe strand gets one of these colors so the loose fur looks like
    // it actually came from the cat instead of being a generic game particle.
    const furColors = <Color>[
      Color(0xFF3F3028),
      Color(0xFF6E422B),
      Color(0xFF8A5836),
      Color(0xFFB77A4D),
      Color(0xFFD2A477),
      Color(0xFFE8D5B7),
    ];

    final spread = (_furRandom.nextDouble() - 0.5) * 1.2;
    final speed = 12 + _furRandom.nextDouble() * 24;

    setState(() {
      _liveFurParticles.add(
        _LiveFurParticle(
          position: position,
          velocity: Offset(
            cos(spread) * speed,
            sin(spread) * speed + 18,
          ),
          angle: (_furRandom.nextDouble() - 0.5) * 1.1,
          length: 12 + _furRandom.nextDouble() * 8,
          thickness: 1.2 + _furRandom.nextDouble() * 0.9,
          color: furColors[_furRandom.nextInt(furColors.length)],
          createdAt: DateTime.now(),
          seed: _furRandom.nextInt(100000),
        ),
      );
    });

    _startLiveFurParticles();
  }

  void _moveLiveFurParticles(Offset localPosition, {bool dense = false}) {
    if (!_isOverCat(localPosition)) {
      return;
    }

    final gameRenderObject = _gameKey.currentContext?.findRenderObject();
    final roomRenderObject = _roomKey.currentContext?.findRenderObject();

    if (gameRenderObject is! RenderBox || roomRenderObject is! RenderBox) {
      return;
    }

    // Hit testing uses the GameWidget's local coordinates, while the fur
    // painter is drawn over the whole grooming-room Stack. Convert the swipe
    // point so the fur appears exactly where the brush/scissors touch the cat.
    final globalPosition = gameRenderObject.localToGlobal(localPosition);
    final roomPosition = roomRenderObject.globalToLocal(globalPosition);

    _spawnLiveFurParticle(roomPosition, dense: dense);
  }

  // Shower and blower play continuously while their tool is held/dragged.
  // Soap, towel, trim, and brush use swipe-only audio below.
  void _startGroomingSound(String filename) {
    final pet = context.read<VirtualPetProvider>();
    if ((pet.isSleepy || pet.isSleeping) && !pet.isNeglected) {
      _stopGroomingSound();
      return;
    }
    _groomingSoundIdleTimer?.cancel();
    _lastGroomingSoundPosition = null;
    _currentGroomingSoundFilename = filename;
    _groomingSoundPlaying = true;
    unawaited(GlobalMusicService.instance.startLoopingSfx(filename));
  }

  // Tool audio follows actual movement, not merely pointer-down. If the user
  // holds the tool still, stop the loop shortly after the last swipe update.
  void _playGroomingSoundOnSwipe(String filename, Offset position) {
    final pet = context.read<VirtualPetProvider>();
    if ((pet.isSleepy || pet.isSleeping) && !pet.isNeglected) {
      _stopGroomingSound();
      return;
    }
    final lastPosition = _lastGroomingSoundPosition;
    if (lastPosition != null && (position - lastPosition).distance < 4.0) {
      return;
    }

    _lastGroomingSoundPosition = position;
    _groomingSoundIdleTimer?.cancel();

    if (!_groomingSoundPlaying || _currentGroomingSoundFilename != filename) {
      _groomingSoundPlaying = true;
      _currentGroomingSoundFilename = filename;
      unawaited(GlobalMusicService.instance.startLoopingSfx(filename));
    }

    _groomingSoundIdleTimer = Timer(const Duration(milliseconds: 180), () {
      _groomingSoundPlaying = false;
      _currentGroomingSoundFilename = null;
      _lastGroomingSoundPosition = null;
      unawaited(GlobalMusicService.instance.stopLoopingSfx());
    });
  }

  void _stopGroomingSound() {
    _groomingSoundIdleTimer?.cancel();
    _groomingSoundIdleTimer = null;
    _lastGroomingSoundPosition = null;
    _currentGroomingSoundFilename = null;
    _groomingSoundPlaying = false;
    unawaited(GlobalMusicService.instance.stopLoopingSfx());
  }

  // SOAP

  void _addSoapBubble(
    Offset globalPosition,
  ) {
    final localPosition = _gameLocalPosition(globalPosition);

    if (localPosition == null) {
      return;
    }

    final renderObject = _gameKey.currentContext?.findRenderObject();

    if (renderObject is! RenderBox) {
      return;
    }

    final roomSize = renderObject.size;

    final catCenter = Offset(
      roomSize.width / 2,
      roomSize.height / 2 + 15,
    );

    final dx = (localPosition.dx - catCenter.dx) / 60;

    final dy = (localPosition.dy - catCenter.dy) / 60;

    if ((dx * dx) + (dy * dy) > 1) {
      return;
    }

    if (_lastSoapPosition != null &&
        (localPosition - _lastSoapPosition!).distance < 8) {
      return;
    }

    _lastSoapPosition = localPosition;

    _groomGame.addSoapBubble(
      localPosition.dx - 10,
      localPosition.dy + 8,
    );

    _groomGame.addSoapBubble(
      localPosition.dx - 15,
      localPosition.dy + 5,
    );

    _groomGame.addSoapBubble(
      localPosition.dx - 5,
      localPosition.dy + 11,
    );
  }

  void _startSoapDrag() {
    // Match Trim: unavailable cats must never leave a grooming-tool sound playing.
    _stopGroomingSound();
    final pet = context.read<VirtualPetProvider>();
    if (!_isNightCareNeeded(pet, trimming: false)) {
      unawaited(_showNightRestBlocked());
      return;
    }
    if (pet.cleanliness >= 100) {
      setState(() => _feedbackText =
          'Already clean! You can trim or choose another action ✨');
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _feedbackText = '');
      });
      return;
    }
    if (_isGroomingBlockedByHunger(pet)) {
      unawaited(_showHungryBlocked());
      return;
    }

    if (pet.isSleeping && !pet.isNeglected) {
      _stopGroomingSound();
      unawaited(_showNightRestBlocked());
      return;
    }

    if (pet.isSleepy && !pet.isNeglected) {
      _stopGroomingSound();
      unawaited(_showSleepyBlocked());
      return;
    }

    _cancelShowerInteraction();
    setState(() {
      _soapDragging = true;
      _trimMode = false;

      _showerDragging = false;
      _blowerDragging = false;
      _towelDragging = false;

      _lastSoapPosition = null;

      _feedbackText = 'Soap the cat 🧼';
    });
  }

  void _moveSoap(
    Offset globalPosition,
  ) {
    if (!_soapDragging) {
      return;
    }

    final localPosition = _gameLocalPosition(globalPosition);
    if (localPosition != null) {
      _playGroomingSoundOnSwipe('bubbles.wav', localPosition);
    }
    _addSoapBubble(globalPosition);
  }

  void _finishSoap() {
    _stopGroomingSound();
    if (!_soapDragging) {
      return;
    }

    setState(() {
      _soapDragging = false;
      _lastSoapPosition = null;
      _feedbackText = '';
    });

    // Soap only adds bubbles. It does NOT clean the dirt.
  }

  void _cancelShowerInteraction() {
    if (_showerDragging) {
      _stopGroomingSound();
    }
    _showerCleaningTimer?.cancel();
    _showerCleaningTimer = null;
    _groomGame.stopTransientEffects();
    _showerDragging = false;
    _showerOverCat = false;
    _lastShowerCenter = null;
  }

  // SHOWER

  void _startShowerDrag() {
    // Match Trim: unavailable cats must never leave a grooming-tool sound playing.
    _stopGroomingSound();
    final pet = context.read<VirtualPetProvider>();
    if (!_isNightCareNeeded(pet, trimming: false)) {
      unawaited(_showNightRestBlocked());
      return;
    }
    if (pet.cleanliness >= 100) {
      setState(() => _feedbackText =
          'Already clean! You can trim or choose another action ✨');
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _feedbackText = '');
      });
      return;
    }
    if (_isGroomingBlockedByHunger(pet)) {
      unawaited(_showHungryBlocked());
      return;
    }

    if (pet.isSleeping && !pet.isNeglected) {
      _stopGroomingSound();
      unawaited(_showNightRestBlocked());
      return;
    }

    if (pet.isSleepy && !pet.isNeglected) {
      _stopGroomingSound();
      unawaited(_showSleepyBlocked());
      return;
    }

    _cancelShowerInteraction();
    _stopGroomingSound();
    _groomGame.stopBlower();
    _startGroomingSound('shower.wav');
    _showerCleaningTimer?.cancel();

    // Keep partial shower progress when the user releases the shower and
    // starts it again. The dirt visually fades gradually while water is held
    // over the cat; releasing the shower pauses that progress.
    if (!pet.isDirty || _showerCleanProgress >= 1.0) {
      _showerCleanProgress = 0.0;
    }

    setState(() {
      _showerDragging = true;
      _showerOverCat = false;
      _lastShowerCenter = null;
      _soapDragging = false;

      _blowerDragging = false;
      _towelDragging = false;

      _trimMode = false;

      _feedbackText = 'Wash the cat 🚿';
    });

    _showerCleaningTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) async {
        if (!mounted || !_showerDragging || !_showerOverCat) {
          return;
        }

        // Keep the water stream alive even when the user holds the shower
        // still. DragUpdate is not guaranteed to fire while stationary.
        final showerCenter = _lastShowerCenter;
        if (showerCenter != null) {
          final touchingCat = _groomGame.moveShower(showerCenter);
          if (mounted && touchingCat != _showerOverCat) {
            setState(() {
              _showerOverCat = touchingCat;
            });
          }
        }

        if (!_showerOverCat) {
          return;
        }

        final next = (_showerCleanProgress + 0.0125).clamp(0.0, 1.0).toDouble();
        if (mounted) {
          setState(() {
            _showerCleanProgress = next;
          });
        }

        if (next >= 1.0) {
          await _completeShowerCleaning();
        }
      },
    );
  }

  void _moveShower(
    Offset globalPosition,
  ) {
    if (!_showerDragging) {
      return;
    }

    final localPosition = _gameLocalPosition(globalPosition);

    if (localPosition == null) {
      return;
    }

    final renderObject = _gameKey.currentContext?.findRenderObject();

    if (renderObject is! RenderBox) {
      return;
    }

    final roomSize = renderObject.size;

    final maxX = max(
      0.0,
      roomSize.width - 46,
    );

    final maxY = max(
      0.0,
      roomSize.height - 46,
    );

    final clampedPosition = Offset(
      localPosition.dx.clamp(0.0, maxX),
      localPosition.dy.clamp(0.0, maxY),
    );

    final showerCenter = clampedPosition +
        const Offset(
          23,
          23,
        );

    // GroomGame owns the exact water/cat collision geometry so the screen
    // and Flame game cannot disagree about whether the cat is being washed.
    _lastShowerCenter = showerCenter;

    final touchingCat = _groomGame.moveShower(
      showerCenter,
    );

    if (mounted && touchingCat != _showerOverCat) {
      setState(() {
        _showerOverCat = touchingCat;
      });
    }
  }

  Future<void> _completeShowerCleaning() async {
    if (!_showerDragging || _showerCleanProgress < 1.0) {
      return;
    }

    // Completion cleans the cat but does NOT stop the shower while the
    // user is still holding it. The water stays visible until release.
    _showerCleaningTimer?.cancel();
    _showerCleaningTimer = null;
    _groomGame.clearSoapBubbles();
    _groomGame.showWetCat();

    final pet = context.read<VirtualPetProvider>();
    final delta = 100 - pet.cleanliness;
    if (delta > 0) {
      await pet.groom(
        cleanlinessDelta: delta,
        happinessDelta: 5,
      );
    }

    if (!mounted) return;

    setState(() {
      cleanliness = pet.cleanliness;
      isDirty = pet.isDirty;
      // Keep the drag active until the user releases the shower so the
      // visible water stream remains attached to the held shower.
      _showerDragging = true;
      _showerOverCat = true;
      _showerCleanProgress = 1.0;
      _feedbackText = 'Squeaky clean ✨';
    });
  }

  void _finishShower() {
    _stopGroomingSound();
    if (!_showerDragging) {
      return;
    }

    final showerCompleted = _showerCleanProgress >= 1.0;
    _cancelShowerInteraction();

    // Re-assert the wet pose after the shower is released. The water stops,
    // but the cat must stay visibly wet until the blower dries it.
    if (showerCompleted) {
      _groomGame.showWetCat();
    }

    setState(() {
      _showerDragging = false;
      _showerOverCat = false;
      _feedbackText =
          _showerCleanProgress > 0 ? 'Keep showering to finish 🚿' : '';
    });
  }

  Widget _showerFeedback(
    Map<String, dynamic> item,
  ) {
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 46,
        height: 46,
        child: Center(
          child: Transform.rotate(
            angle: -pi / 4,
            child: Text(
              item['emoji'] as String,
              style: const TextStyle(
                fontSize: 46,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _showerDraggable(
    Map<String, dynamic> item,
  ) {
    return Draggable<String>(
      data: 'Shower',
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: _startShowerDrag,
      onDragUpdate: (details) {
        _moveShower(
          details.globalPosition,
        );
      },
      onDragEnd: (_) {
        _finishShower();
      },
      onDraggableCanceled: (_, __) {
        _finishShower();
      },
      feedback: _showerFeedback(item),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _toolCard(item),
      ),
      child: _toolCard(item),
    );
  }

  // BLOWER

  void _startBlowerDrag() {
    // Match Trim: unavailable cats must never leave a grooming-tool sound playing.
    _stopGroomingSound();
    final pet = context.read<VirtualPetProvider>();
    if (!_isNightCareNeeded(pet, trimming: false)) {
      unawaited(_showNightRestBlocked());
      return;
    }
    if (_isGroomingBlockedByHunger(pet)) {
      unawaited(_showHungryBlocked());
      return;
    }

    if (pet.isSleeping && !pet.isNeglected) {
      _stopGroomingSound();
      unawaited(_showNightRestBlocked());
      return;
    }

    if (pet.isSleepy && !pet.isNeglected) {
      _stopGroomingSound();
      unawaited(_showSleepyBlocked());
      return;
    }

    _cancelShowerInteraction();
    _stopGroomingSound();
    _startGroomingSound('blower.wav');
    _blowerPose.value = const _BlowerPose(
      flipped: false,
    );

    setState(() {
      _blowerDragging = true;
      _soapDragging = false;

      _showerDragging = false;
      _towelDragging = false;

      _trimMode = false;

      _feedbackText = 'Dry the cat 💨';
    });
  }

  void _moveBlower(
    Offset globalPosition,
  ) {
    if (!_blowerDragging) {
      return;
    }

    final localPosition = _gameLocalPosition(globalPosition);

    if (localPosition == null) {
      return;
    }

    final renderObject = _gameKey.currentContext?.findRenderObject();

    if (renderObject is! RenderBox) {
      return;
    }

    final roomSize = renderObject.size;

    final catCenter = Offset(
      roomSize.width / 2,
      roomSize.height / 2 + 15,
    );

    final blowerIsOnRight = localPosition.dx > catCenter.dx;

    _blowerPose.value = _BlowerPose(
      flipped: blowerIsOnRight,
    );

    final blowerCenter = localPosition +
        const Offset(
          40,
          40,
        );

    _groomGame.moveBlower(
      blowerCenter,
    );
  }

  void _finishBlower() {
    _stopGroomingSound();
    if (!_blowerDragging) {
      return;
    }

    _groomGame.stopBlower();

    setState(() {
      _blowerDragging = false;
      _feedbackText = '';
    });

    _blowerPose.value = const _BlowerPose(
      flipped: false,
    );

    _groom('Blower');
  }

  Widget _blowerFeedback(
    Map<String, dynamic> item,
  ) {
    final image = item['image'] as String;

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 80,
        height: 80,
        child: ValueListenableBuilder<_BlowerPose>(
          valueListenable: _blowerPose,
          builder: (
            context,
            pose,
            child,
          ) {
            return Transform.scale(
              scaleX: pose.flipped ? -1.0 : 1.0,
              child: Image.asset(
                'assets/images/items/$image',
                width: 80,
                height: 80,
                fit: BoxFit.contain,
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _blowerDraggable(
    Map<String, dynamic> item,
  ) {
    return Draggable<String>(
      data: 'Blower',
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: _startBlowerDrag,
      onDragUpdate: (details) {
        _moveBlower(
          details.globalPosition,
        );
      },
      onDragEnd: (_) {
        _finishBlower();
      },
      feedback: _blowerFeedback(item),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _toolCard(item),
      ),
      child: _toolCard(item),
    );
  }

  // TOWEL

  void _startTowelDrag() {
    // Match Trim: unavailable cats must never leave a grooming-tool sound playing.
    _stopGroomingSound();
    final pet = context.read<VirtualPetProvider>();
    if (!_isNightCareNeeded(pet, trimming: false)) {
      unawaited(_showNightRestBlocked());
      return;
    }
    if (pet.cleanliness >= 100) {
      setState(() => _feedbackText =
          'Already clean! You can trim or choose another action ✨');
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _feedbackText = '');
      });
      return;
    }
    if (_isGroomingBlockedByHunger(pet)) {
      unawaited(_showHungryBlocked());
      return;
    }

    if (pet.isSleeping && !pet.isNeglected) {
      _stopGroomingSound();
      unawaited(_showNightRestBlocked());
      return;
    }

    if (pet.isSleepy && !pet.isNeglected) {
      _stopGroomingSound();
      unawaited(_showSleepyBlocked());
      return;
    }

    _cancelShowerInteraction();
    setState(() {
      _towelDragging = true;
      _soapDragging = false;

      _showerDragging = false;
      _blowerDragging = false;

      _trimMode = false;

      _lastTowelPosition = null;

      _feedbackText = 'Dry with the towel 🧺';
    });
  }

  void _moveTowel(
    Offset globalPosition,
  ) {
    if (!_towelDragging) {
      return;
    }

    final localPosition = _gameLocalPosition(globalPosition);

    if (localPosition == null) {
      return;
    }

    if (_lastTowelPosition != null &&
        (localPosition - _lastTowelPosition!).distance < 10) {
      return;
    }

    _playGroomingSoundOnSwipe('towel.wav', localPosition);
    _lastTowelPosition = localPosition;

    final towelCenter = localPosition +
        const Offset(
          32,
          32,
        );

    _groomGame.towelSwipe(
      towelCenter,
    );
  }

  void _finishTowel() {
    _stopGroomingSound();
    if (!_towelDragging) {
      return;
    }

    setState(() {
      _towelDragging = false;
      _lastTowelPosition = null;
      _feedbackText = '';
    });

    _groom('Towel');
  }

  Widget _towelFeedback(
    Map<String, dynamic> item,
  ) {
    final image = item['image'] as String;

    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 80,
        height: 80,
        child: Image.asset(
          'assets/images/items/$image',
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _towelDraggable(
    Map<String, dynamic> item,
  ) {
    return Draggable<String>(
      data: 'Towel',
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: _startTowelDrag,
      onDragUpdate: (details) {
        _moveTowel(
          details.globalPosition,
        );
      },
      onDragEnd: (_) {
        _finishTowel();
      },
      feedback: _towelFeedback(item),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _toolCard(item),
      ),
      child: _toolCard(item),
    );
  }

  // BRUSH

  void _startBrushDrag() {
    // Match Trim: unavailable cats must never leave a grooming-tool sound playing.
    _stopGroomingSound();
    final pet = context.read<VirtualPetProvider>();
    if (!_isNightCareNeeded(pet, trimming: false)) {
      unawaited(_showNightRestBlocked());
      return;
    }

    if (_isGroomingBlockedByHunger(pet)) {
      unawaited(_showHungryBlocked());
      return;
    }

    _cancelShowerInteraction();

    if (pet.isSleeping && !pet.isNeglected) {
      _stopGroomingSound();
      unawaited(_showNightRestBlocked());
      return;
    }

    if (pet.isSleepy && !pet.isNeglected) {
      unawaited(_showSleepyBlocked());
      return;
    }

    // Reset any stale grooming-audio state before a new brush swipe. The
    // brush sound will start again on the first actual movement.
    _stopGroomingSound();

    setState(() {
      _brushDragging = true;
      _lastBrushPosition = null;
      _lastFurSpawnPosition = null;

      _soapDragging = false;
      _showerDragging = false;
      _blowerDragging = false;
      _towelDragging = false;

      _trimMode = false;

      _feedbackText = 'Brush the cat 🪮';
    });
  }

  void _moveBrush(Offset globalPosition) {
    if (!_brushDragging) {
      return;
    }

    final localPosition = _gameLocalPosition(globalPosition);
    if (localPosition == null) {
      return;
    }

    _playGroomingSoundOnSwipe('brush.wav', localPosition);
    _lastBrushPosition = localPosition;
    _moveLiveFurParticles(localPosition);
  }

  bool _isOverCat(Offset localPosition) {
    final renderObject = _gameKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) {
      return false;
    }

    final roomSize = renderObject.size;
    final catCenter = Offset(
      roomSize.width / 2,
      roomSize.height / 2 + 40,
    );

    final dx = (localPosition.dx - catCenter.dx) / 62;
    final dy = (localPosition.dy - catCenter.dy) / 62;

    return (dx * dx) + (dy * dy) <= 1.0;
  }

  void _finishBrush() {
    _stopGroomingSound();
    if (!_brushDragging) {
      return;
    }

    final overCat =
        _lastBrushPosition != null && _isOverCat(_lastBrushPosition!);

    setState(() {
      _brushDragging = false;
      _lastBrushPosition = null;
      _lastFurSpawnPosition = null;
      _feedbackText = '';
    });

    if (overCat) {
      unawaited(_groom('Brush'));
    }
  }

  Widget _brushFeedback(Map<String, dynamic> item) {
    final emoji = item['emoji'] as String;

    return Material(
      color: Colors.transparent,
      child: Text(
        emoji,
        style: const TextStyle(fontSize: 46),
      ),
    );
  }

  Widget _brushDraggable(Map<String, dynamic> item) {
    return Draggable<String>(
      data: 'Brush',
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: _startBrushDrag,
      onDragUpdate: (details) {
        _moveBrush(details.globalPosition);
      },
      onDragEnd: (_) {
        _finishBrush();
      },
      feedback: _brushFeedback(item),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _toolCard(item),
      ),
      child: _toolCard(item),
    );
  }

  // TRIM

  void _startTrim() {
    // A blocked nighttime attempt must never leave another tool's SFX playing.
    _stopGroomingSound();
    final pet = context.read<VirtualPetProvider>();
    if (!_isNightCareNeeded(pet, trimming: true)) {
      unawaited(_showNightRestBlocked());
      return;
    }

    if (_isGroomingBlockedByHunger(pet)) {
      unawaited(_showHungryBlocked());
      return;
    }

    _cancelShowerInteraction();
    if (pet.isSleeping && !pet.isNeglected) {
      return;
    }

    if (pet.isSleepy && !pet.isNeglected) {
      _showSleepyBlocked();
      return;
    }

    // Trim is available even when the cat is already at Fur 0. In that
    // case it acts as optional grooming (and still records the care action),
    // but it must not change the fur stage or interfere with future growth.
    final shortFurTrim = pet.furStage <= 0;

    final continuingTrim = _trimMode;
    setState(() {
      _trimMode = true;
      _soapDragging = false;

      _showerDragging = false;
      _blowerDragging = false;
      _towelDragging = false;

      // Keep progress between separate swipes; a new drag must not reset the
      // current visual stage or the three-pass trimming requirement.
      if (!continuingTrim) {
        _currentFurStage = pet.furStage;
      }
      // For Fur 0, complete the optional trim interaction without lowering
      // the fur stage. Fur 1/Fur 2 keep the existing trimming sequence.
      _trimFinished = shortFurTrim;

      _trimPassStartX = null;

      _trimPassMovement = 0;

      _feedbackText =
          shortFurTrim ? 'A little trim for short fur ✂️' : 'Trim the fur ✂️';
    });
  }

  void _startTrimDrag() {
    _startTrim();

    if (!mounted || !_trimMode) {
      return;
    }

    setState(() {
      _trimDragging = true;
      _lastTrimPosition = null;
      _lastFurSpawnPosition = null;
      _trimPassStartX = null;

      _trimPassMovement = 0;
    });
  }

  void _moveTrim(Offset globalPosition) {
    if (!_trimDragging || !_trimMode) {
      return;
    }

    final localPosition = _gameLocalPosition(globalPosition);
    if (localPosition == null) {
      return;
    }

    final renderObject = _gameKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox) {
      return;
    }

    if (!_isOverCat(localPosition)) {
      setState(() {});
      return;
    }

    _playGroomingSoundOnSwipe('scissors.wav', localPosition);
    if (_lastTrimPosition != null) {
      _trimPassMovement += (localPosition - _lastTrimPosition!).distance;
    }
    _lastTrimPosition = localPosition;
    _moveLiveFurParticles(localPosition, dense: true);

    // Update the displayed fur stage during the swipe, not on pointer release.
    // Each 220px of actual movement over the cat advances one visual stage,
    // making fur shortening feel slower and more deliberate.
    // Multiple stages can advance during the same drag if enough movement
    // accumulates; this is intentionally not gated by pointer release.
    var stageChanged = false;
    // Allow more than one fur-stage transition during a single continuous
    // drag. Keeping the remaining movement lets Fur2 -> Fur1 -> Fur0 happen
    // naturally as the scissors continue moving, without requiring release
    // and a second drag.
    while (_trimPassMovement >= 220 && _currentFurStage > 0) {
      final previousStage = _currentFurStage;
      _trimPassMovement -= 220;
      _currentFurStage = (_currentFurStage - 1).clamp(0, 2).toInt();
      stageChanged = previousStage != _currentFurStage;

      if (_currentFurStage == 0) {
        _trimFinished = true;
      }
    }

    setState(() {});

    // A pass is active while scissors travel over the cat.
    _trimPassStartX ??= localPosition.dx;

    if (stageChanged) {
      unawaited(
        context.read<VirtualPetProvider>().trimFurToStage(_currentFurStage),
      );
    }
  }

  Future<void> _finishTrimDrag() async {
    _stopGroomingSound();
    if (!_trimDragging) {
      return;
    }

    setState(() {
      _trimDragging = false;
    });

    // Fur stages are updated in real time inside _moveTrim while swiping.
    _trimPassStartX = null;

    _trimPassMovement = 0;

    if (_trimFinished) {
      if (!context.mounted) return;

      widget.onAction('groom');

      // Finishing a trim must leave the player in the Groom screen so they
      // can choose another tool or return manually with the back button.
      setState(() {
        _trimFinished = false;
        _trimMode = false;
        _trimDragging = false;
        _lastTrimPosition = null;
        _lastFurSpawnPosition = null;
        _feedbackText = '';
      });
      return;
    }

    setState(() {
      // Keep trimming mode and the current visual stage between swipes.
      _lastTrimPosition = null;
      _lastFurSpawnPosition = null;
    });
  }

  Widget _trimFeedback(Map<String, dynamic> item) {
    return Material(
      color: Colors.transparent,
      child: Text(
        item['emoji'] as String,
        style: const TextStyle(fontSize: 46),
      ),
    );
  }

  Widget _trimDraggable(Map<String, dynamic> item) {
    return Draggable<String>(
      data: 'Trim',
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: _startTrimDrag,
      onDragUpdate: (details) {
        _moveTrim(details.globalPosition);
      },
      onDragEnd: (_) {
        unawaited(_finishTrimDrag());
      },
      feedback: _trimFeedback(item),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _toolCard(item),
      ),
      child: _toolCard(item),
    );
  }

  // TOOL CARD

  Color _shopCardColor(Map<String, dynamic> item, Color fallback) {
    final rewards = context.watch<RewardService>();
    final equippedId = rewards.equippedShopItem('item_grooming');
    if (equippedId == null) return fallback;

    final itemName = (item['name'] as String).toLowerCase().replaceAll(' ', '');
    final idParts = equippedId.split('_');
    if (idParts.length < 3 || idParts.first != 'grooming') {
      return fallback;
    }
    final equippedItemName = idParts.sublist(1, idParts.length - 1).join('');
    if (equippedItemName != itemName) return fallback;

    switch (idParts.last) {
      case 'mint':
        return const Color(0xFFDDF4E7);
      case 'pink':
        return const Color(0xFFFFDCE8);
      case 'blue':
        return const Color(0xFFD9EEFF);
      case 'lilac':
        return const Color(0xFFEADFFF);
      case 'peach':
        return const Color(0xFFFFE2D4);
      case 'u1':
        return const Color(0xFFFFF09B);
      case 'u2':
        return const Color(0xFF9DEBE8);
      case 'u3':
        return const Color(0xFFFFA6B7);
      case 'u4':
        return const Color(0xFFC9E0B5);
      case 'u5':
        return const Color(0xFFB9C5FF);
      default:
        return fallback;
    }
  }

  Widget _toolCard(
    Map<String, dynamic> item,
  ) {
    final name = item['name'] as String;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _shopCardColor(item, item['color'] as Color),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (item['emoji'] != null)
            Text(
              item['emoji'] as String,
              style: const TextStyle(
                fontSize: 34,
              ),
            )
          else
            Image.asset(
              'assets/images/items/${item['image']}',
              height: 38,
              fit: BoxFit.contain,
            ),
          const SizedBox(
            height: 4,
          ),
          Text(
            name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _draggable(
    Map<String, dynamic> item,
  ) {
    final name = item['name'] as String;

    if (name == 'Shower') {
      return _showerDraggable(item);
    }

    if (name == 'Blower') {
      return _blowerDraggable(item);
    }

    if (name == 'Towel') {
      return _towelDraggable(item);
    }

    if (name == 'Soap') {
      return Draggable<String>(
        data: 'Soap',
        dragAnchorStrategy: pointerDragAnchorStrategy,
        onDragStarted: _startSoapDrag,
        onDragUpdate: (details) {
          _moveSoap(
            details.globalPosition,
          );
        },
        onDragEnd: (_) {
          _finishSoap();
        },
        feedback: const Material(
          color: Colors.transparent,
          child: Text(
            '🧼',
            style: TextStyle(
              fontSize: 46,
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.3,
          child: _toolCard(item),
        ),
        child: _toolCard(item),
      );
    }

    if (name == 'Trim') {
      return _trimDraggable(item);
    }

    if (name == 'Brush') {
      return _brushDraggable(item);
    }

    return GestureDetector(
      onTap: () {
        _groom(name);
      },
      child: _toolCard(item),
    );
  }

  void _onDayPeriodChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _groomingSoundIdleTimer?.cancel();
    _stopGroomingSound();
    unawaited(GlobalMusicService.instance.stopSfx());
    dayPeriodNotifier.removeListener(_onDayPeriodChanged);
    _cancelShowerInteraction();
    _groomGame.stopBlower();
    _groomGame.pauseEngine();
    _sadCatGame.pauseEngine();
    _blowerPose.dispose();
    _furParticleTimer?.cancel();

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final pet = context.watch<VirtualPetProvider>();

    // Care conditions take visual priority over a stale saved sleep state.
    // Keep neglect detection unchanged; critical hunger or dirt wakes the
    // visual state so the player can see the cat's current needs.
    final isSleeping =
        pet.isSleeping && pet.hunger < 90 && pet.cleanliness > 30;
    final isNeglected =
        pet.hunger >= 90 && pet.happiness <= 20 && pet.cleanliness <= 20;
    final isSleepy = pet.isSleepy && !isSleeping && !isNeglected;
    final isSad = !isSleeping && !isNeglected && !isSleepy && pet.isSadOrHungry;
    final isNight = NighttimeMode.isNighttime();
    final needsCareAtNight =
        isNeglected || pet.isDirty || pet.furStage > 0 || pet.hunger >= 70;
    final showCat =
        isNeglected || (!isSleeping && (!isNight || needsCareAtNight));
    // Active grooming interactions must keep control of the Flame cat
    // animation. In particular, do not call showSad() on every rebuild while
    // the shower timer is running, because that can repeatedly replace the
    // wet animation and make the shower appear to pause.
    final groomingInteractionActive = _showerDragging ||
        _blowerDragging ||
        _towelDragging ||
        _soapDragging ||
        _trimMode ||
        _brushDragging ||
        _trimDragging;

    // While Fur1/Fur2 is present, keep that fur artwork visible even when
    // care stats are critical. During trimming, use the live visual stage
    // (_currentFurStage) rather than the provider's not-yet-committed stage.
    final trimmingVisualActive = _trimMode || _trimDragging || _trimFinished;
    final visibleFurStage =
        trimmingVisualActive ? _currentFurStage : pet.furStage;

    _groomGame.setFurStage(visibleFurStage);

    if (!groomingInteractionActive) {
      if (visibleFurStage > 0) {
        // Explicitly select the current fur-stage idle after each trim pass.
        // This keeps Fur2 -> Fur1 visible even while provider state is still
        // awaiting the completed trim commit.
        _groomGame.showFurIdle(visibleFurStage, force: true);
      } else if (isSleepy) {
        _sleepyCatGame.enterSleepy();
      } else if (isNeglected || isSad) {
        // Care status is applied only after the trim has reached Fur0.
        _groomGame.showSad();
      } else {
        _groomGame.showIdle();
      }
    }

    _groomGame.setDirt(
      visible: pet.isDirty,
      heavy: isNeglected,
      // Dirt fades smoothly as the shower stays over the cat. The provider's
      // cleanliness is only completed at the end, so the visual wash does not
      // instantly turn the cat clean.
      opacity: (1.0 - _showerCleanProgress).clamp(0.0, 1.0).toDouble(),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFFE6CC),
      body: Stack(
        children: [
          const ShopSceneBackground(slot: 'background_groom'),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    8,
                    4,
                    16,
                    0,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          size: 20,
                        ),
                        onPressed: () {
                          Navigator.pop(
                            context,
                            {
                              'cleanliness': pet.cleanliness,
                              'isDirty': pet.isDirty,
                              'furStage': _currentFurStage,
                            },
                          );
                        },
                      ),
                      const Expanded(
                        child: Text(
                          '✂️  Groom Your Cat',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Use the grooming tools to care for your cat!',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFAA7755),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.cleaning_services,
                        color: Color(0xFF7B68EE),
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Cleanliness: ${pet.cleanliness}%',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7A3B1E),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Stack(
                  children: [
                    DragTarget<String>(
                      onWillAcceptWithDetails: (details) {
                        if (_isGroomingBlockedByHunger(pet)) {
                          return false;
                        }
                        return !isSleeping || isNeglected;
                      },
                      onAcceptWithDetails: (details) {
                        if (details.data == 'Soap') {
                          _finishSoap();
                        }

                        if (details.data == 'Shower') {
                          _finishShower();
                        }

                        if (details.data == 'Blower') {
                          _finishBlower();
                        }

                        if (details.data == 'Towel') {
                          _finishTowel();
                        }
                      },
                      onMove: (details) {
                        if (details.data == 'Soap') {
                          _moveSoap(
                            details.offset,
                          );
                        }
                      },
                      builder: (
                        _,
                        __,
                        ___,
                      ) {
                        return AnimatedContainer(
                          key: _roomKey,
                          duration: const Duration(
                            milliseconds: 200,
                          ),
                          height: 220,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: _hovering
                                  ? const Color(0xFF7B68EE)
                                  : Colors.transparent,
                              width: _hovering ? 3 : 0,
                            ),
                            boxShadow: _hovering
                                ? [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF7B68EE,
                                      ).withValues(
                                        alpha: 0.35,
                                      ),
                                      blurRadius: 16,
                                    ),
                                  ]
                                : null,
                            image: DecorationImage(
                              image: AssetImage(
                                roomAsset(
                                  dayPeriodNotifier.value,
                                  day:
                                      'assets/images/cat_room/groom_cat_room.png',
                                  noon:
                                      'assets/images/cat_room/groom_cat_roomnoon.png',
                                  night:
                                      'assets/images/cat_room/groom_cat_roomnight.png',
                                ),
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Stack(
                            children: [
                              const Positioned(
                                top: 10,
                                right: 12,
                                child: RealtimeClock(),
                              ),
                              // Sleeping = no cat shown.
                              //
                              // Neglected = cat remains visible
                              // using the SAME sad animation.
                              if (showCat)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Center(
                                      child: SizedBox(
                                        width: 180,
                                        height: 170,
                                        child: Stack(
                                          clipBehavior: Clip.none,
                                          children: [
                                            Positioned.fill(
                                              child: GameWidget(
                                                key: _gameKey,
                                                game: isSleepy
                                                    ? _sleepyCatGame
                                                    : _groomGame,
                                                loadingBuilder: (_) =>
                                                    const SizedBox.shrink(),
                                                errorBuilder: (
                                                  _,
                                                  __,
                                                ) =>
                                                    const SizedBox.shrink(),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Feedback message.
                    if (_feedbackText.isNotEmpty &&
                        (!isSleeping || _feedbackText.startsWith('🌙')))
                      Positioned(
                        // Keep feedback below the room clock and above the cat.
                        bottom: 130,
                        left: 16,
                        right: 16,
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: 270,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(
                                  alpha: 0.85,
                                ),
                                borderRadius: BorderRadius.circular(
                                  20,
                                ),
                              ),
                              child: Text(
                                _feedbackText,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF7A3B1E),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    if (_liveFurParticles.isNotEmpty)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _LiveFurParticlePainter(
                              particles: List<_LiveFurParticle>.of(
                                _liveFurParticles,
                              ),
                              now: DateTime.now(),
                            ),
                          ),
                        ),
                      ),

                    // Existing grooming sparkles.
                    ...List.generate(
                      _sparkleCount,
                      (i) => Positioned(
                        left: (MediaQuery.sizeOf(context).width / 2) -
                            48 +
                            ((i % 3) * 24).toDouble(),
                        bottom: 92 + ((i % 2) * 22).toDouble(),
                        child: const Text(
                          '✨',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                    itemCount: _tools.length,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 120,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemBuilder: (_, i) {
                      return _draggable(
                        _tools[i],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveFurParticle {
  final Offset position;
  final Offset velocity;
  final double angle;
  final double length;
  final double thickness;
  final Color color;
  final DateTime createdAt;
  final int seed;

  const _LiveFurParticle({
    required this.position,
    required this.velocity,
    required this.angle,
    required this.length,
    required this.thickness,
    required this.color,
    required this.createdAt,
    required this.seed,
  });
}

class _LiveFurParticlePainter extends CustomPainter {
  final List<_LiveFurParticle> particles;
  final DateTime now;

  const _LiveFurParticlePainter({
    required this.particles,
    required this.now,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final particle in particles) {
      final elapsed = now.difference(particle.createdAt).inMilliseconds;
      final t = (elapsed / 850).clamp(0.0, 1.0);
      final drift = particle.velocity * t;
      final gravity = 18 * t * t;
      final position = particle.position + drift + Offset(0, gravity);
      final opacity = (1 - Curves.easeOut.transform(t)).clamp(0.0, 1.0);

      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(particle.angle + t * 0.9);
      _drawFurStrand(
        canvas,
        particle.length,
        particle.thickness,
        particle.color.withValues(alpha: opacity),
        particle.seed,
      );
      canvas.restore();
    }
  }

  void _drawFurStrand(
    Canvas canvas,
    double length,
    double thickness,
    Color color,
    int seed,
  ) {
    // Long, curved and tapered like the supplied loose-fur reference.
    final main = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    final highlight = Paint()
      ..color = color.withValues(alpha: color.a * 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.4, thickness * 0.45)
      ..strokeCap = StrokeCap.round;

    final variation = ((seed % 100) / 100.0) - 0.5;

    final mainPath = Path()
      ..moveTo(-length * 0.5, 0)
      ..cubicTo(
        -length * 0.22,
        -4 + variation * 3,
        length * 0.10,
        5 + variation * 4,
        length * 0.5,
        -1 + variation * 2,
      );

    canvas.drawPath(mainPath, main);

    // Several very fine internal strands make it look like actual fur,
    // rather than a single brown line.
    final fine1 = Path()
      ..moveTo(-length * 0.43, 1.4)
      ..cubicTo(
        -length * 0.15,
        -1.5,
        length * 0.15,
        3.5,
        length * 0.43,
        -0.5,
      );

    final fine2 = Path()
      ..moveTo(-length * 0.31, -0.8)
      ..cubicTo(
        -length * 0.05,
        -3,
        length * 0.22,
        2,
        length * 0.38,
        -2.2,
      );

    canvas.drawPath(fine1, highlight);
    canvas.drawPath(fine2, highlight);

    final fiber = Paint()
      ..color = color.withValues(alpha: color.a * 0.72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = max(0.3, thickness * 0.5)
      ..strokeCap = StrokeCap.round;

    final fiber1 = Path()
      ..moveTo(-length * 0.13, 0)
      ..quadraticBezierTo(
        -length * 0.05,
        -4.5,
        length * 0.02,
        -6.5,
      );
    final fiber2 = Path()
      ..moveTo(length * 0.10, 1.5)
      ..quadraticBezierTo(
        length * 0.19,
        5,
        length * 0.29,
        6,
      );

    canvas.drawPath(fiber1, fiber);
    canvas.drawPath(fiber2, fiber);
  }

  @override
  bool shouldRepaint(covariant _LiveFurParticlePainter oldDelegate) => true;
}
