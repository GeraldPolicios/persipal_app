import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:provider/provider.dart';

import '../services/activity_service.dart';
import '../services/reward_service.dart';
import '../services/global_music_service.dart';
import '../widgets/play_thought.dart';
import '../game/play.dart';
import '../game/cat_animation.dart';
import '../providers/virtual_pet_provider.dart';
import '../widgets/realtime_clock.dart';
import '../widgets/shop_scene_background.dart';
import '../widgets/dirt_overlay.dart';

import '../utils/day_period.dart';
import '../utils/nighttime_mode.dart';

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

  late final PlayGame _playGame;
  late final CatAnimation _sadCatGame;
  late final CatAnimation _sleepyCatGame;

  bool _hovering = false;

  String _feedbackText = '';
  String _feedbackEmoji = '😺';

  bool _isPlaying = false;

  final List<Map<String, dynamic>> _toys = const [
    {
      'emoji': '🎾',
      'name': 'Tennis Ball',
      'color': Color(0xFFDCEDC8),
    },
    {
      'emoji': '🪶',
      'name': 'Feather',
      'color': Color(0xFFFCE4EC),
    },
    {
      'emoji': '🔴',
      'name': 'Laser Dot',
      'color': Color(0xFFFFEBEE),
    },
    {
      'emoji': '🧶',
      'name': 'Yarn Ball',
      'color': Color(0xFFFFF3E0),
    },
  ];

  @override
  void initState() {
    super.initState();

    _playGame = PlayGame();

    // Same sad animation used for Sad/Hungry and Neglected.
    _sadCatGame = CatAnimation(
      startSad: true,
    );
    _sleepyCatGame = CatAnimation();
    dayPeriodNotifier.addListener(_onDayPeriodChanged);
  }

  bool _isNeglected(
    VirtualPetProvider pet,
  ) {
    return pet.hunger >= 90 && pet.happiness <= 20 && pet.cleanliness <= 20;
  }

  Future<void> _showCleanFirst() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _feedbackEmoji = '🧼';
      _feedbackText = 'Clean me first!';
    });

    await Future.delayed(
      const Duration(seconds: 2),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _feedbackText = '';
    });
  }

  Future<void> _showHungryBlocked() async {
    if (!mounted) return;

    setState(() {
      _feedbackEmoji = '🍗';
      _feedbackText = 'Im too hungry to play!';
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
      _feedbackEmoji = '😴';
      _feedbackText = 'Zzz... Im sleepy!';
    });

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() {
      _feedbackText = '';
    });
  }

  Future<void> _play(
    String toy,
  ) async {
    // Nighttime is strictly non-interactive: dropping a toy must never start play.
    if (NighttimeMode.isNighttime()) {
      return;
    }

    if (_isPlaying) {
      return;
    }

    final pet = context.read<VirtualPetProvider>();

    if (pet.furStage > 0) {
      await _showCleanFirst();
      return;
    }

    // Sleeping/Sleepy cats cannot play.
    if (pet.isSleeping) {
      return;
    }
    if (pet.isSleepy) {
      await _showSleepyBlocked();
      return;
    }

    if (pet.isCriticalHunger) {
      await _showHungryBlocked();
      return;
    }

    // Neglected cats must be groomed first.
    if (_isNeglected(pet)) {
      await _showCleanFirst();
      return;
    }

    unawaited(GlobalMusicService.instance.playSfx('happycat.wav'));
    final feedback = _getFeedback(toy);

    setState(() {
      _isPlaying = true;

      _feedbackEmoji = feedback['emoji']!;
      _feedbackText = feedback['text']!;
    });

    await pet.play(
      happinessDelta: 20,
      hungerDelta: 10,
      energyDelta: -10,
      // Every completed play lowers Cleanliness by 5.
      // Dirty is triggered when Cleanliness reaches 30 or below.
      cleanlinessDelta: -5,
    );

    _service.logActivity(
      icon: Icons.sports_esports,
      iconColor: const Color(0xFF20B2AA),
      title: 'Played with cat — $toy',
    );

    switch (toy) {
      case 'Tennis Ball':
        await _playGame.playTennis();
        break;

      case 'Feather':
        await _playGame.playFeather();
        break;

      case 'Laser Dot':
        await _playGame.playLaser();
        break;

      case 'Yarn Ball':
        await _playGame.playYarn();
        break;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isPlaying = false;
    });

    await Future.delayed(
      const Duration(milliseconds: 300),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _feedbackText = '';
    });
  }

  Map<String, String> _getFeedback(
    String toy,
  ) {
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

  Color _shopCardColor(Map<String, dynamic> item, Color fallback) {
    final rewards = context.watch<RewardService>();
    final equippedId = rewards.equippedShopItem('item_play');
    if (equippedId == null) return fallback;

    final itemName = (item['name'] as String).toLowerCase().replaceAll(' ', '');
    final idParts = equippedId.split('_');
    if (idParts.length < 3 || idParts.first != 'play') {
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
      default:
        return fallback;
    }
  }

  Widget _toyCard(
    Map<String, dynamic> item,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: _shopCardColor(item, item['color'] as Color),
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
          Text(
            item['emoji'] as String,
            style: const TextStyle(
              fontSize: 30,
            ),
          ),
          const SizedBox(
            height: 5,
          ),
          Text(
            item['name'] as String,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _draggable(
    Map<String, dynamic> item,
  ) {
    if (_isPlaying) {
      return Opacity(
        opacity: 0.45,
        child: _toyCard(item),
      );
    }

    return Draggable<String>(
      data: item['name'] as String,
      feedback: Material(
        color: Colors.transparent,
        child: Text(
          item['emoji'] as String,
          style: const TextStyle(
            fontSize: 50,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _toyCard(item),
      ),
      child: _toyCard(item),
    );
  }

  void _onDayPeriodChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    dayPeriodNotifier.removeListener(_onDayPeriodChanged);
    _playGame.pauseEngine();
    _sadCatGame.pauseEngine();

    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final pet = context.watch<VirtualPetProvider>();

    final isNighttime = NighttimeMode.isNighttime();
    // Care conditions take visual priority over a stale saved sleep state.
    // Keep neglect detection unchanged; critical hunger or dirt wakes the
    // visual state so the player can see the cat's current needs.
    final isSleeping =
        pet.isSleeping && pet.hunger < 90 && pet.cleanliness > 30;
    final isNeglected = _isNeglected(pet);
    final isSleepy = pet.isSleepy && !isSleeping && !isNeglected;
    final isSad = !isSleeping && !isNeglected && !isSleepy && pet.isSadOrHungry;
    _playGame.setFurStage(pet.furStage);
    if (isSleepy) {
      _sleepyCatGame.enterSleepy();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFE6CC),
      body: Stack(
        children: [
          const ShopSceneBackground(slot: 'background_play'),
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
                          Navigator.pop(context);
                        },
                      ),
                      const Expanded(
                        child: Text(
                          '🎾  Play With Your Cat',
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
                  'Drag a toy to your cat to play!',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFFAA7755),
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                Stack(
                  children: [
                    DragTarget<String>(
                      onWillAcceptWithDetails: (_) {
                        // Keep Play available at night, but hide the cat and
                        // prevent toy interactions during nighttime.
                        if (isNighttime) {
                          return false;
                        }

                        // Long fur must be groomed and trimmed before play.
                        if (pet.furStage > 0) {
                          unawaited(_showCleanFirst());
                          return false;
                        }

                        // Actual Sleeping cannot play.
                        if (isSleeping) {
                          return false;
                        }

                        setState(() {
                          _hovering = true;
                        });

                        return true;
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

                        // Re-check in case nighttime begins during a drag.
                        if (!NighttimeMode.isNighttime()) {
                          _play(details.data);
                        }
                      },
                      builder: (
                        _,
                        __,
                        ___,
                      ) {
                        return AnimatedContainer(
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
                                    ),
                                  ]
                                : null,
                            image: DecorationImage(
                              image: AssetImage(
                                roomAsset(
                                  dayPeriodNotifier.value,
                                  day:
                                      'assets/images/cat_room/play_cat_room.png',
                                  noon:
                                      'assets/images/cat_room/play_cat_roomnoon.png',
                                  night:
                                      'assets/images/cat_room/play_cat_roomnight.png',
                                ),
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),

                          // IMPORTANT:
                          // The room background remains visible while sleeping.
                          // Only the cat is hidden.
                          child: Stack(
                            children: [
                              const Positioned(
                                top: 10,
                                right: 12,
                                child: RealtimeClock(),
                              ),
                              if (!isSleeping && !isNighttime)
                                Positioned.fill(
                                  child: Center(
                                    child: SizedBox(
                                      width: 180,
                                      height: 170,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Positioned.fill(
                                            child: _isPlaying
                                                ? GameWidget(
                                                    game: _playGame,
                                                  )
                                                : (isNeglected &&
                                                        pet.furStage == 0)
                                                    ? GameWidget(
                                                        game: _sadCatGame,
                                                      )
                                                    : isSad
                                                        ? GameWidget(
                                                            game: _sadCatGame,
                                                          )
                                                        : isSleepy
                                                            ? GameWidget(
                                                                game:
                                                                    _sleepyCatGame,
                                                              )
                                                            : GameWidget(
                                                                game: _playGame,
                                                              ),
                                          ),
                                          if (pet.isDirty && !isNeglected)
                                            const Positioned(
                                              left: 42,
                                              top: 62,
                                              child: DirtOverlay(
                                                size: 96,
                                                showFly: false,
                                              ),
                                            ),
                                          if (isNeglected)
                                            const Positioned(
                                              left: 42,
                                              top: 62,
                                              child: DirtOverlay(
                                                size: 96,
                                                showFly: true,
                                                heavy: true,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Only show a thought bubble after an interaction.
                    // Do not show ordinary feedback while sleeping.
                    if (_feedbackText.isNotEmpty && !isSleeping && !isNighttime)
                      Positioned(
                        bottom: 118,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: PlayThought(
                            emoji: _feedbackEmoji,
                            text: _feedbackText,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(
                  height: 14,
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                    itemCount: _toys.length,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 120,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemBuilder: (_, i) {
                      return _draggable(
                        _toys[i],
                      );
                    },
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
