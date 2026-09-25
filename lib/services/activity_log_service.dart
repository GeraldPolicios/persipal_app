// lib/services/activity_log_service.dart
//
// Dedicated activity logging service.
// Writes to Hive first (instant), then Firestore in background.
// Exposes a ChangeNotifier so the Activity Log screen rebuilds automatically.

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../models/virtual_pet_state.dart';
import 'local_storage_service.dart';
import 'firebase_sync_service.dart';
import 'auth_service.dart';

class ActivityLogService extends ChangeNotifier {
  ActivityLogService._();
  static final ActivityLogService instance = ActivityLogService._();

  final _local = LocalStorageService.instance;
  final _sync = FirebaseSyncService.instance;
  final _auth = AuthService.instance;
  final _uuid = const Uuid();

  List<ActivityLogModel> _logs = [];

  List<ActivityLogModel> get logs => List.unmodifiable(_logs);
  int get count => _logs.length;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    _logs = await _local.fetchLogs();
    notifyListeners();
  }

  // ── Core log method ───────────────────────────────────────────────────────

  Future<void> log({
    required ActionType type,
    required String description,
    String petId = '',
    String petName = '',
    Map<String, int> statChanges = const {},
  }) async {
    final entry = ActivityLogModel(
      id: _uuid.v4(),
      petId: petId,
      petName: petName,
      actionType: type,
      description: description,
      statChanges: statChanges,
      timestamp: DateTime.now(),
    );

    // 1. Update in-memory list immediately
    _logs.insert(0, entry);
    if (_logs.length > 500) _logs.removeLast();

    // 2. Persist to Hive (primary source)
    await _local.addLog(entry);

    // 3. Notify UI
    notifyListeners();

    // 4. Push to Firestore in background (non-blocking)
    if (_auth.isAuthenticated) {
      _sync.addLog(entry).catchError((_) {});
    }
  }

  // ── Typed convenience methods ─────────────────────────────────────────────

  Future<void> logFeed(String petName, String foodName) => log(
        type: ActionType.feed,
        description: 'Fed $petName — $foodName',
        petName: petName,
      );

  Future<void> logGroom(String petName, String toolName) => log(
        type: ActionType.groom,
        description: 'Groomed $petName — $toolName',
        petName: petName,
      );

  Future<void> logPlay(String petName, String toyName) => log(
        type: ActionType.play,
        description: 'Played with $petName — $toyName',
        petName: petName,
      );

  Future<void> logLesson(String lessonTitle) => log(
        type: ActionType.lesson,
        description: 'Opened lesson — $lessonTitle',
      );

  Future<void> logLessonComplete(String lessonTitle) => log(
        type: ActionType.lesson,
        description: 'Completed lesson — $lessonTitle',
      );

  Future<void> logQuiz(int score, int total) => log(
        type: ActionType.quiz,
        description: 'Completed quiz — Score: $score/$total',
      );

  Future<void> logReminderAdded(
    String title,
    String type, {
    String petId = '',
  }) =>
      log(
        type: ActionType.reminder,
        description: 'Added reminder — $title ($type)',
        petId: petId,
      );

  Future<void> logReminderCompleted(
    String title, {
    String petId = '',
  }) =>
      log(
        type: ActionType.reminder,
        description: 'Completed reminder — $title',
        petId: petId,
      );

  Future<void> logReminderEdited(
    String title, {
    String petId = '',
  }) =>
      log(
        type: ActionType.reminder,
        description: 'Edited reminder — $title',
        petId: petId,
      );

  Future<void> logReminderDeleted(
    String title, {
    String petId = '',
  }) =>
      log(
        type: ActionType.reminder,
        description: 'Deleted reminder — $title',
        petId: petId,
      );

  /// The user manually reverted a completed reminder back to pending (the
  /// Done tab's "Reset" action) — distinct from [logReminderEdited] so
  /// Activity History shows plainly that this was a completion undone, not
  /// a title/date/pet edit.
  Future<void> logReminderReset(
    String title, {
    String petId = '',
  }) =>
      log(
        type: ActionType.reminder,
        description: 'Reset reminder to pending — $title',
        petId: petId,
      );

  Future<void> logProfileAdded(String name) => log(
        type: ActionType.profile,
        description: 'Added profile — $name',
        petName: name,
      );

  Future<void> logProfileUpdated(String name) => log(
        type: ActionType.profile,
        description: "Edited profile — $name's details updated",
        petName: name,
      );

  Future<void> logProfileDeleted(String name) => log(
        type: ActionType.profile,
        description: 'Deleted profile — $name',
        petName: name,
      );

  Future<void> logVaccinationAdded(String vaccineName, String petName) => log(
        type: ActionType.vaccination,
        description: 'Added vaccination — $vaccineName',
        petName: petName,
      );

  Future<void> logVaccinationUpdated(String vaccineName, String petName) => log(
        type: ActionType.vaccination,
        description: 'Edited vaccination — $vaccineName',
        petName: petName,
      );

  Future<void> logVaccinationDeleted(String vaccineName, String petName) => log(
        type: ActionType.vaccination,
        description: 'Deleted vaccination — $vaccineName',
        petName: petName,
      );

  Future<void> logVaccinationSeriesCreated(
    String vaccineName,
    String petName,
    int totalDoses,
  ) =>
      log(
        type: ActionType.vaccination,
        description:
            'Created vaccination series — $vaccineName ($totalDoses doses)',
        petName: petName,
      );

  Future<void> logVaccinationCompleted(
    String vaccineName,
    String petName, {
    bool wasPlanned = false,
  }) =>
      log(
        type: ActionType.vaccination,
        description: wasPlanned
            ? 'Completed planned vaccination — $vaccineName'
            : 'Completed vaccination — $vaccineName',
        petName: petName,
      );

  Future<void> logGuestCreated() => log(
        type: ActionType.login,
        description: 'Guest session created',
      );

  Future<void> logSignIn(String email) => log(
        type: ActionType.login,
        description: 'Signed in — $email',
      );

  Future<void> logSignUp(String email) => log(
        type: ActionType.login,
        description: 'Account created — $email',
      );

  Future<void> logSignOut() => log(
        type: ActionType.login,
        description: 'Signed out',
      );

  Future<void> logGoogleSignIn(String email) => log(
        type: ActionType.login,
        description: 'Signed in with Google — $email',
      );

  Future<void> logSyncStarted() => log(
        type: ActionType.sync,
        description: 'Cloud sync started',
      );

  Future<void> logSyncCompleted() => log(
        type: ActionType.sync,
        description: 'Cloud sync completed',
      );

  Future<void> logSyncFailed(String reason) => log(
        type: ActionType.sync,
        description: 'Cloud sync failed — $reason',
      );

  Future<void> logOfflineChangesQueued(int count) => log(
        type: ActionType.sync,
        description: '$count change(s) queued for sync when online',
      );

  Future<void> logGuestMerged() => log(
        type: ActionType.login,
        description: 'Guest progress merged into account',
      );

  Future<void> logGrowthAdded(String petName, double weightKg, String notes,
          {String petId = ''}) =>
      log(
        type: ActionType.growth,
        description: notes.trim().isEmpty
            ? 'Recorded weight — $petName: ${weightKg}kg'
            : 'Recorded weight — $petName: ${weightKg}kg ($notes)',
        petId: petId,
        petName: petName,
      );

  Future<void> logHealthRecord(String petName, String notes,
          {String petId = ''}) =>
      log(
        type: ActionType.health,
        description: 'Health/checkup note — $petName: $notes',
        petId: petId,
        petName: petName,
      );

  // ── Virtual-pet actions ─────────────────────────────────────────────────
  // Forwarded from main.dart on each VirtualPetProvider change (the same
  // observer pattern already used by RewardService/VirtualSoundService — see
  // their header comments). Labeled "Virtual play" so these are never
  // mistaken for real-pet care in Activity History/search/trends/export.
  // Gameplay itself (game_screen.dart, feed/groom/play_screen.dart,
  // VirtualPetProvider, CatAnimation) is untouched by this.

  int? _lastVirtualFeed, _lastVirtualGroom, _lastVirtualPlay;

  void onVirtualPetChanged(VirtualPetState pet) {
    final lf = _lastVirtualFeed, lg = _lastVirtualGroom, lp = _lastVirtualPlay;
    _lastVirtualFeed = pet.simFeedCount;
    _lastVirtualGroom = pet.simGroomCount;
    _lastVirtualPlay = pet.simPlayCount;
    // First call after (re)load is a baseline, not an action — otherwise a
    // cloud restore or app start would be logged as if the user just acted.
    if (lf == null || lg == null || lp == null) return;

    if (pet.simFeedCount == lf + 1) {
      log(type: ActionType.feed, description: '🎮 Virtual play — fed ${pet.catName}');
    } else if (pet.simGroomCount == lg + 1) {
      log(
          type: ActionType.groom,
          description: '🎮 Virtual play — groomed ${pet.catName}');
    } else if (pet.simPlayCount == lp + 1) {
      log(
          type: ActionType.play,
          description: '🎮 Virtual play — played with ${pet.catName}');
    }
  }

  // ── Clear ─────────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    _logs.clear();
    await _local.clearLogs();
    notifyListeners();
  }

  // ── Reload from Hive (e.g. after cloud sync) ──────────────────────────────

  Future<void> reload() async {
    _logs = await _local.fetchLogs();
    notifyListeners();
  }

  Future<void> logAchievementUnlocked(
    String achievementTitle,
    String petName,
  ) =>
      log(
        type: ActionType.other,
        description: 'Unlocked achievement — $achievementTitle',
        petName: petName,
      );
}
