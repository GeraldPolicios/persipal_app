// screens/feed_screen.dart
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/activity_service.dart';
import '../widgets/feed_pet.dart';
import '../widgets/feed_thought.dart';

class FeedScreen extends StatefulWidget {
  final int hunger;
  final int happiness;
  final int cleanliness;
  final bool isDirty;
  final Function(int hunger, int happiness, int cleanliness) onUpdate;

  const FeedScreen({
    super.key,
    required this.hunger,
    required this.happiness,
    required this.cleanliness,
    required this.isDirty,
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
  String _feedbackEmoji = '😺';
  bool _showFeedEffect = false;

  String? _foodInBowl;

  bool _isEating = false;

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

  Future<void> _startEating(String food) async {
    // Prevent multiple foods from being processed at the same time.
    if (_foodInBowl != null || _isEating) {
      return;
    }
    if (widget.isDirty) {
      setState(() {
        _feedbackEmoji = "🧼";
        _feedbackText = "Clean me first!";
        _showFeedEffect = true;
      });

      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      setState(() {
        _showFeedEffect = false;
        _feedbackText = "";
      });

      return;
    }

    // Show food in bowl first
    setState(() {
      _foodInBowl = food;
    });

    // Give player time to see the food
    await Future.delayed(
      const Duration(milliseconds: 800),
    );

    if (!mounted) return;

    // Cat starts eating
    setState(() {
      _isEating = true;
    });

    // Length of your eating animation
    await Future.delayed(
      const Duration(seconds: 5),
    );

    if (!mounted) return;

    // Apply stats
    _feed(food);

    // Remove food
    setState(() {
      _isEating = false;
    });

    await Future.delayed(const Duration(milliseconds: 400));

    if (!mounted) return;

    setState(() {
      _foodInBowl = null;
    });
  }

  void _feed(String food) {
    String feedback;

    setState(() {
      switch (food) {
        case 'Dry Food':
          hunger = (hunger - 25).clamp(0, 100);
          happiness = (happiness + 5).clamp(0, 100);
          feedback = 'Crunchy!';
          _feedbackEmoji = '😸';
          break;

        case 'Wet Food':
          hunger = (hunger - 20).clamp(0, 100);
          happiness = (happiness + 10).clamp(0, 100);
          feedback = 'Yummy!';
          _feedbackEmoji = '😻';
          break;

        case 'Fish':
          hunger = (hunger - 15).clamp(0, 100);
          happiness = (happiness + 20).clamp(0, 100);
          feedback = 'Fishy treat!';
          _feedbackEmoji = '🐟';
          break;

        case 'Milk':
          hunger = (hunger - 10).clamp(0, 100);
          happiness = (happiness + 15).clamp(0, 100);
          cleanliness = (cleanliness + 5).clamp(0, 100);
          feedback = 'Milk time!';
          _feedbackEmoji = '🥛';
          break;

        case 'Water':
          cleanliness = (cleanliness + 10).clamp(0, 100);
          feedback = 'Hydrated!';
          _feedbackEmoji = '💧';
          break;

        case 'Treat':
          hunger = (hunger - 10).clamp(0, 100);
          happiness = (happiness + 25).clamp(0, 100);
          feedback = 'Treat time!';
          _feedbackEmoji = '🍖';
          break;

        default:
          feedback = '';
          _feedbackEmoji = '😺';
      }

      _feedbackText = feedback;
      _showFeedEffect = true;
    });

    widget.onUpdate(hunger, happiness, cleanliness);

    _service.logActivity(
      icon: Icons.restaurant,
      iconColor: const Color(0xFFFF8C69),
      title: 'Fed cat — $food',
    );

    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;

      setState(() {
        _showFeedEffect = false;
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

  String _getBowlImage(String food) {
    switch (food) {
      case 'Dry Food':
        return 'assets/images/states/dry_bowl.png';

      case 'Wet Food':
        return 'assets/images/states/wet_bowl.png';

      case 'Treat':
        return 'assets/images/states/treat_bowl.png';

      case 'Fish':
        return 'assets/images/states/fish_bowl.png';

      case 'Water':
        return 'assets/images/states/water_bowl.png';

      case 'Milk':
        return 'assets/images/states/milk_bowl.png';

      default:
        return 'assets/images/states/bowl.png';
    }
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
    // Disable dragging while food is already in the bowl
    // or while the cat is eating.
    if (_foodInBowl != null || _isEating) {
      return Opacity(
        opacity: 0.45,
        child: _foodCard(item),
      );
    }

    return Draggable<String>(
      data: item['name'] as String,
      feedback: Material(
        color: Colors.transparent,
        child: Text(
          item['emoji'] as String,
          style: const TextStyle(fontSize: 46),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _foodCard(item),
      ),
      child: _foodCard(item),
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
                      onWillAcceptWithDetails: (_) {
                        // Do not allow another food while the cat is already
                        // waiting for food or eating.
                        if (_foodInBowl != null || _isEating) {
                          return false;
                        }

                        setState(() => _hovering = true);
                        return true;
                      },
                      onLeave: (_) => setState(() => _hovering = false),
                      onAcceptWithDetails: (details) {
                        setState(() {
                          _hovering = false;
                        });

                        _startEating(details.data);
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
                                          .withValues(alpha: 0.35),
                                      blurRadius: 16,
                                    )
                                  ]
                                : null,
                            image: const DecorationImage(
                              image: AssetImage(
                                  'assets/images/cat_room/feed_cat_room.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                          child: Stack(
                            children: [
                              // CAT
                              Positioned(
                                left: 0,
                                right: 0,
                                bottom: 6,
                                child: Center(
                                  child: SizedBox(
                                    width: 180,
                                    height: 170,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      alignment: Alignment.bottomCenter,
                                      children: [
                                        // Cat
                                        Positioned(
                                          bottom: 12,
                                          child: FeedPet(
                                            isEating: _isEating,
                                            isDirty: widget.isDirty,
                                            height: 105,
                                          ),
                                        ),
                                        // Bowl - positioned in front of the cat
                                        Positioned(
                                          left: 82,
                                          bottom: 0,
                                          child: SizedBox(
                                            width: 62,
                                            height: 48,
                                            child: Image.asset(
                                              _foodInBowl == null
                                                  ? 'assets/images/states/bowl.png'
                                                  : _getBowlImage(_foodInBowl!),
                                              fit: BoxFit.contain,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )),
                    ),

                    // Feedback text
                    // Clean feeding feedback
                    if (_showFeedEffect && _feedbackText.isNotEmpty)
                      Positioned(
                        bottom: 118,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: FeedThought(
                            emoji: _feedbackEmoji,
                            text: _feedbackText,
                          ),
                        ),
                      ),
                  ],
                ), // <-- CLOSE INNER STACK

                const SizedBox(height: 12),

                // Food grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _foods.length,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 120,
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
