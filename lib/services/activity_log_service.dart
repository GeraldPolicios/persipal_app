// lib/services/activity_log_service.dart
//
// Dedicated activity logging service.
// Writes to Hive first (instant), then Firestore in background.
// Exposes a ChangeNotifier so the Activity Log screen rebuilds automatically.

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
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

  Future<void> logReminderAdded(String title, String type) => log(
        type: ActionType.reminder,
        description: 'Added reminder — $title ($type)',
      );

  Future<void> logReminderCompleted(String title) => log(
        type: ActionType.reminder,
        description: 'Completed reminder — $title',
      );

  Future<void> logReminderEdited(String title) => log(
        type: ActionType.reminder,
        description: 'Edited reminder — $title',
      );

  Future<void> logReminderDeleted(String title) => log(
        type: ActionType.reminder,
        description: 'Deleted reminder — $title',
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
}
