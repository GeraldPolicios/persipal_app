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
  late final CatAnimation _happyCatGame;

  late int hunger;
  late int happiness;
  late int cleanliness;

  bool _hovering = false;

  String _feedbackText = '';
  String _feedbackEmoji = '😺';

  bool _showFeedEffect = false;

  String? _foodInBowl;

  bool _isEating = false;
  bool _isHappyReaction = false;
  String _foodExplanation = '';

  final List<Map<String, dynamic>> _foods = const [
    {
      'emoji': '🥣',
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
      'emoji': '🥩',
      'name': 'Treat',
      'color': Color(0xFFFFCCBC),
    },
    {
      'emoji': '🍫',
      'name': 'Chocolate',
      'color': Color(0xFFD7CCC8),
    },
    {
      'emoji': '🧅',
      'name': 'Onion',
      'color': Color(0xFFE6EE9C),
    },
    {
      'emoji': '🧄',
      'name': 'Garlic',
      'color': Color(0xFFFFF9C4),
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
    _happyCatGame = CatAnimation(positionYOffset: 17);
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

    // Unsafe foods are educational choices only: the cat refuses them,
    // no eating animation starts, and care stats are never changed.
    final unsafeExplanations = <String, String>{
      'Chocolate': 'Chocolate is toxic to cats.',
      'Onion': 'Onions can damage a cat’s red blood cells.',
      'Garlic': 'Garlic is toxic to cats.',
    };
    const unsafeThoughts = <String, String>{
      'Chocolate': 'That is dangerous for me!',
      'Onion': 'I should stay away from that!',
      'Garlic': 'No thanks, that is not safe!',
    };
    if (unsafeExplanations.containsKey(food)) {
      setState(() {
        _feedbackEmoji = '🙀';
        _feedbackText = unsafeThoughts[food]!;
        _foodExplanation = unsafeExplanations[food]!;
        _showFeedEffect = true;
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() {
          _showFeedEffect = false;
          _feedbackText = '';
        });
      });
      return;
    }

    // Show the cat's food reaction while the eating/drinking animation is
    // playing, not only after it finishes. The bubble is kept through the
    // happy reaction below and cleared when that reaction ends.
    const eatingThoughts = <String, Map<String, String>>{
      'Dry Food': {'emoji': '😸', 'text': 'Yum! My tummy will be happy!'},
      'Wet Food': {'emoji': '😻', 'text': 'Mmm, this smells delicious!'},
      'Fish': {'emoji': '🐟', 'text': 'Fishy treat? Yes, please!'},
      'Milk': {'emoji': '🥛', 'text': 'Water is better for me!'},
      'Water': {'emoji': '💧', 'text': 'Ahh, fresh water!'},
      'Treat': {'emoji': '🍖', 'text': 'A little treat makes me happy!'},
    };
    final thought =
        eatingThoughts[food] ?? const {'emoji': '😺', 'text': 'Yum!'};

    // Mark the care animation and thought bubble active together so the
    // reaction is visible while the cat eats/drinks.
    setState(() {
      _foodInBowl = food;
      _isEating = true;
      _feedbackEmoji = thought['emoji']!;
      _feedbackText = thought['text']!;
      _showFeedEffect = true;
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
      _isHappyReaction = true;
      _foodInBowl = null;
    });

    await _happyCatGame.doHappy();

    if (!mounted) return;

    setState(() {
      _isHappyReaction = false;
      _showFeedEffect = false;
      _feedbackText = '';
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
        feedback = 'Yum! My tummy will be happy!';
        emoji = '😸';
        break;
      case 'Wet Food':
        hungerDelta = -20;
        happinessDelta = 10;
        feedback = 'Mmm, this smells delicious!';
        emoji = '😻';
        break;
      case 'Fish':
        hungerDelta = -15;
        happinessDelta = 20;
        feedback = 'Fishy treat? Yes, please!';
        emoji = '🐟';
        break;
      case 'Milk':
        hungerDelta = -10;
        happinessDelta = 15;
        cleanlinessDelta = 5;
        feedback = 'Water is better for me!';
        emoji = '🥛';
        break;
      case 'Water':
        cleanlinessDelta = 10;
        feedback = 'Ahh, fresh water!';
        emoji = '💧';
        break;
      case 'Treat':
        hungerDelta = -10;
        happinessDelta = 25;
        feedback = 'A little treat makes me happy!';
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

    const explanations = <String, String>{
      'Dry Food': 'Balanced cat food provides essential nutrients.',
      'Wet Food': 'Complete wet food provides nutrients and extra moisture.',
      'Fish': 'Plain, cooked, boneless fish is an occasional treat.',
      'Milk': 'Many cats cannot digest cow’s milk well. Water is better.',
      'Water': 'Fresh water helps keep your cat hydrated.',
      'Treat': 'Cat-safe treats should be given in small amounts.',
    };
    setState(() {
      hunger = pet.hunger;
      happiness = pet.happiness;
      cleanliness = pet.cleanliness;
      _foodExplanation = explanations[food] ?? '';
      _feedbackText = feedback;
      _feedbackEmoji = emoji;
      _showFeedEffect = true;
    });

    _service.logActivity(
      icon: Icons.restaurant,
      iconColor: const Color(0xFFFF8C69),
      title: 'Fed cat — $food',
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

    // The Unsafe Food Card theme applies to all three educational unsafe-food
    // cards together, rather than to a purchasable food item.
    final isUnsafeFood =
        const {'Chocolate', 'Onion', 'Garlic'}.contains(item['name']);
    if (isUnsafeFood &&
        idParts.length == 3 &&
        idParts[0] == 'feed' &&
        idParts[1] == 'unsafe') {
      switch (idParts[2]) {
        case 'pink':
          return const Color(0xFFFFDCE8);
        case 'mint':
          return const Color(0xFFDDF4E7);
        case 'blue':
          return const Color(0xFFD9EEFF);
        case 'lilac':
          return const Color(0xFFEADFFF);
        case 'peach':
          return const Color(0xFFFFE2D4);
      }
    }
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
      case 'u1':
        return const Color(0xFFFFF09B);
      case 'u2':
        return const Color(0xFF9DEBE8);
      case 'u3':
        return const Color(0xFFFFA6B7);
      case 'u4':
        return const Color(0xFFC9E0B5);
      case 'u5':
        return const Color(0xFFB9C5FF);
      case 'u6':
        return const Color(0xFF8FE3D1);
      case 'u7':
        return const Color(0xFFCDBDFF);
      case 'u8':
        return const Color(0xFFA9D9FF);
      case 'u9':
        return const Color(0xFFFFA6B7);
      case 'u10':
        return const Color(0xFFB7F0C4);
      case 'u11':
        return const Color(0xFFFFCFB4);
      case 'u12':
        return const Color(0xFFE6B8FF);
      case 'u13':
        return const Color(0xFFF4F59C);
      case 'u14':
        return const Color(0xFF9DEBE8);
      case 'u15':
        return const Color(0xFFE9B4D8);
      case 'u16':
        return const Color(0xFFB9C5FF);
      case 'u17':
        return const Color(0xFFFFD0A1);
      case 'u18':
        return const Color(0xFFC9E0B5);
      case 'u19':
        return const Color(0xFFE2E4E8);
      case 'u20':
        return const Color(0xFFD8A7E8);
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
                                                : pet.furStage > 0
                                                    // The sad/sleepy animations use
                                                    // the clean-fur sprite sheet. Keep
                                                    // the fur-stage animation visible
                                                    // until grooming returns it to 0.
                                                    ? GameWidget(
                                                        game: _feedGame)
                                                    : _isHappyReaction
                                                        ? GameWidget(
                                                            game: _happyCatGame,
                                                          )
                                                        : (isNeglected &&
                                                                pet.furStage ==
                                                                    0)
                                                            ? GameWidget(
                                                                game:
                                                                    _sadCatGame,
                                                              )
                                                            : isSad
                                                                ? GameWidget(
                                                                    game:
                                                                        _sadCatGame,
                                                                  )
                                                                : isSleepy
                                                                    ? GameWidget(
                                                                        game:
                                                                            _sleepyCatGame,
                                                                      )
                                                                    : GameWidget(
                                                                        game:
                                                                            _feedGame,
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
                if (_foodExplanation.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(horizontal: 18),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE8C8A8)),
                    ),
                    child: Text(
                      _foodExplanation,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF80583F),
                      ),
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
