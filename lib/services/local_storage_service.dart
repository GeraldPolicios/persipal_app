// lib/services/local_storage_service.dart
//
// Hive-backed offline-first primary data store.
// ALL app data is written here first — Firestore is only a backup.
// Uses String boxes with JSON serialisation (no generated adapters needed).

import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';

class LocalStorageService {
  LocalStorageService._();
  static final LocalStorageService instance = LocalStorageService._();

  // Box names
  static const _bPets = 'ls_pets';
  static const _bLogs = 'ls_logs';
  static const _bReminders = 'ls_reminders';
  static const _bSettings = 'ls_settings';
  static const _bQuizzes = 'ls_quizzes';
  static const _bPending = 'ls_pending_sync'; // ops queued while offline

  bool _ready = false;
  bool get isReady => _ready;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox<String>(_bPets),
      Hive.openBox<String>(_bLogs),
      Hive.openBox<String>(_bReminders),
      Hive.openBox<String>(_bSettings),
      Hive.openBox<String>(_bQuizzes),
      Hive.openBox<String>(_bPending),
    ]);
    _ready = true;
  }

  // ── Box accessors ─────────────────────────────────────────────────────────

  Box<String> get _pets => Hive.box<String>(_bPets);
  Box<String> get _logs => Hive.box<String>(_bLogs);
  Box<String> get _reminders => Hive.box<String>(_bReminders);
  Box<String> get _settings => Hive.box<String>(_bSettings);
  Box<String> get _quizzes => Hive.box<String>(_bQuizzes);
  Box<String> get _pending => Hive.box<String>(_bPending);

  Map<String, dynamic> _dec(String raw) =>
      jsonDecode(raw) as Map<String, dynamic>;

  // ── Pets ──────────────────────────────────────────────────────────────────

  Future<List<PetModel>> fetchPets() async =>
      _pets.values.map((r) => PetModel.fromMap(_dec(r))).toList();

  Future<void> savePet(PetModel pet) async =>
      _pets.put(pet.id, jsonEncode(pet.toMap()));

  Future<void> deletePet(String id) async => _pets.delete(id);

  Future<void> deleteAllPets() async => _pets.clear();

  // ── Activity Logs ─────────────────────────────────────────────────────────

  Future<List<ActivityLogModel>> fetchLogs() async {
    final all = _logs.values
        .map((r) => ActivityLogModel.fromMap(_dec(r)))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return all.take(500).toList();
  }

  Future<void> addLog(ActivityLogModel log) async {
    await _logs.put(log.id, jsonEncode(log.toMap()));
    // Prune if over 500
    if (_logs.length > 500) {
      final keys = _logs.keys.toList();
      await _logs.delete(keys.first);
    }
  }

  Future<void> clearLogs() async => _logs.clear();

  // ── Reminders ─────────────────────────────────────────────────────────────

  Future<List<ReminderModel>> fetchReminders() async =>
      _reminders.values.map((r) => ReminderModel.fromMap(_dec(r))).toList();

  Future<void> saveReminder(ReminderModel r) async =>
      _reminders.put(r.id, jsonEncode(r.toMap()));

  Future<void> deleteReminder(String id) async => _reminders.delete(id);

  Future<void> deleteAllReminders() async => _reminders.clear();

  // ── Settings ──────────────────────────────────────────────────────────────

  Future<AppSettings> fetchSettings() async {
    final raw = _settings.get('app_settings');
    if (raw == null) return const AppSettings();
    return AppSettings.fromMap(_dec(raw));
  }

  Future<void> saveSettings(AppSettings s) async =>
      _settings.put('app_settings', jsonEncode(s.toMap()));

  Future<String?> getSelectedPetId() async => _settings.get('selected_pet_id');

  Future<void> setSelectedPetId(String id) async =>
      _settings.put('selected_pet_id', id);

  Future<void> clearSelectedPetId() async =>
      _settings.delete('selected_pet_id');

  // ── Quiz Results ──────────────────────────────────────────────────────────

  Future<List<QuizResult>> fetchQuizResults() async =>
      _quizzes.values.map((r) => QuizResult.fromMap(_dec(r))).toList();

  Future<void> saveQuizResult(QuizResult r) async =>
      _quizzes.put(r.id, jsonEncode(r.toMap()));

  // ── Pending sync ops ──────────────────────────────────────────────────────
  // We store simple string tokens like "pet:id", "reminder:id", "log:id"
  // so that the sync service knows what to push on next online.

  Future<void> queuePendingOp(String token) async => _pending.put(token, token);

  Future<List<String>> fetchPendingOps() async => _pending.values.toList();

  Future<void> clearPendingOps() async => _pending.clear();

  Future<void> removePendingOp(String token) async => _pending.delete(token);

  // ── Bulk export / import ──────────────────────────────────────────────────

  Future<Map<String, dynamic>> exportAll() async => {
        'pets': _pets.values.map(_dec).toList(),
        'logs': _logs.values.map(_dec).toList(),
        'reminders': _reminders.values.map(_dec).toList(),
        'settings': _settings.toMap(),
        'quizzes': _quizzes.values.map(_dec).toList(),
        'exportedAt': DateTime.now().toIso8601String(),
      };

  Future<void> importAll(Map<String, dynamic> data) async {
    if (data['pets'] is List) {
      await _pets.clear();
      for (final raw in data['pets'] as List) {
        final pet = PetModel.fromMap(raw as Map<String, dynamic>);
        await _pets.put(pet.id, jsonEncode(pet.toMap()));
      }
    }
    if (data['logs'] is List) {
      await _logs.clear();
      for (final raw in data['logs'] as List) {
        final log = ActivityLogModel.fromMap(raw as Map<String, dynamic>);
        await _logs.put(log.id, jsonEncode(log.toMap()));
      }
    }
    if (data['reminders'] is List) {
      await _reminders.clear();
      for (final raw in data['reminders'] as List) {
        final r = ReminderModel.fromMap(raw as Map<String, dynamic>);
        await _reminders.put(r.id, jsonEncode(r.toMap()));
      }
    }
    if (data['quizzes'] is List) {
      await _quizzes.clear();
      for (final raw in data['quizzes'] as List) {
        final q = QuizResult.fromMap(raw as Map<String, dynamic>);
        await _quizzes.put(q.id, jsonEncode(q.toMap()));
      }
    }
  }

  // ── Nuclear option ────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    await Future.wait([
      _pets.clear(),
      _logs.clear(),
      _reminders.clear(),
      _settings.clear(),
      _quizzes.clear(),
      _pending.clear(),
    ]);
  }
}
