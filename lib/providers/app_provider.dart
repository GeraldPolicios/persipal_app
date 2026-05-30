// lib/providers/app_provider.dart
//
// Central ChangeNotifier.  Offline-first architecture:
//   1. Every mutation hits LocalStorageService first (instant UI update)
//   2. FirebaseSyncService syncs to Firestore in background
//   3. App never waits for internet to start

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';
import '../services/local_storage_service.dart';
import '../services/firebase_sync_service.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../services/session_manager.dart';
import '../services/activity_log_service.dart';

class AppProvider extends ChangeNotifier {
  final _local = LocalStorageService.instance;
  final _sync = FirebaseSyncService.instance;
  final _auth = AuthService.instance;
  final _connectivity = ConnectivityService.instance;
  final _session = SessionManager.instance;
  final _activityLog = ActivityLogService.instance;
  final _uuid = const Uuid();

  // ── State ─────────────────────────────────────────────────────────────────

  List<PetModel> _pets = [];
  List<ReminderModel> _reminders = [];
  List<QuizResult> _quizzes = [];
  List<ActivityLogModel> _logs = []; // FIX: was missing
  AppSettings _settings = const AppSettings();
  PetModel? _selectedPet;
  bool _loading = true;
  bool _syncing = false;

  // ── Getters ───────────────────────────────────────────────────────────────

  List<PetModel> get pets => List.unmodifiable(_pets);
  List<ReminderModel> get reminders => List.unmodifiable(_reminders);
  List<QuizResult> get quizzes => List.unmodifiable(_quizzes);
  List<ActivityLogModel> get logs => List.unmodifiable(_logs); // FIX: added
  AppSettings get settings => _settings;
  PetModel? get selectedPet => _selectedPet;
  bool get loading => _loading;
  bool get syncing => _syncing;
  bool get hasPets => _pets.isNotEmpty;
  SyncState get syncState => _sync.state;
  DateTime? get lastSyncAt => _sync.lastSyncAt;
  bool get isOnline => _connectivity.isOnline;
  bool get isGuest => _session.isGuest;
  bool get isAuthenticated => _session.isAuthenticated;
  String get displayName => _session.displayName;

  // Reminder helpers
  List<ReminderModel> get pendingReminders =>
      _reminders.where((r) => !r.isCompleted).toList()
        ..sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));

  List<ReminderModel> get completedReminders =>
      _reminders.where((r) => r.isCompleted).toList()
        ..sort((a, b) => b.scheduledTime.compareTo(a.scheduledTime));

  List<ReminderModel> get overdueReminders =>
      _reminders.where((r) => r.isOverdue).toList();

  int get pendingReminderCount => pendingReminders.length;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    _loading = true;
    notifyListeners();

    // Step 1: Load all data from Hive (always, regardless of connectivity)
    _pets = await _local.fetchPets();
    _reminders = await _local.fetchReminders();
    _settings = await _local.fetchSettings();
    _quizzes = await _local.fetchQuizResults();
    _logs = await _local.fetchLogs(); // FIX: populate logs on init

    // Step 2: Restore selected pet
    final savedId = await _local.getSelectedPetId();
    _selectedPet = _pets.isEmpty
        ? null
        : _pets.firstWhere(
            (p) => p.id == savedId,
            orElse: () => _pets.first,
          );

    // Step 3: Open app immediately
    _loading = false;
    notifyListeners();

    // Step 4: Wire up reactive listeners
    _connectivity.addListener(_onConnectivityChanged);
    _auth.addListener(_onAuthChanged);
    _sync.addListener(notifyListeners);

    // Step 5: Background cloud sync (non-blocking)
    unawaited(_backgroundSync());
  }

  @override
  void dispose() {
    _connectivity.removeListener(_onConnectivityChanged);
    _auth.removeListener(_onAuthChanged);
    _sync.removeListener(notifyListeners);
    super.dispose();
  }

  // ── Reactive listeners ────────────────────────────────────────────────────

  void _onConnectivityChanged() {
    if (_connectivity.isOnline) {
      unawaited(_backgroundSync());
    } else {
      _sync.markOffline();
    }
    notifyListeners();
  }

  void _onAuthChanged() {
    if (_auth.isAuthenticated) {
      unawaited(_backgroundSync());
    }
    notifyListeners();
  }

  // ── Background sync ───────────────────────────────────────────────────────

  Future<void> _backgroundSync() async {
    if (!_auth.isAuthenticated || !_connectivity.isOnline) return;
    if (_syncing) return;
    _syncing = true;
    notifyListeners();
    try {
      // Flush any pending offline ops first
      await _sync.flushPendingOps(this);

      // Download cloud data and merge
      final cloud = await _sync.downloadAll();
      if (!cloud.isEmpty) {
        await _mergeCloudData(cloud);
      } else {
        // First login on this device — push local data up
        await _pushToCloud();
      }
      await _activityLog.logSyncCompleted();
    } catch (_) {
      // Silent fail — app works offline
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> _pushToCloud() async {
    if (!_auth.isAuthenticated || !_connectivity.isOnline) return;
    try {
      final logs = await _local.fetchLogs();
      await _sync.uploadAll(
        pets: _pets,
        logs: logs,
        reminders: _reminders,
        settings: _settings,
        quizzes: _quizzes,
      );
    } catch (_) {}
  }

  /// Merge cloud data into local state using updatedAt timestamps.
  Future<void> _mergeCloudData(CloudData cloud) async {
    // Pets: prefer newer version by updatedAt
    final petMap = {for (final p in _pets) p.id: p};
    for (final cp in cloud.pets) {
      final local = petMap[cp.id];
      if (local == null || cp.updatedAt.isAfter(local.updatedAt)) {
        petMap[cp.id] = cp;
        await _local.savePet(cp);
      }
    }
    _pets = petMap.values.toList();

    // Reminders: union by id
    final rMap = {for (final r in _reminders) r.id: r};
    for (final cr in cloud.reminders) {
      if (!rMap.containsKey(cr.id)) {
        rMap[cr.id] = cr;
        await _local.saveReminder(cr);
      }
    }
    _reminders = rMap.values.toList();

    // Quizzes: union
    final qIds = {for (final q in _quizzes) q.id};
    for (final cq in cloud.quizzes) {
      if (!qIds.contains(cq.id)) {
        _quizzes.insert(0, cq);
        await _local.saveQuizResult(cq);
      }
    }

    // Settings: use cloud if newer
    if (cloud.settings != null) {
      final cs = cloud.settings!;
      if (cs.updatedAt.isAfter(_settings.updatedAt)) {
        _settings = cs;
        await _local.saveSettings(_settings);
      }
    }

    // Restore selected pet if cleared
    if (_selectedPet == null && _pets.isNotEmpty) {
      _selectedPet = _pets.first;
    }

    // FIX: refresh logs after merge
    _logs = await _local.fetchLogs();

    notifyListeners();
  }

  // ── Manual sync ───────────────────────────────────────────────────────────

  Future<SyncResult> syncNow() async {
    if (!_auth.isAuthenticated) {
      return SyncResult.failed('Sign in to enable cloud sync.');
    }
    if (!_connectivity.isOnline) {
      return SyncResult.failed('No internet connection.');
    }
    await _backgroundSync();
    return _sync.lastSyncAt != null
        ? SyncResult.success(_sync.lastSyncAt!)
        : SyncResult.failed('Sync failed. Please try again.');
  }

  // ── Guest-to-account upgrade ──────────────────────────────────────────────

  Future<void> mergeGuestDataWithCloud() async {
    await _pushToCloud();
    await _activityLog.logGuestMerged();
    await _backgroundSync();
  }

  Future<void> replaceLocalWithCloud() async {
    final cloud = await _sync.downloadAll();
    if (cloud.isEmpty) return;

    await _local.deleteAllPets();
    await _local.deleteAllReminders();
    await _local.clearLogs();

    for (final p in cloud.pets) await _local.savePet(p);
    for (final r in cloud.reminders) await _local.saveReminder(r);

    final logs = await _local.fetchLogs();
    for (final l in cloud.logs) {
      if (!logs.any((e) => e.id == l.id)) await _local.addLog(l);
    }

    _pets = cloud.pets;
    _reminders = cloud.reminders;
    _selectedPet = _pets.isNotEmpty ? _pets.first : null;
    _logs = await _local.fetchLogs(); // FIX: refresh logs
    await _activityLog.reload();
    notifyListeners();
  }

  // ── Pet CRUD ──────────────────────────────────────────────────────────────

  Future<void> addPet(PetModel pet) async {
    _pets.add(pet);
    if (_selectedPet == null) {
      _selectedPet = pet;
      await _local.setSelectedPetId(pet.id);
    }
    await _local.savePet(pet);
    unawaited(_sync.savePet(pet));
    await _activityLog.logProfileAdded(pet.name);
    _logs = await _local.fetchLogs(); // FIX: keep logs in sync
    notifyListeners();
  }

  Future<void> updatePet(PetModel pet) async {
    final idx = _pets.indexWhere((p) => p.id == pet.id);
    if (idx < 0) return;
    _pets[idx] = pet;
    if (_selectedPet?.id == pet.id) _selectedPet = pet;
    await _local.savePet(pet);
    unawaited(_sync.savePet(pet));
    notifyListeners();
  }

  Future<void> deletePet(String petId) async {
    final name = _pets
        .firstWhere((p) => p.id == petId,
            orElse: () => PetModel(
                id: '',
                name: 'Unknown',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now()))
        .name;
    _pets.removeWhere((p) => p.id == petId);
    if (_selectedPet?.id == petId) {
      _selectedPet = _pets.isNotEmpty ? _pets.first : null;
      if (_selectedPet != null) {
        await _local.setSelectedPetId(_selectedPet!.id);
      } else {
        await _local.clearSelectedPetId();
      }
    }
    await _local.deletePet(petId);
    unawaited(_sync.deletePet(petId));
    await _activityLog.logProfileDeleted(name);
    _logs = await _local.fetchLogs(); // FIX: keep logs in sync
    notifyListeners();
  }

  Future<void> selectPet(PetModel pet) async {
    _selectedPet = pet;
    await _local.setSelectedPetId(pet.id);
    notifyListeners();
  }

  // ── Virtual pet stat mutations ────────────────────────────────────────────

  Future<void> feedPet(String petId, String foodName,
      {required int hungerDelta,
      required int happinessDelta,
      int cleanlinessDelta = 0}) async {
    final pet = _petById(petId);
    if (pet == null) return;
    final updated = pet.copyWith(
      stats: pet.stats.copyWith(
        hunger: pet.stats.hunger + hungerDelta,
        happiness: pet.stats.happiness + happinessDelta,
        cleanliness: pet.stats.cleanliness + cleanlinessDelta,
      ),
      updatedAt: DateTime.now(),
    );
    await updatePet(updated);
    await _activityLog.logFeed(pet.name, foodName);
    _logs = await _local.fetchLogs(); // FIX: keep logs in sync
    notifyListeners();
  }

  Future<void> groomPet(String petId, String toolName,
      {required int cleanlinessDelta, int happinessDelta = 0}) async {
    final pet = _petById(petId);
    if (pet == null) return;
    final updated = pet.copyWith(
      stats: pet.stats.copyWith(
        cleanliness: pet.stats.cleanliness + cleanlinessDelta,
        happiness: pet.stats.happiness + happinessDelta,
      ),
      updatedAt: DateTime.now(),
    );
    await updatePet(updated);
    await _activityLog.logGroom(pet.name, toolName);
    _logs = await _local.fetchLogs(); // FIX: keep logs in sync
    notifyListeners();
  }

  Future<void> playWithPet(String petId, String activity,
      {required int happinessDelta,
      int hungerDelta = 0,
      int energyDelta = 0}) async {
    final pet = _petById(petId);
    if (pet == null) return;
    final updated = pet.copyWith(
      stats: pet.stats.copyWith(
        happiness: pet.stats.happiness + happinessDelta,
        hunger: pet.stats.hunger + hungerDelta,
        energy: pet.stats.energy + energyDelta,
      ),
      updatedAt: DateTime.now(),
    );
    await updatePet(updated);
    await _activityLog.logPlay(pet.name, activity);
    _logs = await _local.fetchLogs(); // FIX: keep logs in sync
    notifyListeners();
  }

  Future<void> tickDecay(String petId) async {
    final pet = _petById(petId);
    if (pet == null) return;
    final updated = pet.copyWith(
      stats: pet.stats.copyWith(
        hunger: pet.stats.hunger + 1,
        happiness: pet.stats.happiness - 1,
        cleanliness: pet.stats.cleanliness - 1,
        energy: pet.stats.energy - 1,
      ),
      updatedAt: DateTime.now(),
    );
    final idx = _pets.indexWhere((p) => p.id == petId);
    if (idx >= 0) _pets[idx] = updated;
    if (_selectedPet?.id == petId) _selectedPet = updated;
    await _local.savePet(updated); // no cloud push for frequent decay ticks
    notifyListeners();
  }

  // ── Reminders CRUD ────────────────────────────────────────────────────────

  Future<void> addReminder(ReminderModel reminder) async {
    _reminders.add(reminder);
    await _local.saveReminder(reminder);
    unawaited(_sync.saveReminder(reminder));
    await _activityLog.logReminderAdded(reminder.title, reminder.type);
    _logs = await _local.fetchLogs(); // FIX: keep logs in sync
    notifyListeners();
  }

  Future<void> updateReminder(ReminderModel reminder) async {
    final idx = _reminders.indexWhere((r) => r.id == reminder.id);
    if (idx < 0) return;
    _reminders[idx] = reminder;
    await _local.saveReminder(reminder);
    unawaited(_sync.saveReminder(reminder));
    await _activityLog.logReminderEdited(reminder.title);
    _logs = await _local.fetchLogs(); // FIX: keep logs in sync
    notifyListeners();
  }

  Future<void> toggleReminder(String id) async {
    final idx = _reminders.indexWhere((r) => r.id == id);
    if (idx < 0) return;
    final updated =
        _reminders[idx].copyWith(isCompleted: !_reminders[idx].isCompleted);
    _reminders[idx] = updated;
    await _local.saveReminder(updated);
    unawaited(_sync.saveReminder(updated));
    if (updated.isCompleted) {
      await _activityLog.logReminderCompleted(updated.title);
      _logs = await _local.fetchLogs(); // FIX: keep logs in sync
    }
    notifyListeners();
  }

  Future<void> deleteReminder(String id) async {
    final title = _reminders
        .firstWhere((r) => r.id == id, orElse: () => _reminders.first)
        .title;
    _reminders.removeWhere((r) => r.id == id);
    await _local.deleteReminder(id);
    unawaited(_sync.deleteReminder(id));
    await _activityLog.logReminderDeleted(title);
    _logs = await _local.fetchLogs(); // FIX: keep logs in sync
    notifyListeners();
  }

  // ── Quiz ──────────────────────────────────────────────────────────────────

  Future<void> saveQuizResult(int score, int total) async {
    final result = QuizResult(
      id: _uuid.v4(),
      score: score,
      total: total,
      completedAt: DateTime.now(),
    );
    _quizzes.insert(0, result);
    await _local.saveQuizResult(result);
    unawaited(_sync.saveQuizResult(result));
    await _activityLog.logQuiz(score, total);
    _logs = await _local.fetchLogs(); // FIX: keep logs in sync
    notifyListeners();
  }

  // ── Settings ──────────────────────────────────────────────────────────────

  Future<void> updateSettings(AppSettings s) async {
    _settings = s;
    await _local.saveSettings(s);
    unawaited(_sync.saveSettings(s));
    notifyListeners();
  }

  // ── Data management ───────────────────────────────────────────────────────

  Future<void> clearAllLocalData() async {
    await _local.clearAll();
    await _activityLog.clearAll();
    _pets.clear();
    _reminders.clear();
    _quizzes.clear();
    _logs.clear(); // FIX: also clear the in-memory logs list
    _selectedPet = null;
    notifyListeners();
  }

  /// Alias used by SettingsScreen.
  Future<void> clearLocalData() => clearAllLocalData();

  Future<Map<String, dynamic>> exportLocalData() => _local.exportAll();

  Future<void> importLocalData(Map<String, dynamic> data) async {
    await _local.importAll(data);
    await _reload();
  }

  Future<void> _reload() async {
    _pets = await _local.fetchPets();
    _reminders = await _local.fetchReminders();
    _settings = await _local.fetchSettings();
    _quizzes = await _local.fetchQuizResults();
    _logs = await _local.fetchLogs(); // FIX: reload logs too
    await _activityLog.reload();
    _selectedPet = _pets.isNotEmpty ? _pets.first : null;
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  PetModel? _petById(String id) {
    try {
      return _pets.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  String generateId() => _uuid.v4();
}
