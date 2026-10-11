// lib/providers/virtual_pet_provider.dart
//
// Owns the single VIRTUAL GAME PET used only by:
// GameScreen / FeedScreen / GroomScreen / PlayScreen.
//
// INDEPENDENCE RULE
// This provider must NEVER import pet_extended_models.dart or
// pet_profile_provider.dart, and must NEVER take a real pet's id.
//
// The virtual pet is separate from the user's real Persian cat profiles
// and is not part of the 10-profile limit.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

import '../models/virtual_pet_state.dart';
import '../models/virtual_pet_status.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DECAY TUNING
// ─────────────────────────────────────────────────────────────────────────────

const int kDecayIntervalMinutes = 30;

const int kDecayHunger = 3;
const int kDecayHappiness = -2;
const int kDecayCleanliness = -2;

// IMPORTANT:
// Energy is NOT included in passive time decay.
//
// Energy is changed by:
// - Play
// - Tricks / active gameplay
// - Feeding/grooming only if an action explicitly supplies energyDelta
// - Sleeping recovery
const Duration kDecayCheckInterval = Duration(minutes: 1);

// Virtual fur growth is intentionally much faster than real Persian-cat coat
// development because Persipal is a virtual pet.
// Fur0 -> Fur1 after 3 days, then Fur1 -> Fur2 after another 4 days.
const Duration kFur0GrowthDuration = Duration(days: 3);
const Duration kFur1GrowthDuration = Duration(days: 4);
// Separate optional rule: not trimming for 3 days can grow one fur stage.
const Duration kNoTrimGrowthDuration = Duration(days: 3);

// Default energy cost for Play.
const int kPlayEnergyCost = 10;

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDER
// ─────────────────────────────────────────────────────────────────────────────

class VirtualPetProvider extends ChangeNotifier with WidgetsBindingObserver {
  final _local = LocalStorageService.instance;
  final _auth = AuthService.instance;
  final _connectivity = ConnectivityService.instance;
  final _notifications = NotificationService.instance;

  VirtualPetState _pet = VirtualPetState.initial();

  bool _loading = true;

  Timer? _decayTimer;
  bool _lifecycleObserverRegistered = false;

  // Prevent overlapping Firestore reconciliations. If a local gameplay
  // change happens while a sync is running, request one more pass after the
  // current transaction finishes.
  bool _cloudSyncInProgress = false;
  bool _cloudSyncRequested = false;

  // ──────────────────────────────────────────────────────────────────────────
  // STATE
  // ──────────────────────────────────────────────────────────────────────────

  VirtualPetState get pet => _pet;

  bool get loading => _loading;

  // ──────────────────────────────────────────────────────────────────────────
  // TEMPORARY FUR-STAGE TESTING
  // Remove this helper after Fur1/Fur2 animation testing is complete.
  Future<void> setFurStageForTesting(int stage) async {
    final safeStage = stage.clamp(0, 2).toInt();
    final now = DateTime.now();
    _pet = _pet.copyWith(
      furStage: safeStage,
      lastFurGrowthAt: now,
      lastTrimAt: now,
      furStageAtLastTrim: safeStage,
      updatedAt: now,
    );
    await _save();
    notifyListeners();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // BASIC STATS
  // ──────────────────────────────────────────────────────────────────────────

  bool get needsNaming => !_pet.isNamed;

  String get catName => _pet.catName;

  int get hunger => _pet.hunger;

  int get happiness => _pet.happiness;

  int get cleanliness => _pet.cleanliness;

  int get energy => _pet.energy;

  int get furStage => _pet.furStage.clamp(0, 2).toInt();

  // ──────────────────────────────────────────────────────────────────────────
  // GAME STATES
  // ──────────────────────────────────────────────────────────────────────────

  bool get isSleeping => _pet.isSleeping;

  bool get wantsToPlay => _pet.wantsToPlay;

  VirtualPetStatus get petStatus => resolveVirtualPetStatus(_pet);

  bool get isCriticalHunger => petStatus == VirtualPetStatus.criticalHunger;

  /// Shared thought-bubble priority for every virtual-pet room.
  ///
  /// Neglected > Critical Hunger > Sleepy > Sad > Hungry > Dirty >
  /// Wants to Play. Actual Sleeping is shown separately by the room.
  String? get priorityThoughtEmoji {
    switch (petStatus) {
      case VirtualPetStatus.neglected:
        return '😿';
      case VirtualPetStatus.criticalHunger:
      case VirtualPetStatus.hungry:
        return '🍗';
      case VirtualPetStatus.sleepy:
        return '😴';
      case VirtualPetStatus.sad:
        return '😿';
      case VirtualPetStatus.dirty:
        return '🧼';
      case VirtualPetStatus.wantsToPlay:
        return '🎾';
      case VirtualPetStatus.normal:
        return null;
    }
  }

  bool get isDirty => _pet.cleanliness <= 30;

  bool get isNeglected => petStatus == VirtualPetStatus.neglected;

  bool get isSadOrHungry =>
      petStatus == VirtualPetStatus.sad ||
      petStatus == VirtualPetStatus.hungry ||
      petStatus == VirtualPetStatus.criticalHunger;

  /// Energy <= 20 makes the cat Sleepy. It does not directly put the cat
  /// to sleep; the player must tap Sleepy to start Rest -> Sleep.
  bool get isSleepy => petStatus == VirtualPetStatus.sleepy;

  // ──────────────────────────────────────────────────────────────────────────
  // INIT
  // ──────────────────────────────────────────────────────────────────────────

  Future<void> init() async {
    _loading = true;

    notifyListeners();

    final loaded = await _local.fetchVirtualPet();

    _pet = loaded ?? VirtualPetState.initial();

    // Restore Fur0 after the temporary Fur2 QA override used during testing.
    // That override stamped lastFurGrowthAt and lastTrimAt with the exact same
    // timestamp. Reset only that recognizable test state, then let normal fur
    // growth and saved progress work as usual on future launches.
    if (loaded != null &&
        loaded.furStage == 2 &&
        loaded.lastFurGrowthAt.isAtSameMomentAs(loaded.lastTrimAt)) {
      final resetAt = DateTime.now();
      _pet = _pet.copyWith(
        furStage: 0,
        lastFurGrowthAt: resetAt,
        lastTrimAt: resetAt,
        furStageAtLastTrim: 0,
        updatedAt: resetAt,
      );
    }

    // IMPORTANT:
    // Do not apply elapsed decay and upload before checking Firestore.
    // Passive elapsed decay must not make an otherwise stale local copy look
    // newer than a newer copy from another device.
    if (_auth.isAuthenticated && _connectivity.isOnline) {
      final synced = await _syncWithCloud();

      if (!synced) {
        // Cloud was temporarily unavailable. Keep the app fully usable
        // offline and persist the locally reconciled state.
        _pet = _normalizeSleepState(_applyElapsedDecay(_pet));
        await _save(syncCloud: false);
        await _local.queuePendingOp('virtual_pet:sync');
      }
    } else {
      _pet = _normalizeSleepState(_applyElapsedDecay(_pet));
      await _save(syncCloud: false);

      if (_auth.isAuthenticated) {
        await _local.queuePendingOp('virtual_pet:sync');
      }
    }

    _loading = false;

    notifyListeners();

    // Reconcile virtual-pet notifications after the saved state has been
    // restored, including states reached while the app was closed.
    unawaited(_syncPetNotifications());

    // Keep passive stat decay moving while the app is running.
    _decayTimer?.cancel();

    _decayTimer = Timer.periodic(
      kDecayCheckInterval,
      (_) {
        refreshDecay();
      },
    );

    if (_auth.isAuthenticated && _connectivity.isOnline) {
      unawaited(_syncWithCloud());
    }

    _auth.addListener(_onAuthChanged);
    _connectivity.addListener(_onConnectivityChanged);

    // Reconcile elapsed virtual-pet time whenever the app returns from
    // background/inactive state. This keeps Android and iOS behavior
    // consistent even when the one-minute timer was paused.
    if (!_lifecycleObserverRegistered) {
      WidgetsBinding.instance.addObserver(this);
      _lifecycleObserverRegistered = true;
    }
  }

  @override
  void dispose() {
    _decayTimer?.cancel();

    if (_lifecycleObserverRegistered) {
      WidgetsBinding.instance.removeObserver(this);
      _lifecycleObserverRegistered = false;
    }

    _auth.removeListener(_onAuthChanged);
    _connectivity.removeListener(_onConnectivityChanged);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Reconcile elapsed time immediately on resume instead of waiting
      // for the periodic timer.
      unawaited(refreshDecay());

      if (_auth.isAuthenticated && _connectivity.isOnline) {
        unawaited(_syncWithCloud());
      }
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // AUTH / CONNECTIVITY
  // ──────────────────────────────────────────────────────────────────────────

  void _onAuthChanged() {
    if (_auth.isAuthenticated && _connectivity.isOnline) {
      unawaited(_syncWithCloud());
    }
  }

  void _onConnectivityChanged() {
    if (_connectivity.isOnline && _auth.isAuthenticated) {
      unawaited(_syncWithCloud());
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // SLEEP STATE
  // ──────────────────────────────────────────────────────────────────────────

  /// Changes the shared sleeping state of the virtual cat.
  ///
  /// Sleeping is stored inside VirtualPetState, so all game screens can
  /// read the same state.
  ///
  /// A neglected cat can never remain sleeping.
  Future<void> setSleeping(bool value) async {
    // Always reconcile elapsed time before changing the sleep clock.
    // This prevents lost hunger/cleanliness/happiness decay or lost sleep
    // recovery when the user changes screens after returning to the app.
    _pet = _applyElapsedDecay(_pet);

    // A cat can only be put to sleep when it is not neglected.
    // A sleeping cat can only be woken once Energy is ABOVE 20.
    if (!value && _pet.isSleeping && _pet.energy <= 20) {
      return;
    }

    final shouldSleep = value && !isNeglected;

    if (_pet.isSleeping == shouldSleep) {
      return;
    }

    final now = DateTime.now();

    _pet = _pet.copyWith(
      isSleeping: shouldSleep,
      lastTickAt: now,
      lastSleepRecoveryAt: shouldSleep ? now : null,
      updatedAt: now,
    );

    await _save();

    notifyListeners();
    await _syncPetNotifications();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // NORMALIZE SLEEP STATE
  // ──────────────────────────────────────────────────────────────────────────

  /// Urgent care needs override the persisted sleeping state.
  ///
  /// A cat should not remain visually asleep when it becomes critically
  /// hungry or dirty. This also handles stats that decay while the app is
  /// closed: on the next refresh, the saved sleep state is normalized and
  /// GameScreen can show the appropriate care-related animation.
  ///
  /// Ordinary hunger does not interrupt sleep; critical hunger (90+) or
  /// cleanliness at/below 30 does. The player still chooses whether to feed
  /// or groom first once they return to the game.
  VirtualPetState _normalizeSleepState(
    VirtualPetState state,
  ) {
    final urgentCareNeeded = state.hunger >= 90 || state.cleanliness <= 30;

    if (urgentCareNeeded && state.isSleeping) {
      return state.copyWith(
        isSleeping: false,
        lastSleepRecoveryAt: null,
      );
    }

    return state;
  }

  // ──────────────────────────────────────────────────────────────────────────
  // DECAY
  // ──────────────────────────────────────────────────────────────────────────

  /// Applies PASSIVE time decay.
  ///
  /// Time affects:
  ///   Hunger       -> increases
  ///   Happiness    -> decreases
  ///   Cleanliness  -> decreases
  ///
  /// Time does NOT affect:
  ///   Energy
  ///
  /// Energy is consumed by gameplay and restored by sleeping.
  VirtualPetState _applyFurGrowth(
    VirtualPetState state,
    DateTime now,
  ) {
    var stage = state.furStage.clamp(0, 2).toInt();
    var growthStart = state.lastFurGrowthAt;
    var trimStart = state.lastTrimAt;

    // Keep old/future timestamps safe.
    if (growthStart.isAfter(now)) growthStart = now;
    if (trimStart.isAfter(now)) trimStart = now;

    // Rule A: time-based growth continues while the player is away.
    var timeStage = stage;
    var timeCursor = growthStart;
    while (timeStage < 2) {
      final duration =
          timeStage == 0 ? kFur0GrowthDuration : kFur1GrowthDuration;
      final nextStageAt = timeCursor.add(duration);
      if (now.isBefore(nextStageAt)) break;
      timeStage += 1;
      timeCursor = nextStageAt;
    }

    // Rule B: independently, not using Trim for 3 days can grow one stage.
    // This clock is reset only by a completed trim, not by login/activity.
    final noTrimDays = now.difference(trimStart).inDays;
    final trimStage = (state.furStageAtLastTrim +
            (noTrimDays ~/ kNoTrimGrowthDuration.inDays))
        .clamp(0, 2)
        .toInt();

    final nextStage = timeStage > trimStage ? timeStage : trimStage;
    final nextGrowthStart = nextStage != stage ? now : state.lastFurGrowthAt;
    if (nextStage == state.furStage &&
        nextGrowthStart == state.lastFurGrowthAt &&
        trimStart == state.lastTrimAt) {
      return state;
    }

    return state.copyWith(
      furStage: nextStage,
      lastFurGrowthAt: nextGrowthStart,
      lastTrimAt: trimStart,
    );
  }

  VirtualPetState _applyElapsedDecay(
    VirtualPetState state,
  ) {
    final now = DateTime.now();
    final elapsedMinutes = now.difference(state.lastTickAt).inMinutes;

    // Hunger/Happiness/Cleanliness use 30-minute simulation intervals.
    final intervals = elapsedMinutes ~/ kDecayIntervalMinutes;

    // Energy recovery has its own persisted clock because it recovers every
    // minute while sleeping. This lets recovery continue while the app is
    // backgrounded or completely closed without double-counting time.
    final sleepRecoveryStart = state.lastSleepRecoveryAt ?? state.lastTickAt;
    final sleepMinutes =
        state.isSleeping ? now.difference(sleepRecoveryStart).inMinutes : 0;

    if (intervals <= 0 && sleepMinutes <= 0) {
      return _normalizeSleepState(_applyFurGrowth(state, now));
    }

    final newLastTick = intervals > 0
        ? state.lastTickAt.add(
            Duration(
              minutes: intervals * kDecayIntervalMinutes,
            ),
          )
        : state.lastTickAt;

    final newSleepRecoveryAt = state.isSleeping && sleepMinutes > 0
        ? sleepRecoveryStart.add(Duration(minutes: sleepMinutes))
        : state.lastSleepRecoveryAt;

    final updated = state
        .copyWith(
          hunger: state.hunger + kDecayHunger * intervals,
          happiness: state.happiness + kDecayHappiness * intervals,
          cleanliness: state.cleanliness + kDecayCleanliness * intervals,
          energy: state.energy + (sleepMinutes * 5),
          lastTickAt: newLastTick,
          lastSleepRecoveryAt: newSleepRecoveryAt,
        )
        .clamp();

    return _normalizeSleepState(_applyFurGrowth(updated, now));
  }

  Future<void> refreshDecay() async {
    final updated = _applyElapsedDecay(_pet);

    if (!identical(updated, _pet)) {
      _pet = updated;

      await _save();

      notifyListeners();
      await _syncPetNotifications();
    }

    // This also schedules a future alert when the next threshold has not
    // been reached yet, so the alert can fire while the app is closed.
    await _syncPetNotifications();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // VIRTUAL PET NOTIFICATIONS
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _syncPetNotifications() async {
    // The provider is also used in guest/offline mode, so these notifications
    // never depend on Firebase.
    final petState = _pet;

    await _syncNeedNotification(
      id: NotificationService.virtualPetNeglectedNotificationId,
      active: isNeglected,
      sent: petState.neglectedNotificationSent,
      title: 'Your Persian cat needs you',
      body:
          'Meow Meow is feeling neglected. Check on hunger, happiness, and cleanliness.',
      onSent: () {
        _pet = _pet.copyWith(neglectedNotificationSent: true);
      },
      onReset: () {
        _pet = _pet.copyWith(neglectedNotificationSent: false);
      },
      scheduleAt: _neglectedThresholdTime(),
    );

    // Do not send lower-priority alerts while the cat is neglected.
    // When critical hunger and dirt happen together, send one combined alert
    // instead of separate hunger and cleanliness notifications.
    final criticalAndDirty = hunger >= 90 && cleanliness <= 30;

    if (isNeglected) {
      await _cancelNeedIfHandled(
        NotificationService.virtualPetHungerNotificationId,
      );
      await _cancelNeedIfHandled(
        NotificationService.virtualPetCleanlinessNotificationId,
      );
      await _cancelNeedIfHandled(
        NotificationService.virtualPetCombinedCareNotificationId,
      );
    } else if (criticalAndDirty) {
      // Individual reminders may already be scheduled for a future threshold.
      // Their persisted flags are set when scheduled, not only when displayed.
      // If we replace those pending alerts with one combined alert, clear those
      // flags first so the combined reminder is not incorrectly treated as sent.
      final combinedAlreadyScheduled =
          await _notifications.isVirtualPetNeedScheduled(
        NotificationService.virtualPetCombinedCareNotificationId,
      );
      final individualAlertWasScheduled =
          await _notifications.isVirtualPetNeedScheduled(
                NotificationService.virtualPetHungerNotificationId,
              ) ||
              await _notifications.isVirtualPetNeedScheduled(
                NotificationService.virtualPetCleanlinessNotificationId,
              );

      if (individualAlertWasScheduled && !combinedAlreadyScheduled) {
        _pet = _pet.copyWith(
          hungerNotificationSent: false,
          cleanlinessNotificationSent: false,
        );
      }

      await _cancelNeedIfHandled(
        NotificationService.virtualPetHungerNotificationId,
      );
      await _cancelNeedIfHandled(
        NotificationService.virtualPetCleanlinessNotificationId,
      );

      await _syncNeedNotification(
        id: NotificationService.virtualPetCombinedCareNotificationId,
        active: true,
        // Existing per-need flags provide persisted anti-spam state without
        // adding a new field to the local/cloud pet model.
        sent: _pet.hungerNotificationSent && _pet.cleanlinessNotificationSent,
        title: 'Your Persian cat needs care',
        body:
            'Your virtual cat is very hungry and dirty. Open Persipal to check on your cat.',
        onSent: () {
          _pet = _pet.copyWith(
            hungerNotificationSent: true,
            cleanlinessNotificationSent: true,
          );
        },
        onReset: () {
          _pet = _pet.copyWith(
            hungerNotificationSent: false,
            cleanlinessNotificationSent: false,
          );
        },
        scheduleAt: _earliestCareThresholdTime(),
      );
    } else {
      // If a combined-care alert was only scheduled for a future time and the
      // cat no longer meets both conditions, cancel it and let any still-active
      // individual need schedule its own alert. Do not reset flags when the
      // combined alert has already fired, which would cause repeat reminders.
      final combinedAlertWasScheduled =
          await _notifications.isVirtualPetNeedScheduled(
        NotificationService.virtualPetCombinedCareNotificationId,
      );
      if (combinedAlertWasScheduled) {
        _pet = _pet.copyWith(
          hungerNotificationSent: false,
          cleanlinessNotificationSent: false,
        );
      }
      await _cancelNeedIfHandled(
        NotificationService.virtualPetCombinedCareNotificationId,
      );

      final hungerAt = _thresholdTime(
        current: hunger,
        threshold: 70,
        changePerInterval: kDecayHunger,
        isIncreasing: true,
      );
      final cleanlinessAt = _thresholdTime(
        current: cleanliness,
        threshold: 30,
        changePerInterval: kDecayCleanliness,
        isIncreasing: false,
      );

      await _syncNeedNotification(
        id: NotificationService.virtualPetHungerNotificationId,
        active: hunger >= 70,
        sent: _pet.hungerNotificationSent,
        title: 'Your Persian cat is hungry',
        body:
            'Your virtual cat is getting hungry. Open Persipal and feed your cat.',
        onSent: () {
          _pet = _pet.copyWith(hungerNotificationSent: true);
        },
        onReset: () {
          _pet = _pet.copyWith(hungerNotificationSent: false);
        },
        scheduleAt: hungerAt,
      );

      await _syncNeedNotification(
        id: NotificationService.virtualPetCleanlinessNotificationId,
        active: cleanliness <= 30,
        sent: _pet.cleanlinessNotificationSent,
        title: 'Your Persian cat needs grooming',
        body:
            'Your virtual cat is getting dirty. Open Persipal and groom your cat.',
        onSent: () {
          _pet = _pet.copyWith(cleanlinessNotificationSent: true);
        },
        onReset: () {
          _pet = _pet.copyWith(cleanlinessNotificationSent: false);
        },
        scheduleAt: cleanlinessAt,
      );
    }

    await _syncNeedNotification(
      id: NotificationService.virtualPetPlayNotificationId,
      active: wantsToPlay,
      sent: _pet.wantsToPlayNotificationSent,
      title: 'Your Persian cat wants to play',
      body:
          'Your virtual cat wants some playtime. Open Persipal and play together.',
      onSent: () {
        _pet = _pet.copyWith(wantsToPlayNotificationSent: true);
      },
      onReset: () {
        _pet = _pet.copyWith(wantsToPlayNotificationSent: false);
      },
      scheduleAt: null,
    );

    // Persist the anti-spam state. Use the normal save path so authenticated
    // users also sync the notification flags with their cloud pet state.
    await _save();
  }

  Future<void> _syncNeedNotification({
    required int id,
    required bool active,
    required bool sent,
    required String title,
    required String body,
    required void Function() onSent,
    required void Function() onReset,
    required DateTime? scheduleAt,
  }) async {
    if (!active) {
      onReset();
      await _notifications.cancelVirtualPetNeed(id);
      return;
    }

    if (sent) {
      // The alert has already been delivered. Keep it from being re-sent
      // on every provider refresh.
      return;
    }

    if (scheduleAt != null && scheduleAt.isAfter(DateTime.now())) {
      final alreadyScheduled =
          await _notifications.isVirtualPetNeedScheduled(id);

      if (!alreadyScheduled) {
        await _notifications.scheduleVirtualPetNeed(
          notificationId: id,
          title: title,
          body: body,
          scheduledDate: scheduleAt,
          payload: 'virtual_pet:$id',
        );
      }

      // Whether this call created the alarm or found an existing one, the
      // persisted flag prevents duplicate delivery after app restart.
      onSent();
      return;
    }

    await _notifications.showVirtualPetNeed(
      notificationId: id,
      title: title,
      body: body,
      payload: 'virtual_pet:$id',
    );

    onSent();
  }

  Future<void> _cancelNeedIfHandled(int id) async {
    await _notifications.cancelVirtualPetNeed(id);
  }

  DateTime? _neglectedThresholdTime() {
    if (isNeglected) return DateTime.now();

    int intervalsForIncrease(
      int current,
      int threshold,
      int change,
    ) {
      if (current >= threshold) return 0;
      final remaining = threshold - current;
      return (remaining + change - 1) ~/ change;
    }

    int intervalsForDecrease(
      int current,
      int threshold,
      int change,
    ) {
      if (current <= threshold) return 0;
      final remaining = current - threshold;
      return (remaining + change - 1) ~/ change;
    }

    final hungerIntervals = intervalsForIncrease(
      hunger,
      90,
      kDecayHunger,
    );

    final happinessIntervals = intervalsForDecrease(
      happiness,
      20,
      kDecayHappiness.abs(),
    );

    final cleanlinessIntervals = intervalsForDecrease(
      cleanliness,
      20,
      kDecayCleanliness.abs(),
    );

    final intervals = [
      hungerIntervals,
      happinessIntervals,
      cleanlinessIntervals,
    ].reduce((a, b) => a > b ? a : b);

    if (intervals <= 0) return DateTime.now();

    return DateTime.now().add(
      Duration(minutes: intervals * kDecayIntervalMinutes),
    );
  }

  DateTime? _earliestCareThresholdTime() {
    final hungerAt = _thresholdTime(
      current: hunger,
      threshold: 90,
      changePerInterval: kDecayHunger,
      isIncreasing: true,
    );
    final cleanlinessAt = _thresholdTime(
      current: cleanliness,
      threshold: 30,
      changePerInterval: kDecayCleanliness,
      isIncreasing: false,
    );

    if (hungerAt == null) return cleanlinessAt;
    if (cleanlinessAt == null) return hungerAt;
    return hungerAt.isBefore(cleanlinessAt) ? hungerAt : cleanlinessAt;
  }

  DateTime? _thresholdTime({
    required int current,
    required int threshold,
    required int changePerInterval,
    required bool isIncreasing,
  }) {
    if (isIncreasing) {
      if (current >= threshold) return DateTime.now();
    } else {
      if (current <= threshold) return DateTime.now();
    }

    final step = changePerInterval.abs();
    if (step == 0) return null;

    final remaining = isIncreasing ? threshold - current : current - threshold;

    final intervals = (remaining + step - 1) ~/ step;

    return DateTime.now().add(
      Duration(minutes: intervals * kDecayIntervalMinutes),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // SAVE
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> _save({
    bool syncCloud = true,
  }) async {
    // Hive is always the immediate source of truth for offline play.
    await _local.saveVirtualPet(_pet);

    if (syncCloud && _auth.isAuthenticated && _connectivity.isOnline) {
      unawaited(_syncWithCloud());
    } else if (syncCloud && _auth.isAuthenticated) {
      await _local.queuePendingOp('virtual_pet:sync');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // NAMING
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> setName(String name) async {
    final trimmed = name.trim();

    if (trimmed.isEmpty) {
      return;
    }

    _pet = _pet.copyWith(
      catName: trimmed,
      updatedAt: DateTime.now(),
    );

    await _save();

    notifyListeners();
    await _syncPetNotifications();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // FEED
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> feed({
    required int hungerDelta,
    required int happinessDelta,
    int cleanlinessDelta = 0,
    int energyDelta = 0,
  }) async {
    _pet = _applyElapsedDecay(_pet);

    final now = DateTime.now();

    _pet = _pet
        .copyWith(
          hunger: _pet.hunger + hungerDelta,
          happiness: _pet.happiness + happinessDelta,
          cleanliness: _pet.cleanliness + cleanlinessDelta,

          // Normally feeding does not change Energy.
          // It only changes if the specific food action supplies
          // an explicit energyDelta.
          energy: _pet.energy + energyDelta,

          lastTickAt: now,
          updatedAt: now,

          simFeedCount: _pet.simFeedCount + 1,
          wantsToPlay: true,
        )
        .clamp();

    // Feeding can change the state enough to remove or create
    // the neglected condition.
    _pet = _normalizeSleepState(_pet);

    await _save();

    notifyListeners();
    await _syncPetNotifications();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // GROOM
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> groom({
    required int cleanlinessDelta,
    int happinessDelta = 0,
  }) async {
    _pet = _applyElapsedDecay(_pet);

    final now = DateTime.now();

    _pet = _pet
        .copyWith(
          cleanliness: _pet.cleanliness + cleanlinessDelta,
          happiness: _pet.happiness + happinessDelta,

          // Grooming does not passively consume Energy.
          energy: _pet.energy,

          lastTickAt: now,
          updatedAt: now,

          simGroomCount: _pet.simGroomCount + 1,
          wantsToPlay: true,
        )
        .clamp();

    _pet = _normalizeSleepState(_pet);

    await _save();

    notifyListeners();
    await _syncPetNotifications();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // PLAY
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> play({
    required int happinessDelta,
    int hungerDelta = 0,

    // Play consumes Energy.
    //
    // Default:
    // 80 -> 70 -> 60 -> 50 -> ...
    int energyDelta = -kPlayEnergyCost,

    // Playing makes the cat a little dirty.
    // Dirty is triggered when Cleanliness reaches 30 or below.
    int cleanlinessDelta = -5,
  }) async {
    _pet = _applyElapsedDecay(_pet);

    final today = _dateOnly(DateTime.now());

    int streak;

    final lastPlay = _pet.simLastPlayDate;

    if (lastPlay == null) {
      streak = 1;
    } else {
      final dayDiff = today
          .difference(
            _dateOnly(lastPlay),
          )
          .inDays;

      if (dayDiff == 0) {
        streak = _pet.simPlayStreakDays;
      } else if (dayDiff == 1) {
        streak = _pet.simPlayStreakDays + 1;
      } else {
        streak = 1;
      }
    }

    _pet = _pet
        .copyWith(
          happiness: _pet.happiness + happinessDelta,

          // Playing makes the cat hungrier.
          hunger: _pet.hunger + hungerDelta,

          // Playing consumes Energy.
          energy: _pet.energy + energyDelta,

          // Playing makes the cat a little dirty.
          // Cleanliness <= 30 triggers the shared Dirty state.
          cleanliness: _pet.cleanliness + cleanlinessDelta,

          lastTickAt: DateTime.now(),
          updatedAt: DateTime.now(),

          simPlayCount: _pet.simPlayCount + 1,

          wantsToPlay: false,

          simPlayStreakDays: streak,

          simLastPlayDate: today,
        )
        .clamp();

    _pet = _normalizeSleepState(_pet);

    await _save();

    notifyListeners();
    await _syncPetNotifications();
  }

  DateTime _dateOnly(DateTime dt) {
    return DateTime(
      dt.year,
      dt.month,
      dt.day,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // FUR TRIMMING
  // ─────────────────────────────────────────────────────────────────────────────

  /// Reduces the fur stage after a completed trim and restarts growth timing.
  /// Trimming can only move fur backwards; it never creates a stage above Fur2.
  Future<void> trimFurToStage(int stage) async {
    final target = stage.clamp(0, 2).toInt();

    if (target >= _pet.furStage) {
      return;
    }

    final now = DateTime.now();

    _pet = _pet.copyWith(
      furStage: target,
      lastFurGrowthAt: now,
      lastTrimAt: now,
      furStageAtLastTrim: target,
      updatedAt: now,
    );

    await _save();
    notifyListeners();
    await _syncPetNotifications();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // RECONCILIATION
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> reconcile({
    int? hunger,
    int? happiness,
    int? cleanliness,
    int? energy,
  }) async {
    _pet = _pet
        .copyWith(
          hunger: hunger ?? _pet.hunger,
          happiness: happiness ?? _pet.happiness,
          cleanliness: cleanliness ?? _pet.cleanliness,
          energy: energy ?? _pet.energy,
          updatedAt: DateTime.now(),
        )
        .clamp();

    _pet = _normalizeSleepState(_pet);

    await _save();

    notifyListeners();
    await _syncPetNotifications();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // ENERGY RECOVERY FROM SLEEP
  // ─────────────────────────────────────────────────────────────────────────────

  /// Restores Energy while the virtual cat is actually sleeping.
  ///
  /// This is intentionally separate from passive stat decay.
  Future<void> recoverEnergyFromSleep({
    int amount = 5,
  }) async {
    if (!_pet.isSleeping || isNeglected) {
      return;
    }

    final reconciled = _applyElapsedDecay(_pet);
    final now = DateTime.now();

    _pet = reconciled
        .copyWith(
          energy: reconciled.energy + amount,
          lastSleepRecoveryAt: now,
          updatedAt: now,
        )
        .clamp();

    await _save();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // FIRESTORE DOCUMENT
  // ─────────────────────────────────────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>>? get _document {
    if (!_auth.isAuthenticated) {
      return null;
    }

    final userId = _auth.userId;

    if (userId.isEmpty) {
      return null;
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('virtual_pet')
        .doc('state');
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // SAFE CLOUD RECONCILIATION
  // ─────────────────────────────────────────────────────────────────────────────

  /// Reconciles Hive and Firestore without blindly overwriting the cloud.
  ///
  /// `updatedAt` represents a real state mutation (user action or explicit
  /// state change). Passive elapsed decay is represented by lastTickAt and
  /// therefore does not make an old local copy appear newer just because the
  /// app was closed for a while.
  ///
  /// The final Firestore write happens inside a transaction. This means a
  /// second device that changes the pet while this device is syncing can win
  /// the comparison instead of being silently overwritten.
  Future<bool> _syncWithCloud() async {
    if (!_auth.isAuthenticated || !_connectivity.isOnline) {
      return false;
    }

    if (_cloudSyncInProgress) {
      _cloudSyncRequested = true;
      return false;
    }

    _cloudSyncInProgress = true;

    try {
      do {
        _cloudSyncRequested = false;

        final doc = _document;
        if (doc == null) {
          return false;
        }

        // Capture the local version BEFORE applying passive elapsed time.
        // This is the important conflict-resolution timestamp.
        final localBase = _pet;
        final localBaseUpdatedAt = localBase.updatedAt;

        // Apply offline decay only after the local version has been captured.
        final localCandidate =
            _normalizeSleepState(_applyElapsedDecay(localBase));

        final reconciled =
            await FirebaseFirestore.instance.runTransaction<VirtualPetState>(
          (transaction) async {
            final snapshot = await transaction.get(doc);
            final data = snapshot.data();

            if (data == null) {
              // No cloud pet exists yet. This account can safely receive the
              // local pet.
              transaction.set(
                doc,
                localCandidate.toMap(),
                SetOptions(merge: true),
              );
              return localCandidate;
            }

            final cloudPet = VirtualPetState.fromMap(data);

            // A newer cloud mutation normally wins. However, an empty cloud
            // cat name must never erase a name already saved locally. This can
            // happen when account resolution uploads an older/unnamed cloud
            // record after the player has named the guest pet.
            if (cloudPet.updatedAt.isAfter(localBaseUpdatedAt)) {
              var cloudWinner = cloudPet;
              final localName = localBase.catName.trim();
              if (cloudPet.catName.trim().isEmpty && localName.isNotEmpty) {
                cloudWinner = cloudPet.copyWith(
                  catName: localName,
                  updatedAt: DateTime.now(),
                );
                transaction.set(
                  doc,
                  cloudWinner.toMap(),
                  SetOptions(merge: true),
                );
              }
              return _normalizeSleepState(
                _applyElapsedDecay(cloudWinner),
              );
            }

            // Local is newer (or equal). Write the locally reconciled state.
            // Because this is a transaction, Firestore rechecks the document
            // if another device changes it during the transaction.
            transaction.set(
              doc,
              localCandidate.toMap(),
              SetOptions(merge: true),
            );

            return localCandidate;
          },
        );

        final changed =
            reconciled.toMap().toString() != _pet.toMap().toString();

        _pet = reconciled;
        await _local.saveVirtualPet(_pet);

        if (changed) {
          notifyListeners();
        }

        // Remove only this feature's pending operations after a successful
        // reconciliation. Other providers use the same Hive queue.
        final tokens = await _local.fetchPendingOps();
        for (final token in tokens) {
          if (token.startsWith('virtual_pet:')) {
            await _local.removePendingOp(token);
          }
        }

        // If gameplay changed the local pet while the transaction was running,
        // perform one more reconciliation with the newest local state.
      } while (_cloudSyncRequested &&
          _auth.isAuthenticated &&
          _connectivity.isOnline);

      return true;
    } catch (e) {
      debugPrint(
        'VirtualPetProvider: safe cloud reconciliation failed: $e',
      );

      // Never discard local progress because cloud sync failed.
      if (_auth.isAuthenticated) {
        await _local.queuePendingOp('virtual_pet:sync');
      }

      return false;
    } finally {
      _cloudSyncInProgress = false;
    }
  }

  Future<void> flushPendingOpsIfPossible() {
    return _syncWithCloud();
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // GUEST → ACCOUNT MERGE
  // ─────────────────────────────────────────────────────────────────────────────

  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> syncNow() async {
    if (!_auth.isAuthenticated) {
      return;
    }

    await _syncWithCloud();
  }

  Future<void> pushGuestDataToCloud() async {
    if (!_auth.isAuthenticated) {
      return;
    }

    // Merge the guest/local virtual-pet state using the same conflict-safe
    // transaction as normal online synchronization.
    await _syncWithCloud();
  }

  Future<void> replaceLocalWithCloud() async {
    if (!_auth.isAuthenticated) {
      return;
    }

    final doc = _document;

    if (doc == null) {
      return;
    }

    try {
      final snapshot = await doc.get();

      final data = snapshot.data();

      if (data == null) {
        return;
      }

      final cloudPet = VirtualPetState.fromMap(data);
      // "Use Cloud" should not trigger the naming dialog just because the
      // cloud record predates the local cat name. Preserve an existing local
      // name when the cloud record has no name.
      final localName = _pet.catName.trim();
      _pet = cloudPet.catName.trim().isEmpty && localName.isNotEmpty
          ? cloudPet.copyWith(
              catName: localName,
              updatedAt: DateTime.now(),
            )
          : cloudPet;

      _pet = _normalizeSleepState(_pet);

      await _local.saveVirtualPet(_pet);
      if (cloudPet.catName.trim().isEmpty && localName.isNotEmpty) {
        await doc.set(_pet.toMap(), SetOptions(merge: true));
      }

      notifyListeners();
    } catch (e) {
      debugPrint(
        'VirtualPetProvider: '
        'replaceLocalWithCloud failed: $e',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // CLEAR LOCAL DATA
  // ─────────────────────────────────────────────────────────────────────────────

  Future<void> clearAllLocalData() async {
    _pet = VirtualPetState.initial();

    await _local.saveVirtualPet(
      _pet,
    );

    notifyListeners();
  }
}
