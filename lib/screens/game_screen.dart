// screens/game_screen.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/virtual_pet_provider.dart';
import '../services/activity_service.dart';
import '../widgets/tap_effects.dart';
import '../widgets/animated_pet.dart';
import '../widgets/pet_thought.dart';

import 'feed_screen.dart';
import 'play_screen.dart';
import 'groom_screen.dart';

import '../models/pet_brain.dart';
import '../models/dirty_state.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final _service = ActivityService.instance;

  // ────────────────────────────────────────────────────────────────────────
  // Naming
  // ────────────────────────────────────────────────────────────────────────

  bool _askedName = false;

  String catName = 'Meow Meow';

  // ────────────────────────────────────────────────────────────────────────
  // Timers
  // ────────────────────────────────────────────────────────────────────────

  Timer? _thoughtTimer;
  Timer? _furTimer;

  // ────────────────────────────────────────────────────────────────────────
  // Local visual/game interaction state
  //
  // IMPORTANT:
  // Actual persistent stats belong to VirtualPetProvider.
  // These values are only used for the current visual interaction state.
  // ────────────────────────────────────────────────────────────────────────

  int furStage = 0;

  bool isDirty = false;
  bool isNeglected = false;

  bool _isBeingPetted = false;
  bool _isAngry = false;

  int _petCount = 0;

  Timer? _petResetTimer;
  Timer? _angryTimer;

  bool _showHeart = false;
  DateTime? _lastPet;

  bool _showThought = false;
  String _thoughtEmoji = "🍗";

  // ────────────────────────────────────────────────────────────────────────
  // Init
  // ────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final vp = context.read<VirtualPetProvider>();

      if (vp.needsNaming && !_askedName) {
        _askedName = true;
        _askCatName(vp);
      }

      _syncLocalState(vp);
    });

    // Thought bubble timer.
    _thoughtTimer = Timer.periodic(
      const Duration(seconds: 12),
      (_) {
        if (!mounted) return;
        _showThoughtBubble();
      },
    );

    // Fur progression.
    //
    // This is currently visual-only.
    // It does not modify the actual virtual pet stats.
    _furTimer = Timer.periodic(
      const Duration(hours: 1),
      (_) {
        if (!mounted) return;

        setState(() {
          if (furStage < 3) {
            furStage++;
          }
        });
      },
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // Dispose
  // ────────────────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _thoughtTimer?.cancel();
    _furTimer?.cancel();
    _petResetTimer?.cancel();
    _angryTimer?.cancel();

    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────────────
  // Sync local visual state with provider
  // ────────────────────────────────────────────────────────────────────────

  void _syncLocalState(VirtualPetProvider vp) {
    final newDirty = vp.cleanliness <= 30;

    final newNeglected =
        vp.hunger >= 90 && vp.happiness <= 20 && vp.cleanliness <= 20;

    if (isDirty != newDirty || isNeglected != newNeglected) {
      setState(() {
        isDirty = newDirty;
        isNeglected = newNeglected;
      });
    }

    DirtyState.instance.setDirty(newDirty);
  }

  // ────────────────────────────────────────────────────────────────────────
  // CAT TAP
  // ────────────────────────────────────────────────────────────────────────

  void _onCatTap() {
    if (!mounted) return;

    final vp = context.read<VirtualPetProvider>();

    final hunger = vp.hunger;
    final happiness = vp.happiness;
    final cleanliness = vp.cleanliness;

    // Update dirty / neglected state first.
    _syncLocalState(vp);

    // Hungry cats don't want pets.
    if (hunger >= 70) {
      _showThoughtBubble();
      return;
    }

    // Dirty cats don't want pets.
    if (isDirty || isNeglected) {
      _showThoughtBubble();
      return;
    }

    // Already angry.
    if (_isAngry) {
      _angryTimer?.cancel();

      setState(() {
        happiness;
        _isAngry = true;
      });

      vp.reconcile(
        happiness: (happiness - 5).clamp(0, 100),
      );

      _angryTimer = Timer(
        const Duration(seconds: 2),
        () {
          if (!mounted) return;

          setState(() {
            _isAngry = false;
            _petCount = 0;
          });
        },
      );

      return;
    }

    // Count taps.
    _petCount++;

    _petResetTimer?.cancel();

    _petResetTimer = Timer(
      const Duration(seconds: 3),
      () {
        if (!mounted) return;

        setState(() {
          _petCount = 0;
        });
      },
    );

    // Too many taps = angry.
    if (_petCount >= 4) {
      _angryTimer?.cancel();

      setState(() {
        _isAngry = true;
        _isBeingPetted = false;
        _showHeart = false;
      });

      vp.reconcile(
        happiness: (happiness - 3).clamp(0, 100),
      );

      _angryTimer = Timer(
        const Duration(seconds: 2),
        () {
          if (!mounted) return;

          setState(() {
            _isAngry = false;
            _petCount = 0;
          });
        },
      );

      return;
    }

    // Happy pet.
    setState(() {
      _isBeingPetted = true;
      _showHeart = true;
    });

    vp.reconcile(
      happiness: (happiness + 2).clamp(0, 100),
    );

    Future.delayed(
      const Duration(milliseconds: 1200),
      () {
        if (!mounted) return;

        setState(() {
          _showHeart = false;
          _isBeingPetted = false;
        });
      },
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // CONTINUOUS PETTING
  // ────────────────────────────────────────────────────────────────────────

  void _onPetting() {
    if (!mounted) return;

    final vp = context.read<VirtualPetProvider>();

    if (vp.hunger >= 70 || isDirty || isNeglected || _isAngry) {
      return;
    }

    final now = DateTime.now();

    if (_lastPet == null || now.difference(_lastPet!).inMilliseconds > 300) {
      _lastPet = now;

      setState(() {
        _isBeingPetted = true;
        _showHeart = true;
      });

      vp.reconcile(
        happiness: (vp.happiness + 1).clamp(0, 100),
      );

      Future.delayed(
        const Duration(milliseconds: 700),
        () {
          if (!mounted) return;

          setState(() {
            _showHeart = false;
          });
        },
      );
    }
  }

  // ────────────────────────────────────────────────────────────────────────
  // CAT NAME DIALOG
  // ────────────────────────────────────────────────────────────────────────

  void _askCatName(VirtualPetProvider vp) {
    final ctrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        backgroundColor: const Color(0xFFFFF5EE),
        title: const Row(
          children: [
            Text(
              '🐱 ',
              style: TextStyle(fontSize: 22),
            ),
            Text(
              'Name your cat!',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
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
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              final name =
                  ctrl.text.trim().isEmpty ? 'Meow Meow' : ctrl.text.trim();

              await vp.setName(name);

              _service.logActivity(
                icon: Icons.pets,
                iconColor: const Color(0xFF32CD32),
                title: 'Started simulation with cat — $name',
              );

              if (mounted) {
                setState(() {
                  catName = name;
                });
              }

              if (ctx.mounted) {
                Navigator.pop(ctx);
              }
            },
            child: const Text("Let's Go!"),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ────────────────────────────────────────────────────────────────────────

  String _getEmotion(
    int hunger,
    int happiness,
    int cleanliness,
  ) {
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

  void _checkNeglected(VirtualPetProvider vp) {
    final dirty = vp.cleanliness <= 30;

    final neglected =
        vp.hunger >= 90 && vp.happiness <= 20 && vp.cleanliness <= 20;

    if (mounted) {
      setState(() {
        isDirty = dirty;
        isNeglected = neglected;
      });
    }

    DirtyState.instance.setDirty(dirty);
  }

  void _showThoughtBubble() {
    if (!mounted) return;

    final vp = context.read<VirtualPetProvider>();

    final hunger = vp.hunger;
    final happiness = vp.happiness;
    final cleanliness = vp.cleanliness;

    String? emoji;

    final neglected = hunger >= 90 && happiness <= 20 && cleanliness <= 20;

    final dirty = cleanliness <= 30;

    if (neglected) {
      if (hunger >= cleanliness && hunger >= happiness) {
        emoji = "🍗";
      } else if (cleanliness <= happiness) {
        emoji = "🧼";
      } else {
        emoji = "❤️";
      }
    } else if (hunger >= 70) {
      emoji = "🍗";
    } else if (dirty) {
      emoji = "🧼";
    }

    if (emoji == null) return;

    setState(() {
      _thoughtEmoji = emoji!;
      _showThought = true;
    });

    Future.delayed(
      const Duration(seconds: 4),
      () {
        if (!mounted) return;

        setState(() {
          _showThought = false;
        });
      },
    );
  }

  String _getHearts(int happiness) {
    if (happiness > 80) return '❤️ ❤️ ❤️';
    if (happiness > 50) return '❤️ ❤️ 🤍';
    return '❤️ 🤍 🤍';
  }

  Color _statColor(
    int val, {
    bool invert = false,
  }) {
    final v = invert ? 100 - val : val;

    if (v >= 66) {
      return const Color(0xFF32CD32);
    }

    if (v >= 33) {
      return const Color(0xFFFFA500);
    }

    return Colors.redAccent;
  }

  // ────────────────────────────────────────────────────────────────────────
  // BUILD
  // ────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VirtualPetProvider>();

    if (vp.loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFE6CC),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Sync visual state with provider.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _syncLocalState(vp);
    });

    if (vp.needsNaming && !_askedName) {
      _askedName = true;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        _askCatName(vp);
      });
    }

    final providerCatName = vp.catName.isEmpty ? 'Meow Meow' : vp.catName;

    if (catName == 'Meow Meow' && providerCatName != 'Meow Meow') {
      catName = providerCatName;
    }

    final brain = PetBrain(
      hunger: vp.hunger,
      happiness: vp.happiness,
      cleanliness: vp.cleanliness,
      isBeingPetted: _isBeingPetted,
      isAngry: _isAngry,
      isDirty: isDirty,
      isNeglected: isNeglected,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFFE6CC),
      body: Stack(
        children: [
          // ────────────────────────────────────────────────────────────────
          // Background
          // ────────────────────────────────────────────────────────────────

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ──────────────────────────────────────────────────────────
                // Top bar
                // ──────────────────────────────────────────────────────────

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
                          Navigator.pop(context);
                        },
                      ),
                      const Icon(
                        Icons.pets,
                        color: Color(0xFFFF8C69),
                        size: 22,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '$catName\'s World',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        _getHearts(vp.happiness),
                        style: const TextStyle(
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),

                // ──────────────────────────────────────────────────────────
                // Cat scene
                // ──────────────────────────────────────────────────────────

                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    8,
                    16,
                    0,
                  ),
                  child: Container(
                    height: 180,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      image: const DecorationImage(
                        image: AssetImage(
                          'assets/images/cat_room/cat_bg_room_ver2.png',
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(
                          bottom: 10,
                        ),
                        child: GestureDetector(
                          onTap: _onCatTap,
                          onPanStart: (_) {
                            if (!mounted) return;

                            setState(() {
                              _isBeingPetted = true;
                            });
                          },
                          onPanUpdate: (_) {
                            _onPetting();
                          },
                          onPanEnd: (_) {
                            if (!mounted) return;

                            setState(() {
                              _isBeingPetted = false;
                            });
                          },
                          child: SizedBox(
                            width: 180,
                            height: 170,
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.bottomCenter,
                              children: [
                                // ────────────────────────────────────────
                                // CAT
                                // ────────────────────────────────────────

                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: AnimatedPet(
                                    state: brain.animation,
                                    furStage: furStage,
                                    isDirty: isDirty,
                                    height: 100,
                                  ),
                                ),

                                // ────────────────────────────────────────
                                // THOUGHT BUBBLE
                                // ────────────────────────────────────────

                                if (_showThought)
                                  Positioned(
                                    top: 28,
                                    right: -5,
                                    child: PetThought(
                                      emoji: _thoughtEmoji,
                                    ),
                                  ),

                                // ────────────────────────────────────────
                                // HEART
                                // ────────────────────────────────────────

                                if (_showHeart)
                                  Positioned(
                                    bottom: 78,
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween(
                                        begin: 0,
                                        end: -45,
                                      ),
                                      duration: const Duration(
                                        milliseconds: 900,
                                      ),
                                      builder: (
                                        context,
                                        value,
                                        child,
                                      ) {
                                        return Transform.translate(
                                          offset: Offset(
                                            0,
                                            value,
                                          ),
                                          child: Opacity(
                                            opacity: 1 - (-value / 45),
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        "❤️",
                                        style: TextStyle(
                                          fontSize: 28,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // ──────────────────────────────────────────────────────────
                // Stat bars
                // ──────────────────────────────────────────────────────────

                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    0,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: 0.8,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _statRow(
                          '🍗',
                          'Hunger',
                          vp.hunger,
                          _statColor(
                            vp.hunger,
                            invert: true,
                          ),
                        ),
                        _statRow(
                          '😺',
                          'Happiness',
                          vp.happiness,
                          _statColor(vp.happiness),
                        ),
                        _statRow(
                          '🧼',
                          'Cleanliness',
                          vp.cleanliness,
                          _statColor(vp.cleanliness),
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ──────────────────────────────────────────────────────────
                // Action label
                // ──────────────────────────────────────────────────────────

                const Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
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

                // ──────────────────────────────────────────────────────────
                // Action grid
                // ──────────────────────────────────────────────────────────

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      16,
                    ),
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.6,
                      children: [
                        _actionCard(
                          '🍗',
                          'Feed',
                          const Color(0xFFFF8C69),
                          () => _onFeed(vp),
                        ),
                        _actionCard(
                          '✂️',
                          'Groom',
                          const Color(0xFF7B68EE),
                          () => _onGroom(vp),
                        ),
                        _actionCard(
                          '🎾',
                          'Play',
                          const Color(0xFF20B2AA),
                          () => _onPlay(vp),
                        ),
                        _actionCard(
                          '❤️',
                          'Status',
                          const Color(0xFFDC143C),
                          () => _onStatus(
                            catName,
                            vp.hunger,
                            vp.happiness,
                            vp.cleanliness,
                          ),
                        ),
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

  // ────────────────────────────────────────────────────────────────────────
  // STAT ROW
  // ────────────────────────────────────────────────────────────────────────

  Widget _statRow(
    String emoji,
    String label,
    int value,
    Color color, {
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: isLast ? 0 : 8,
      ),
      child: Row(
        children: [
          Text(
            emoji,
            style: const TextStyle(
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: value / 100,
                minHeight: 8,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              '$value%',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // ACTION CARD
  // ────────────────────────────────────────────────────────────────────────

  Widget _actionCard(
    String emoji,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return BounceButton(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              emoji,
              style: const TextStyle(
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // FEED
  // ────────────────────────────────────────────────────────────────────────

  Future<void> _onFeed(
    VirtualPetProvider vp,
  ) async {
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
          isDirty: isDirty,
          onUpdate: (
            h,
            hp,
            c,
          ) {
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

    _checkNeglected(vp);
  }

  // ────────────────────────────────────────────────────────────────────────
  // GROOM
  // ────────────────────────────────────────────────────────────────────────

  Future<void> _onGroom(
    VirtualPetProvider vp,
  ) async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => GroomScreen(
          isDirty: isDirty,
          cleanliness: vp.cleanliness,
          onAction: (action) {
            if (action == 'groom') {
              vp.groom(
                cleanlinessDelta: 20,
                happinessDelta: 5,
              );
            }
          },
        ),
      ),
    );

    if (!mounted) return;

    if (result != null && result['cleanliness'] != null) {
      await vp.reconcile(
        cleanliness: result['cleanliness'] as int,
      );
    }

    _checkNeglected(vp);
  }

  // ────────────────────────────────────────────────────────────────────────
  // PLAY
  // ────────────────────────────────────────────────────────────────────────

  void _onPlay(
    VirtualPetProvider vp,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayScreen(
          isDirty: isDirty,
          onAction: (action) {
            if (action == 'play') {
              vp.play(
                happinessDelta: 20,
                hungerDelta: 10,
              );

              _checkNeglected(vp);
            }
          },
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  // STATUS
  // ────────────────────────────────────────────────────────────────────────

  void _onStatus(
    String catName,
    int hunger,
    int happiness,
    int cleanliness,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFFF5EE),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '❤️ ',
                  style: TextStyle(
                    fontSize: 20,
                  ),
                ),
                Text(
                  '$catName\'s Status',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _statRow(
              '🍗',
              'Hunger',
              hunger,
              _statColor(
                hunger,
                invert: true,
              ),
            ),
            _statRow(
              '😺',
              'Happiness',
              happiness,
              _statColor(happiness),
            ),
            _statRow(
              '🧼',
              'Cleanliness',
              cleanliness,
              _statColor(cleanliness),
              isLast: true,
            ),
            const SizedBox(height: 16),
            Text(
              '$catName is your virtual Persian cat. '
              'Take care of it daily!',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
