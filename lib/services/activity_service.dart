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

import 'package:flutter/material.dart';

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
}

// ─── Reminder Model ──────────────────────────────────────────────────────────

class ReminderItem {
  String id;
  String title;
  String type;
  DateTime scheduledAt;
  bool isDone;

  ReminderItem({
    required this.id,
    required this.title,
    required this.type,
    required this.scheduledAt,
    this.isDone = false,
  });
}

// ─── Pet Profile Model ───────────────────────────────────────────────────────

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

  // ── Data stores ──────────────────────────────────────────────────────────
  final List<ActivityEntry> _log = [];
  final List<ReminderItem> _reminders = [];
  final List<PetProfile> _profiles = [];

  List<ActivityEntry> get log => List.unmodifiable(_log);
  List<ReminderItem> get reminders => List.unmodifiable(_reminders);
  List<PetProfile> get profiles => List.unmodifiable(_profiles);

  // ── Activity Log ─────────────────────────────────────────────────────────

  void logActivity({
    required IconData icon,
    required Color iconColor,
    required String title,
  }) {
    _log.insert(
      0,
      ActivityEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        icon: icon,
        iconColor: iconColor,
        title: title,
        timestamp: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  void clearLog() {
    _log.clear();
    notifyListeners();
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

  // ── Pet Profiles ──────────────────────────────────────────────────────────

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
