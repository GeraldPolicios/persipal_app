// screens/game_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../services/activity_service.dart';
import '../widgets/tap_effects.dart';
import 'feed_screen.dart';
import 'play_screen.dart';
import 'groom_screen.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final _service = ActivityService.instance;

  String catName = 'Meow Meow';
  Timer? _timer;

  int happiness = 70;
  int hunger = 30; // 0 = full, 100 = starving
  int cleanliness = 90;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _askCatName());

    // Real-time stat decay
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() {
        hunger = (hunger + 2).clamp(0, 100);
        happiness = (happiness - 1).clamp(0, 100);
        cleanliness = (cleanliness - 1).clamp(0, 100);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ── Cat name dialog ───────────────────────────────────────────────────────

  void _askCatName() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFFFF5EE),
        title: const Row(
          children: [
            Text('🐱 ', style: TextStyle(fontSize: 22)),
            Text('Name your cat!',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'e.g. Mochi',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8C69),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              setState(() {
                catName =
                    ctrl.text.trim().isEmpty ? 'Meow Meow' : ctrl.text.trim();
              });
              _service.logActivity(
                icon: Icons.pets,
                iconColor: const Color(0xFF32CD32),
                title: 'Started simulation with cat — $catName',
              );
              Navigator.pop(ctx);
            },
            child: const Text('Let\'s Go!'),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _getEmotion() {
    final avg = (happiness + cleanliness + (100 - hunger)) ~/ 3;
    if (avg >= 60) return 'happy';
    if (avg >= 30) return 'normal';
    return 'sad';
  }

  String _getHair() {
    if (cleanliness >= 70) return 'clean';
    if (cleanliness >= 40) return 'messy';
    return 'very_messy';
  }

  String _getHearts() {
    if (happiness > 80) return '❤️ ❤️ ❤️';
    if (happiness > 50) return '❤️ ❤️ 🤍';
    return '❤️ 🤍 🤍';
  }

  Color _statColor(int val, {bool invert = false}) {
    final v = invert ? 100 - val : val;
    if (v >= 66) return const Color(0xFF32CD32);
    if (v >= 33) return const Color(0xFFFFA500);
    return Colors.redAccent;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Icon(Icons.pets,
                          color: Color(0xFFFF8C69), size: 22),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$catName\'s World',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(_getHearts(), style: const TextStyle(fontSize: 16)),
                    ],
                  ),
                ),

                // Cat scene
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      image: const DecorationImage(
                        image: AssetImage('assets/images/cat_bg_room.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Image.asset(
                            'assets/images/cat_${emotion}_$hair.png',
                            key: ValueKey('${emotion}_$hair'),
                            height: 100,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Stat bars
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _statRow('🍗', 'Hunger', hunger,
                            _statColor(hunger, invert: true)),
                        _statRow('😺', 'Happiness', happiness,
                            _statColor(happiness)),
                        _statRow('🧼', 'Cleanliness', cleanliness,
                            _statColor(cleanliness),
                            isLast: true),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Action label
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'WHAT WOULD YOU LIKE TO DO?',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: Color(0xFFAA7755),
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Action grid
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.6,
                      children: [
                        _actionCard(
                            '🍗', 'Feed', const Color(0xFFFF8C69), _onFeed),
                        _actionCard(
                            '✂️', 'Groom', const Color(0xFF7B68EE), _onGroom),
                        _actionCard(
                            '🎾', 'Play', const Color(0xFF20B2AA), _onPlay),
                        _actionCard(
                            '❤️', 'Status', const Color(0xFFDC143C), _onStatus),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statRow(String emoji, String label, int value, Color color,
      {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          SizedBox(
            width: 72,
            child: Text(label,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: value / 100,
                minHeight: 8,
                backgroundColor: color.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              '$value%',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(
      String emoji, String label, Color color, VoidCallback onTap) {
    return BounceButton(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _onFeed() async {
    final result = await Navigator.push<Map<String, int>>(
      context,
      MaterialPageRoute(
        builder: (_) => FeedScreen(
          hunger: hunger,
          happiness: happiness,
          cleanliness: cleanliness,
          onUpdate: (h, hp, c) {
            setState(() {
              hunger = h;
              happiness = hp;
              cleanliness = c;
            });
          },
        ),
      ),
    );
    if (result != null) {
      setState(() {
        hunger = result['hunger'] ?? hunger;
        happiness = result['happiness'] ?? happiness;
        cleanliness = result['cleanliness'] ?? cleanliness;
      });
    }
  }

  Future<void> _onGroom() async {
    final result = await Navigator.push<Map<String, int>>(
      context,
      MaterialPageRoute(
        builder: (_) => GroomScreen(
          cleanliness: cleanliness,
          onAction: (action) {
            if (action == 'groom') {
              setState(() {
                cleanliness = (cleanliness + 20).clamp(0, 100);
                happiness = (happiness + 5).clamp(0, 100);
              });
            }
          },
        ),
      ),
    );
    if (result != null) {
      setState(() {
        cleanliness = result['cleanliness'] ?? cleanliness;
      });
    }
  }

  void _onPlay() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayScreen(
          onAction: (action) {
            if (action == 'play') {
              setState(() {
                happiness = (happiness + 20).clamp(0, 100);
                hunger = (hunger + 10).clamp(0, 100);
              });
            }
          },
        ),
      ),
    );
  }

  void _onStatus() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFFF5EE),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('❤️ ', style: TextStyle(fontSize: 20)),
                Text(
                  '$catName\'s Status',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _statRow('🍗', 'Hunger', hunger, _statColor(hunger, invert: true)),
            _statRow('😺', 'Happiness', happiness, _statColor(happiness)),
            _statRow('🧼', 'Cleanliness', cleanliness, _statColor(cleanliness),
                isLast: true),
            const SizedBox(height: 16),
            Text(
              '$catName is your virtual Persian cat. Take care of it daily!',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
