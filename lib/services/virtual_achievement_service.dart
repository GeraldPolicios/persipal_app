// lib/services/virtual_achievement_service.dart
//
// Tracks achievement progress for the VIRTUAL CAT SIMULATION scope only
// (Game/Feed/Play/Groom). Deliberately separate from real-pet achievements
// (which live inside FullPetProfile/PetProfileProvider) — virtual
// achievements are never associated with a real pet's petId.
//
// ── How this observes the virtual pet without touching frozen files ────────
// game_screen.dart / virtual_pet_provider.dart / virtual_pet_state.dart are
// frozen. This service never imports or modifies them for its own sake —
// instead, main.dart (not frozen) forwards VirtualPetProvider's already
// public, already-persisted counters (simFeedCount/simGroomCount/
// simPlayCount) to [onVirtualPetChanged] every time VirtualPetProvider
// notifies its listeners (i.e. on every feed/groom/play action, and on
// decay ticks). This service diffs against the last counts it has seen to
// detect a real action (not a decay tick) and stamps "today" into its own
// day-sets — the raw counters remain VirtualPetProvider's sole source of
// truth; this service only derives additional achievement-only state
// (distinct-day sets, unlocked flags, unlock dates) that doesn't exist
// anywhere else.
//
// ── Persistence ──────────────────────────────────────────────────────────
// Device-local only (Hive), matching VirtualPetProvider's own treatment:
// not cloud-synced, and not cleared on sign-out/account deletion, because
// the virtual simulation is one-per-device, not one-per-account (see
// virtual_pet_state.dart's header comment).

import 'package:flutter/foundation.dart';
import '../models/virtual_achievement_model.dart';
import '../models/virtual_pet_state.dart';
import 'activity_log_service.dart';
import 'local_storage_service.dart';

class VirtualAchievementService extends ChangeNotifier {
  VirtualAchievementService._();
  static final VirtualAchievementService instance =
      VirtualAchievementService._();

  final _local = LocalStorageService.instance;
  final _log = ActivityLogService.instance;

  List<VirtualAchievement> _achievements = List.of(kDefaultVirtualAchievements);
  Set<String> _feedDays = {};
  Set<String> _groomDays = {};
  Set<String> _playDays = {};
  int _lastFeedCount = 0;
  int _lastGroomCount = 0;
  int _lastPlayCount = 0;

  bool _initialized = false;

  List<VirtualAchievement> get achievements => List.unmodifiable(_achievements);

  int get unlockedCount => _achievements.where((a) => a.unlocked).length;
  int get totalCount => _achievements.length;

  // ── Init ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final saved = await _local.fetchVirtualAchievementState();
    if (saved != null) {
      final rawAchievements = (saved['achievements'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      _achievements = kDefaultVirtualAchievements.map((base) {
        final match = rawAchievements.firstWhere(
          (a) => a['type'] == base.type.name,
          orElse: () => <String, dynamic>{},
        );
        return match.isEmpty ? base : VirtualAchievement.fromMap(match, base);
      }).toList();

      _feedDays = ((saved['feedDays'] as List<dynamic>? ?? []))
          .cast<String>()
          .toSet();
      _groomDays = ((saved['groomDays'] as List<dynamic>? ?? []))
          .cast<String>()
          .toSet();
      _playDays = ((saved['playDays'] as List<dynamic>? ?? []))
          .cast<String>()
          .toSet();
      _lastFeedCount = (saved['lastFeedCount'] as num?)?.toInt() ?? 0;
      _lastGroomCount = (saved['lastGroomCount'] as num?)?.toInt() ?? 0;
      _lastPlayCount = (saved['lastPlayCount'] as num?)?.toInt() ?? 0;
    }

    notifyListeners();
  }

  // ── Live updates from VirtualPetProvider (forwarded via main.dart) ────────

  Future<void> onVirtualPetChanged(VirtualPetState pet) async {
    if (!_initialized) return;

    final today = _dayKey(DateTime.now());
    var changed = false;

    if (pet.simFeedCount > _lastFeedCount) {
      _feedDays.add(today);
      _lastFeedCount = pet.simFeedCount;
      changed = true;
    }
    if (pet.simGroomCount > _lastGroomCount) {
      _groomDays.add(today);
      _lastGroomCount = pet.simGroomCount;
      changed = true;
    }
    if (pet.simPlayCount > _lastPlayCount) {
      _playDays.add(today);
      _lastPlayCount = pet.simPlayCount;
      changed = true;
    }

    if (!changed) return;

    final combined = pet.simFeedCount + pet.simGroomCount + pet.simPlayCount;
    final categoriesTouched = [
      pet.simFeedCount > 0,
      pet.simGroomCount > 0,
      pet.simPlayCount > 0,
    ].where((v) => v).length;

    await _unlockAndLog(VirtualAchievementType.firstFeed, pet.simFeedCount);
    await _unlockAndLog(VirtualAchievementType.feedingFriend, pet.simFeedCount);
    await _unlockAndLog(VirtualAchievementType.feedingRoutine, _feedDays.length);
    await _unlockAndLog(VirtualAchievementType.firstPlay, pet.simPlayCount);
    await _unlockAndLog(VirtualAchievementType.playtimePal, pet.simPlayCount);
    await _unlockAndLog(VirtualAchievementType.playtimeRegular, _playDays.length);
    await _unlockAndLog(VirtualAchievementType.firstGroom, pet.simGroomCount);
    await _unlockAndLog(VirtualAchievementType.groomingBuddy, pet.simGroomCount);
    await _unlockAndLog(VirtualAchievementType.fluffyRoutine, _groomDays.length);
    await _unlockAndLog(VirtualAchievementType.caringCompanion, categoriesTouched);
    await _unlockAndLog(VirtualAchievementType.dedicatedPlayer, combined);

    await _save();
    notifyListeners();
  }

  Future<void> _unlockAndLog(VirtualAchievementType type, int progress) async {
    final index = _achievements.indexWhere((a) => a.type == type);
    if (index < 0) return;

    final before = _achievements[index];
    final wasUnlocked = before.unlocked;
    final nowUnlocked = wasUnlocked || progress >= before.progressTarget;

    _achievements[index] = before.copyWith(
      progressCurrent: progress,
      unlocked: nowUnlocked,
      unlockedAt: !wasUnlocked && nowUnlocked ? DateTime.now() : null,
    );

    if (!wasUnlocked && nowUnlocked) {
      await _log.logAchievementUnlocked(before.title, 'Virtual Cat');
    }
  }

  Future<void> _save() async {
    await _local.saveVirtualAchievementState({
      'achievements': _achievements.map((a) => a.toMap()).toList(),
      'feedDays': _feedDays.toList(),
      'groomDays': _groomDays.toList(),
      'playDays': _playDays.toList(),
      'lastFeedCount': _lastFeedCount,
      'lastGroomCount': _lastGroomCount,
      'lastPlayCount': _lastPlayCount,
    });
  }

  String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
