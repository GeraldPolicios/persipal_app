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

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/virtual_achievement_model.dart';
import '../models/virtual_pet_state.dart';
import 'activity_log_service.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';
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

  // The 89 added milestones must count actions performed after this tracker
  // was introduced, not the pet's historical lifetime counters.
  int _milestoneFeedBaseline = 0;
  int _milestoneGroomBaseline = 0;
  int _milestonePlayBaseline = 0;
  bool _milestoneBaselineInitialized = false;
  static const int _milestoneTrackingVersion = 2;

  bool _initialized = false;
  bool _initializing = false;
  bool _syncRequested = false;
  bool _allowAccountTransferRequested = false;
  bool _hasObservedPetBaseline = false;
  bool _syncing = false;
  bool _syncListenersAttached = false;

  List<VirtualAchievement> get achievements => List.unmodifiable(_achievements);

  int get unlockedCount => _achievements.where((a) => a.unlocked).length;
  int get totalCount => _achievements.length;

  /// Lifetime achievement score. Only unlocked badges contribute; this is
  /// intentionally separate from spendable Reward Points and Cat XP.
  int get achievementPoints => _achievements
      .where((achievement) => achievement.unlocked)
      .fold<int>(0, (total, achievement) => total + achievement.coinReward);

  /// Forgets all in-memory virtual-achievement state. The persisted copy
  /// lives in LocalStorageService's own box, which clearAll() now also wipes
  /// (see its own comment) — this keeps the in-memory copy from outliving
  /// it, so the next guest/account on this device never sees a departed
  /// account's virtual-cat badges. Does not touch gameplay/VirtualPetState.
  void resetInMemory() {
    _achievements = List.of(kDefaultVirtualAchievements);
    _feedDays = {};
    _groomDays = {};
    _playDays = {};
    _lastFeedCount = 0;
    _lastGroomCount = 0;
    _lastPlayCount = 0;
    _milestoneFeedBaseline = 0;
    _milestoneGroomBaseline = 0;
    _milestonePlayBaseline = 0;
    _milestoneBaselineInitialized = false;
    _hasObservedPetBaseline = false;
    notifyListeners();
  }

  // ── Init ─────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized || _initializing) return;
    _initializing = true;

    final saved = await _local.fetchVirtualAchievementState();
    if (saved != null) {
      _hasObservedPetBaseline = true;
      final rawAchievements = (saved['achievements'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>();
      final savedMilestoneVersion =
          (saved['milestoneTrackingVersion'] as num?)?.toInt() ?? 0;
      _achievements = kDefaultVirtualAchievements.map((base) {
        final match = rawAchievements.firstWhere(
          (a) => a['type'] == base.type.name,
          orElse: () => <String, dynamic>{},
        );
        if (match.isEmpty) return base;
        final restored = VirtualAchievement.fromMap(match, base);
        // Earlier tracker versions incorrectly completed many milestones
        // from the combined total. Re-lock only the 89 added milestones once.
        if (savedMilestoneVersion < _milestoneTrackingVersion &&
            base.type.name.startsWith('catMilestone')) {
          return base;
        }
        return restored;
      }).toList();
      _milestoneBaselineInitialized =
          savedMilestoneVersion >= _milestoneTrackingVersion &&
              saved['milestoneBaselineInitialized'] == true;
      _milestoneFeedBaseline =
          (saved['milestoneFeedBaseline'] as num?)?.toInt() ?? 0;
      _milestoneGroomBaseline =
          (saved['milestoneGroomBaseline'] as num?)?.toInt() ?? 0;
      _milestonePlayBaseline =
          (saved['milestonePlayBaseline'] as num?)?.toInt() ?? 0;

      _feedDays =
          ((saved['feedDays'] as List<dynamic>? ?? [])).cast<String>().toSet();
      _groomDays =
          ((saved['groomDays'] as List<dynamic>? ?? [])).cast<String>().toSet();
      _playDays =
          ((saved['playDays'] as List<dynamic>? ?? [])).cast<String>().toSet();
      _lastFeedCount = (saved['lastFeedCount'] as num?)?.toInt() ?? 0;
      _lastGroomCount = (saved['lastGroomCount'] as num?)?.toInt() ?? 0;
      _lastPlayCount = (saved['lastPlayCount'] as num?)?.toInt() ?? 0;
    }

    // Achievement rewards now contribute to the separate lifetime
    // Achievement Points score; they no longer add spendable Reward Points.
    // Existing RewardService balances are intentionally left untouched.

    _initialized = true;
    _initializing = false;

    if (!_syncListenersAttached) {
      _syncListenersAttached = true;
      AuthService.instance.addListener(_onAccountOrNetworkChanged);
      ConnectivityService.instance.addListener(_onAccountOrNetworkChanged);
    }
    notifyListeners();
    // Merge, never blindly replace, so first login preserves offline badges.
    if (AuthService.instance.accountSyncAllowed) {
      await syncProgress();
    }
  }

  void _onAccountOrNetworkChanged() {
    // Avoid starting account sync before the login data choice is resolved.
    if (AuthService.instance.accountSyncAllowed) {
      syncProgress();
    }
  }

  // ── Live updates from VirtualPetProvider (forwarded via main.dart) ────────

  Future<void> onVirtualPetChanged(VirtualPetState pet) async {
    if (!_initialized) return;

    // Establish a lifetime-counter baseline for the added milestones. This
    // prevents pre-existing feed/groom/play counts from instantly completing
    // achievements that were only recently introduced.
    if (!_milestoneBaselineInitialized) {
      _milestoneFeedBaseline = pet.simFeedCount;
      _milestoneGroomBaseline = pet.simGroomCount;
      _milestonePlayBaseline = pet.simPlayCount;
      _milestoneBaselineInitialized = true;
      _lastFeedCount = pet.simFeedCount;
      _lastGroomCount = pet.simGroomCount;
      _lastPlayCount = pet.simPlayCount;
      _hasObservedPetBaseline = true;
      await _save();
      notifyListeners();
      return;
    }

    // On a genuinely fresh local achievement state, the first provider
    // notification establishes a baseline only. It must not count historical
    // pet counters as actions performed after the tracker was installed.
    if (!_hasObservedPetBaseline) {
      _lastFeedCount = pet.simFeedCount;
      _lastGroomCount = pet.simGroomCount;
      _lastPlayCount = pet.simPlayCount;
      _hasObservedPetBaseline = true;
      await _save();
      return;
    }

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
    await _unlockAndLog(
        VirtualAchievementType.feedingRoutine, _feedDays.length);
    await _unlockAndLog(VirtualAchievementType.firstPlay, pet.simPlayCount);
    await _unlockAndLog(VirtualAchievementType.playtimePal, pet.simPlayCount);
    await _unlockAndLog(
        VirtualAchievementType.playtimeRegular, _playDays.length);
    await _unlockAndLog(VirtualAchievementType.firstGroom, pet.simGroomCount);
    await _unlockAndLog(
        VirtualAchievementType.groomingBuddy, pet.simGroomCount);
    await _unlockAndLog(
        VirtualAchievementType.fluffyRoutine, _groomDays.length);
    await _unlockAndLog(
        VirtualAchievementType.caringCompanion, categoriesTouched);
    await _unlockAndLog(VirtualAchievementType.dedicatedPlayer, combined);

    // The 89 added milestones count only actions performed since their
    // baseline was established, and use the action category named by each
    // achievement rather than the combined total for every badge.
    final feedProgress =
        (pet.simFeedCount - _milestoneFeedBaseline).clamp(0, 1 << 30);
    final groomProgress =
        (pet.simGroomCount - _milestoneGroomBaseline).clamp(0, 1 << 30);
    final playProgress =
        (pet.simPlayCount - _milestonePlayBaseline).clamp(0, 1 << 30);
    final careActions = feedProgress + groomProgress;
    final milestoneCombined = careActions + playProgress;
    for (final achievement in List<VirtualAchievement>.from(_achievements)) {
      if (!achievement.type.name.startsWith('catMilestone')) continue;
      final description = achievement.description.toLowerCase();
      final int progress;
      if (description.startsWith('fed the virtual cat')) {
        progress = feedProgress;
      } else if (description.startsWith('played with the virtual cat')) {
        progress = playProgress;
      } else if (description.startsWith('groomed the virtual cat')) {
        progress = groomProgress;
      } else if (description.contains('care actions')) {
        progress = careActions;
      } else {
        // "spent time", "routine", and "interactions" describe combined
        // care/play milestones.
        progress = milestoneCombined;
      }
      await _unlockAndLog(achievement.type, progress);
    }

    await _save();
    notifyListeners();
    syncProgress();
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
      // Achievement Points are derived from unlocked badges, so the score
      // increases exactly once per achievement and never inflates shop currency.
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
      'milestoneTrackingVersion': _milestoneTrackingVersion,
      'milestoneBaselineInitialized': _milestoneBaselineInitialized,
      'milestoneFeedBaseline': _milestoneFeedBaseline,
      'milestoneGroomBaseline': _milestoneGroomBaseline,
      'milestonePlayBaseline': _milestonePlayBaseline,
    });
  }

  /// Syncs virtual-cat achievements to the signed-in user's cloud profile.
  /// Local and cloud progress are merged monotonically: unlocked badges stay
  /// unlocked, progress uses the maximum seen, and distinct-day sets are unioned.
  /// Guests remain fully offline-first and never write to a shared guest path.
  Future<void> syncProgress({bool allowAccountTransfer = false}) async {
    if (!_initialized ||
        !AuthService.instance.isAuthenticated ||
        !ConnectivityService.instance.isOnline) {
      return;
    }
    if (_syncing) {
      _syncRequested = true;
      _allowAccountTransferRequested =
          _allowAccountTransferRequested || allowAccountTransfer;
      return;
    }
    final uid = AuthService.instance.userId;
    final ownerUid = _local.fetchVirtualProgressOwner();
    // Keep local achievements available offline, but don't silently upload a
    // previous account's virtual-cat achievements into a different account.
    if (!allowAccountTransfer && ownerUid != null && ownerUid != uid) {
      debugPrint('VirtualAchievementService: account mismatch; sync paused.');
      return;
    }
    _syncing = true;
    try {
      final doc = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('virtual_achievements');
      final snapshot = await doc.get();
      final cloud = snapshot.data();
      var changed = false;

      if (cloud != null) {
        final cloudMilestoneVersion =
            (cloud['milestoneTrackingVersion'] as num?)?.toInt() ?? 0;
        final ignoreLegacyMilestoneUnlocks =
            cloudMilestoneVersion < _milestoneTrackingVersion;
        final rawAchievements =
            (cloud['achievements'] as List<dynamic>? ?? const [])
                .whereType<Map>()
                .map((m) => Map<String, dynamic>.from(m))
                .toList();
        final mergedAchievements = <VirtualAchievement>[];
        for (final localAchievement in _achievements) {
          final remote =
              rawAchievements.cast<Map<String, dynamic>?>().firstWhere(
                    (m) => m?['type'] == localAchievement.type.name,
                    orElse: () => null,
                  );
          if (remote == null) {
            mergedAchievements.add(localAchievement);
            continue;
          }
          final remoteAchievement =
              VirtualAchievement.fromMap(remote, localAchievement);
          // Ignore pre-fix cloud states for the added milestones; they were
          // often unlocked from the wrong combined counter.
          if (ignoreLegacyMilestoneUnlocks &&
              localAchievement.type.name.startsWith('catMilestone')) {
            mergedAchievements.add(localAchievement);
            continue;
          }
          final isUnlocked =
              localAchievement.unlocked || remoteAchievement.unlocked;
          final localDate = localAchievement.unlockedAt;
          final remoteDate = remoteAchievement.unlockedAt;
          final unlockedAt = localDate == null
              ? remoteDate
              : remoteDate == null || localDate.isBefore(remoteDate)
                  ? localDate
                  : remoteDate;
          final merged = localAchievement.copyWith(
            unlocked: isUnlocked,
            unlockedAt: unlockedAt,
            progressCurrent: localAchievement.progressCurrent >
                    remoteAchievement.progressCurrent
                ? localAchievement.progressCurrent
                : remoteAchievement.progressCurrent,
          );
          if (merged.unlocked != localAchievement.unlocked ||
              merged.progressCurrent != localAchievement.progressCurrent ||
              merged.unlockedAt != localAchievement.unlockedAt) {
            changed = true;
          }
          mergedAchievements.add(merged);
        }
        _achievements = mergedAchievements;
        for (final key in ['feedDays', 'groomDays', 'playDays']) {
          final localSet = switch (key) {
            'feedDays' => _feedDays,
            'groomDays' => _groomDays,
            _ => _playDays,
          };
          final remoteSet =
              ((cloud[key] as List<dynamic>?) ?? const []).cast<String>();
          final union = {...localSet, ...remoteSet};
          if (union.length != localSet.length) changed = true;
          if (key == 'feedDays') _feedDays = union;
          if (key == 'groomDays') _groomDays = union;
          if (key == 'playDays') _playDays = union;
        }
      }

      await _save();
      await doc.set({
        'achievements': _achievements.map((a) => a.toMap()).toList(),
        'feedDays': _feedDays.toList(),
        'groomDays': _groomDays.toList(),
        'playDays': _playDays.toList(),
        'lastFeedCount': _lastFeedCount,
        'lastGroomCount': _lastGroomCount,
        'lastPlayCount': _lastPlayCount,
        'milestoneTrackingVersion': _milestoneTrackingVersion,
        'milestoneBaselineInitialized': _milestoneBaselineInitialized,
        'milestoneFeedBaseline': _milestoneFeedBaseline,
        'milestoneGroomBaseline': _milestoneGroomBaseline,
        'milestonePlayBaseline': _milestonePlayBaseline,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      await _local.saveVirtualProgressOwner(uid);

      // Achievement Points are derived from the merged unlocked badges, so
      // they remain consistent across local/cloud achievement merges.
      if (changed) notifyListeners();
    } catch (e) {
      debugPrint('VirtualAchievementService: sync failed: $e');
    } finally {
      _syncing = false;
      if (_syncRequested) {
        final allowTransfer = _allowAccountTransferRequested;
        _syncRequested = false;
        _allowAccountTransferRequested = false;
        unawaited(syncProgress(allowAccountTransfer: allowTransfer));
      }
    }
  }

  String _dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
