// screens/game_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/virtual_pet_provider.dart';
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

  bool _askedName = false;

  // ── Cat name dialog ───────────────────────────────────────────────────────

  void _askCatName(VirtualPetProvider vp) {
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
              final name =
                  ctrl.text.trim().isEmpty ? 'Meow Meow' : ctrl.text.trim();
              vp.setName(name);
              _service.logActivity(
                icon: Icons.pets,
                iconColor: const Color(0xFF32CD32),
                title: 'Started simulation with cat — $name',
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

  String _getEmotion(int hunger, int happiness, int cleanliness) {
    final avg = (happiness + cleanliness + (100 - hunger)) ~/ 3;
    if (avg >= 60) return 'happy';
    if (avg >= 30) return 'normal';
    return 'sad';
  }

  String _getHair(int cleanliness) {
    if (cleanliness >= 70) return 'clean';
    if (cleanliness >= 40) return 'messy';
    return 'very_messy';
  }

  String _getHearts(int happiness) {
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
    final vp = context.watch<VirtualPetProvider>();

    if (vp.loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFE6CC),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (vp.needsNaming && !_askedName) {
      _askedName = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _askCatName(vp));
    }

    final catName = vp.catName.isEmpty ? 'Meow Meow' : vp.catName;
    final hunger = vp.hunger;
    final happiness = vp.happiness;
    final cleanliness = vp.cleanliness;

    final emotion = _getEmotion(hunger, happiness, cleanliness);
    final hair = _getHair(cleanliness);

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
                      Text(_getHearts(happiness),
                          style: const TextStyle(fontSize: 16)),
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
                        _actionCard('🍗', 'Feed', const Color(0xFFFF8C69),
                            () => _onFeed(vp)),
                        _actionCard('✂️', 'Groom', const Color(0xFF7B68EE),
                            () => _onGroom(vp)),
                        _actionCard('🎾', 'Play', const Color(0xFF20B2AA),
                            () => _onPlay(vp)),
                        _actionCard(
                            '❤️',
                            'Status',
                            const Color(0xFFDC143C),
                            () => _onStatus(
                                catName, hunger, happiness, cleanliness)),
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

  Future<void> _onFeed(VirtualPetProvider vp) async {
    // Snapshot the values handed to FeedScreen. Every onUpdate report from
    // FeedScreen is applied to VirtualPetProvider as a DELTA relative to this
    // snapshot (not an absolute overwrite), so any background decay tick that
    // happens to land while FeedScreen is open is preserved rather than lost.
    int lastHunger = vp.hunger;
    int lastHappiness = vp.happiness;
    int lastCleanliness = vp.cleanliness;

    await Navigator.push<Map<String, int>>(
      context,
      MaterialPageRoute(
        builder: (_) => FeedScreen(
          hunger: lastHunger,
          happiness: lastHappiness,
          cleanliness: lastCleanliness,
          onUpdate: (h, hp, c) {
            vp.feed(
              hungerDelta: h - lastHunger,
              happinessDelta: hp - lastHappiness,
              cleanlinessDelta: c - lastCleanliness,
            );
            lastHunger = h;
            lastHappiness = hp;
            lastCleanliness = c;
          },
        ),
      ),
    );
    // No further action needed on the popped result — FeedScreen's final
    // back-press payload duplicates the last onUpdate call already applied.
  }

  Future<void> _onGroom(VirtualPetProvider vp) async {
    final result = await Navigator.push<Map<String, int>>(
      context,
      MaterialPageRoute(
        builder: (_) => GroomScreen(
          cleanliness: vp.cleanliness,
          onAction: (action) {
            if (action == 'groom') {
              vp.groom(cleanlinessDelta: 20, happinessDelta: 5);
            }
          },
        ),
      ),
    );
    if (result != null && result['cleanliness'] != null) {
      // GroomScreen tracks its own authoritative progress-based cleanliness
      // internally; reconcile to that final value without double-counting
      // the groom action (already counted by vp.groom() above).
      vp.reconcile(cleanliness: result['cleanliness']);
    }
  }

  void _onPlay(VirtualPetProvider vp) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayScreen(
          onAction: (action) {
            if (action == 'play') {
              vp.play(happinessDelta: 20, hungerDelta: 10);
            }
          },
        ),
      ),
    );
  }

  void _onStatus(String catName, int hunger, int happiness, int cleanliness) {
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
