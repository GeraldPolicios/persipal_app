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

const int kDecayIntervalMinutes = 30;

const int kDecayHunger = 3;
const int kDecayHappiness = -2;
const int kDecayCleanliness = -2;
const int kDecayEnergy = -1;

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

  // ── Stats ────────────────────────────────────────────────────────────────

  bool get needsNaming => !_pet.isNamed;

  String get catName => _pet.catName;

  int get hunger => _pet.hunger;

  int get happiness => _pet.happiness;

  int get cleanliness => _pet.cleanliness;

  int get energy => _pet.energy;

  // ── Init ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    _loading = true;
    notifyListeners();

    final loaded = await _local.fetchVirtualPet();

    _pet = loaded ?? VirtualPetState.initial();

    // Apply any decay that happened while the app was closed.
    _pet = _applyElapsedDecay(_pet);

    await _save();

    _loading = false;
    notifyListeners();

    // Keep decay moving while the app is running.
    _decayTimer = Timer.periodic(
      kDecayCheckInterval,
      (_) => refreshDecay(),
    );

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

  // ── Decay ────────────────────────────────────────────────────────────────

  VirtualPetState _applyElapsedDecay(
    VirtualPetState state,
  ) {
    final elapsedMinutes =
        DateTime.now().difference(state.lastTickAt).inMinutes;

    final intervals = elapsedMinutes ~/ kDecayIntervalMinutes;

    if (intervals <= 0) {
      return state;
    }

    final newLastTick = state.lastTickAt.add(
      Duration(
        minutes: intervals * kDecayIntervalMinutes,
      ),
    );

    return state
        .copyWith(
          // Hunger becomes higher when the cat becomes hungry.
          hunger: state.hunger + kDecayHunger * intervals,

          // Happiness slowly decreases without interaction.
          happiness: state.happiness + kDecayHappiness * intervals,

          // Persian-cat grooming need increases over time.
          cleanliness: state.cleanliness + kDecayCleanliness * intervals,

          // Energy slowly decreases over time.
          energy: state.energy + kDecayEnergy * intervals,

          lastTickAt: newLastTick,
          updatedAt: DateTime.now(),
        )
        .clamp();
  }

  Future<void> refreshDecay() async {
    final updated = _applyElapsedDecay(_pet);

    if (!identical(updated, _pet)) {
      _pet = updated;

      await _save();

      notifyListeners();
    }
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    await _local.saveVirtualPet(_pet);

    unawaited(
      _uploadToCloud(_pet),
    );
  }

  // ── Naming ───────────────────────────────────────────────────────────────

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
  }

  // ── Feed ─────────────────────────────────────────────────────────────────

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

  // ── Groom ────────────────────────────────────────────────────────────────

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

  // ── Play ─────────────────────────────────────────────────────────────────

  Future<void> play({
    required int happinessDelta,
    int hungerDelta = 0,
    int energyDelta = -10,
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

          // Playing consumes energy.
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

  DateTime _dateOnly(DateTime dt) {
    return DateTime(
      dt.year,
      dt.month,
      dt.day,
    );
  }

  // ── Reconciliation ──────────────────────────────────────────────────────

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

  // ── Firestore ───────────────────────────────────────────────────────────

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

  Future<void> _uploadToCloud(
    VirtualPetState pet,
  ) async {
    final doc = _document;

    if (doc == null) {
      return;
    }

    if (!_connectivity.isOnline) {
      await _local.queuePendingOp(
        'virtual_pet:sync',
      );

      return;
    }

    try {
      await doc.set(
        pet.toMap(),
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint(
        'VirtualPetProvider: cloud upload failed: $e',
      );

      await _local.queuePendingOp(
        'virtual_pet:sync',
      );
    }
  }

  Future<void> _downloadFromCloud() async {
    try {
      final doc = _document;

      if (doc == null) {
        return;
      }

      final snapshot = await doc.get();

      final data = snapshot.data();

      if (data == null) {
        return;
      }

      final cloudPet = VirtualPetState.fromMap(data);

      if (cloudPet.updatedAt.isAfter(
        _pet.updatedAt,
      )) {
        _pet = cloudPet;

        await _local.saveVirtualPet(
          _pet,
        );

        notifyListeners();
      }
    } catch (e) {
      debugPrint(
        'VirtualPetProvider: cloud download failed: $e',
      );
    }
  }

  Future<void> _flushPendingOps() async {
    if (!_auth.isAuthenticated || !_connectivity.isOnline) {
      return;
    }

    final doc = _document;

    if (doc == null) {
      return;
    }

    final tokens = await _local.fetchPendingOps();

    if (tokens.isEmpty) {
      return;
    }

    for (final token in tokens) {
      if (!token.startsWith('virtual_pet:')) {
        continue;
      }

      try {
        await doc.set(
          _pet.toMap(),
          SetOptions(merge: true),
        );

        await _local.removePendingOp(
          token,
        );
      } catch (_) {
        // Keep the pending operation.
      }
    }
  }

  Future<void> flushPendingOpsIfPossible() {
    return _flushPendingOps();
  }

  // ── Guest → account merge ────────────────────────────────────────────────

  Future<void> syncNow() async {
    if (!_auth.isAuthenticated) {
      return;
    }

    unawaited(
      _uploadToCloud(_pet),
    );

    await _downloadFromCloud();
  }

  Future<void> pushGuestDataToCloud() async {
    if (!_auth.isAuthenticated) {
      return;
    }

    final doc = _document;

    if (doc == null) {
      return;
    }

    try {
      final snapshot = await doc.get();

      final cloudData = snapshot.data();

      if (cloudData == null) {
        await _uploadToCloud(_pet);
        return;
      }

      final cloudPet = VirtualPetState.fromMap(cloudData);

      if (_pet.updatedAt.isAfter(
        cloudPet.updatedAt,
      )) {
        await _uploadToCloud(_pet);
      } else {
        _pet = cloudPet;

        await _local.saveVirtualPet(
          _pet,
        );

        notifyListeners();
      }
    } catch (e) {
      debugPrint(
        'VirtualPetProvider: pushGuestDataToCloud failed: $e',
      );

      await _local.queuePendingOp(
        'virtual_pet:sync',
      );
    }
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

      _pet = VirtualPetState.fromMap(
        data,
      );

      await _local.saveVirtualPet(
        _pet,
      );

      notifyListeners();
    } catch (e) {
      debugPrint(
        'VirtualPetProvider: replaceLocalWithCloud failed: $e',
      );
    }
  }

  // ── Clear local data ─────────────────────────────────────────────────────

  Future<void> clearAllLocalData() async {
    _pet = VirtualPetState.initial();

    await _local.saveVirtualPet(
      _pet,
    );

    notifyListeners();
  }
}
