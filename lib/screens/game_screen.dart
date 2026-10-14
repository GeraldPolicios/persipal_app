import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flame/game.dart';
import 'package:audioplayers/audioplayers.dart';

import '../providers/virtual_pet_provider.dart';
import '../services/activity_service.dart';
import '../services/reward_service.dart';
import '../services/virtual_cat_progress_service.dart';
import '../services/global_music_service.dart';
import '../widgets/tap_effects.dart';
import '../widgets/pet_thought.dart';
import '../widgets/nighttime_thought_bubble.dart';
import '../widgets/realtime_clock.dart';
import '../widgets/shop_scene_background.dart';
import '../widgets/dirt_overlay.dart';

import 'feed_screen.dart';
import 'play_screen.dart';
import 'groom_screen.dart';
import 'shop_screen.dart';

import '../models/dirty_state.dart';
import '../models/virtual_pet_status.dart';
import '../models/virtual_pet_state.dart';

import '../game/cat_animation.dart';
import '../game/cat_state_controller.dart';

import '../utils/day_period.dart';
import '../utils/nighttime_mode.dart';
import '../utils/nighttime_thoughts.dart';

Widget _equippedRoomDecoration(String itemId) {
  const decorations = <String, String>{
    'decor_teddybear': '🧸',
    'decor_pottedplant': '🪴',
    'decor_littlestar': '⭐',
    'decor_tinymushroom': '🍄',
    'decor_smallflower': '🌼',
    'decor_minilamp': '🏮',
    'decor_tinycloud': '☁️',
    'decor_littlecactus': '🌵',
    'decor_smallbell': '🔔',
    'decor_miniclock': '🕒',
  };
  final emoji = decorations[itemId];
  if (emoji == null) return const SizedBox.shrink();
  return Container(
    width: 42,
    height: 42,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFE8C7AC), width: 1.5),
      boxShadow: const [
        BoxShadow(
            color: Color(0x22000000), blurRadius: 5, offset: Offset(0, 2)),
      ],
    ),
    child: Text(emoji, style: const TextStyle(fontSize: 25)),
  );
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final _service = ActivityService.instance;
  // Sleep purring belongs only to GameScreen and must not play on Feed/Play/Groom.
  final AudioPlayer _sleepcatPlayer = AudioPlayer();
  bool _sleepcatLoopActive = false;

  bool _askedName = false;
  String catName = 'Meow Meow';

  Timer? _thoughtTimer;
  final Random _thoughtRandom = Random();
  Timer? _petResetTimer;
  Timer? _angryTimer;
  Timer? _nightRoutineTimer;
  Timer? _highFiveSoundTimer;
  Timer? _occasionalMeowTimer;

  // Nighttime bedtime is intentionally handled here as a small layer around
  // the existing Virtual Pet sleep/status system. The time rules themselves
  // live in NighttimeMode so GameScreen does not own a second clock.
  DateTime? _nightRoutineStartedOn;
  bool _initialBedtimeReconciled = false;

  bool isDirty = false;
  bool isNeglected = false;

  bool _isAngry = false;

  int _petCount = 0;

  bool _showHeart = false;
  DateTime? _lastPet;

  bool _showThought = false;
  String _thoughtEmoji = '🍗';
  String? _thoughtText;
  int _nightThoughtIndex = 0;

  double _swipeStartY = 0;
  double _swipeStartX = 0;
  double _swipeCurrentY = 0;

  late CatAnimation catGame;
  late CatStateController catStateController;

  // ==========================================================
  // CAT STATE SYNC CONTROL
  // ==========================================================
  //
  // This prevents the animation from being restarted every time
  // GameScreen rebuilds.
  //
  // More importantly, it allows the cat animation to synchronize
  // AFTER VirtualPetProvider finishes loading its saved state.
  //
  bool _syncScheduled = false;

  int? _lastSyncedHunger;
  int? _lastSyncedHappiness;
  int? _lastSyncedCleanliness;
  int? _lastSyncedEnergy;
  bool? _lastSyncedSleeping;
  int? _lastSyncedFurStage;

  @override
  void initState() {
    super.initState();

    // BGM belongs to the Virtual Pet module only.
    // GameScreen stays mounted while Feed/Play/Groom are pushed, so the
    // same looping track continues without restarting on those screens.
    GlobalMusicService.instance.startForVirtualPet();

    catGame = CatAnimation();

    catStateController = CatStateController(
      catAnimation: catGame,
    );

    dayPeriodNotifier.addListener(_onDayPeriodChanged);

    // Check bedtime independently of day-period changes so an already-open
    // GameScreen notices the 10:00 PM sleepy and 10:30 PM rest transitions.
    _nightRoutineTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _maybeStartNightRoutine(),
    );

    // ========================================================
    // INITIAL SETUP
    // ========================================================
    //
    // Do NOT directly call _syncLocalState() here.
    //
    // VirtualPetProvider may still be loading its saved values.
    // The build() method below will schedule synchronization
    // once loading is finished.
    //
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final vp = context.read<VirtualPetProvider>();

      // The provider may still be restoring the saved virtual pet from Hive
      // or reconciling it with Firestore. Never show the naming dialog from
      // the temporary initial state while that restoration is in progress.
      if (!vp.loading && vp.needsNaming && !_askedName) {
        _askedName = true;
        _askCatName(vp);
      }

      _scheduleCatStateSync();
      _maybeStartNightRoutine();
    });

    _scheduleNextThought();
    _scheduleOccasionalMeow();
  }

  void _onDayPeriodChanged() {
    if (mounted) {
      setState(() {});
      _maybeStartNightRoutine();
    }
  }

  // ==========================================================
  // NIGHT BEDTIME ROUTINE
  // ==========================================================
  //
  // 6:00 PM starts the night environment. At 10:00 PM the cat becomes sleepy;
  // at 10:30 PM the automatic Rest -> Sleep phase begins:
  //
  //   Idle -> Sleepy -> Rest -> Sleep
  //
  // The existing VirtualPetProvider neglected-state rule remains in effect:
  // a genuinely neglected cat is not forced into sleep. Fur stage and normal
  // hunger/cleanliness thresholds do not block bedtime for other cats.
  // Once the existing sleep animation reaches Sleeping, the shared provider
  // sleep state is persisted so reopening the app keeps the cat asleep.
  Future<void> _maybeStartNightRoutine() async {
    if (!mounted) return;

    final now = DateTime.now();
    if (!NighttimeMode.isNighttime(now) || !NighttimeMode.isBedtime(now)) {
      return;
    }

    final today = DateTime(now.year, now.month, now.day);
    if (_nightRoutineStartedOn == today) return;

    final vp = context.read<VirtualPetProvider>();
    if (vp.loading || vp.isNeglected) return;

    final restStart = DateTime(now.year, now.month, now.day, 22, 30);

    // When the player opens the game after bedtime, don't make them wait
    // through a routine that should have happened while the app was closed.
    // Reconcile straight to the sleeping pose once per GameScreen entry.
    // If the screen was already open before 10:30 PM, keep the normal
    // Sleepy -> Rest -> Sleep animation below.
    if (!_initialBedtimeReconciled && !now.isBefore(restStart)) {
      // The app may be reopened after bedtime while the animation controller
      // still reports a transient busy/waking state. Do not let that transient
      // state permanently skip tonight's sleep reconciliation. At this point
      // the bedtime routine should already have completed while the app was
      // closed, so restore the sleeping pose directly after 10:30 PM.
      // Fur stage and ordinary hunger/cleanliness thresholds must not leave
      // a healthy cat awake overnight. The existing neglected-state guard
      // above remains authoritative, so a genuinely neglected cat still
      // follows its existing sad/neglected behavior.
      if (!vp.isNeglected) {
        catGame.showSleeping();
        _initialBedtimeReconciled = true;
        _nightRoutineStartedOn = today;
        await vp.setSleeping(true);
        return;
      }
      // A genuinely neglected cat keeps its existing neglected behavior.
    }

    // If already asleep, synchronize the persisted state and mark tonight done.
    if (catGame.isSleeping || vp.isSleeping) {
      _nightRoutineStartedOn = today;
      if (!vp.isSleeping && catGame.isSleeping) {
        await vp.setSleeping(true);
      }
      return;
    }

    // Do not interrupt waking or a user-triggered trick.
    if (catGame.isWaking || catGame.isBusy) return;

    // At 10:00 PM the cat becomes sleepy. Keep this state for 30 minutes.
    // The 30-second timer will retry and begin Rest only at/after 10:30 PM.
    if (now.isBefore(restStart)) {
      if (!catGame.isSleepy && !catGame.isResting) {
        catGame.enterSleepy(force: true);
      }
      return;
    }

    // From 10:30 PM onward, automatically continue Sleepy -> Rest -> Sleep.
    if (!catGame.isSleepy && !catGame.isResting && !catGame.isSleeping) {
      catGame.enterSleepy(force: true);
    }

    for (var i = 0;
        i < 80 &&
            mounted &&
            !catGame.isSleepy &&
            !catGame.isResting &&
            !catGame.isSleeping;
        i++) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted) return;

    if (catGame.isSleepy) {
      await catGame.restAndSleep();
    } else if (catGame.isResting) {
      for (var i = 0; i < 80 && mounted && !catGame.isSleeping; i++) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    if (!mounted || !catGame.isSleeping) return;

    _nightRoutineStartedOn = today;
    await vp.setSleeping(true);
  }

  // Random, occasional meows while the cat is awake and Game Screen is active.
  // Uses the existing softcat.wav SFX, with no new assets or sound system.
  void _scheduleOccasionalMeow() {
    _occasionalMeowTimer?.cancel();
    final seconds = 65 + _thoughtRandom.nextInt(56); // 65–120 seconds
    _occasionalMeowTimer = Timer(Duration(seconds: seconds), () {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      final vp = context.read<VirtualPetProvider>();
      final bedtime = NighttimeMode.isBedtime();

      if (route?.isCurrent == true &&
          !vp.loading &&
          !vp.isSleeping &&
          !catGame.isSleeping &&
          !catGame.isResting &&
          !catGame.isSleepy &&
          !catGame.isBusy &&
          !bedtime &&
          !NighttimeMode.interactionsLocked) {
        unawaited(GlobalMusicService.instance.playSfx('softcat.wav'));
      }
      _scheduleOccasionalMeow();
    });
  }

  @override
  void dispose() {
    dayPeriodNotifier.removeListener(_onDayPeriodChanged);
    _thoughtTimer?.cancel();
    _petResetTimer?.cancel();
    _angryTimer?.cancel();
    _nightRoutineTimer?.cancel();
    _highFiveSoundTimer?.cancel();
    _occasionalMeowTimer?.cancel();
    _sleepcatLoopActive = false;
    unawaited(_sleepcatPlayer.stop());
    unawaited(_sleepcatPlayer.dispose());

    // Leaving GameScreen means leaving the entire Virtual Pet module.
    GlobalMusicService.instance.stopForVirtualPet();

    super.dispose();
  }

  // ==========================================================
  // SCHEDULE CAT STATE SYNC
  // ==========================================================
  //
  // This is the important fix.
  //
  // context.watch<VirtualPetProvider>() causes build() to run
  // whenever the provider changes.
  //
  // Once the provider is no longer loading, this schedules a
  // post-frame synchronization using the CURRENT stats.
  //
  Future<void> _syncSleepcatLoop(bool sleeping) async {
    if (!mounted) return;
    if (sleeping) {
      if (_sleepcatLoopActive) return;
      _sleepcatLoopActive = true;
      try {
        await _sleepcatPlayer.setReleaseMode(ReleaseMode.loop);
        await _sleepcatPlayer.setVolume(1.0);
        await _sleepcatPlayer.play(AssetSource('sounds/sleepcat.wav'));
      } catch (e) {
        _sleepcatLoopActive = false;
        debugPrint('GameScreen: sleepcat loop failed: $e');
      }
    } else {
      _sleepcatLoopActive = false;
      try {
        await _sleepcatPlayer.stop();
      } catch (e) {
        debugPrint('GameScreen: stopping sleepcat failed: $e');
      }
    }
  }

  void _scheduleCatStateSync() {
    if (_syncScheduled) return;

    _syncScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;

      if (!mounted) return;

      final vp = context.read<VirtualPetProvider>();

      // Provider is still loading.
      //
      // Do nothing here.
      // Once loading changes, context.watch() causes build()
      // to run again and synchronization will happen then.
      if (vp.loading) return;
      if (!vp.needsNaming) _showWelcomeThought(vp);
      // Keep the looping purr synchronized with the saved sleeping state.
      unawaited(_syncSleepcatLoop(vp.isSleeping || catGame.isSleeping));

      final statsUnchanged = _lastSyncedHunger == vp.hunger &&
          _lastSyncedHappiness == vp.happiness &&
          _lastSyncedCleanliness == vp.cleanliness &&
          _lastSyncedEnergy == vp.energy &&
          _lastSyncedSleeping == vp.isSleeping &&
          _lastSyncedFurStage == vp.furStage;

      // Nothing changed since the last synchronization.
      if (statsUnchanged) return;

      // Remember exactly which provider state we synchronized.
      _lastSyncedHunger = vp.hunger;
      _lastSyncedHappiness = vp.happiness;
      _lastSyncedCleanliness = vp.cleanliness;
      _lastSyncedEnergy = vp.energy;
      _lastSyncedSleeping = vp.isSleeping;

      _syncLocalState(vp);
    });
  }

  // ==========================================================
  // SYNC CAT STATE
  // ==========================================================
  void _syncLocalState(VirtualPetProvider vp) {
    if (!mounted) return;

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
    catGame.setFurStage(vp.furStage);

    // Bedtime must win over a stale animation/provider state when GameScreen
    // first opens or rebuilds after 10:30 PM. Otherwise the normal controller
    // can restore Idle/FurIdle while the persisted sleep flag is still saving.
    // Keep the existing neglected-cat exception unchanged.
    final now = DateTime.now();
    final afterBedtime =
        now.hour < 6 || now.hour > 22 || (now.hour == 22 && now.minute >= 30);
    if (afterBedtime && !vp.isNeglected) {
      if (!vp.isSleeping) {
        unawaited(vp.setSleeping(true));
      }
      if (!catGame.isSleeping) {
        catGame.showSleeping();
      }
      return;
    }

    // ========================================================
    // NEVER INTERRUPT A WAKE TRANSITION
    //
    // The provider remains isSleeping=true until the wake animation
    // finishes. If a rebuild happens during those few seconds, calling
    // showSleeping() here would restart the sleep animation and cause:
    // Wake -> Idle -> Sleep.
    // ========================================================
    if (catGame.isWaking) {
      return;
    }

    // ========================================================
    // PROVIDER SAYS CAT IS SLEEPING
    // ========================================================
    else if (vp.isSleeping &&
        vp.hunger < 90 &&
        vp.cleanliness > 30 &&
        vp.furStage == 0) {
      catGame.showSleeping();
    }

    // ========================================================
    // OTHERWISE LET THE CONTROLLER DECIDE
    // Urgent hunger/dirty status and fur appearance must not be hidden by
    // a stale persisted sleep flag.
    // ========================================================
    else if (vp.furStage > 0) {
      // Only the Fur1/Fur2 animation is shown until grooming is completed.
      // Status is still stored in the provider and re-evaluated at Fur0.
      catGame.showFurIdle(vp.furStage, force: true);
    } else {
      catStateController.refresh(
        hunger: vp.hunger,
        happiness: vp.happiness,
        cleanliness: vp.cleanliness,
        energy: vp.energy,
        wantsToPlay: vp.wantsToPlay,
        furStage: vp.furStage,
      );
    }
  }

  // ==========================================================
  // CAT TAP
  // ==========================================================
  Future<void> _onCatTap() async {
    if (!mounted) return;

    // Nighttime is a separate, non-interactive mode. Thoughts are still
    // allowed, but tapping cannot wake, pet, or otherwise affect the cat.
    if (NighttimeMode.interactionsLocked) {
      return;
    }

    final vp = context.read<VirtualPetProvider>();

    if (isNeglected) {
      _showThoughtBubble();
      return;
    }

    // ========================================================
    // SLEEPY → REST → SLEEPING
    // ========================================================
    if (catGame.isSleepy) {
      await catStateController.onCatTap(energy: vp.energy);

      if (!mounted) return;

      if (catGame.isSleeping) {
        await vp.setSleeping(true);
      }

      return;
    }

    // ========================================================
    // RESTING
    // ========================================================
    if (catGame.isResting) {
      return;
    }

    // ========================================================
    // SLEEPING
    //
    // Energy <= 20: only show 😴 / ZZZ and remain asleep.
    // Energy > 20: tapping is allowed to trigger Wake.
    // ========================================================
    if (catGame.isSleeping) {
      if (vp.energy <= 20) {
        _showThoughtBubble(forcedEmoji: '😴');
        return;
      }

      await catStateController.onCatTap(energy: vp.energy);

      if (!mounted) return;

      if (!catGame.isSleeping && !catGame.isWaking) {
        await vp.setSleeping(false);

        catStateController.refresh(
          hunger: vp.hunger,
          happiness: vp.happiness,
          cleanliness: vp.cleanliness,
          energy: vp.energy,
          wantsToPlay: vp.wantsToPlay,
          furStage: vp.furStage,
        );
      }

      return;
    }

    // ========================================================
    // WAKING
    // ========================================================
    if (catGame.isWaking || catGame.isStanding) {
      // A standing cat must remain standing until the user swipes down.
      return;
    }

    // ========================================================
    // HUNGRY / DIRTY
    // ========================================================
    if (vp.hunger >= 70 || isDirty) {
      unawaited(GlobalMusicService.instance.playSfx(
        vp.hunger >= 70 ? 'hungrycat.wav' : 'sadcat.wav',
      ));
      _showThoughtBubble();
      return;
    }

    _petCount++;

    _petResetTimer?.cancel();

    _petResetTimer = Timer(
      const Duration(seconds: 3),
      () {
        _petCount = 0;
      },
    );

    // ========================================================
    // 4 TAPS → ANGRY
    // ========================================================
    if (_petCount >= 4) {
      unawaited(GlobalMusicService.instance.playSfx('angrycat.wav'));
      _petCount = 0;
      _petResetTimer?.cancel();

      _isAngry = true;

      setState(() {
        _showHeart = false;
      });

      await catGame.doAngry();

      if (!mounted) return;

      await vp.reconcile(
        happiness: (vp.happiness - 3).clamp(0, 100),
      );

      _angryTimer?.cancel();

      _angryTimer = Timer(
        const Duration(milliseconds: 4800),
        () {
          if (!mounted) return;

          setState(() {
            _isAngry = false;
          });
        },
      );

      return;
    }

    // ========================================================
    // NORMAL TAP → HAPPY
    // ========================================================
    // One reaction sound per animation; playing both at once caused timing conflicts.
    unawaited(GlobalMusicService.instance.playSfx('pettedcat.wav'));
    setState(() {
      _showHeart = true;
    });

    final happyFuture = catGame.doHappy();

    await vp.reconcile(
      happiness: (vp.happiness + 2).clamp(0, 100),
    );

    Future.delayed(
      const Duration(milliseconds: 1200),
      () {
        if (!mounted) return;

        setState(() {
          _showHeart = false;
        });
      },
    );

    await happyFuture;
  }

  // ==========================================================
  // PETTING
  // ==========================================================
  void _onPetting() {
    if (!mounted) return;
    if (NighttimeMode.interactionsLocked) return;

    final vp = context.read<VirtualPetProvider>();

    if (catGame.isSleeping ||
        catGame.isSleepy ||
        catGame.isResting ||
        catGame.isWaking ||
        catGame.isStanding ||
        vp.hunger >= 70 ||
        isDirty ||
        isNeglected ||
        _isAngry) {
      return;
    }

    final now = DateTime.now();

    if (_lastPet == null || now.difference(_lastPet!).inMilliseconds > 300) {
      _lastPet = now;

      setState(() {
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

  // ==========================================================
  // SWIPE UP → HIGH FIVE
  // ==========================================================
  void _onSwipeUp() {
    if (!mounted) return;
    if (NighttimeMode.interactionsLocked) return;

    if (catGame.isSleeping ||
        catGame.isSleepy ||
        catGame.isResting ||
        catGame.isWaking ||
        catGame.isBusy ||
        isNeglected ||
        isDirty) {
      return;
    }

    // Stand animation runs for 60 frames × 0.06s = 3.6s.
    // Start the high-five sound when the high-five animation begins.
    _highFiveSoundTimer?.cancel();
    catGame.doHighFive();
    _highFiveSoundTimer = Timer(const Duration(milliseconds: 3600), () {
      if (!mounted || !catGame.isStanding) return;
      unawaited(GlobalMusicService.instance.playSfx('softcat.wav'));
    });
  }

  // ==========================================================
  // SWIPE DOWN → SIT
  // ==========================================================
  void _onSwipeDown() {
    if (!mounted) return;
    _highFiveSoundTimer?.cancel();
    if (NighttimeMode.interactionsLocked) return;

    if (catGame.isSleeping ||
        catGame.isSleepy ||
        catGame.isResting ||
        catGame.isWaking ||
        catGame.isBusy ||
        isNeglected ||
        isDirty) {
      return;
    }

    catGame.sitDown();
  }

  // ==========================================================
  // CAT NAME
  // ==========================================================
  void _askCatName(VirtualPetProvider vp) {
    final ctrl = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
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
        );
      },
    );
  }

  // ==========================================================
  // EMOTION
  // ==========================================================
  String _getEmotion(
    int hunger,
    int happiness,
    int cleanliness,
    int energy,
  ) {
    final status = resolveVirtualPetStatus(
      VirtualPetState.initial().copyWith(
        hunger: hunger,
        happiness: happiness,
        cleanliness: cleanliness,
        energy: energy,
      ),
    );

    switch (status) {
      case VirtualPetStatus.neglected:
        return 'sad';
      case VirtualPetStatus.criticalHunger:
        return 'sad';
      case VirtualPetStatus.sleepy:
        return 'sleepy';
      case VirtualPetStatus.sad:
        return 'sad';
      case VirtualPetStatus.hungry:
        return 'sad';
      case VirtualPetStatus.dirty:
      case VirtualPetStatus.wantsToPlay:
      case VirtualPetStatus.normal:
        final avg = (happiness + cleanliness + (100 - hunger) + energy) ~/ 4;
        if (avg >= 60) return 'happy';
        if (avg >= 30) return 'normal';
        return 'sad';
    }
  }

  // ==========================================================
  // NEGLECTED CHECK
  // ==========================================================
  void _checkNeglected(VirtualPetProvider vp) {
    // Update the last synchronized values so the next provider
    // rebuild can detect the latest state correctly.
    _lastSyncedHunger = null;
    _lastSyncedHappiness = null;
    _lastSyncedCleanliness = null;
    _lastSyncedEnergy = null;
    _lastSyncedSleeping = null;

    _syncLocalState(vp);
    if (vp.furStage > 0 && !_showThought) {
      _showCleanFirstThought();
    }
  }

  // Show a short welcome thought when the named cat is first loaded.
  // This is called by the post-frame sync, so avoid repeating it on every
  // provider update while the Game Screen remains mounted.
  bool _welcomeThoughtShown = false;

  DateTime? _lastThoughtCareSoundAt;
  DateTime? _lastThoughtMeowAt;

  // Sound follows the thought that was selected. Cooldowns prevent rebuilds
  // or rapid thought changes from replaying the same sound repeatedly.
  void _playCareThoughtSound(VirtualPetProvider vp) {
    final now = DateTime.now();
    if (_lastThoughtCareSoundAt != null &&
        now.difference(_lastThoughtCareSoundAt!) <
            const Duration(seconds: 45)) {
      return;
    }

    String? sound;
    if (vp.hunger >= 70) {
      sound = 'hungrycat.wav';
    } else if (vp.cleanliness <= 30 || isNeglected) {
      sound = 'sadcat.wav';
    }
    if (sound == null) return;

    _lastThoughtCareSoundAt = now;
    unawaited(GlobalMusicService.instance.playSfx(sound));
  }

  void _maybeMeowWithNormalThought() {
    final now = DateTime.now();
    if (_thoughtRandom.nextInt(3) != 0) return; // Not every thought meows.
    if (_lastThoughtMeowAt != null &&
        now.difference(_lastThoughtMeowAt!) < const Duration(seconds: 65)) {
      return;
    }
    _lastThoughtMeowAt = now;
    unawaited(GlobalMusicService.instance.playSfx('softcat.wav'));
  }

  void _showWelcomeThought(VirtualPetProvider vp) {
    if (!mounted || _welcomeThoughtShown || vp.loading || vp.needsNaming) {
      return;
    }
    // Nighttime, sleep, and care-priority thoughts take precedence.
    if (NighttimeMode.interactionsLocked ||
        vp.isSleeping ||
        vp.furStage > 0 ||
        vp.hunger >= 90 ||
        vp.cleanliness <= 30) {
      return;
    }
    _welcomeThoughtShown = true;
    _thoughtTimer?.cancel();
    setState(() {
      _thoughtEmoji = '🐾';
      _thoughtText = "You're home, my hooman!";
      _showThought = true;
    });
    unawaited(GlobalMusicService.instance.playSfx('softcat.wav'));
    _thoughtTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      setState(() {
        _showThought = false;
        _thoughtText = null;
      });
      _scheduleNextThought();
    });
  }

  void _showCleanFirstThought() {
    if (!mounted) return;
    _thoughtTimer?.cancel();

    final vp = context.read<VirtualPetProvider>();
    final sleepingAtNight = NighttimeMode.isNighttime() &&
        (vp.isSleeping || catGame.isSleeping || catGame.isResting);

    setState(() {
      _thoughtEmoji = sleepingAtNight ? '😴' : '🧼';
      // Sleeping cats show emoji-only thoughts at night.
      _thoughtText = sleepingAtNight ? null : 'Clean me first!';
      _showThought = true;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() {
        _showThought = false;
        _thoughtText = null;
      });
      _scheduleNextThought();
    });
  }

  // ==========================================================
  // THOUGHT BUBBLE
  // ==========================================================
  // During 6:00 PM–9:00 PM, nighttime thoughts are text-based and
  // appear at a random interval so the player has time to read them.
  // Once bedtime starts, sleeping keeps the existing emoji-only thought.
  void _scheduleNextThought() {
    _thoughtTimer?.cancel();

    final now = DateTime.now();
    final vp = context.read<VirtualPetProvider>();

    // While the cat still has long/medium fur, keep the only thought as
    // "Clean me first!" and do not rotate in unrelated thoughts.
    if (vp.furStage > 0) {
      _thoughtTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        _showCleanFirstThought();
      });
      return;
    }

    final nighttimeAwake = NighttimeMode.isNighttime(now) &&
        !NighttimeMode.isBedtime(now) &&
        !vp.isSleeping &&
        !catGame.isSleeping &&
        !catGame.isResting;

    final seconds = nighttimeAwake
        ? 20 + _thoughtRandom.nextInt(26) // 20–45 seconds
        : 12;

    _thoughtTimer = Timer(
      Duration(seconds: seconds),
      () {
        if (!mounted) return;
        _showThoughtBubble();
        _scheduleNextThought();
      },
    );
  }

  void _showThoughtBubble({String? forcedEmoji}) {
    if (!mounted) return;

    final vp = context.read<VirtualPetProvider>();

    final now = DateTime.now();
    final sleepingAtNight = NighttimeMode.isNighttime(now) &&
        (vp.isSleeping || catGame.isSleeping || catGame.isResting);

    if (vp.furStage > 0 && forcedEmoji == null) {
      if (sleepingAtNight) {
        setState(() {
          _thoughtEmoji = '😴';
          _thoughtText = null;
          _showThought = true;
        });
        Future.delayed(const Duration(seconds: 4), () {
          if (!mounted) return;
          setState(() {
            _showThought = false;
            _thoughtText = null;
          });
        });
      } else {
        _showCleanFirstThought();
      }
      return;
    }

    final nighttimeAwake = NighttimeMode.isNighttime(now) &&
        !NighttimeMode.isBedtime(now) &&
        !vp.isSleeping &&
        !catGame.isSleeping &&
        !catGame.isResting;

    // 6:00 PM–10:00 PM: use the dedicated funny nighttime thought pool.
    // This does not change any stats or the existing status system.
    if (nighttimeAwake && forcedEmoji == null) {
      var index = _thoughtRandom.nextInt(NighttimeThoughts.all.length);
      // Avoid showing the same thought twice in a row.
      if (NighttimeThoughts.all.length > 1 &&
          index == (_nightThoughtIndex - 1) % NighttimeThoughts.all.length) {
        index = (index + 1) % NighttimeThoughts.all.length;
      }
      final thought = NighttimeThoughts.all[index];
      _nightThoughtIndex = index + 1;

      setState(() {
        _thoughtEmoji = '🐱';
        _thoughtText = thought;
        _showThought = true;
      });

      Future.delayed(
        const Duration(seconds: 6),
        () {
          if (!mounted) return;
          setState(() {
            _showThought = false;
            _thoughtText = null;
          });
        },
      );
      return;
    }

    // Normal daytime/status thoughts continue to use the existing priority.
    // Sleeping remains emoji-only, including the 😴 thought.
    String? emoji = forcedEmoji ?? vp.priorityThoughtEmoji;

    if (emoji == null && NighttimeMode.interactionsLocked) {
      const nightThoughts = ['😴', '💤', '🌙', '⭐'];
      emoji = nightThoughts[_nightThoughtIndex % nightThoughts.length];
      _nightThoughtIndex++;
    }

    if (emoji == null) {
      // Gentle everyday thoughts are only shown when no care/status thought
      // has priority. This prevents normal chatter from replacing urgent
      // hunger, dirt, fur, sleep, or nighttime thoughts.
      final normalDaytime = !NighttimeMode.interactionsLocked &&
          !NighttimeMode.isNighttime(now) &&
          !vp.isSleeping &&
          !catGame.isSleeping &&
          !catGame.isResting &&
          vp.furStage == 0 &&
          vp.hunger < 90 &&
          vp.cleanliness > 30 &&
          vp.happiness > 20 &&
          vp.energy > 15;

      if (!normalDaytime) return;

      const everydayThoughts = [
        'That was a nice nap… oh wait, I am always napping.',
        'I wonder if my hooman knows I am adorable.',
        'Everything is better with a little head scratch.',
        'I am supervising. It is a very important cat job.',
        'If I sit here, does that make it my spot?',
        'Purrhaps today is a good day for cuddles.',
      ];
      final thought =
          everydayThoughts[_thoughtRandom.nextInt(everydayThoughts.length)];

      setState(() {
        _thoughtEmoji = '🐱';
        _thoughtText = thought;
        _showThought = true;
      });
      // Sometimes pair an everyday thought with a meow; keep the existing
      // text and emoji untouched and avoid competing with care sounds.
      _maybeMeowWithNormalThought();

      Future.delayed(const Duration(seconds: 4), () {
        if (!mounted || !_showThought || _thoughtText != thought) return;
        setState(() {
          _showThought = false;
          _thoughtText = null;
        });
      });
      return;
    }

    setState(() {
      _thoughtEmoji = emoji!;
      _thoughtText = null;
      _showThought = true;
    });

    // Only sync care audio with a genuine status-priority thought. Forced
    // action thoughts (for example, a feed button) retain their existing audio.
    if (forcedEmoji == null && vp.priorityThoughtEmoji != null) {
      _playCareThoughtSound(vp);
    }

    Future.delayed(
      const Duration(seconds: 4),
      () {
        if (!mounted) return;
        setState(() {
          _showThought = false;
          _thoughtText = null;
        });
      },
    );
  }

  Color _statColor(
    int value, {
    bool invert = false,
  }) {
    final v = invert ? 100 - value : value;

    if (v >= 66) {
      return const Color(0xFF32CD32);
    }

    if (v >= 33) {
      return const Color(0xFFFFA500);
    }

    return Colors.redAccent;
  }

  Widget _conditionBadge(String emotion) {
    late String label;
    late String emoji;
    late Color color;

    switch (emotion) {
      case 'happy':
        label = 'Doing Great';
        emoji = '😻';
        color = const Color(0xFF32CD32);
        break;

      case 'normal':
        label = 'Doing Okay';
        emoji = '😺';
        color = const Color(0xFFFFA500);
        break;

      case 'sleepy':
        label = 'Sleepy';
        emoji = '😴';
        color = const Color(0xFF7B68EE);
        break;

      default:
        label = 'Needs Care';
        emoji = '😿';
        color = Colors.redAccent;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 8,
        horizontal: 10,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Text(
            emoji,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(width: 6),
          const Text(
            'Overall Condition',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: Color(0xFFAA7755),
            ),
          ),
          const Spacer(),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vp = context.watch<VirtualPetProvider>();
    final rewards = context.watch<RewardService>();

    // ========================================================
    // WAIT FOR PROVIDER TO FINISH LOADING
    // ========================================================
    if (vp.loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFE6CC),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // ========================================================
    // IMPORTANT FIX
    //
    // Provider is now loaded.
    //
    // Schedule synchronization using the CURRENT provider
    // values.
    // ========================================================
    _scheduleCatStateSync();

    // Naming is checked only after the saved pet has finished loading. This
    // prevents a restart from prompting for a name before Hive/cloud restore
    // has supplied the existing catName.
    if (vp.needsNaming && !_askedName) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _askedName) return;
        final currentVp = context.read<VirtualPetProvider>();
        if (currentVp.loading || !currentVp.needsNaming) return;
        _askedName = true;
        _askCatName(currentVp);
      });
    }

    final providerCatName = vp.catName.isEmpty ? 'Meow Meow' : vp.catName;

    if (catName == 'Meow Meow' && providerCatName != 'Meow Meow') {
      catName = providerCatName;
    }

    final emotion = _getEmotion(
      vp.hunger,
      vp.happiness,
      vp.cleanliness,
      vp.energy,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFFFE6CC),
      body: Stack(
        children: [
          const ShopSceneBackground(slot: 'background_room'),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                      const Icon(
                        Icons.pets,
                        color: Color(0xFFFF8C69),
                        size: 22,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          "$catName's World",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      AnimatedBuilder(
                        animation: VirtualCatProgressService.instance,
                        builder: (context, _) {
                          final progression =
                              VirtualCatProgressService.instance;
                          return GestureDetector(
                            onTap: () {
                              showDialog<void>(
                                context: context,
                                barrierDismissible: true,
                                builder: (dialogContext) => Dialog(
                                  backgroundColor: const Color(0xFFFFF9F1),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                  child: AnimatedBuilder(
                                    animation:
                                        VirtualCatProgressService.instance,
                                    builder: (context, _) {
                                      final progress =
                                          VirtualCatProgressService.instance;
                                      final milestones = <({
                                        int level,
                                        String title,
                                        String subtitle
                                      })>[
                                        (
                                          level: 5,
                                          title: 'Feed & Grooming',
                                          subtitle:
                                              'Feeding items and care tools'
                                        ),
                                        (
                                          level: 7,
                                          title: 'Decor',
                                          subtitle: 'Furniture and decorations'
                                        ),
                                        (
                                          level: 10,
                                          title: 'All Rooms',
                                          subtitle: 'Additional room designs'
                                        ),
                                      ];
                                      return Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: SingleChildScrollView(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              Row(
                                                children: [
                                                  const Icon(Icons.star_rounded,
                                                      color: Color(0xFFE6A62E),
                                                      size: 30),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                            'Level ${progress.level}',
                                                            style: const TextStyle(
                                                                fontSize: 22,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Color(
                                                                    0xFF7B4D22))),
                                                        const Text(
                                                            'Your cat-care journey',
                                                            style: TextStyle(
                                                                fontSize: 12,
                                                                color: Color(
                                                                    0xFF9A7048))),
                                                      ],
                                                    ),
                                                  ),
                                                  IconButton(
                                                    tooltip: 'Close',
                                                    onPressed: () =>
                                                        Navigator.of(
                                                                dialogContext)
                                                            .pop(),
                                                    icon: const Icon(
                                                        Icons.close_rounded),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 16),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  const Text('Experience (XP)',
                                                      style: TextStyle(
                                                          fontWeight:
                                                              FontWeight.w600)),
                                                  Text(
                                                      '${progress.xpIntoLevel}/${progress.xpNeededForNextLevel} XP',
                                                      style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700)),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                                child: LinearProgressIndicator(
                                                  value: progress.levelProgress,
                                                  minHeight: 10,
                                                  backgroundColor:
                                                      const Color(0xFFFFDDB0),
                                                  valueColor:
                                                      const AlwaysStoppedAnimation<
                                                              Color>(
                                                          Color(0xFFFFA23A)),
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                  '${progress.xpNeededForNextLevel - progress.xpIntoLevel} XP to reach Level ${progress.level + 1}',
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color:
                                                          Color(0xFF9A7048))),
                                              const SizedBox(height: 20),
                                              const Text(
                                                  'UPCOMING SHOP UNLOCKS',
                                                  style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      letterSpacing: 1,
                                                      color:
                                                          Color(0xFF9A7048))),
                                              const SizedBox(height: 10),
                                              ...milestones.map((milestone) {
                                                final unlocked =
                                                    progress.level >=
                                                        milestone.level;
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          bottom: 10),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: 42,
                                                        height: 42,
                                                        decoration: BoxDecoration(
                                                            color: const Color(
                                                                0xFFF6E7D4),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        12)),
                                                        child: Icon(
                                                          milestone.level == 5
                                                              ? Icons
                                                                  .restaurant_rounded
                                                              : milestone.level ==
                                                                      7
                                                                  ? Icons
                                                                      .chair_rounded
                                                                  : Icons
                                                                      .home_rounded,
                                                          color: const Color(
                                                              0xFFA6784E),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 10),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                                'Level ${milestone.level} · ${milestone.title}',
                                                                style: const TextStyle(
                                                                    fontSize:
                                                                        13,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w700)),
                                                            const SizedBox(
                                                                height: 2),
                                                            Text(
                                                                unlocked
                                                                    ? 'Unlocked!'
                                                                    : milestone
                                                                        .subtitle,
                                                                style: TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                    color: unlocked
                                                                        ? const Color(
                                                                            0xFF3A9B68)
                                                                        : const Color(
                                                                            0xFF9A7048))),
                                                          ],
                                                        ),
                                                      ),
                                                      Icon(
                                                          unlocked
                                                              ? Icons
                                                                  .check_circle_rounded
                                                              : Icons
                                                                  .lock_rounded,
                                                          color: unlocked
                                                              ? const Color(
                                                                  0xFF3A9B68)
                                                              : const Color(
                                                                  0xFFA6784E),
                                                          size: 20),
                                                    ],
                                                  ),
                                                );
                                              }),
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                    color:
                                                        const Color(0xFFFFE9D4),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            14)),
                                                child: const Text(
                                                    'Keep caring for your cat to earn XP!',
                                                    textAlign: TextAlign.center,
                                                    style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color:
                                                            Color(0xFF79502F))),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 104,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF0D9),
                                borderRadius: BorderRadius.circular(11),
                                border:
                                    Border.all(color: const Color(0xFFFFC56B)),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.star_rounded,
                                          color: Color(0xFFE6A62E), size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Lv. ${progression.level}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF7B4D22),
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '${progression.xpIntoLevel}/${progression.xpNeededForNextLevel}',
                                        style: const TextStyle(
                                          fontSize: 8,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF9A7048),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: LinearProgressIndicator(
                                      value: progression.levelProgress,
                                      minHeight: 4,
                                      backgroundColor: const Color(0xFFFFDDB0),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                        Color(0xFFFFA23A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
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
                      image: DecorationImage(
                        image: AssetImage(
                          roomAsset(
                            dayPeriodNotifier.value,
                            day: 'assets/images/cat_room/cat_bg_room_ver2.png',
                            noon:
                                'assets/images/cat_room/cat_bg_room_ver2noon.png',
                            night:
                                'assets/images/cat_room/cat_bg_room_ver2night.png',
                          ),
                        ),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Stack(
                      children: [
                        // The currently equipped room decoration is placed at a
                        // fixed floor spot. It is intentionally not draggable,
                        // and RewardService notifications update it immediately.
                        if (rewards.equippedShopItem('item_room_decor') != null)
                          Positioned(
                            left: 22,
                            bottom: 12,
                            child: IgnorePointer(
                              child: _equippedRoomDecoration(
                                rewards.equippedShopItem('item_room_decor')!,
                              ),
                            ),
                          ),
                        const Positioned(
                          top: 10,
                          right: 12,
                          child: RealtimeClock(),
                        ),
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              bottom: 10,
                            ),
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: NighttimeMode.interactionsLocked
                                  ? () {}
                                  : _onCatTap,
                              onPanStart: (details) {
                                if (!mounted ||
                                    NighttimeMode.interactionsLocked) {
                                  return;
                                }

                                _swipeStartX = details.localPosition.dx;

                                _swipeStartY = details.localPosition.dy;

                                _swipeCurrentY = details.localPosition.dy;

                                setState(() {});
                              },
                              onPanUpdate: (details) {
                                if (!mounted ||
                                    NighttimeMode.interactionsLocked) {
                                  return;
                                }

                                _swipeCurrentY = details.localPosition.dy;

                                final verticalDistance =
                                    _swipeStartY - _swipeCurrentY;

                                final horizontalDistance =
                                    (_swipeStartX - details.localPosition.dx)
                                        .abs();

                                if (verticalDistance.abs() > 40 &&
                                    verticalDistance.abs() >
                                        horizontalDistance) {
                                  setState(() {});
                                } else {
                                  _onPetting();
                                }
                              },
                              onPanEnd: (details) {
                                if (!mounted ||
                                    NighttimeMode.interactionsLocked) {
                                  return;
                                }

                                final swipeDistance =
                                    _swipeStartY - _swipeCurrentY;

                                if (swipeDistance > 60) {
                                  _onSwipeUp();
                                } else if (swipeDistance < -60) {
                                  _onSwipeDown();
                                }

                                setState(() {});
                              },
                              child: SizedBox(
                                width: 180,
                                height: 170,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.bottomCenter,
                                  children: [
                                    Align(
                                      alignment: Alignment.bottomCenter,
                                      child: SizedBox(
                                        width: 180,
                                        height: 170,
                                        child: IgnorePointer(
                                          child: GameWidget<CatAnimation>(
                                            game: catGame,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (isDirty && !isNeglected)
                                      const Positioned(
                                        left: 42,
                                        top: 62,
                                        child: DirtOverlay(
                                          size: 110,
                                          showFly: false,
                                        ),
                                      ),
                                    if (isNeglected)
                                      const Positioned(
                                        left: 42,
                                        top: 62,
                                        child: DirtOverlay(
                                          size: 110,
                                          showFly: true,
                                          heavy: true,
                                        ),
                                      ),
                                    if (_showThought && _thoughtText != null)
                                      NighttimeThoughtBubble(
                                        text: _thoughtText!,
                                      )
                                    else if (_showThought)
                                      Positioned(
                                        // Emoji thoughts use a dedicated
                                        // anchor for the lying sleeping/resting
                                        // cat. Keep the bubble near the cat's
                                        // head rather than over its body.
                                        left: 92,
                                        bottom: 82,
                                        child: PetThought(
                                          emoji: _thoughtEmoji,
                                          text: null,
                                        ),
                                      ),
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
                                            '❤️',
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
                      ],
                    ),
                  ),
                ),
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
                        _conditionBadge(emotion),
                        const SizedBox(height: 10),
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
                        ),
                        _statRow(
                          '⚡',
                          'Energy',
                          vp.energy,
                          _statColor(vp.energy),
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
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
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      0,
                      16,
                      4,
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // The action area is the tightest part of the room on
                        // smaller iPhones. Keep the same 2x2 design but let
                        // the cards become slightly shorter when needed.
                        final compact = constraints.maxHeight < 275;

                        return Column(
                          children: [
                            Expanded(
                              child: GridView.count(
                                shrinkWrap: false,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 2,
                                mainAxisSpacing: compact ? 6 : 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: compact ? 2.15 : 1.8,
                                children: [
                                  _actionCard(
                                    '🍗',
                                    'Feed',
                                    const Color(0xFFFF8C69),
                                    () => _onFeed(vp),
                                    playClick: true,
                                    enabled: true,
                                  ),
                                  _actionCard(
                                    '✂️',
                                    'Groom',
                                    const Color(0xFF7B68EE),
                                    () => _onGroom(vp),
                                    playClick: true,
                                    enabled: true,
                                  ),
                                  _actionCard(
                                    '🎾',
                                    'Play',
                                    const Color(0xFF20B2AA),
                                    () => _onPlay(vp),
                                    playClick: true,
                                    enabled: true,
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
                                      vp.energy,
                                    ),
                                    playClick: true,
                                    enabled: true,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            SizedBox(
                              height: compact ? 40 : 48,
                              width: double.infinity,
                              child: _actionCard(
                                '🛍️',
                                'Shop',
                                const Color(0xFFAA7755),
                                _onShop,
                                playClick: true,
                                enabled: true,
                              ),
                            ),
                          ],
                        );
                      },
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
            style: const TextStyle(fontSize: 14),
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
            width: 42,
            child: Text(
              '$value%',
              maxLines: 1,
              softWrap: false,
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

  Widget _actionCard(
    String emoji,
    String label,
    Color color,
    VoidCallback onTap, {
    bool playClick = false,
    bool enabled = true,
  }) {
    final card = Opacity(
      opacity: enabled ? 1.0 : 0.38,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              emoji,
              style: const TextStyle(
                fontSize: 20,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                height: 1.0,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );

    if (!enabled) {
      // No GestureDetector at night: the action cannot bounce, click, or
      // produce an SFX. It is visually present but intentionally inactive.
      return card;
    }

    return BounceButton(
      onTap: () {
        if (playClick) {
          GlobalMusicService.instance.playSfx('click.mp3');
        }
        onTap();
      },
      child: card,
    );
  }

  // ==========================================================
  // FEED
  // ==========================================================
  Future<void> _onFeed(
    VirtualPetProvider vp,
  ) async {
    // Feed remains available at night; only direct GameScreen interaction
    // is locked. Nighttime home actions are intentionally limited to care.

    // Hunger has higher care priority than ordinary Dirt.
    // A hungry + dirty cat must still be able to open FeedScreen.
    // Neglected remains blocked until the cat receives higher-priority care.
    if (isNeglected) {
      _showThoughtBubble();
      return;
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FeedScreen(
          hunger: vp.hunger,
          happiness: vp.happiness,
          cleanliness: vp.cleanliness,
          isDirty: isDirty,
          onUpdate: (
            h,
            hp,
            c,
          ) {
            // FeedScreen now updates VirtualPetProvider directly.
            // Keep this callback for compatibility with the existing screen API.
          },
        ),
      ),
    );

    if (!mounted) return;

    _checkNeglected(vp);
  }

  // ==========================================================
  // GROOM
  // ==========================================================
  Future<void> _onGroom(
    VirtualPetProvider vp,
  ) async {
    // Groom remains available at night; only direct GameScreen interaction
    // is locked. Nighttime home actions are intentionally limited to care.

    // Match PlayScreen: a critically hungry cat should be fed before normal
    // grooming. Neglected cats remain groomable so grooming can break the
    // neglected condition.
    if (vp.isCriticalHunger && !vp.isNeglected) {
      _showThoughtBubble(forcedEmoji: '🍗');
      return;
    }

    await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => GroomScreen(
          isDirty: isDirty,
          cleanliness: vp.cleanliness,
          onAction: (action) {
            // GroomScreen now updates VirtualPetProvider directly.
            // Keep this callback for compatibility with the existing screen API.
          },
        ),
      ),
    );

    if (!mounted) return;

    // GroomScreen already updates VirtualPetProvider directly.
    // Do not write the same cleanliness value a second time here.
    _checkNeglected(vp);
  }

  // ==========================================================
  // PLAY
  // ==========================================================
  void _onPlay(
    VirtualPetProvider vp,
  ) {
    // Keep Play screen accessible at night; PlayScreen handles visibility.

    // Let PlayScreen apply the same hunger/sleep rules as its own
    // interaction logic. Ordinary Dirt must not prevent the user from
    // opening PlayScreen.
    if (vp.isNeglected) {
      _showThoughtBubble();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayScreen(
          isDirty: isDirty,
          onAction: (action) {
            // PlayScreen now updates VirtualPetProvider directly.
            // Keep this callback for compatibility with the existing screen API.
          },
        ),
      ),
    );
  }

  // ==========================================================
  // SHOP
  // ==========================================================
  void _onShop() {
    // Keep Shop accessible at night, like in the morning.
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ShopScreen()),
    );
  }

  // ==========================================================
  // STATUS
  // ==========================================================
  void _onStatus(
    String catName,
    int hunger,
    int happiness,
    int cleanliness,
    int energy,
  ) {
    final emotion = _getEmotion(
      hunger,
      happiness,
      cleanliness,
      energy,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFFF5EE),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    '❤️ ',
                    style: TextStyle(fontSize: 20),
                  ),
                  Text(
                    "$catName's Status",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _conditionBadge(emotion),
              const SizedBox(height: 14),
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
              ),
              _statRow(
                '⚡',
                'Energy',
                energy,
                _statColor(energy),
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
        );
      },
    );
  }
}
