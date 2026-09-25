// lib/services/reward_service.dart
//
// Reward points (capstone FR: "earn points by completing tasks, quizzes, and
// pet care activities" / "unlock features or content using earned rewards").
//
// Points are a LEDGER of one-time events, so a one-time activity can never
// be paid twice:
//   lesson:<type>      +10   first completion of a lesson
//   quiz:best          5 + 2 per correct answer of the BEST score so far —
//                      a retake only pays for improving on that best
//   care:<reminderId>  +3    each completed care reminder (once per reminder)
//   growth:<entryId>   +2    each recorded weigh-in (once per entry)
//   virtual:<date>     +1 per virtual-cat action, capped at 5 a day
// Spending: claiming "unlock <lesson> early" costs [lessonUnlockCost]; each
// claim is stored once, so it can't be claimed twice. points = earned - spent.
//
// Separate from real-pet achievements (which are untouched). Persisted in
// Hive (offline-first); when signed in it is merged with a single
// users/{uid}/settings/progress document (ledger max-per-key, claims/lessons
// union) so progress survives sign-out/sign-in and other devices.

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/virtual_pet_state.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';
import 'lesson_progress_service.dart';
import 'local_storage_service.dart';

class RewardService extends ChangeNotifier {
  RewardService._();
  static final RewardService instance = RewardService._();

  static const lessonCompletePoints = 10;
  static const quizFirstBonus = 5;
  static const quizPointsPerCorrect = 2;
  static const carePoints = 3;
  static const growthPoints = 2;
  static const virtualDailyCap = 5;
  static const lessonUnlockCost = 25;

  final _local = LocalStorageService.instance;

  Map<String, int> _ledger = {};
  Set<String> _claimed = {};
  bool _syncing = false;
  bool _listening = false;

  int get earned => _ledger.values.fold(0, (a, b) => a + b);
  int get spent => _claimed.length * lessonUnlockCost;
  int get points => (earned - spent).clamp(0, 1 << 30);

  bool isLessonUnlockClaimed(String type) => _claimed.contains('lesson:$type');

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  Future<void> init() async {
    _load();
    notifyListeners();
    if (!_listening) {
      _listening = true;
      AuthService.instance.addListener(_onAuthChanged);
      ConnectivityService.instance.addListener(_onAuthChanged);
    }
    unawaited(syncProgress());
  }

  void _onAuthChanged() => unawaited(syncProgress());

  void _load() {
    try {
      final raw = _local.fetchRewardState();
      if (raw == null) {
        _ledger = {};
        _claimed = {};
        return;
      }
      final m = jsonDecode(raw) as Map<String, dynamic>;
      _ledger = {
        for (final e in (m['ledger'] as Map? ?? {}).entries)
          e.key as String: (e.value as num).toInt(),
      };
      _claimed = {...((m['claimed'] as List?) ?? const []).cast<String>()};
    } catch (_) {
      _ledger = {};
      _claimed = {};
    }
  }

  Future<void> _save() => _local.saveRewardState(jsonEncode({
        'ledger': _ledger,
        'claimed': _claimed.toList(),
      }));

  /// Called when local data is wiped during sign-out or account deletion so
  /// the in-memory copy doesn't outlive the persisted one.
  void resetInMemory() {
    if (_ledger.isEmpty && _claimed.isEmpty) return;
    _ledger = {};
    _claimed = {};
    notifyListeners();
  }

  /// Discards local points/claims AND persists the empty state (unlike
  /// [resetInMemory]). Pairs with LessonProgressService.discardLocal() for
  /// "Use Cloud Data" — call this, then [syncProgress] to pull the
  /// account's real cloud progress into what is now an empty local state.
  Future<void> discardLocal() async {
    _ledger = {};
    _claimed = {};
    await _save();
    notifyListeners();
  }

  // ── Earning ───────────────────────────────────────────────────────────────

  /// Awards [pts] once for [key]. Returns the points actually added (0 if
  /// this event was already rewarded).
  Future<int> awardOnce(String key, int pts) async {
    if (_ledger.containsKey(key)) return 0;
    _ledger = {..._ledger, key: pts};
    await _changed();
    return pts;
  }

  /// Quiz completion, scoped per lesson topic ('general' for the mixed
  /// quiz). Pays 5 + 2/correct answer the first time a topic's quiz is
  /// completed, and after that only for beating that topic's previous best
  /// — so retaking a DIFFERENT lesson's quiz is never blocked by an
  /// unrelated topic's best score. Returns points added.
  Future<int> awardQuiz(int score, {String topic = 'general'}) async {
    final now = quizFirstBonus + quizPointsPerCorrect * score;
    final key = 'quiz:$topic:best';
    final before = _ledger[key] ?? 0;
    if (now <= before) return 0;
    _ledger = {..._ledger, key: now};
    await _changed();
    return now - before;
  }

  /// Virtual-cat care action: +1, up to [virtualDailyCap] a day, so the
  /// simulation can't be farmed. Independent of real-pet achievements.
  Future<void> awardVirtualAction({DateTime? now}) async {
    final d = now ?? DateTime.now();
    final key =
        'virtual:${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    final cur = _ledger[key] ?? 0;
    if (cur >= virtualDailyCap) return;
    _ledger = {..._ledger, key: cur + 1};
    await _changed();
  }

  int? _lastVirtualTotal;

  /// Forwarded from main.dart on each VirtualPetProvider change (once
  /// loaded). Awards a (daily-capped) point only when the action counter
  /// rises by exactly one — never on start-up, decay ticks or cloud restores.
  void onVirtualPetChanged(VirtualPetState pet) {
    final total = pet.simFeedCount + pet.simGroomCount + pet.simPlayCount;
    final last = _lastVirtualTotal;
    _lastVirtualTotal = total;
    if (last != null && total == last + 1) {
      unawaited(awardVirtualAction());
    }
  }

  // ── Spending ──────────────────────────────────────────────────────────────

  /// Claims "unlock this lesson early". False if already claimed or not
  /// enough points.
  Future<bool> claimLessonUnlock(String type) async {
    final key = 'lesson:$type';
    if (_claimed.contains(key) || points < lessonUnlockCost) return false;
    _claimed = {..._claimed, key};
    await _changed();
    return true;
  }

  Future<void> _changed() async {
    await _save();
    notifyListeners();
    unawaited(syncProgress());
  }

  // ── Cloud merge (best effort — never blocks or breaks offline use) ────────

  DocumentReference<Map<String, dynamic>>? get _doc {
    final auth = AuthService.instance;
    if (!auth.isAuthenticated) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(auth.userId)
        .collection('settings')
        .doc('progress');
  }

  Future<void> syncProgress() async {
    DocumentReference<Map<String, dynamic>>? doc;
    try {
      doc = _doc;
    } catch (_) {
      doc = null; // Firebase unavailable — stay purely local
    }
    if (doc == null || !ConnectivityService.instance.isOnline || _syncing) {
      return;
    }
    _syncing = true;
    try {
      final snap = await doc.get();
      final cloud = snap.data();
      final lessons = LessonProgressService.instance;
      if (cloud != null) {
        final cloudLedger = {
          for (final e in (cloud['ledger'] as Map? ?? {}).entries)
            e.key as String: (e.value as num).toInt(),
        };
        final merged = {..._ledger};
        cloudLedger.forEach((k, v) {
          if (v > (merged[k] ?? -1)) merged[k] = v;
        });
        _ledger = merged;
        _claimed = {
          ..._claimed,
          ...((cloud['claimed'] as List?) ?? const []).cast<String>(),
        };
        await lessons.mergeCompleted(
            ((cloud['lessons'] as List?) ?? const []).cast<String>());
        await _save();
        notifyListeners();
      }
      await doc.set({
        'ledger': _ledger,
        'claimed': _claimed.toList(),
        'lessons': lessons.completedTypes.toList(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('RewardService: progress sync failed: $e');
    } finally {
      _syncing = false;
    }
  }
}
