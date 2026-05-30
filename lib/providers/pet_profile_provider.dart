// lib/providers/pet_profile_provider.dart
//
// Manages FullPetProfile CRUD.
// Hive is the primary store (offline-first).
// Firestore sync is background-only.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/pet_extended_models.dart';
import '../services/auth_service.dart';
import '../services/activity_log_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const _boxName = 'full_pet_profiles';
const _maxProfiles = 10;

class PetProfileProvider extends ChangeNotifier {
  PetProfileProvider._();
  static final PetProfileProvider instance = PetProfileProvider._();

  final _uuid = const Uuid();
  final _auth = AuthService.instance;
  final _log = ActivityLogService.instance;

  List<FullPetProfile> _profiles = [];
  bool _loading = false;

  List<FullPetProfile> get profiles => List.unmodifiable(_profiles);
  bool get loading => _loading;
  bool get canAdd => _profiles.length < _maxProfiles;
  int get count => _profiles.length;

  Box<String> get _box => Hive.box<String>(_boxName);

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    await Hive.openBox<String>(_boxName);
    await _loadFromHive();

    // Background sync from Firestore if signed in
    if (_auth.isAuthenticated) {
      unawaited(_downloadFromCloud());
    }
    _auth.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (_auth.isAuthenticated) {
      unawaited(_downloadFromCloud());
    }
  }

  // ── Hive ──────────────────────────────────────────────────────────────────

  Future<void> _loadFromHive() async {
    _loading = true;
    notifyListeners();
    _profiles = _box.values
        .map((raw) =>
            FullPetProfile.fromMap(jsonDecode(raw) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    _loading = false;
    notifyListeners();
  }

  Future<void> _saveToHive(FullPetProfile p) async =>
      _box.put(p.id, jsonEncode(p.toMap()));

  Future<void> _deleteFromHive(String id) async => _box.delete(id);

  // ── Firestore ─────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>>? get _col {
    if (!_auth.isAuthenticated) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_auth.userId)
        .collection('full_pet_profiles');
  }

  Future<void> _uploadToCloud(FullPetProfile p) async {
    try {
      await _col?.doc(p.id).set(p.toMap(), SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _deleteFromCloud(String id) async {
    try {
      await _col?.doc(id).delete();
    } catch (_) {}
  }

  Future<void> _downloadFromCloud() async {
    try {
      final snap = await _col?.get();
      if (snap == null || snap.docs.isEmpty) return;

      final cloudProfiles =
          snap.docs.map((d) => FullPetProfile.fromMap(d.data())).toList();

      // Merge: newer updatedAt wins
      final map = {for (final p in _profiles) p.id: p};
      for (final cp in cloudProfiles) {
        final local = map[cp.id];
        if (local == null || cp.updatedAt.isAfter(local.updatedAt)) {
          map[cp.id] = cp;
          await _saveToHive(cp);
        }
      }
      _profiles = map.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      notifyListeners();
    } catch (_) {}
  }

  // ── Create ────────────────────────────────────────────────────────────────

  Future<FullPetProfile?> createProfile({
    required String name,
    required String breed,
    required int avatarColorValue,
  }) async {
    if (!canAdd) return null;

    final profile = FullPetProfile.create(
      id: _uuid.v4(),
      name: name.trim(),
      breed: breed.trim().isEmpty ? 'Persian' : breed.trim(),
      avatarColorValue: avatarColorValue,
    ).copyWith(
      achievements: _unlockAchievement(
        List.of(kDefaultAchievements),
        AchievementType.firstProfile,
        1,
      ),
    );

    _profiles.add(profile);
    notifyListeners();

    await _saveToHive(profile);
    unawaited(_uploadToCloud(profile));
    await _log.logProfileAdded(profile.name);

    return profile;
  }

  // ── Update full details ───────────────────────────────────────────────────

  Future<void> updateDetails(FullPetProfile updated) async {
    final idx = _profiles.indexWhere((p) => p.id == updated.id);
    if (idx < 0) return;
    final saved = updated.copyWith(updatedAt: DateTime.now());
    _profiles[idx] = saved;
    notifyListeners();
    await _saveToHive(saved);
    unawaited(_uploadToCloud(saved));
    await _log.logProfileUpdated(saved.name);
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> deleteProfile(String id) async {
    final name = _profiles
        .firstWhere((p) => p.id == id, orElse: () => _profiles.first)
        .name;
    _profiles.removeWhere((p) => p.id == id);
    notifyListeners();
    await _deleteFromHive(id);
    unawaited(_deleteFromCloud(id));
    await _log.logProfileDeleted(name);
  }

  // ── Growth tracker ────────────────────────────────────────────────────────

  Future<void> addGrowthEntry(String petId, GrowthEntry entry) async {
    final profile = _getById(petId);
    if (profile == null) return;
    final updated = profile.copyWith(
      growthEntries: [...profile.growthEntries, entry]
        ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt)),
    );
    await updateDetails(updated);
  }

  Future<void> updateGrowthEntry(String petId, GrowthEntry entry) async {
    final profile = _getById(petId);
    if (profile == null) return;
    final entries =
        profile.growthEntries.map((e) => e.id == entry.id ? entry : e).toList();
    await updateDetails(profile.copyWith(growthEntries: entries));
  }

  Future<void> deleteGrowthEntry(String petId, String entryId) async {
    final profile = _getById(petId);
    if (profile == null) return;
    final entries =
        profile.growthEntries.where((e) => e.id != entryId).toList();
    await updateDetails(profile.copyWith(growthEntries: entries));
  }

  // ── Vaccinations ──────────────────────────────────────────────────────────

  Future<void> addVaccination(String petId, VaccinationRecord record) async {
    final profile = _getById(petId);
    if (profile == null) return;
    final updatedVax = [...profile.vaccinations, record];
    var updated = profile.copyWith(vaccinations: updatedVax);

    // Unlock vaccine achievement
    updated = updated.copyWith(
      achievements: _unlockAchievement(
        updated.achievements,
        AchievementType.vaccinationComplete,
        updatedVax.length,
      ),
    );
    await updateDetails(updated);
  }

  Future<void> updateVaccination(String petId, VaccinationRecord record) async {
    final profile = _getById(petId);
    if (profile == null) return;
    final vax = profile.vaccinations
        .map((v) => v.id == record.id ? record : v)
        .toList();
    await updateDetails(profile.copyWith(vaccinations: vax));
  }

  Future<void> deleteVaccination(String petId, String vaccId) async {
    final profile = _getById(petId);
    if (profile == null) return;
    final vax = profile.vaccinations.where((v) => v.id != vaccId).toList();
    await updateDetails(profile.copyWith(vaccinations: vax));
  }

  // ── Activity counters (called from game screens) ──────────────────────────

  Future<void> incrementFeedCount(String petId) async =>
      _incrementCounter(petId, ActionType.feed);

  Future<void> incrementGroomCount(String petId) async =>
      _incrementCounter(petId, ActionType.groom);

  Future<void> incrementPlayCount(String petId) async =>
      _incrementCounter(petId, ActionType.play);

  Future<void> _incrementCounter(String petId, ActionType type) async {
    final profile = _getById(petId);
    if (profile == null) return;

    int feed = profile.feedCount;
    int groom = profile.groomCount;
    int play = profile.playCount;
    var achievements = List.of(profile.achievements);

    switch (type) {
      case ActionType.feed:
        feed++;
        achievements =
            _unlockAchievement(achievements, AchievementType.feedStreak, feed);
        break;
      case ActionType.groom:
        groom++;
        achievements = _unlockAchievement(
            achievements, AchievementType.groomStreak, groom);
        break;
      case ActionType.play:
        play++;
        achievements =
            _unlockAchievement(achievements, AchievementType.playStreak, play);
        break;
      default:
        break;
    }

    final updated = profile.copyWith(
      feedCount: feed,
      groomCount: groom,
      playCount: play,
      achievements: achievements,
    );
    await updateDetails(updated);
  }

  // ── Achievement helpers ───────────────────────────────────────────────────

  List<PetAchievement> _unlockAchievement(
    List<PetAchievement> list,
    AchievementType type,
    int newProgress,
  ) {
    return list.map((a) {
      if (a.type != type) return a;
      final updated = a.copyWith(progressCurrent: newProgress);
      if (!a.unlocked && newProgress >= a.progressTarget) {
        return updated.copyWith(unlocked: true, unlockedAt: DateTime.now());
      }
      return updated;
    }).toList();
  }

  // ── Manual sync ───────────────────────────────────────────────────────────

  Future<void> syncNow() async {
    if (!_auth.isAuthenticated) return;
    for (final p in _profiles) {
      unawaited(_uploadToCloud(p));
    }
    await _downloadFromCloud();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  FullPetProfile? _getById(String id) {
    try {
      return _profiles.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  FullPetProfile? getById(String id) => _getById(id);

  String generateId() => _uuid.v4();
}

// Needed for _incrementCounter type switch
enum ActionType { feed, groom, play }
