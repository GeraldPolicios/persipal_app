// screens/play_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/activity_service.dart';

class PlayScreen extends StatefulWidget {
  final Function(String) onAction;

  const PlayScreen({super.key, required this.onAction});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  final _service = ActivityService.instance;
  final _random = Random();

  bool _hovering = false;
  String _feedbackText = '';
  int _starCount = 0;

  final List<Map<String, dynamic>> _toys = const [
    {'emoji': '🎾', 'name': 'Tennis Ball', 'color': Color(0xFFDCEDC8)},
    {'emoji': '🪶', 'name': 'Feather', 'color': Color(0xFFFCE4EC)},
    {'emoji': '🔴', 'name': 'Laser Dot', 'color': Color(0xFFFFEBEE)},
    {'emoji': '🧶', 'name': 'Yarn Ball', 'color': Color(0xFFFFF3E0)},
  ];

  void _play(String toy) {
    setState(() {
      _feedbackText = _getFeedback(toy);
      _starCount = 8;
    });

    widget.onAction('play');

    _service.logActivity(
      icon: Icons.sports_esports,
      iconColor: const Color(0xFF20B2AA),
      title: 'Played with cat — $toy',
    );

    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _starCount = 0;
        _feedbackText = '';
      });
    });

    // Go back after a brief delay so player sees the reaction
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      Navigator.pop(context);
    });
  }

  String _getFeedback(String toy) {
    switch (toy) {
      case 'Tennis Ball':
        return 'Pouncing! 🎾';
      case 'Feather':
        return 'Swat swat! 🪶';
      case 'Laser Dot':
        return 'ZOOM!! 🔴';
      case 'Yarn Ball':
        return 'So tangled! 🧶';
      default:
        return 'Playtime! 😸';
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
                      onWillAccept: (_) {
                        setState(() => _hovering = true);
                        return true;
                      },
                      onLeave: (_) => setState(() => _hovering = false),
                      onAccept: (data) {
                        setState(() => _hovering = false);
                        _play(data);
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
                        child: const Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 16),
                            child: Image(
                              image: AssetImage(
                                  'assets/images/cat_happy_clean.png'),
                              height: 100,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Stars
                    ...List.generate(
                        _starCount,
                        (i) => Positioned(
                              left: 30 + _random.nextDouble() * 220,
                              bottom: 60 + _random.nextDouble() * 120,
                              child: Text(
                                ['⭐', '🌟', '✨'][i % 3],
                                style: const TextStyle(fontSize: 18),
                              ),
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
                              color: Colors.white.withOpacity(0.88),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _feedbackText,
                              style: const TextStyle(
                                fontSize: 20,
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

                const SizedBox(height: 14),

                // Toy grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _toys.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.4,
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
