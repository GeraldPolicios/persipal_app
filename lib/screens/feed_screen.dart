import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flame/game.dart';
import 'package:provider/provider.dart';

import '../services/activity_service.dart';
import '../services/reward_service.dart';
import '../services/global_music_service.dart';
import '../widgets/feed_thought.dart';
import '../game/feed.dart';
import '../game/cat_animation.dart';
import '../providers/virtual_pet_provider.dart';
import '../widgets/realtime_clock.dart';
import '../widgets/shop_scene_background.dart';
import '../widgets/dirt_overlay.dart';

import '../utils/day_period.dart';
import '../utils/nighttime_mode.dart';

class FeedScreen extends StatefulWidget {
  final int hunger;
  final int happiness;
  final int cleanliness;
  final bool isDirty;

  final Function(
    int hunger,
    int happiness,
    int cleanliness,
  ) onUpdate;

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

  late final FeedGame _feedGame;
  late final CatAnimation _sadCatGame;
  late final CatAnimation _sleepyCatGame;

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
    {
      'emoji': '🍗',
      'name': 'Dry Food',
      'color': Color(0xFFFFE0B2),
    },
    {
      'emoji': '🥫',
      'name': 'Wet Food',
      'color': Color(0xFFFFCDD2),
    },
    {
      'emoji': '🐟',
      'name': 'Fish',
      'color': Color(0xFFB3E5FC),
    },
    {
      'emoji': '🥛',
      'name': 'Milk',
      'color': Color(0xFFE1F5FE),
    },
    {
      'emoji': '💧',
      'name': 'Water',
      'color': Color(0xFFBBDEFB),
    },
    {
      'emoji': '🍖',
      'name': 'Treat',
      'color': Color(0xFFFFCCBC),
    },
  ];

  @override
  void initState() {
    super.initState();

    hunger = widget.hunger;
    happiness = widget.happiness;
    cleanliness = widget.cleanliness;

    _feedGame = FeedGame();

    // Neglected uses the SAME sad animation.
    _sadCatGame = CatAnimation(
      startSad: true,
      // Match FeedGame so Sad/Hungry and eating animations share the
      // same cat position relative to the bowl.
      positionYOffset: 17,
    );
    _sleepyCatGame = CatAnimation(
      // Keep sleepy animation aligned with the feed/eating cat and bowl.
      positionYOffset: 17,
    );
    dayPeriodNotifier.addListener(_onDayPeriodChanged);
  }

  bool _isNeglected(
    VirtualPetProvider pet,
  ) {
    return pet.hunger >= 90 && pet.happiness <= 20 && pet.cleanliness <= 20;
  }

  Future<void> _showSleepyBlocked() async {
    if (!mounted) return;

    setState(() {
      _feedbackEmoji = '😴';
      _feedbackText = 'Zzz... Im sleepy!';
      _showFeedEffect = true;
    });

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() {
      _showFeedEffect = false;
      _feedbackText = '';
    });
  }

  Future<void> _showFullBlocked() async {
    if (!mounted) return;

    setState(() {
      _feedbackEmoji = '😸';
      _feedbackText = 'Im full!';
      _showFeedEffect = true;
    });

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() {
      _showFeedEffect = false;
      _feedbackText = '';
    });
  }

  Future<void> _showNighttimeBlocked() async {
    if (!mounted) return;

    setState(() {
      _feedbackEmoji = '🌙';
      _feedbackText = 'I’m not hungry. Let me rest!';
      _showFeedEffect = true;
    });

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    setState(() {
      _showFeedEffect = false;
      _feedbackText = '';
    });
  }

  Future<void> _showCleanFirst() async {
    if (!mounted) return;

    setState(() {
      _feedbackEmoji = '🧼';
      _feedbackText = 'Clean me first!';
      _showFeedEffect = true;
    });

    await Future.delayed(
      const Duration(seconds: 2),
    );

    if (!mounted) return;

    setState(() {
      _showFeedEffect = false;
      _feedbackText = '';
    });
  }

  Future<void> _startEating(
    String food,
  ) async {
    if (_foodInBowl != null || _isEating) {
      return;
    }

    final pet = context.read<VirtualPetProvider>();

    // Long fur blocks feeding before any bowl/animation state starts.
    if (pet.furStage > 0) {
      await _showCleanFirst();
      return;
    }

    // Sleeping/Sleepy cats cannot be fed.
    // Keep the two states distinct: sleeping silently blocks feeding, while
    // a sleepy (but awake) cat shows the sleepy feedback.
    if (pet.isSleeping) {
      return;
    }
    if (pet.isSleepy) {
      await _showSleepyBlocked();
      return;
    }

    // A cat with 0 hunger is already full. Do not start the eating/drinking
    // animation or place food in the bowl; show the same thought-bubble style
    // used by the other care/play screens instead.
    if (pet.hunger <= 0) {
      await _showFullBlocked();
      return;
    }

    // Neglected cat must be groomed first.
    if (_isNeglected(pet)) {
      await _showCleanFirst();
      return;
    }

    // At night, feeding is allowed only when the cat actually needs care.
    // Keep this aligned with the Feed screen's nighttime visibility rule:
    // hunger >= 70, dirt, or fur means care is still permitted.
    final needsCareAtNight =
        pet.hunger >= 70 || pet.isDirty || pet.furStage > 0;
    if (NighttimeMode.isNighttime() && !needsCareAtNight) {
      await _showNighttimeBlocked();
      return;
    }

    // Mark the care animation as active BEFORE the short bowl delay.
    // This is important because a hungry cat normally uses the SadCat game;
    // while feeding, FeedGame must be the visible cat so its eating/drinking
    // animation can actually be seen.
    setState(() {
      _foodInBowl = food;
      _isEating = true;
    });

    if (!mounted) return;

    final isDrinking = food == 'Milk' || food == 'Water';

    // Start the SFX only when the sprite reaches the bowl, not when the
    // animation begins. The first part of each sheet is the cat lowering its
    // head, so playing the sound immediately makes it feel out of sync.
    void playBowlContactSound() {
      unawaited(
        GlobalMusicService.instance.playSfx(
          isDrinking ? 'drinkcat.wav' : 'eatcat.wav',
        ),
      );
    }

    try {
      if (isDrinking) {
        await _feedGame.playDrinking(
          onHeadAtBowl: playBowlContactSound,
        );
      } else {
        await _feedGame.playEating(
          onHeadAtBowl: playBowlContactSound,
        );
      }
    } finally {
      // Also stops the sound if the animation is interrupted by navigation.
      await GlobalMusicService.instance.stopSfx();
    }

    if (!mounted) return;

    await _feed(food);

    if (!mounted) return;

    setState(() {
      _isEating = false;
    });

    await Future.delayed(
      const Duration(milliseconds: 400),
    );

    if (!mounted) return;

    setState(() {
      _foodInBowl = null;
    });
  }

  Future<void> _feed(
    String food,
  ) async {
    final pet = context.read<VirtualPetProvider>();

    if (pet.furStage > 0) {
      await _showCleanFirst();
      return;
    }

    int hungerDelta = 0;
    int happinessDelta = 0;
    int cleanlinessDelta = 0;
    String feedback;
    String emoji;

    switch (food) {
      case 'Dry Food':
        hungerDelta = -25;
        happinessDelta = 5;
        feedback = 'Crunchy!';
        emoji = '😸';
        break;
      case 'Wet Food':
        hungerDelta = -20;
        happinessDelta = 10;
        feedback = 'Yummy!';
        emoji = '😻';
        break;
      case 'Fish':
        hungerDelta = -15;
        happinessDelta = 20;
        feedback = 'Fishy treat!';
        emoji = '🐟';
        break;
      case 'Milk':
        hungerDelta = -10;
        happinessDelta = 15;
        cleanlinessDelta = 5;
        feedback = 'Milk time!';
        emoji = '🥛';
        break;
      case 'Water':
        cleanlinessDelta = 10;
        feedback = 'Hydrated!';
        emoji = '💧';
        break;
      case 'Treat':
        hungerDelta = -10;
        happinessDelta = 25;
        feedback = 'Treat time!';
        emoji = '🍖';
        break;
      default:
        feedback = '';
        emoji = '😺';
    }

    await pet.feed(
      hungerDelta: hungerDelta,
      happinessDelta: happinessDelta,
      cleanlinessDelta: cleanlinessDelta,
    );
    if (!mounted) return;

    setState(() {
      hunger = pet.hunger;
      happiness = pet.happiness;
      cleanliness = pet.cleanliness;
      _feedbackText = feedback;
      _feedbackEmoji = emoji;
      _showFeedEffect = true;
    });

    _service.logActivity(
      icon: Icons.restaurant,
      iconColor: const Color(0xFFFF8C69),
      title: 'Fed cat — $food',
    );

    Future.delayed(
      const Duration(milliseconds: 1200),
      () {
        if (!mounted) return;

        setState(() {
          _showFeedEffect = false;
          _feedbackText = '';
        });
      },
    );
  }

  String _getBowlImage(
    String food,
  ) {
    switch (food) {
      case 'Dry Food':
        return 'assets/images/bowl/dry.png';

      case 'Wet Food':
        return 'assets/images/bowl/wet.png';

      case 'Treat':
        return 'assets/images/bowl/treat.png';

      case 'Fish':
        return 'assets/images/bowl/fish.png';

      case 'Water':
        return 'assets/images/bowl/water.png';

      case 'Milk':
        return 'assets/images/bowl/milk.png';

      default:
        return 'assets/images/bowl/bowl.png';
    }
  }

  Color _shopCardColor(Map<String, dynamic> item, Color fallback) {
    final rewards = context.watch<RewardService>();
    final equippedId = rewards.equippedShopItem('item_feed');
    if (equippedId == null) return fallback;

    final itemName = (item['name'] as String).toLowerCase().replaceAll(' ', '');
    final idParts = equippedId.split('_');
    if (idParts.length < 3 || idParts.first != 'feed') {
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

  Widget _foodCard(
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
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 5),
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

  Widget _draggable(
    Map<String, dynamic> item,
  ) {
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
          style: const TextStyle(
            fontSize: 46,
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _foodCard(item),
      ),
      child: _foodCard(item),
    );
  }

  void _onDayPeriodChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    dayPeriodNotifier.removeListener(_onDayPeriodChanged);
    _feedGame.pauseEngine();
    _sadCatGame.pauseEngine();
    unawaited(GlobalMusicService.instance.stopSfx());
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final pet = context.watch<VirtualPetProvider>();

    // Care conditions take visual priority over a stale saved sleep state.
    // Keep neglect detection unchanged; critical hunger or dirt wakes the
    // visual state so the player can see the cat's current needs.
    final isSleeping =
        pet.isSleeping && pet.hunger < 90 && pet.cleanliness > 30;
    final isNeglected = _isNeglected(pet);
    final isSleepy = pet.isSleepy && !isSleeping && !isNeglected;
    final isSad = !isSleeping && !isNeglected && !isSleepy && pet.isSadOrHungry;
    final isNight = NighttimeMode.isNighttime();
    final needsCareAtNight =
        isNeglected || pet.hunger >= 70 || pet.isDirty || pet.furStage > 0;
    final showCat =
        isNeglected || (!isSleeping && (!isNight || needsCareAtNight));
    _feedGame.setFurStage(pet.furStage);
    if (isSleepy) {
      _sleepyCatGame.enterSleepy();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFE6CC),
      body: Stack(
        children: [
          const ShopSceneBackground(slot: 'background_feed'),
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
                              'hunger': pet.hunger,
                              'happiness': pet.happiness,
                              'cleanliness': pet.cleanliness,
                            },
                          );
                        },
                      ),
                      const Expanded(
                        child: Text(
                          '🍗  Feed Your Cat',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
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
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 8),
                Stack(
                  children: [
                    DragTarget<String>(
                      onWillAcceptWithDetails: (_) {
                        // Long fur must be groomed and trimmed before feeding.
                        if (pet.furStage > 0) {
                          unawaited(_showCleanFirst());
                          return false;
                        }

                        // Actual Sleeping cannot receive food.
                        if (isSleeping) {
                          return false;
                        }

                        // Sleepy still accepts the drop so the user gets
                        // the ZZZ reaction instead of a silent rejection.

                        if (_foodInBowl != null || _isEating) {
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

                        _startEating(details.data);
                      },
                      builder: (_, __, ___) {
                        return AnimatedContainer(
                          duration: const Duration(
                            milliseconds: 200,
                          ),
                          height: 210,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                          ),
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
                                    ),
                                  ]
                                : null,
                            image: DecorationImage(
                              image: AssetImage(
                                roomAsset(
                                  dayPeriodNotifier.value,
                                  day:
                                      'assets/images/cat_room/feed_cat_room.png',
                                  noon:
                                      'assets/images/cat_room/feed_cat_roomnoon.png',
                                  night:
                                      'assets/images/cat_room/feed_cat_roomnight.png',
                                ),
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),

                          // IMPORTANT:
                          // The room background stays visible while sleeping.
                          // Only the cat is hidden.
                          child: Stack(
                            children: [
                              const Positioned(
                                top: 10,
                                right: 12,
                                child: RealtimeClock(),
                              ),
                              if (showCat)
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: SizedBox(
                                      width: 180,
                                      height: 170,
                                      child: Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Positioned.fill(
                                            child: _isEating
                                                ? GameWidget(
                                                    game: _feedGame,
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
                                                                game: _feedGame,
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
                              Positioned(
                                bottom: -6,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: SizedBox(
                                    width: _foodInBowl == null ? 82 : 72,
                                    height: _foodInBowl == null ? 64 : 56,
                                    child: Image.asset(
                                      _foodInBowl == null
                                          ? 'assets/images/bowl/bowl.png'
                                          : _getBowlImage(
                                              _foodInBowl!,
                                            ),
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    if (_showFeedEffect &&
                        _feedbackText.isNotEmpty &&
                        !isSleeping)
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
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                    ),
                    itemCount: _foods.length,
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 120,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemBuilder: (_, i) {
                      return _draggable(
                        _foods[i],
                      );
                    },
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
