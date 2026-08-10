// screens/play_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/activity_service.dart';
import '../widgets/play_pet.dart';
import '../widgets/play_thought.dart';
import '../models/dirty_state.dart';

class PlayScreen extends StatefulWidget {
  final Function(String) onAction;
  final bool isDirty;

  const PlayScreen({
    super.key,
    required this.onAction,
    required this.isDirty,
  });

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  final _service = ActivityService.instance;
  final _random = Random();

  bool _hovering = false;

  String _feedbackText = '';
  String _feedbackEmoji = '😺';

  bool _isPlaying = false;
  String? _currentToy;

  final List<Map<String, dynamic>> _toys = const [
    {'emoji': '🎾', 'name': 'Tennis Ball', 'color': Color(0xFFDCEDC8)},
    {'emoji': '🪶', 'name': 'Feather', 'color': Color(0xFFFCE4EC)},
    {'emoji': '🔴', 'name': 'Laser Dot', 'color': Color(0xFFFFEBEE)},
    {'emoji': '🧶', 'name': 'Yarn Ball', 'color': Color(0xFFFFF3E0)},
  ];

  Future<void> _play(String toy) async {
    if (_isPlaying) return;

    if (DirtyState.instance.isDirty) {
      setState(() {
        _feedbackEmoji = "🧼";
        _feedbackText = "Clean me first!";
      });

      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      setState(() {
        _feedbackText = "";
      });

      return;
    }

    final feedback = _getFeedback(toy);

    setState(() {
      _currentToy = toy;
      _isPlaying = true;

      _feedbackEmoji = feedback['emoji']!;
      _feedbackText = feedback['text']!;
    });
    widget.onAction('play');

    _service.logActivity(
      icon: Icons.sports_esports,
      iconColor: const Color(0xFF20B2AA),
      title: 'Played with cat — $toy',
    );

    // Wait for the animation
    int frames = 301;

    switch (toy) {
      case 'Tennis Ball':
        frames = 301;
        break;

      case 'Yarn Ball':
        frames = 302;
        break;

      case 'Laser Dot':
        frames = 302;
        break;

      case 'Feather':
        frames = 302;
        break;
    }

    await Future.delayed(
      Duration(milliseconds: ((frames / 60) * 1000).round()),
    );

    if (!mounted) return;

    setState(() {
      _isPlaying = false;
      _currentToy = null;
    });

    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    setState(() {
      _feedbackText = '';
    });
  }

  Map<String, String> _getFeedback(String toy) {
    switch (toy) {
      case 'Tennis Ball':
        return {
          'emoji': '😆',
          'text': 'Catch!',
        };

      case 'Feather':
        return {
          'emoji': '😻',
          'text': 'Purrr~',
        };

      case 'Laser Dot':
        return {
          'emoji': '😳',
          'text': 'There!',
        };

      case 'Yarn Ball':
        return {
          'emoji': '🤩',
          'text': 'Spin!',
        };

      default:
        return {
          'emoji': '😺',
          'text': 'Meow!',
        };
    }
  }

  Widget _toyCard(Map<String, dynamic> item) {
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
          Text(item['emoji'] as String, style: const TextStyle(fontSize: 30)),
          const SizedBox(height: 5),
          Text(item['name'] as String,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _draggable(Map<String, dynamic> item) {
    if (_isPlaying) {
      return Opacity(
        opacity: .45,
        child: _toyCard(item),
      );
    }

    return Draggable<String>(
      data: item['name'] as String,
      feedback: Material(
        color: Colors.transparent,
        child:
            Text(item['emoji'] as String, style: const TextStyle(fontSize: 50)),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _toyCard(item)),
      child: _toyCard(item),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          '🎾  Play With Your Cat',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),
                const Text(
                  'Drag a toy to your cat to play!',
                  style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFAA7755),
                      fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 10),

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
                        setState(() => _hovering = false);
                        _play(details.data);
                      },
                      builder: (_, __, ___) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 220,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: _hovering
                                ? const Color(0xFF20B2AA)
                                : Colors.transparent,
                            width: _hovering ? 3 : 0,
                          ),
                          boxShadow: _hovering
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF20B2AA)
                                        .withValues(alpha: 0.35),
                                    blurRadius: 16,
                                  )
                                ]
                              : null,
                          image: const DecorationImage(
                            image: AssetImage(
                                'assets/images/cat_room/play_cat_room.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: AnimatedBuilder(
                              animation: DirtyState.instance,
                              builder: (context, child) {
                                return PlayPet(
                                  toy: _currentToy,
                                  isPlaying: _isPlaying,
                                  isDirty: DirtyState.instance.isDirty,
                                  height: 110,
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Feedback
                    if (_feedbackText.isNotEmpty)
                      Positioned(
                        bottom: 118,
                        left: 0,
                        right: 0,
                        child: Center(
                            child: PlayThought(
                          emoji: _feedbackEmoji,
                          text: _feedbackText,
                        )),
                      ),
                  ],
                ),

                const SizedBox(height: 14),

                // Toy grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _toys.length,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 120,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemBuilder: (_, i) => _draggable(_toys[i]),
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
