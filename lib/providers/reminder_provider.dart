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
import '../services/notification_service.dart';

class ReminderProvider extends ChangeNotifier {
  final _local = LocalStorageService.instance;
  final _notifications = NotificationService.instance;

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

    // Reconcile notifications for whatever was just loaded from disk:
    // reschedule anything still pending/future (scheduling with the same
    // notification ID simply replaces any existing one, so this is safe to
    // repeat every launch), and cancel anything done or already in the past
    // so a stale notification can't fire after the fact.
    for (final r in _reminders) {
      await _syncNotification(r);
    }

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
    await _syncNotification(reminder);
  }

  Future<void> updateReminder(ReminderItem updated) async {
    final idx = _reminders.indexWhere((r) => r.id == updated.id);
    if (idx == -1) return;
    _reminders[idx] = updated;
    notifyListeners();
    await _local.saveReminderItem(updated);
    // Scheduling again under the same notification ID replaces whatever was
    // previously scheduled for this reminder — this covers "cancel the old
    // notification and schedule the updated one" in a single call.
    await _syncNotification(updated);
  }

  Future<void> deleteReminder(String id) async {
    _reminders.removeWhere((r) => r.id == id);
    notifyListeners();
    await _local.deleteReminderItem(id);
    await _cancelNotification(id);
  }

  Future<void> markReminderDone(String id) async {
    final idx = _reminders.indexWhere((r) => r.id == id);
    if (idx == -1) return;
    final updated = _reminders[idx].copyWith(isDone: true);
    _reminders[idx] = updated;
    notifyListeners();
    await _local.saveReminderItem(updated);
    // isDone is now true, so _syncNotification's own check cancels it —
    // same code path used for the restart-reconciliation loop in init().
    await _syncNotification(updated);
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
    await addReminder(next); // addReminder already schedules its notification
  }

  // ── Notification sync (private — screens never touch NotificationService
  //    directly; this keeps them unaware of notification mechanics) ─────────

  /// Schedules (or cancels, if done/past) the notification for one reminder.
  /// Safe to call repeatedly — scheduling under the same ID just replaces
  /// whatever was previously scheduled.
  Future<void> _syncNotification(ReminderItem r) async {
    final id = NotificationService.careNotifId(r.id);
    if (r.isDone || r.scheduledAt.isBefore(DateTime.now())) {
      await _notifications.cancelCareReminder(id);
      return;
    }
    await _notifications.scheduleCareReminder(
      notificationId: id,
      title: r.title,
      body: _bodyFor(r),
      scheduledDate: r.scheduledAt,
      payload: 'care:${r.id}',
    );
  }

  Future<void> _cancelNotification(String reminderId) async {
    await _notifications
        .cancelCareReminder(NotificationService.careNotifId(reminderId));
  }

  String _bodyFor(ReminderItem r) =>
      r.type.isNotEmpty ? '${r.type} reminder' : 'Reminder';

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
