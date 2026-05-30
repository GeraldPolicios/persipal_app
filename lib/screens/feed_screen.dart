// screens/feed_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/activity_service.dart';

class FeedScreen extends StatefulWidget {
  final int hunger;
  final int happiness;
  final int cleanliness;
  final Function(int hunger, int happiness, int cleanliness) onUpdate;

  const FeedScreen({
    super.key,
    required this.hunger,
    required this.happiness,
    required this.cleanliness,
    required this.onUpdate,
  });

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _service = ActivityService.instance;
  final _random = Random();

  late int hunger;
  late int happiness;
  late int cleanliness;

  bool _hovering = false;
  String _feedbackText = '';
  int _heartCount = 0;

  final List<Map<String, dynamic>> _foods = const [
    {'emoji': '🍗', 'name': 'Dry Food', 'color': Color(0xFFFFE0B2)},
    {'emoji': '🥫', 'name': 'Wet Food', 'color': Color(0xFFFFCDD2)},
    {'emoji': '🐟', 'name': 'Fish', 'color': Color(0xFFB3E5FC)},
    {'emoji': '🥛', 'name': 'Milk', 'color': Color(0xFFE1F5FE)},
    {'emoji': '💧', 'name': 'Water', 'color': Color(0xFFBBDEFB)},
    {'emoji': '🍖', 'name': 'Treat', 'color': Color(0xFFFFCCBC)},
  ];

  @override
  void initState() {
    super.initState();
    hunger = widget.hunger;
    happiness = widget.happiness;
    cleanliness = widget.cleanliness;
  }

  void _feed(String food) {
    String feedback;
    setState(() {
      switch (food) {
        case 'Dry Food':
          hunger = (hunger - 25).clamp(0, 100);
          happiness = (happiness + 5).clamp(0, 100);
          feedback = 'Crunchy! 😺';
          break;
        case 'Wet Food':
          hunger = (hunger - 20).clamp(0, 100);
          happiness = (happiness + 10).clamp(0, 100);
          feedback = 'Yummy! 😻';
          break;
        case 'Fish':
          hunger = (hunger - 15).clamp(0, 100);
          happiness = (happiness + 20).clamp(0, 100);
          feedback = 'Fishy treat 🐟';
          break;
        case 'Milk':
          hunger = (hunger - 10).clamp(0, 100);
          happiness = (happiness + 15).clamp(0, 100);
          cleanliness = (cleanliness + 5).clamp(0, 100);
          feedback = 'Milk time 🥛';
          break;
        case 'Water':
          cleanliness = (cleanliness + 10).clamp(0, 100);
          feedback = 'Hydrated 💧';
          break;
        case 'Treat':
          hunger = (hunger - 10).clamp(0, 100);
          happiness = (happiness + 25).clamp(0, 100);
          feedback = 'Treat time!! 🍖';
          break;
        default:
          feedback = '';
      }
      _feedbackText = feedback;
      _heartCount = 6;
    });

    widget.onUpdate(hunger, happiness, cleanliness);

    // Log real activity
    _service.logActivity(
      icon: Icons.restaurant,
      iconColor: const Color(0xFFFF8C69),
      title: 'Fed cat — $food',
    );

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _heartCount = 0;
        _feedbackText = '';
      });
    });
  }

  String _getEmotion() {
    final avg = (happiness + cleanliness + (100 - hunger)) ~/ 3;
    if (avg >= 75) return 'happy';
    if (avg >= 40) return 'normal';
    return 'sad';
  }

  String _getHair() {
    if (cleanliness >= 70) return 'clean';
    if (cleanliness >= 40) return 'messy';
    return 'very_messy';
  }

  Widget _foodCard(Map<String, dynamic> item) {
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
      childWhenDragging: Opacity(opacity: 0.3, child: _foodCard(item)),
      child: _foodCard(item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final emotion = _getEmotion();
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
                          'hunger': hunger,
                          'happiness': happiness,
                          'cleanliness': cleanliness,
                        }),
                      ),
                      const Expanded(
                        child: Text(
                          '🍗  Feed Your Cat',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),
                const Text(
                  'Drag food to your cat to feed it!',
                  style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFAA7755),
                      fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 8),

                // Drop zone
                Stack(
                  children: [
                    DragTarget<String>(
                      onWillAccept: (_) {
                        setState(() => _hovering = true);
                        return true;
                      },
                      onLeave: (_) => setState(() => _hovering = false),
                      onAccept: (data) {
                        setState(() => _hovering = false);
                        _feed(data);
                      },
                      builder: (_, __, ___) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 210,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: _hovering
                                ? const Color(0xFFFF8C69)
                                : Colors.transparent,
                            width: _hovering ? 3 : 0,
                          ),
                          boxShadow: _hovering
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFFF8C69)
                                        .withOpacity(0.35),
                                    blurRadius: 16,
                                  )
                                ]
                              : null,
                          image: const DecorationImage(
                            image: AssetImage('assets/images/cat_bg_room.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Image.asset(
                                'assets/images/cat_${emotion}_$hair.png',
                                key: ValueKey('$emotion$hair'),
                                height: 95,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Floating hearts
                    ...List.generate(
                        _heartCount,
                        (i) => Positioned(
                              left: 40 + _random.nextDouble() * 200,
                              bottom: 70 + _random.nextDouble() * 80,
                              child: Text(
                                ['❤️', '🧡', '💛'][i % 3],
                                style: const TextStyle(fontSize: 20),
                              ),
                            )),

                    // Feedback text
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
                              color: Colors.white.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _feedbackText,
                              style: const TextStyle(
                                fontSize: 18,
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

                // Food grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _foods.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemBuilder: (_, i) => _draggable(_foods[i]),
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
