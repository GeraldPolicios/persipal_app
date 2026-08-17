// services/activity_service.dart
//
// Singleton service that acts as the single source of truth for:
//   • Activity log entries (real, not hardcoded)
//   • Pet profiles (persisted in-memory across navigations)
//   • Reminders (persisted in-memory across navigations)
//
// In a production app you would swap the in-memory lists for
// shared_preferences / sqflite / hive calls.  The public API is
// identical regardless of the backing store, so the migration is
// a one-file change.
//
// WHAT'S NEW:
//   • ReminderItem now carries petId (which cat it's for), linkedVaccinationId
//     (set when it was auto-created from a vaccine's "next dose"), and
//     recurrence ('none' | 'daily' | 'weekly' | 'monthly').
//   • ReminderItem.copyWith() — uses a sentinel so petId/linkedVaccinationId
//     can be explicitly cleared (copyWith(petId: null)), not just skipped.
//   • remindersForPet() and scheduleNextOccurrence() helpers.

import 'package:flutter/material.dart';
import 'local_storage_service.dart';

const Object _unset = Object();

// ─── Activity Entry ──────────────────────────────────────────────────────────

class ActivityEntry {
  final String id;
  final IconData icon;
  final Color iconColor;
  final String title;
  final DateTime timestamp;

  ActivityEntry({
    required this.id,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'iconCodePoint': icon.codePoint,
        'iconFontFamily': icon.fontFamily,
        'iconFontPackage': icon.fontPackage,
        'colorValue': iconColor.value,
        'title': title,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ActivityEntry.fromMap(Map<String, dynamic> m) => ActivityEntry(
        id: m['id'] as String,
        icon: IconData(
          m['iconCodePoint'] as int,
          fontFamily: m['iconFontFamily'] as String?,
          fontPackage: m['iconFontPackage'] as String?,
        ),
        iconColor: Color(m['colorValue'] as int),
        title: m['title'] as String? ?? '',
        timestamp: DateTime.tryParse(m['timestamp'] as String? ?? '') ??
            DateTime.now(),
      );
}

// ─── Reminder Model ──────────────────────────────────────────────────────────

class ReminderItem {
  String id;
  String title;
  String type;
  DateTime scheduledAt;
  bool isDone;
  String? petId; // NEW — which cat this reminder belongs to
  String? linkedVaccinationId; // NEW — set if auto-created from a vaccine dose
  String recurrence; // NEW — 'none' | 'daily' | 'weekly' | 'monthly'

  ReminderItem({
    required this.id,
    required this.title,
    required this.type,
    required this.scheduledAt,
    this.isDone = false,
    this.petId,
    this.linkedVaccinationId,
    this.recurrence = 'none',
  });

  /// Returns a new ReminderItem with the given fields replaced.
  /// Pass `petId: null` / `linkedVaccinationId: null` explicitly to CLEAR
  /// those fields (they use a sentinel default so "not passed" != "null").
  ReminderItem copyWith({
    String? title,
    String? type,
    DateTime? scheduledAt,
    bool? isDone,
    Object? petId = _unset,
    Object? linkedVaccinationId = _unset,
    String? recurrence,
  }) =>
      ReminderItem(
        id: id,
        title: title ?? this.title,
        type: type ?? this.type,
        scheduledAt: scheduledAt ?? this.scheduledAt,
        isDone: isDone ?? this.isDone,
        petId: identical(petId, _unset) ? this.petId : petId as String?,
        linkedVaccinationId: identical(linkedVaccinationId, _unset)
            ? this.linkedVaccinationId
            : linkedVaccinationId as String?,
        recurrence: recurrence ?? this.recurrence,
      );
}

// ─── Pet Profile Model ───────────────────────────────────────────────────────
// (Legacy/simple profile model used elsewhere in the app — unrelated to
// FullPetProfile in pet_extended_models.dart, left untouched.)

class PetProfile {
  String id;
  String name;
  String age;
  String gender;
  String weight;
  String furColor;
  String notes;
  Color avatarColor;

  PetProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.weight,
    required this.furColor,
    required this.notes,
    required this.avatarColor,
  });
}

// ─── Singleton Service ───────────────────────────────────────────────────────

class ActivityService extends ChangeNotifier {
  // Private constructor for singleton
  ActivityService._();
  static final ActivityService instance = ActivityService._();

  final _local = LocalStorageService.instance;

  // ── Data stores ──────────────────────────────────────────────────────────
  final List<ActivityEntry> _log = [];
  final List<ReminderItem> _reminders = [];
  final List<PetProfile> _profiles = [];

  bool _loading = true;
  bool get loading => _loading;

  List<ActivityEntry> get log => List.unmodifiable(_log);
  List<ReminderItem> get reminders => List.unmodifiable(_reminders);
  List<PetProfile> get profiles => List.unmodifiable(_profiles);

  /// Loads persisted activity entries from Hive. Call once at app startup,
  /// before the first screen that reads `.log` builds — same pattern as the
  /// app's other providers (VirtualPetProvider, ReminderProvider, etc.).
  Future<void> init() async {
    final loaded = await _local.fetchActivityEntries();
    _log
      ..clear()
      ..addAll(loaded);
    _loading = false;
    notifyListeners();
  }

  // ── Activity Log ─────────────────────────────────────────────────────────

  void logActivity({
    required IconData icon,
    required Color iconColor,
    required String title,
  }) {
    final entry = ActivityEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      icon: icon,
      iconColor: iconColor,
      title: title,
      timestamp: DateTime.now(),
    );
    _log.insert(0, entry);
    notifyListeners();
    _local.saveActivityEntry(entry);
  }

  void clearLog() {
    _log.clear();
    notifyListeners();
    _local.clearActivityEntries();
  }

  // ── Reminders ─────────────────────────────────────────────────────────────

  void addReminder(ReminderItem reminder) {
    _reminders.add(reminder);
    logActivity(
      icon: Icons.alarm_add,
      iconColor: const Color(0xFFFFA500),
      title: 'Added reminder — ${reminder.title} (${reminder.type})',
    );
    notifyListeners();
  }

  void markReminderDone(String id) {
    final idx = _reminders.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    _reminders[idx].isDone = true;
    logActivity(
      icon: Icons.alarm_on,
      iconColor: const Color(0xFF32CD32),
      title: 'Completed reminder — ${_reminders[idx].title}',
    );
    notifyListeners();
  }

  void deleteReminder(String id) {
    final idx = _reminders.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    final title = _reminders[idx].title;
    _reminders.removeAt(idx);
    logActivity(
      icon: Icons.alarm_off,
      iconColor: Colors.redAccent,
      title: 'Deleted reminder — $title',
    );
    notifyListeners();
  }

  void updateReminder(ReminderItem updated) {
    final idx = _reminders.indexWhere((r) => r.id == updated.id);
    if (idx == -1) return;
    _reminders[idx] = updated;
    logActivity(
      icon: Icons.edit_notifications,
      iconColor: const Color(0xFFFFA500),
      title: 'Edited reminder — ${updated.title}',
    );
    notifyListeners();
  }

  /// NEW — reminders for one cat, or all reminders if petId is null.
  List<ReminderItem> remindersForPet(String? petId) {
    if (petId == null) return reminders;
    return _reminders.where((r) => r.petId == petId).toList();
  }

  /// NEW — call right after markReminderDone() for a recurring reminder
  /// (daily/weekly/monthly feeding, grooming, litter, etc.) to automatically
  /// schedule the next occurrence.
  void scheduleNextOccurrence(ReminderItem completed) {
    if (completed.recurrence == 'none') return;
    addReminder(ReminderItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: completed.title,
      type: completed.type,
      scheduledAt: _nextDate(completed.scheduledAt, completed.recurrence),
      petId: completed.petId,
      recurrence: completed.recurrence,
    ));
  }

  DateTime _nextDate(DateTime from, String recurrence) {
    switch (recurrence) {
      case 'daily':
        return from.add(const Duration(days: 1));
      case 'weekly':
        return from.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(
            from.year, from.month + 1, from.day, from.hour, from.minute);
      default:
        return from;
    }
  }

  // ── Pet Profiles (legacy, unrelated to FullPetProfile) ────────────────────

  void addProfile(PetProfile profile) {
    _profiles.add(profile);
    logActivity(
      icon: Icons.pets,
      iconColor: const Color(0xFF32CD32),
      title: 'Added profile — ${profile.name}',
    );
    notifyListeners();
  }

  void updateProfile(PetProfile updated) {
    final idx = _profiles.indexWhere((p) => p.id == updated.id);
    if (idx == -1) return;
    _profiles[idx] = updated;
    logActivity(
      icon: Icons.edit,
      iconColor: const Color(0xFF4682B4),
      title: "Edited profile — ${updated.name}'s details updated",
    );
    notifyListeners();
  }

  void deleteProfile(String id) {
    final idx = _profiles.indexWhere((p) => p.id == id);
    if (idx == -1) return;
    final name = _profiles[idx].name;
    _profiles.removeAt(idx);
    logActivity(
      icon: Icons.delete_outline,
      iconColor: Colors.redAccent,
      title: 'Deleted profile — $name',
    );
    notifyListeners();
  }
}
