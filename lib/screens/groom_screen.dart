import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flame/game.dart';

import '../services/activity_service.dart';
import '../game/groom.dart';

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

  final _random = Random();

  late int cleanliness;
  late bool isDirty;

  final int _furStage = 3;

  late final GroomGame _groomGame;

  final GlobalKey _gameKey = GlobalKey();

  int _groomProgress = 0;

  bool _hovering = false;

  bool _trimMode = false;
  bool _soapMode = false;

  bool _isCutting = false;

  bool _soapDragging = false;
  bool _showerDragging = false;
  bool _blowerDragging = false;
  bool _towelDragging = false;

  Offset _scissorPosition = const Offset(0, 0);

  int _currentFurStage = 3;

  bool _trimFinished = false;

  String _feedbackText = '';

  int _sparkleCount = 0;

  Offset? _lastSoapPosition;

  Offset? _lastTowelPosition;

  final ValueNotifier<_BlowerPose> _blowerPose = ValueNotifier<_BlowerPose>(
    _BlowerPose(
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

    cleanliness = widget.cleanliness;

    isDirty = widget.isDirty;

    _currentFurStage = _furStage;
  }

  String _getHair() {
    if (cleanliness >= 70) {
      return 'clean';
    }

    if (cleanliness >= 40) {
      return 'messy';
    }

    return 'very_messy';
  }

  void _groom(String tool) {
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

      // Keep the existing sparkle
      // behavior for Brush and Trim.
      if (tool == 'Brush' || tool == 'Trim') {
        _sparkleCount = 8;
      } else {
        _sparkleCount = 0;
      }
    });

    widget.onAction(
      'groom',
    );

    _service.logActivity(
      icon: Icons.content_cut,
      iconColor: const Color(0xFF7B68EE),
      title: 'Groomed cat — $tool',
    );

    Future.delayed(
      const Duration(
        milliseconds: 700,
      ),
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

  // SOAP

  void _addSoapBubble(
    Offset globalPosition,
  ) {
    final localPosition = _gameLocalPosition(
      globalPosition,
    );

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
    setState(() {
      _soapDragging = true;
      _soapMode = true;

      _trimMode = false;
      _isCutting = false;

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

    _addSoapBubble(
      globalPosition,
    );
  }

  void _finishSoap() {
    if (!_soapDragging) {
      return;
    }

    setState(() {
      _soapDragging = false;
      _soapMode = false;
      _lastSoapPosition = null;
      _feedbackText = '';
    });

    _groom('Soap');
  }

  // SHOWER

  void _startShowerDrag() {
    setState(() {
      _showerDragging = true;

      _soapMode = false;
      _soapDragging = false;

      _blowerDragging = false;
      _towelDragging = false;

      _trimMode = false;
      _isCutting = false;

      _feedbackText = 'Wash the cat 🚿';
    });
  }

  void _moveShower(
    Offset globalPosition,
  ) {
    if (!_showerDragging) {
      return;
    }

    final localPosition = _gameLocalPosition(
      globalPosition,
    );

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

    _groomGame.moveShower(
      showerCenter,
    );
  }

  void _finishShower() {
    if (!_showerDragging) {
      return;
    }

    _groomGame.stopShower();

    setState(() {
      _showerDragging = false;
      _feedbackText = '';
    });

    _groom('Shower');
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
    _blowerPose.value = const _BlowerPose(
      flipped: false,
    );

    setState(() {
      _blowerDragging = true;

      _soapMode = false;
      _soapDragging = false;

      _showerDragging = false;
      _towelDragging = false;

      _trimMode = false;
      _isCutting = false;

      _feedbackText = 'Dry the cat 💨';
    });
  }

  void _moveBlower(
    Offset globalPosition,
  ) {
    if (!_blowerDragging) {
      return;
    }

    final localPosition = _gameLocalPosition(
      globalPosition,
    );

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

    // No up/down rotation.
    // Only flip left/right.
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
              scaleX: pose.flipped ? -1 : 1,
              child: child,
            );
          },
          child: Image.asset(
            'assets/images/items/$image',
            width: 80,
            height: 80,
            fit: BoxFit.contain,
          ),
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
    setState(() {
      _towelDragging = true;

      _soapMode = false;
      _soapDragging = false;

      _showerDragging = false;
      _blowerDragging = false;

      _trimMode = false;
      _isCutting = false;

      _lastTowelPosition = null;

      _feedbackText = 'Dry the cat 🧺';
    });
  }

  void _moveTowel(
    Offset globalPosition,
  ) {
    if (!_towelDragging) {
      return;
    }

    final localPosition = _gameLocalPosition(
      globalPosition,
    );

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
      roomSize.width - 64,
    );

    final maxY = max(
      0.0,
      roomSize.height - 64,
    );

    final clampedPosition = Offset(
      localPosition.dx.clamp(0.0, maxX),
      localPosition.dy.clamp(0.0, maxY),
    );

    _lastTowelPosition = clampedPosition;

    final towelCenter = clampedPosition +
        const Offset(
          32,
          32,
        );

    _groomGame.towelSwipe(
      towelCenter,
    );
  }

  void _finishTowel() {
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
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        width: 64,
        height: 64,
        child: Image.asset(
          'assets/images/items/${item['image']}',
          width: 64,
          height: 64,
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

  // TOOL CARD

  Widget _toolCard(
    Map<String, dynamic> item,
  ) {
    final image = item['image'] as String?;

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: item['color'] as Color,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(2, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (image != null)
            SizedBox(
              width: 42,
              height: 42,
              child: Image.asset(
                'assets/images/items/$image',
                fit: BoxFit.contain,
              ),
            )
          else
            Text(
              item['emoji'] as String,
              style: const TextStyle(
                fontSize: 28,
              ),
            ),
          const SizedBox(
            height: 5,
          ),
          Text(
            item['name'] as String,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // SOAP DRAGGABLE

  Widget _soapDraggable(
    Map<String, dynamic> item,
  ) {
    return Draggable<String>(
      data: 'Soap',
      onDragStarted: _startSoapDrag,
      onDragEnd: (_) {
        _finishSoap();
      },
      feedback: Material(
        color: Colors.transparent,
        child: Text(
          item['emoji'] as String,
          style: const TextStyle(
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

  // ALL DRAGGABLE TOOLS

  Widget _draggable(
    Map<String, dynamic> item,
  ) {
    final name = item['name'] as String;

    if (name == 'Soap') {
      return _soapDraggable(
        item,
      );
    }

    if (name == 'Shower') {
      return _showerDraggable(
        item,
      );
    }

    if (name == 'Blower') {
      return _blowerDraggable(
        item,
      );
    }

    if (name == 'Towel') {
      return _towelDraggable(
        item,
      );
    }

    // Brush and Trim stay
    // on their existing path.

    return Draggable<String>(
      data: name,
      feedback: Material(
        color: Colors.transparent,
        child: item['image'] != null
            ? SizedBox(
                width: 80,
                height: 80,
                child: Image.asset(
                  'assets/images/items/${item['image']}',
                  fit: BoxFit.contain,
                ),
              )
            : Text(
                item['emoji'] as String,
                style: const TextStyle(
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

  @override
  void dispose() {
    _groomGame.stopShower();
    _groomGame.stopBlower();
    _groomGame.pauseEngine();
    _blowerPose.dispose();

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final hair = _getHair();

    return Scaffold(
      backgroundColor: const Color(0xFFFFE6CC),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.12,
              child: Image.asset(
                'assets/images/paws_bg.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
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
                              'cleanliness': cleanliness,
                              'isDirty': isDirty,
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
                const SizedBox(
                  height: 4,
                ),
                const Text(
                  'Drag grooming tools to your cat!',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFAA7755),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Grooming Progress',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(
                                0xFFAA7755,
                              ),
                            ),
                          ),
                          Text(
                            '${(_groomProgress / 10 * 100).clamp(0, 100).round()}%',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(
                                0xFF7B68EE,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 4,
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          8,
                        ),
                        child: LinearProgressIndicator(
                          value: (_groomProgress / 10).clamp(
                            0,
                            1,
                          ),
                          minHeight: 8,
                          backgroundColor: const Color(
                            0xFF7B68EE,
                          ).withValues(
                            alpha: 0.15,
                          ),
                          valueColor: const AlwaysStoppedAnimation(
                            Color(
                              0xFF7B68EE,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 8,
                ),
                Stack(
                  children: [
                    DragTarget<String>(
                      onWillAcceptWithDetails: (details) {
                        setState(() {
                          _hovering = true;
                        });

                        return true;
                      },
                      onMove: (details) {
                        if (details.data == 'Soap') {
                          _moveSoap(
                            details.offset,
                          );
                        }
                      },
                      onLeave: (_) {
                        setState(() {
                          _hovering = false;
                        });
                      },
                      onAcceptWithDetails: (details) {
                        setState(() {
                          _hovering = false;
                        });

                        if (details.data == 'Trim') {
                          setState(() {
                            _trimMode = true;
                            _soapMode = false;
                            _soapDragging = false;
                            _showerDragging = false;
                            _blowerDragging = false;
                            _towelDragging = false;
                            _lastSoapPosition = null;
                          });

                          return;
                        }

                        if (details.data == 'Shower') {
                          return;
                        }

                        if (details.data == 'Blower') {
                          return;
                        }

                        if (details.data == 'Towel') {
                          return;
                        }

                        if (details.data == 'Brush') {
                          _groom(
                            'Brush',
                          );

                          return;
                        }

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
                        return GestureDetector(
                          onPanStart: (details) {
                            if (!_trimMode) {
                              return;
                            }

                            setState(() {
                              _isCutting = true;
                              _scissorPosition = details.localPosition;
                            });
                          },
                          onPanUpdate: (details) {
                            if (!_trimMode) {
                              return;
                            }

                            setState(() {
                              _scissorPosition = details.localPosition;
                            });

                            if (_currentFurStage == 3 &&
                                details.localPosition.dx > 80) {
                              setState(() {
                                _currentFurStage = 2;
                              });
                            }

                            if (_currentFurStage == 2 &&
                                details.localPosition.dx > 160) {
                              setState(() {
                                _currentFurStage = 1;
                              });
                            }

                            if (_currentFurStage == 1 &&
                                details.localPosition.dx > 240) {
                              setState(() {
                                _trimFinished = true;
                                _trimMode = false;
                              });
                            }
                          },
                          onPanEnd: (_) async {
                            if (!_trimMode) {
                              return;
                            }

                            setState(() {
                              _isCutting = false;
                            });

                            if (_currentFurStage == 1) {
                              await Future.delayed(
                                const Duration(
                                  milliseconds: 250,
                                ),
                              );

                              widget.onAction(
                                'groom',
                              );

                              if (!mounted) {
                                return;
                              }

                              Navigator.pop(
                                context,
                                {
                                  'cleanliness': 100,
                                  'isDirty': false,
                                  'furStage': 0,
                                  'showCleanBubble': true,
                                },
                              );
                            }
                          },
                          child: Container(
                            height: 200,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(
                                22,
                              ),
                              border: Border.all(
                                color: _hovering
                                    ? const Color(
                                        0xFF7B68EE,
                                      )
                                    : Colors.transparent,
                                width: _hovering ? 3 : 0,
                              ),
                              boxShadow: _hovering
                                  ? [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF7B68EE,
                                        ).withValues(
                                          alpha: 0.3,
                                        ),
                                        blurRadius: 16,
                                      ),
                                    ]
                                  : null,
                              image: const DecorationImage(
                                image: AssetImage(
                                  'assets/images/cat_room/groom_cat_room.png',
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                            child: Stack(
                              children: [
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: GameWidget(
                                      key: _gameKey,
                                      game: _groomGame,
                                      loadingBuilder: (_) =>
                                          const SizedBox.shrink(),
                                      errorBuilder: (_, __) =>
                                          const SizedBox.shrink(),
                                    ),
                                  ),
                                ),
                                if (_trimMode && _isCutting)
                                  Positioned(
                                    left: _scissorPosition.dx - 20,
                                    top: _scissorPosition.dy - 20,
                                    child: IgnorePointer(
                                      child: Transform.rotate(
                                        angle: -0.4,
                                        child: const Text(
                                          '✂️',
                                          style: TextStyle(
                                            fontSize: 42,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                    // Existing Brush/Trim sparkle effect.
                    ...List.generate(
                      _sparkleCount,
                      (i) => Positioned(
                        left: 30 + _random.nextDouble() * 200,
                        bottom: 60 + _random.nextDouble() * 100,
                        child: const Text(
                          '✨',
                          style: TextStyle(
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      top: 12,
                      left: 0,
                      right: 0,
                      child: AnimatedOpacity(
                        duration: const Duration(
                          milliseconds: 300,
                        ),
                        opacity: _feedbackText.isEmpty ? 0 : 1,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
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
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(
                                  0xFF7A3B1E,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 12,
                ),
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
                const SizedBox(
                  height: 8,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
