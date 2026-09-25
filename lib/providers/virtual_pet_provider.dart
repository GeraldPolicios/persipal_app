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
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/virtual_pet_state.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
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
  final _auth = AuthService.instance;
  final _connectivity = ConnectivityService.instance;

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

    // Cloud sync — offline-first: gameplay above never waited on any of
    // this. Mirrors PetProfileProvider's own init() sequencing exactly.
    if (_auth.isAuthenticated) {
      unawaited(_downloadFromCloud());
      unawaited(_flushPendingOps());
    }

    _auth.addListener(_onAuthChanged);
    _connectivity.addListener(_onConnectivityChanged);
  }

  @override
  void dispose() {
    _decayTimer?.cancel();
    _auth.removeListener(_onAuthChanged);
    _connectivity.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (_auth.isAuthenticated) {
      unawaited(_downloadFromCloud());
      unawaited(_flushPendingOps());
    }
  }

  void _onConnectivityChanged() {
    if (_connectivity.isOnline && _auth.isAuthenticated) {
      unawaited(_flushPendingOps());
    }
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
          updatedAt: DateTime.now(),
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

  /// Saves to Hive (awaited — the immediate, offline-first source of
  /// truth) then fires off a best-effort cloud upload (never awaited by
  /// callers, so gameplay is never blocked on a network request). Every
  /// mutating method below funnels through this one place, so cloud sync
  /// doesn't need to be wired into each of them individually.
  Future<void> _save() async {
    await _local.saveVirtualPet(_pet);
    unawaited(_uploadToCloud(_pet));
  }

  // ── Naming ────────────────────────────────────────────────────────────────

  Future<void> setName(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    _pet = _pet.copyWith(catName: trimmed, updatedAt: DateTime.now());
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
          updatedAt: DateTime.now(),
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
          updatedAt: DateTime.now(),
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
          updatedAt: DateTime.now(),
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
          updatedAt: DateTime.now(),
        )
        .clamp();
    await _save();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Firestore — mirrors PetProfileProvider's/ReminderProvider's own
  // hand-rolled sync exactly, adapted for a single record instead of a
  // collection of many: one fixed document per account instead of one
  // document per id. Shares LocalStorageService's pending-sync queue with
  // the other owners — only 'virtual_pet' tokens belong to this provider.
  // ─────────────────────────────────────────────────────────────────────────

  DocumentReference<Map<String, dynamic>>? get _document {
    if (!_auth.isAuthenticated) return null;

    final userId = _auth.userId;
    if (userId.isEmpty) return null;

    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('virtual_pet')
        .doc('state');
  }

  Future<void> _uploadToCloud(VirtualPetState pet) async {
    final doc = _document;

    if (doc == null) {
      // Not authenticated — nothing to sync yet; Hive already has it.
      return;
    }

    if (!_connectivity.isOnline) {
      await _local.queuePendingOp('virtual_pet:sync');
      return;
    }

    try {
      await doc.set(pet.toMap(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('VirtualPetProvider: cloud upload failed: $e');
      await _local.queuePendingOp('virtual_pet:sync');
    }
  }

  /// Only adopts the cloud state if it's strictly newer than what's
  /// already local — never overwrites valid local progress just because a
  /// remote document exists (e.g. an older cloud snapshot from a device
  /// that hasn't synced in a while must not clobber fresher local play).
  Future<void> _downloadFromCloud() async {
    try {
      final doc = _document;
      if (doc == null) return;

      final snapshot = await doc.get();
      final data = snapshot.data();
      if (data == null) return;

      final cloudPet = VirtualPetState.fromMap(data);

      if (cloudPet.updatedAt.isAfter(_pet.updatedAt)) {
        _pet = cloudPet;
        await _local.saveVirtualPet(_pet);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('VirtualPetProvider: cloud download failed: $e');
    }
  }

  Future<void> _flushPendingOps() async {
    if (!_auth.isAuthenticated || !_connectivity.isOnline) return;

    final doc = _document;
    if (doc == null) return;

    final tokens = await _local.fetchPendingOps();
    if (tokens.isEmpty) return;

    for (final token in tokens) {
      if (!token.startsWith('virtual_pet:')) continue;

      try {
        await doc.set(_pet.toMap(), SetOptions(merge: true));
        // Only remove on confirmed success — a failure leaves the token
        // in place for the next connectivity/auth trigger.
        await _local.removePendingOp(token);
      } catch (_) {
        // Leave token in queue for next attempt.
      }
    }
  }

  /// Best-effort: attempts to push a queued 'virtual_pet' op now. Public
  /// wrapper around the private flush so callers outside this provider
  /// (e.g. AppProvider's sign-out orchestration) can request one without
  /// duplicating its logic. Safe to call regardless of auth/connectivity —
  /// it's already a no-op in those cases.
  Future<void> flushPendingOpsIfPossible() => _flushPendingOps();

  // ─────────────────────────────────────────────────────────────────────────
  // Guest → account merge
  //
  // Mirrors PetProfileProvider's pushGuestDataToCloud()/replaceLocalWithCloud(),
  // called from the same post-login "Sync Offline Progress?" prompt in
  // login_screen.dart, so virtual-pet progress made as a guest isn't left
  // behind or silently discarded when the user creates or signs into an
  // account.
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> syncNow() async {
    if (!_auth.isAuthenticated) return;
    unawaited(_uploadToCloud(_pet));
    await _downloadFromCloud();
  }

  /// "Merge Progress": unlike PetProfileProvider's per-record merge (where
  /// each profile has its own id, so a guest profile can never accidentally
  /// clobber a *different*, pre-existing cloud profile), the Virtual Pet is
  /// a single record — blindly pushing local over an already-populated
  /// cloud document could destroy real progress made on another device.
  /// Deterministic rule: whichever side was updated more recently wins,
  /// the same timestamp comparison already used for every other sync
  /// decision in this provider — never a silent, unconditional overwrite
  /// in either direction.
  Future<void> pushGuestDataToCloud() async {
    if (!_auth.isAuthenticated) return;

    final doc = _document;
    if (doc == null) return;

    try {
      final snapshot = await doc.get();
      final cloudData = snapshot.data();

      if (cloudData == null) {
        // Nothing in the cloud yet for this account — the guest's state
        // becomes it.
        await _uploadToCloud(_pet);
        return;
      }

      final cloudPet = VirtualPetState.fromMap(cloudData);

      if (_pet.updatedAt.isAfter(cloudPet.updatedAt)) {
        await _uploadToCloud(_pet);
      } else {
        _pet = cloudPet;
        await _local.saveVirtualPet(_pet);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('VirtualPetProvider: pushGuestDataToCloud failed: $e');
      await _local.queuePendingOp('virtual_pet:sync');
    }
  }

  /// "Use Cloud Data": discard the local/guest virtual pet, unconditionally
  /// adopting whatever is in the cloud — an explicit user choice, so this
  /// bypasses the normal timestamp comparison. A no-op if the account has
  /// no cloud virtual pet yet (nothing to adopt; local state is kept and
  /// will simply upload on the next sync).
  Future<void> replaceLocalWithCloud() async {
    if (!_auth.isAuthenticated) return;

    final doc = _document;
    if (doc == null) return;

    try {
      final snapshot = await doc.get();
      final data = snapshot.data();
      if (data == null) return;

      _pet = VirtualPetState.fromMap(data);
      await _local.saveVirtualPet(_pet);
      notifyListeners();
    } catch (e) {
      debugPrint('VirtualPetProvider: replaceLocalWithCloud failed: $e');
    }
  }

  /// Clears this device's local Virtual Pet data (Hive + in-memory state,
  /// reset to a fresh unnamed pet). Used when an authenticated session
  /// ends (sign-out or account deletion) so the next guest/account on this
  /// device never sees the departed account's virtual pet. Does NOT touch
  /// Firestore — the account's cloud data is untouched by this.
  Future<void> clearAllLocalData() async {
    _pet = VirtualPetState.initial();
    await _local.saveVirtualPet(_pet);
    notifyListeners();
  }
}
