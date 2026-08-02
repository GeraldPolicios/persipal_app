// lib/providers/virtual_pet_provider.dart
//
// Owns the single VIRTUAL GAME PET used only by GameScreen / FeedScreen /
// GroomScreen / PlayScreen.
//
// ── INDEPENDENCE RULE ───────────────────────────────────────────────────────
// This provider must NEVER import pet_extended_models.dart or
// pet_profile_provider.dart, and must NEVER take a real pet's id. The virtual
// pet is not one of the user's real Persian cat profiles and is not part of
// the 10-profile limit.
// ─────────────────────────────────────────────────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import '../models/virtual_pet_state.dart';
import '../services/local_storage_service.dart';

// ── Decay tuning ─────────────────────────────────────────────────────────
// Every [kDecayIntervalMinutes] of real elapsed time, stats move by the
// amounts below. Applied as a single multiplication of elapsed intervals
// (never a loop), so catching up after being away for days is instant.
const int kDecayIntervalMinutes = 30;
const int kDecayHunger = 3; // rises (gets hungrier)
const int kDecayHappiness = -2;
const int kDecayCleanliness = -2;
const int kDecayEnergy = -1;

// How often, while the app is running, the provider re-checks elapsed decay —
// independent of whether GameScreen is mounted. This is what keeps decay
// moving even when the user has navigated away from the virtual pet screens.
const Duration kDecayCheckInterval = Duration(minutes: 1);

class VirtualPetProvider extends ChangeNotifier {
  final _local = LocalStorageService.instance;

  VirtualPetState _pet = VirtualPetState.initial();
  bool _loading = true;
  Timer? _decayTimer;

  VirtualPetState get pet => _pet;
  bool get loading => _loading;

  /// True only until the user has named the cat for the very first time.
  bool get needsNaming => !_pet.isNamed;

  String get catName => _pet.catName;
  int get hunger => _pet.hunger;
  int get happiness => _pet.happiness;
  int get cleanliness => _pet.cleanliness;
  int get energy => _pet.energy;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    _loading = true;
    notifyListeners();

    final loaded = await _local.fetchVirtualPet();
    _pet = loaded ?? VirtualPetState.initial();

    // Catch up on decay for whatever time passed while the app was closed.
    _pet = _applyElapsedDecay(_pet);
    await _save();

    _loading = false;
    notifyListeners();

    // Keep decay moving forward for as long as the app process is alive,
    // regardless of which screen is currently on top.
    _decayTimer = Timer.periodic(kDecayCheckInterval, (_) => refreshDecay());
  }

  @override
  void dispose() {
    _decayTimer?.cancel();
    super.dispose();
  }

  // ── Decay ─────────────────────────────────────────────────────────────────

  /// Applies decay for however much real-world time has passed since
  /// [state.lastTickAt], in whole [kDecayIntervalMinutes] chunks. Any partial
  /// chunk is left for next time (lastTickAt only advances by full
  /// intervals), so short accumulated gaps aren't lost.
  ///
  /// Returns the SAME instance (by reference) if no full interval has
  /// elapsed yet, so callers can cheaply check `identical`/`==` to know
  /// whether anything actually changed.
  VirtualPetState _applyElapsedDecay(VirtualPetState state) {
    final elapsedMinutes =
        DateTime.now().difference(state.lastTickAt).inMinutes;
    final intervals = elapsedMinutes ~/ kDecayIntervalMinutes;
    if (intervals <= 0) return state;

    final newLastTick = state.lastTickAt
        .add(Duration(minutes: intervals * kDecayIntervalMinutes));

    return state
        .copyWith(
          hunger: state.hunger + kDecayHunger * intervals,
          happiness: state.happiness + kDecayHappiness * intervals,
          cleanliness: state.cleanliness + kDecayCleanliness * intervals,
          energy: state.energy + kDecayEnergy * intervals,
          lastTickAt: newLastTick,
        )
        .clamp();
  }

  /// Public hook for callers (e.g. app-resumed lifecycle events in a later
  /// phase) to force a decay re-check outside the periodic timer.
  Future<void> refreshDecay() async {
    final updated = _applyElapsedDecay(_pet);
    if (!identical(updated, _pet)) {
      _pet = updated;
      await _save();
      notifyListeners();
    }
  }

  Future<void> _save() async => _local.saveVirtualPet(_pet);

  // ── Naming ────────────────────────────────────────────────────────────────

  Future<void> setName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _pet = _pet.copyWith(catName: trimmed);
    await _save();
    notifyListeners();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> feed({
    required int hungerDelta,
    required int happinessDelta,
    int cleanlinessDelta = 0,
  }) async {
    _pet = _applyElapsedDecay(_pet);
    _pet = _pet
        .copyWith(
          hunger: _pet.hunger + hungerDelta,
          happiness: _pet.happiness + happinessDelta,
          cleanliness: _pet.cleanliness + cleanlinessDelta,
          lastTickAt: DateTime.now(),
          simFeedCount: _pet.simFeedCount + 1,
        )
        .clamp();
    await _save();
    notifyListeners();
  }

  Future<void> groom({
    required int cleanlinessDelta,
    int happinessDelta = 0,
  }) async {
    _pet = _applyElapsedDecay(_pet);
    _pet = _pet
        .copyWith(
          cleanliness: _pet.cleanliness + cleanlinessDelta,
          happiness: _pet.happiness + happinessDelta,
          lastTickAt: DateTime.now(),
          simGroomCount: _pet.simGroomCount + 1,
        )
        .clamp();
    await _save();
    notifyListeners();
  }

  Future<void> play({
    required int happinessDelta,
    int hungerDelta = 0,
    int energyDelta = 0,
  }) async {
    _pet = _applyElapsedDecay(_pet);

    final today = _dateOnly(DateTime.now());
    int streak;
    final lastPlay = _pet.simLastPlayDate;
    if (lastPlay == null) {
      streak = 1;
    } else {
      final dayDiff = today.difference(_dateOnly(lastPlay)).inDays;
      if (dayDiff == 0) {
        streak = _pet.simPlayStreakDays; // already played today
      } else if (dayDiff == 1) {
        streak = _pet.simPlayStreakDays + 1; // consecutive day
      } else {
        streak = 1; // missed a day — restart the streak
      }
    }

    _pet = _pet
        .copyWith(
          happiness: _pet.happiness + happinessDelta,
          hunger: _pet.hunger + hungerDelta,
          energy: _pet.energy + energyDelta,
          lastTickAt: DateTime.now(),
          simPlayCount: _pet.simPlayCount + 1,
          simPlayStreakDays: streak,
          simLastPlayDate: today,
        )
        .clamp();
    await _save();
    notifyListeners();
  }

  DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  // ── Reconciliation ───────────────────────────────────────────────────────
  // Sets absolute stat value(s) WITHOUT incrementing any simulation counter
  // and WITHOUT re-applying elapsed decay. Used when a screen (e.g.
  // GroomScreen) tracks its own authoritative absolute value internally and
  // reports it back on close, after the corresponding feed()/groom()/play()
  // call has already counted the action.
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
        )
        .clamp();
    await _save();
    notifyListeners();
  }
}
