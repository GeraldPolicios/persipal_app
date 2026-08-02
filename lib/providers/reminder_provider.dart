// lib/providers/reminder_provider.dart
//
// Owns REAL-PET reminders (feeding, grooming, vet visits, vaccinations,
// litter, etc.) — persisted through LocalStorageService.
//
// ── INDEPENDENCE RULE ───────────────────────────────────────────────────────
// This provider is part of the REAL pet system. It must never be used by
// GameScreen / FeedScreen / GroomScreen / PlayScreen — the Virtual Pet has
// no reminders.
// ─────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../models/reminder_item_model.dart';
import '../services/local_storage_service.dart';

class ReminderProvider extends ChangeNotifier {
  final _local = LocalStorageService.instance;

  final List<ReminderItem> _reminders = [];
  bool _loading = true;

  bool get loading => _loading;
  List<ReminderItem> get reminders => List.unmodifiable(_reminders);

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    _loading = true;
    notifyListeners();

    final loaded = await _local.fetchReminderItems();
    _reminders
      ..clear()
      ..addAll(loaded);

    _loading = false;
    notifyListeners();
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  /// Reminders for one real pet, or all reminders if [petId] is null.
  List<ReminderItem> remindersForPet(String? petId) {
    if (petId == null) return reminders;
    return _reminders.where((r) => r.petId == petId).toList();
  }

  ReminderItem? getById(String id) {
    for (final r in _reminders) {
      if (r.id == id) return r;
    }
    return null;
  }

  // ── Mutations ─────────────────────────────────────────────────────────────

  Future<void> addReminder(ReminderItem reminder) async {
    _reminders.add(reminder);
    notifyListeners();
    await _local.saveReminderItem(reminder);
  }

  Future<void> updateReminder(ReminderItem updated) async {
    final idx = _reminders.indexWhere((r) => r.id == updated.id);
    if (idx == -1) return;
    _reminders[idx] = updated;
    notifyListeners();
    await _local.saveReminderItem(updated);
  }

  Future<void> deleteReminder(String id) async {
    _reminders.removeWhere((r) => r.id == id);
    notifyListeners();
    await _local.deleteReminderItem(id);
  }

  Future<void> markReminderDone(String id) async {
    final idx = _reminders.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    final updated = _reminders[idx].copyWith(isDone: true);
    _reminders[idx] = updated;
    notifyListeners();
    await _local.saveReminderItem(updated);
  }

  /// Call after markReminderDone() for a recurring reminder (daily/weekly/
  /// monthly feeding, grooming, litter, etc.) to automatically schedule the
  /// next occurrence.
  Future<void> scheduleNextOccurrence(ReminderItem completed) async {
    if (completed.recurrence == 'none') return;
    final next = ReminderItem(
      id: _newId(),
      title: completed.title,
      type: completed.type,
      scheduledAt: _nextDate(completed.scheduledAt, completed.recurrence),
      petId: completed.petId,
      recurrence: completed.recurrence,
    );
    await addReminder(next);
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

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();
}
