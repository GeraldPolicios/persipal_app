import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';
import '../models/virtual_pet_state.dart';
import '../models/reminder_item_model.dart';
import 'activity_service.dart' show ActivityEntry;

class LocalStorageService {
  LocalStorageService._();
  static final LocalStorageService instance = LocalStorageService._();

  // Box names
  // Box names
  static const _bPets = 'ls_pets';
  static const _bLogs = 'ls_logs';
  static const _bReminders = 'ls_reminders';
  static const _bReminderItems =
      'ls_reminder_items'; // ReminderItem (new system)
  static const _bSettings = 'ls_settings';
  static const _bQuizzes = 'ls_quizzes';
  static const _bPending = 'ls_pending_sync'; // ops queued while offline
  static const _bVirtualPet = 'ls_virtual_pet'; // single-record: virtual pet
  static const _bActivityEntries =
      'ls_activity_entries'; // ActivityService's real activity feed
  static const _bVirtualAchievements =
      'ls_virtual_achievements'; // single-record: virtual-cat achievements
  static const _bPetPhotos =
      'ls_pet_photos'; // single-record: petId -> local photo file path

  static const _bDailyAdvice =
      'ls_daily_advice'; // public online advice cache — not account data

  static const _kVirtualPetKey = 'virtual_pet_state';
  static const _kVirtualAchievementsKey = 'virtual_achievement_state';
  static const _kPetPhotosKey = 'pet_photo_paths';
  static const _kPetCoverPhotosKey = 'pet_cover_photo_paths';

  bool _ready = false;
  bool get isReady => _ready;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox<String>(_bPets),
      Hive.openBox<String>(_bLogs),
      Hive.openBox<String>(_bReminders),
      Hive.openBox<String>(_bReminderItems),
      Hive.openBox<String>(_bSettings),
      Hive.openBox<String>(_bQuizzes),
      Hive.openBox<String>(_bPending),
      Hive.openBox<String>(_bVirtualPet),
      Hive.openBox<String>(_bActivityEntries),
      Hive.openBox<String>(_bVirtualAchievements),
      Hive.openBox<String>(_bPetPhotos),
      Hive.openBox<String>(_bDailyAdvice),
    ]);
    _ready = true;
  }

  // ── Box accessors ─────────────────────────────────────────────────────────

  Box<String> get _pets => Hive.box<String>(_bPets);
  Box<String> get _logs => Hive.box<String>(_bLogs);
  Box<String> get _reminders => Hive.box<String>(_bReminders);
  Box<String> get _reminderItems => Hive.box<String>(_bReminderItems);
  Box<String> get _settings => Hive.box<String>(_bSettings);
  Box<String> get _quizzes => Hive.box<String>(_bQuizzes);
  Box<String> get _pending => Hive.box<String>(_bPending);
  Box<String> get _virtualPet => Hive.box<String>(_bVirtualPet);
  Box<String> get _activityEntries => Hive.box<String>(_bActivityEntries);
  Box<String> get _virtualAchievements =>
      Hive.box<String>(_bVirtualAchievements);
  Box<String> get _petPhotos => Hive.box<String>(_bPetPhotos);
  Box<String> get _dailyAdvice => Hive.box<String>(_bDailyAdvice);

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
    // Prune the OLDEST entry if over 500. (Hive orders keys alphabetically,
    // not by insertion, so keys.first would delete an arbitrary record.)
    if (_logs.length > 500) {
      dynamic oldestKey;
      DateTime? oldestAt;
      for (final key in _logs.keys) {
        final at = ActivityLogModel.fromMap(_dec(_logs.get(key)!)).timestamp;
        if (oldestAt == null || at.isBefore(oldestAt)) {
          oldestAt = at;
          oldestKey = key;
        }
      }
      if (oldestKey != null) await _logs.delete(oldestKey);
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

  // ── Reminder Items (real pets) ──────────────────────────────────────────
  // NEW: persists the richer ReminderItem shape (petId, linkedVaccinationId,
  // recurrence) that the Reminder/Vaccination screens actually use. Uses its
  // OWN dedicated box (ls_reminder_items) — kept separate from ls_reminders
  // above (the old ReminderModel path) so AppProvider's unrelated reminder
  // loading can never misparse this data.

  Future<List<ReminderItem>> fetchReminderItems() async =>
      _reminderItems.values.map((r) => ReminderItem.fromMap(_dec(r))).toList();

  Future<void> saveReminderItem(ReminderItem item) async =>
      _reminderItems.put(item.id, jsonEncode(item.toMap()));

  Future<void> deleteReminderItem(String id) async => _reminderItems.delete(id);

  Future<void> clearReminderItems() async => _reminderItems.clear();

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

  // ── Lesson progress ───────────────────────────────────────────────────────
  // Which Learn Cat Care topics ('feeding'|'grooming'|...) the user has
  // actually completed. Reuses the existing settings box/pattern (same
  // shape as selected_pet_id above) rather than a new Hive box — this is
  // the smallest persistence addition the existing architecture needs.

  Future<List<String>> fetchCompletedLessonTypes() async {
    final raw = _settings.get('completed_lesson_types');
    if (raw == null) return const [];
    return (jsonDecode(raw) as List<dynamic>).cast<String>();
  }

  Future<void> saveCompletedLessonTypes(Set<String> types) async =>
      _settings.put('completed_lesson_types', jsonEncode(types.toList()));

  // ── Reward points / claims ────────────────────────────────────────────────
  // One JSON blob in the settings box (same pattern as lesson progress) —
  // wiped by clearAll(), so it follows the account-isolation rules.

  String? fetchRewardState() => _settings.get('reward_state');

  Future<void> saveRewardState(String json) =>
      _settings.put('reward_state', json);

  // ── Quiz Results ──────────────────────────────────────────────────────────

  Future<List<QuizResult>> fetchQuizResults() async =>
      _quizzes.values.map((r) => QuizResult.fromMap(_dec(r))).toList();

  Future<void> saveQuizResult(QuizResult r) async =>
      _quizzes.put(r.id, jsonEncode(r.toMap()));

  // ── Virtual Pet (single record — NOT a real pet profile) ───────────────────
  // Deliberately separate from the pets/full_pet_profiles storage: there is
  // exactly one virtual pet, stored under one fixed key, never keyed by id.

  Future<VirtualPetState?> fetchVirtualPet() async {
    final raw = _virtualPet.get(_kVirtualPetKey);
    if (raw == null) return null;
    return VirtualPetState.fromMap(_dec(raw));
  }

  Future<void> saveVirtualPet(VirtualPetState pet) async =>
      _virtualPet.put(_kVirtualPetKey, jsonEncode(pet.toMap()));

  // ── Virtual Achievements (single record — mirrors the virtual pet) ─────────
  // Device-local only, exactly like the virtual pet itself: not cloud-synced
  // and not cleared on sign-out/account deletion (see AchievementService's
  // header comment for the reasoning).

  Future<Map<String, dynamic>?> fetchVirtualAchievementState() async {
    final raw = _virtualAchievements.get(_kVirtualAchievementsKey);
    if (raw == null) return null;
    return _dec(raw);
  }

  Future<void> saveVirtualAchievementState(Map<String, dynamic> state) async =>
      _virtualAchievements.put(_kVirtualAchievementsKey, jsonEncode(state));

  // ── Pet Photos (device-local only — never uploaded to Firestore) ───────────
  // A raw file path is meaningless on another device, and the existing
  // FullPetProfile/Firestore sync model has no support for binary blobs, so
  // this is kept entirely separate from full_pet_profiles. See
  // PetPhotoService's header comment for the full reasoning.

  Future<Map<String, String>> fetchPetPhotoPaths() async {
    final raw = _petPhotos.get(_kPetPhotosKey);
    if (raw == null) return {};
    return Map<String, String>.from(_dec(raw));
  }

  Future<void> savePetPhotoPaths(Map<String, String> paths) async =>
      _petPhotos.put(_kPetPhotosKey, jsonEncode(paths));

  // ── Pet cover/background photos (device-local, same box/pattern as the
  // profile photo above — a separate key, not a new Hive box). ────────────

  Future<Map<String, String>> fetchPetCoverPhotoPaths() async {
    final raw = _petPhotos.get(_kPetCoverPhotosKey);
    if (raw == null) return {};
    return Map<String, String>.from(_dec(raw));
  }

  Future<void> savePetCoverPhotoPaths(Map<String, String> paths) async =>
      _petPhotos.put(_kPetCoverPhotosKey, jsonEncode(paths));

  // ── Daily advice cache ────────────────────────────────────────────────────
  // The last successfully downloaded public advice feed (see
  // DailyAdviceService). It holds no user data, so — like the photo box it is
  // deliberately NOT part of clearAll()/sign-out.

  String? fetchDailyAdviceCache() => _dailyAdvice.get('cache');

  Future<void> saveDailyAdviceCache(String json) =>
      _dailyAdvice.put('cache', json);

  // ── Activity Entries (ActivityService's real activity feed) ────────────────
  // This is the actual, user-facing activity log (feeding, grooming, playing,
  // lessons, quizzes, reminders, profile changes, etc.) — distinct from the
  // ls_logs/ActivityLogModel box above, which is a separate, mostly-internal
  // log used only by a few AppProvider operations.

  Future<List<ActivityEntry>> fetchActivityEntries() async {
    final all = _activityEntries.values
        .map((r) => ActivityEntry.fromMap(_dec(r)))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return all.take(500).toList();
  }

  Future<void> saveActivityEntry(ActivityEntry entry) async {
    await _activityEntries.put(entry.id, jsonEncode(entry.toMap()));
    if (_activityEntries.length > 500) {
      final keys = _activityEntries.keys.toList();
      await _activityEntries.delete(keys.first);
    }
  }

  Future<void> clearActivityEntries() async => _activityEntries.clear();

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
      _reminderItems.clear(),
      _settings.clear(),
      _quizzes.clear(),
      _pending.clear(),
      _virtualPet.clear(),
      _virtualAchievements.clear(),
      _activityEntries.clear(),
      _petPhotos.clear(),
    ]);
  }
}
