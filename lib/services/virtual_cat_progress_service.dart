import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/virtual_pet_state.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';
import 'local_storage_service.dart';

/// Offline-first progression for the virtual cat only. Cat XP is intentionally
/// separate from the app-wide achievement/coin system.
class VirtualCatProgressService extends ChangeNotifier {
  VirtualCatProgressService._();
  static final VirtualCatProgressService instance =
      VirtualCatProgressService._();

  final LocalStorageService _local = LocalStorageService.instance;
  int _totalXp = 0;
  int? _lastActionTotal;
  bool _initialized = false;
  bool _syncing = false;
  bool _syncRequested = false;
  bool _allowAccountTransferRequested = false;
  bool _listenersAttached = false;

  int get totalXp => _totalXp;
  int get level {
    var currentLevel = 1;
    var remaining = _totalXp;
    while (remaining >= xpForNextLevel(currentLevel)) {
      remaining -= xpForNextLevel(currentLevel);
      currentLevel++;
    }
    return currentLevel;
  }

  int get xpIntoLevel {
    var remaining = _totalXp;
    for (var currentLevel = 1; currentLevel < level; currentLevel++) {
      remaining -= xpForNextLevel(currentLevel);
    }
    return remaining;
  }

  int get xpNeededForNextLevel => xpForNextLevel(level);
  double get levelProgress =>
      (xpIntoLevel / xpNeededForNextLevel).clamp(0.0, 1.0);

  /// Level 1 -> 2 requires 100 XP; each next level adds 50 XP to the cost.
  int xpForNextLevel(int currentLevel) => 100 + ((currentLevel - 1) * 50);

  /// Proposed shop gates. Purchases still cost coins after unlocking.
  bool isShopFeatureUnlocked(String feature) {
    final requiredLevel = switch (feature) {
      'grooming' || 'feed' || 'play' => 5,
      'decor' => 7,
      'rooms' => 10,
      'special' => 15,
      _ => 1,
    };
    return level >= requiredLevel;
  }

  int requiredLevelFor(String feature) => switch (feature) {
        'grooming' || 'feed' || 'play' => 5,
        'decor' => 7,
        'rooms' => 10,
        'special' => 15,
        _ => 1,
      };

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final raw = _local.fetchVirtualCatProgress();
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _totalXp =
            ((data['totalXp'] as num?)?.toInt() ?? 0).clamp(0, 1 << 30).toInt();
      }
    } catch (_) {
      _totalXp = 0;
    }
    if (!_listenersAttached) {
      _listenersAttached = true;
      AuthService.instance.addListener(_onAccountOrNetworkChanged);
      ConnectivityService.instance.addListener(_onAccountOrNetworkChanged);
    }
    notifyListeners();
    if (AuthService.instance.accountSyncAllowed) {
      unawaited(syncProgress());
    }
  }

  void _onAccountOrNetworkChanged() {
    if (AuthService.instance.accountSyncAllowed) {
      unawaited(syncProgress());
    }
  }

  /// Earn XP only for a genuine +1 rise in the persisted gameplay counters.
  /// Loading/restoring the pet establishes a baseline and never grants XP.
  void onVirtualPetChanged(VirtualPetState pet) {
    final total = pet.simFeedCount + pet.simGroomCount + pet.simPlayCount;
    final previous = _lastActionTotal;
    _lastActionTotal = total;
    final feed = pet.simFeedCount;
    final groom = pet.simGroomCount;
    final previousFeed = _lastFeedCount;
    final previousGroom = _lastGroomCount;
    _lastFeedCount = feed;
    _lastGroomCount = groom;
    if (previous == null || total != previous + 1) return;

    final gained = feed > previousFeed ? 10 : (groom > previousGroom ? 15 : 10);
    unawaited(addXp(gained));
  }

  int _lastFeedCount = 0;
  int _lastGroomCount = 0;

  Future<void> addXp(int amount) async {
    if (amount <= 0) return;
    _totalXp = (_totalXp + amount).clamp(0, 1 << 30).toInt();
    await _save();
    notifyListeners();
    unawaited(syncProgress());
  }

  Future<void> awardAchievementBonus(String achievementId, int amount) async {
    // Kept as a named API so virtual-cat achievement bonuses can be added
    // without coupling app-wide achievements to cat leveling.
    await addXp(amount);
  }

  Future<void> _save() => _local.saveVirtualCatProgress(jsonEncode({
        'totalXp': _totalXp,
        'updatedAt': DateTime.now().toIso8601String(),
      }));

  DocumentReference<Map<String, dynamic>>? get _doc {
    final auth = AuthService.instance;
    if (!auth.isAuthenticated) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(auth.userId)
        .collection('settings')
        .doc('virtual_cat_progress');
  }

  /// Cloud merge is monotonic: an older account/device snapshot cannot lower
  /// the locally saved XP. Offline gameplay continues if Firestore is down.
  Future<void> syncProgress({bool allowAccountTransfer = false}) async {
    if (!_initialized || !ConnectivityService.instance.isOnline) {
      return;
    }
    if (_syncing) {
      _syncRequested = true;
      _allowAccountTransferRequested =
          _allowAccountTransferRequested || allowAccountTransfer;
      return;
    }
    DocumentReference<Map<String, dynamic>>? doc;
    try {
      doc = _doc;
    } catch (_) {
      return;
    }
    if (doc == null) return;
    final uid = AuthService.instance.userId;
    final ownerUid = _local.fetchVirtualProgressOwner();
    // Never silently merge one device's account-bound progression into a
    // different existing account. A future account-switch UI can explicitly
    // offer transfer/merge after user confirmation. Unbound guest progress is
    // allowed to migrate to the first account that successfully syncs.
    if (!allowAccountTransfer && ownerUid != null && ownerUid != uid) {
      debugPrint('VirtualCatProgressService: account mismatch; sync paused.');
      return;
    }
    _syncing = true;
    try {
      final snapshot = await doc.get();
      final cloudXp = (snapshot.data()?['totalXp'] as num?)?.toInt() ?? 0;
      if (cloudXp > _totalXp) {
        _totalXp = cloudXp;
        await _save();
        notifyListeners();
      }
      await doc.set({
        'totalXp': _totalXp,
        'level': level,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
      await _local.saveVirtualProgressOwner(uid);
    } catch (e) {
      debugPrint('VirtualCatProgressService: sync failed: $e');
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
}
