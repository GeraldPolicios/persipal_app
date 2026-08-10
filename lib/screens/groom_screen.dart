// screens/groom_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/activity_service.dart';

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
  int _furStage = 3;
  int _groomProgress = 0;
  bool _hovering = false;
  bool _trimMode = false;
  bool _isCutting = false;
  Offset _scissorPosition = const Offset(0, 0);
  int _currentFurStage = 3;
  bool _trimFinished = false;

  String _feedbackText = '';
  int _sparkleCount = 0;

  final List<Map<String, dynamic>> _tools = const [
    {'emoji': '🧼', 'name': 'Soap', 'color': Color(0xFFE1F5FE)},
    {'emoji': '🚿', 'name': 'Shower', 'color': Color(0xFFB3E5FC)},
    {'emoji': '✂️', 'name': 'Trim', 'color': Color(0xFFFFCDD2)},
    {'emoji': '🪮', 'name': 'Brush', 'color': Color(0xFFFFE0B2)},
  ];

  @override
  void initState() {
    super.initState();
    cleanliness = widget.cleanliness;
    isDirty = widget.isDirty;

    if (cleanliness >= 70) {
      _currentFurStage = _furStage;
    } else if (cleanliness >= 40) {
      _currentFurStage = _furStage;
    } else {
      _currentFurStage = _furStage;
    }
  }

  String _getHair() {
    if (cleanliness >= 70) return 'clean';
    if (cleanliness >= 40) return 'messy';
    return 'very_messy';
  }

  void _groom(String tool) {
    setState(() {
      _groomProgress += 1;
      if (tool == 'Shower' || tool == 'Soap') _groomProgress += 1;
      if (tool == 'Brush') _groomProgress += 1;

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
      _sparkleCount = 8;
    });

    widget.onAction('groom');

    // Log to activity service
    _service.logActivity(
      icon: Icons.content_cut,
      iconColor: const Color(0xFF7B68EE),
      title: 'Groomed cat — $tool',
    );

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _sparkleCount = 0;
        _feedbackText = '';
      });
    });
  }

  Widget _toolCard(Map<String, dynamic> item) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: item['color'] as Color,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(2, 4)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(item['emoji'] as String, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 5),
          Text(item['name'] as String,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _draggable(Map<String, dynamic> item) {
    return Draggable<String>(
      data: item['name'] as String,
      feedback: Material(
        color: Colors.transparent,
        child:
            Text(item['emoji'] as String, style: const TextStyle(fontSize: 46)),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _toolCard(item)),
      child: _toolCard(item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hair = _getHair();

    return Scaffold(
      backgroundColor: const Color(0xFFFFE6CC),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.12,
              child:
                  Image.asset('assets/images/paws_bg.png', fit: BoxFit.cover),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        onPressed: () => Navigator.pop(context, {
                          'cleanliness': cleanliness,
                          'isDirty': isDirty,
                        }),
                      ),
                      const Expanded(
                        child: Text(
                          '✂️  Groom Your Cat',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),
                const Text(
                  'Drag grooming tools to your cat!',
                  style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFAA7755),
                      fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 8),

                // Progress bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Grooming Progress',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFAA7755))),
                          Text(
                              '${(_groomProgress / 10 * 100).clamp(0, 100).round()}%',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF7B68EE))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (_groomProgress / 10).clamp(0, 1),
                          minHeight: 8,
                          backgroundColor:
                              const Color(0xFF7B68EE).withValues(alpha: 0.15),
                          valueColor:
                              const AlwaysStoppedAnimation(Color(0xFF7B68EE)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Drop zone
                Stack(
                  children: [
                    DragTarget<String>(
                        onWillAcceptWithDetails: (_) {
                          setState(() => _hovering = true);
                          return true;
                        },
                        onLeave: (_) => setState(() => _hovering = false),
                        onAcceptWithDetails: (details) {
                          setState(() {
                            _hovering = false;
                          });

                          if (details.data == 'Trim') {
                            setState(() {
                              _trimMode = true;
                            });

                            return;
                          }

                          _groom(details.data);
                        },
                        builder: (_, __, ___) => GestureDetector(
                            onPanStart: (details) {
                              if (!_trimMode) return;

                              setState(() {
                                _isCutting = true;
                                _scissorPosition = details.localPosition;
                              });
                            },
                            onPanUpdate: (details) {
                              if (!_trimMode) return;

                              setState(() {
                                _scissorPosition = details.localPosition;
                              });

                              // swipe distance controls trimming
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
                              if (!_trimMode) return;

                              setState(() {
                                _isCutting = false;
                              });

                              if (_currentFurStage == 1) {
                                await Future.delayed(
                                    const Duration(milliseconds: 250));

                                widget.onAction('groom');

                                if (!mounted) return;

                                Navigator.pop(context, {
                                  'cleanliness': 100,
                                  'isDirty': false,
                                  'furStage': 0,
                                  'showCleanBubble': true,
                                });
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 200,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 16),
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
                                          color: const Color(0xFF7B68EE)
                                              .withValues(alpha: 0.3),
                                          blurRadius: 16,
                                        ),
                                      ]
                                    : null,
                                image: const DecorationImage(
                                  image: AssetImage(
                                      'assets/images/cat_room/groom_cat_room.png'),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 16),
                                      child: AnimatedSwitcher(
                                        duration:
                                            const Duration(milliseconds: 300),
                                        child: AnimatedSwitcher(
                                          duration:
                                              const Duration(milliseconds: 250),
                                          child: _trimFinished
                                              ? Image.asset(
                                                  isDirty
                                                      ? 'assets/images/states/dirty.png'
                                                      : 'assets/images/idle/idle_0001.png',
                                                  key: ValueKey(isDirty
                                                      ? 'dirty'
                                                      : 'idle'),
                                                  height: 95,
                                                )
                                              : Image.asset(
                                                  'assets/images/states/fur_cat$_currentFurStage.png',
                                                  key: ValueKey(
                                                      _currentFurStage),
                                                  height: 95,
                                                ),
                                        ),
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
                                            "✂️",
                                            style: TextStyle(
                                              fontSize: 42,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ))),

                    // Sparkles
                    ...List.generate(
                        _sparkleCount,
                        (i) => Positioned(
                              left: 30 + _random.nextDouble() * 200,
                              bottom: 60 + _random.nextDouble() * 100,
                              child: const Text('✨',
                                  style: TextStyle(fontSize: 18)),
                            )),

                    // Feedback
                    Positioned(
                      top: 12,
                      left: 0,
                      right: 0,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: _feedbackText.isEmpty ? 0 : 1,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _feedbackText,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF7A3B1E),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Tool grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _tools.length,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 120,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemBuilder: (_, i) => _draggable(_tools[i]),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
