// lib/providers/reminder_provider.dart
//
// Owns REAL-PET care reminders.
//
// IMPORTANT:
// This provider is ONLY for the real pet care/reminder system.
// Virtual Pet gameplay does not use this provider.
//
// Responsibilities:
//   • CRUD reminders
//   • Hive/local persistence through LocalStorageService
//   • Notification scheduling/cancellation
//   • Recurring reminder occurrences
//   • Vaccination-linked reminders
//
// The screens should NOT call NotificationService directly.

import 'package:flutter/foundation.dart';

import '../models/reminder_item_model.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';

class ReminderProvider extends ChangeNotifier {
  ReminderProvider();

  final LocalStorageService _local = LocalStorageService.instance;
  final NotificationService _notifications =
      NotificationService.instance;

  final List<ReminderItem> _reminders = [];

  bool _loading = false;

  // ─────────────────────────────────────────────────────────────────────────
  // Getters
  // ─────────────────────────────────────────────────────────────────────────

  bool get loading => _loading;

  List<ReminderItem> get reminders =>
      List.unmodifiable(_reminders);

  List<ReminderItem> get pendingReminders =>
      _reminders.where((r) => !r.isDone).toList();

  List<ReminderItem> get completedReminders =>
      _reminders.where((r) => r.isDone).toList();

  // ─────────────────────────────────────────────────────────────────────────
  // Initialization
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_loading) return;

    _loading = true;
    notifyListeners();

    try {
      final loaded = await _local.fetchReminderItems();

      _reminders
        ..clear()
        ..addAll(loaded);

      // Reconcile all stored reminders with notifications.
      //
      // Future + pending:
      //     schedule notification
      //
      // Done/past:
      //     cancel notification
      //
      // This is safe to execute every time the app starts.
      for (final reminder in List<ReminderItem>.from(_reminders)) {
        await _syncNotification(reminder);
      }
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Queries
  // ─────────────────────────────────────────────────────────────────────────

  List<ReminderItem> remindersForPet(String? petId) {
    if (petId == null || petId.isEmpty) {
      return List.unmodifiable(_reminders);
    }

    return _reminders
        .where((r) => r.petId == petId)
        .toList(growable: false);
  }

  ReminderItem? getById(String id) {
    for (final reminder in _reminders) {
      if (reminder.id == id) {
        return reminder;
      }
    }

    return null;
  }

  List<ReminderItem> remindersForVaccination(
    String vaccinationId,
  ) {
    return _reminders
        .where(
          (r) => r.linkedVaccinationId == vaccinationId,
        )
        .toList(growable: false);
  }

  ReminderItem? reminderForVaccination(
    String vaccinationId,
  ) {
    for (final reminder in _reminders) {
      if (reminder.linkedVaccinationId == vaccinationId) {
        return reminder;
      }
    }

    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Add
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> addReminder(ReminderItem reminder) async {
    // Prevent accidental duplicate IDs.
    final existingIndex =
        _reminders.indexWhere((r) => r.id == reminder.id);

    if (existingIndex >= 0) {
      await updateReminder(reminder);
      return;
    }

    _reminders.add(reminder);
    notifyListeners();

    await _local.saveReminderItem(reminder);

    await _syncNotification(reminder);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Update
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> updateReminder(ReminderItem updated) async {
    final index =
        _reminders.indexWhere((r) => r.id == updated.id);

    if (index < 0) {
      await addReminder(updated);
      return;
    }

    _reminders[index] = updated;

    notifyListeners();

    await _local.saveReminderItem(updated);

    // _syncNotification handles:
    //   • new date
    //   • changed title
    //   • completed reminder
    //   • past reminder
    await _syncNotification(updated);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Delete
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> deleteReminder(String id) async {
    final index =
        _reminders.indexWhere((r) => r.id == id);

    if (index < 0) {
      // Still make sure a stale notification is removed.
      await _cancelNotification(id);
      return;
    }

    _reminders.removeAt(index);

    notifyListeners();

    await _local.deleteReminderItem(id);

    await _cancelNotification(id);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Complete
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> markReminderDone(String id) async {
    final index =
        _reminders.indexWhere((r) => r.id == id);

    if (index < 0) return;

    final current = _reminders[index];

    // Already completed.
    if (current.isDone) {
      await _cancelNotification(id);
      return;
    }

    final updated = current.copyWith(
      isDone: true,
    );

    _reminders[index] = updated;

    notifyListeners();

    await _local.saveReminderItem(updated);

    // Completed reminders remain in the list / Done tab,
    // but their notification must disappear.
    await _cancelNotification(id);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Recurring reminders
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates the next occurrence of a recurring reminder.
  ///
  /// IMPORTANT:
  /// The completed reminder itself remains in the Done tab.
  /// A completely new reminder gets a new ID.
  Future<ReminderItem?> scheduleNextOccurrence(
    ReminderItem completed,
  ) async {
    if (completed.recurrence == 'none') {
      return null;
    }

    final nextDate = _nextDate(
      completed.scheduledAt,
      completed.recurrence,
    );

    final next = ReminderItem(
      id: _newId(),
      title: completed.title,
      type: completed.type,
      scheduledAt: nextDate,
      petId: completed.petId,
      recurrence: completed.recurrence,
      linkedVaccinationId: null,
    );

    await addReminder(next);

    return next;
  }

  /// Convenience method:
  /// complete the reminder and, if recurring, create the next occurrence.
  ///
  /// Vaccination reminders use recurrence == 'none', so they are NOT
  /// automatically duplicated here.
  Future<ReminderItem?> completeAndScheduleNext(
    String id,
  ) async {
    final reminder = getById(id);

    if (reminder == null) {
      return null;
    }

    await markReminderDone(id);

    if (reminder.recurrence == 'none') {
      return null;
    }

    return scheduleNextOccurrence(reminder);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Notification synchronization
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _syncNotification(
    ReminderItem reminder,
  ) async {
    final notificationId =
        NotificationService.careNotifId(reminder.id);

    // Done reminders must never have an active notification.
    if (reminder.isDone) {
      await _notifications.cancelCareReminder(
        notificationId,
      );
      return;
    }

    // Past reminders should not be scheduled.
    //
    // We intentionally do not mark them done here.
    // The reminder remains overdue in the UI.
    if (!reminder.scheduledAt.isAfter(DateTime.now())) {
      await _notifications.cancelCareReminder(
        notificationId,
      );
      return;
    }

    await _notifications.scheduleCareReminder(
      notificationId: notificationId,
      title: reminder.title,
      body: _bodyFor(reminder),
      scheduledDate: reminder.scheduledAt,
      payload: 'care:${reminder.id}',
    );
  }

  Future<void> _cancelNotification(
    String reminderId,
  ) async {
    await _notifications.cancelCareReminder(
      NotificationService.careNotifId(reminderId),
    );
  }

  String _bodyFor(ReminderItem reminder) {
    if (reminder.type.trim().isEmpty) {
      return 'Care reminder';
    }

    return '${reminder.type} reminder';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Recurrence calculation
  // ─────────────────────────────────────────────────────────────────────────

  DateTime _nextDate(
    DateTime from,
    String recurrence,
  ) {
    switch (recurrence) {
      case 'daily':
        return from.add(
          const Duration(days: 1),
        );

      case 'weekly':
        return from.add(
          const Duration(days: 7),
        );

      case 'monthly':
        final nextMonth =
            from.month == 12 ? 1 : from.month + 1;

        final nextYear =
            from.month == 12 ? from.year + 1 : from.year;

        // Avoid invalid dates such as:
        // January 31 -> February 31.
        final lastDayOfNextMonth =
            DateTime(nextYear, nextMonth + 1, 0).day;

        final day =
            from.day > lastDayOfNextMonth
                ? lastDayOfNextMonth
                : from.day;

        return DateTime(
          nextYear,
          nextMonth,
          day,
          from.hour,
          from.minute,
          from.second,
        );

      default:
        return from;
    }
  }

  String _newId() {
    return DateTime.now()
        .microsecondsSinceEpoch
        .toString();
  }
}