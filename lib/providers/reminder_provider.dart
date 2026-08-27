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

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/reminder_item_model.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../services/local_storage_service.dart';
import '../services/notification_service.dart';
import '../services/activity_log_service.dart';

class ReminderProvider extends ChangeNotifier {
  ReminderProvider();

  final LocalStorageService _local = LocalStorageService.instance;
  final NotificationService _notifications = NotificationService.instance;
  final ActivityLogService _activityLog = ActivityLogService.instance;
  final AuthService _auth = AuthService.instance;
  final ConnectivityService _connectivity = ConnectivityService.instance;

  final List<ReminderItem> _reminders = [];

  bool _loading = false;

  // ─────────────────────────────────────────────────────────────────────────
  // Getters
  // ─────────────────────────────────────────────────────────────────────────

  bool get loading => _loading;

  List<ReminderItem> get reminders => List.unmodifiable(_reminders);

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

    if (_auth.isAuthenticated) {
      unawaited(_downloadFromCloud());
      unawaited(_flushPendingOps());
    }
    _auth.addListener(_onAuthChanged);
    _connectivity.addListener(_onConnectivityChanged);
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    _connectivity.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (_auth.isAuthenticated) {
      unawaited(_downloadFromCloud());
      unawaited(_flushPendingOps());
    }
  }

  void _onConnectivityChanged() {
    if (_connectivity.isOnline && _auth.isAuthenticated) {
      unawaited(_flushPendingOps());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Firestore — mirrors PetProfileProvider's own hand-rolled sync (same
  // shape as FirebaseSyncService), scoped to ReminderItem, the model the
  // reminder/vaccination/health-dashboard screens actually use. Shares
  // LocalStorageService's pending-sync queue with the other owners — only
  // 'reminder_item'/'delete_reminder_item' tokens belong to this provider;
  // any other prefix is left untouched.
  // ─────────────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>>? get _collection {
    if (!_auth.isAuthenticated) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_auth.userId)
        .collection('reminder_items');
  }

  Future<void> _uploadToCloud(ReminderItem item) async {
    final collection = _collection;
    if (collection == null) {
      // Not authenticated — nothing to sync yet; Hive already has it.
      return;
    }

    if (!_connectivity.isOnline) {
      await _local.queuePendingOp('reminder_item:${item.id}');
      return;
    }

    try {
      await collection
          .doc(item.id)
          .set(item.toMap(), SetOptions(merge: true));
    } catch (_) {
      await _local.queuePendingOp('reminder_item:${item.id}');
    }
  }

  Future<void> _deleteFromCloud(String id) async {
    final collection = _collection;
    if (collection == null) return;

    if (!_connectivity.isOnline) {
      await _local.queuePendingOp('delete_reminder_item:$id');
      return;
    }

    try {
      await collection.doc(id).delete();
    } catch (_) {
      await _local.queuePendingOp('delete_reminder_item:$id');
    }
  }

  /// Union by id, matching AppProvider's existing reminder-merge strategy
  /// (no field-level conflict resolution): a cloud reminder is added
  /// locally only if this device doesn't already have that id. An edit to
  /// an already-present id is not pulled — same limitation AppProvider
  /// already has for its own reminders.
  Future<void> _downloadFromCloud() async {
    final collection = _collection;
    if (collection == null) return;

    try {
      final snap = await collection.get();
      if (snap.docs.isEmpty) return;

      final existingIds = _reminders.map((r) => r.id).toSet();
      var changed = false;

      for (final doc in snap.docs) {
        try {
          final item = ReminderItem.fromMap(doc.data());
          if (!existingIds.contains(item.id)) {
            _reminders.add(item);
            await _local.saveReminderItem(item);
            await _syncNotification(item);
            changed = true;
          }
        } catch (_) {
          // Skip a malformed cloud doc rather than fail the whole sync.
        }
      }

      if (changed) notifyListeners();
    } catch (_) {
      // Silent fail — app works offline.
    }
  }

  Future<void> _flushPendingOps() async {
    if (!_auth.isAuthenticated || !_connectivity.isOnline) return;

    final collection = _collection;
    if (collection == null) return;

    final tokens = await _local.fetchPendingOps();
    if (tokens.isEmpty) return;

    for (final token in tokens) {
      final parts = token.split(':');
      if (parts.length < 2) continue;
      final type = parts[0];
      final id = parts[1];

      if (type != 'reminder_item' && type != 'delete_reminder_item') continue;

      try {
        if (type == 'reminder_item') {
          final item = getById(id);
          if (item == null) {
            // Reminder no longer exists locally — drop the stale token.
            await _local.removePendingOp(token);
            continue;
          }
          await collection
              .doc(id)
              .set(item.toMap(), SetOptions(merge: true));
        } else {
          await collection.doc(id).delete();
        }
        // Only remove on confirmed success — see PetProfileProvider's
        // _flushPendingOps for why this must not remove on failure.
        await _local.removePendingOp(token);
      } catch (_) {
        // Leave token in queue for next attempt.
      }
    }
  }

  /// Best-effort: attempts to push any queued 'reminder_item'/
  /// 'delete_reminder_item' ops now. Public wrapper around the existing
  /// private flush so callers outside this provider (e.g. AppProvider's
  /// sign-out orchestration) can request one without duplicating its
  /// logic. Safe to call regardless of auth/connectivity — it's already
  /// a no-op in those cases.
  Future<void> flushPendingOpsIfPossible() => _flushPendingOps();

  // ─────────────────────────────────────────────────────────────────────────
  // Guest → account merge
  //
  // Mirrors PetProfileProvider's pushGuestDataToCloud()/replaceLocalWithCloud(),
  // for the ReminderItem data those never touched before. Called from the
  // same post-login "Sync Offline Progress?" prompt in login_screen.dart, so
  // care reminders created as a guest aren't left behind locally when the
  // user creates or signs into an account.
  // ─────────────────────────────────────────────────────────────────────────

  /// "Merge Progress": push every local (guest) reminder to this
  /// account's cloud data, then pull down whatever else already exists
  /// there. Uploading by the reminder's existing id and downloading with
  /// the union-by-id merge in [_downloadFromCloud] together mean this
  /// never creates a duplicate — an uploaded reminder's id is already
  /// present locally, so the subsequent download skips re-adding it.
  Future<void> pushGuestDataToCloud() async {
    for (final r in List<ReminderItem>.from(_reminders)) {
      unawaited(_uploadToCloud(r));
    }
    await _downloadFromCloud();
  }

  /// "Use Cloud Data": discard local (guest) reminders without uploading
  /// them, then replace local state with whatever is in the cloud.
  Future<void> replaceLocalWithCloud() async {
    if (!_auth.isAuthenticated) return;

    for (final r in List<ReminderItem>.from(_reminders)) {
      await _local.deleteReminderItem(r.id);
      await _cancelNotification(r.id);
    }
    _reminders.clear();
    notifyListeners();

    await _downloadFromCloud();
  }

  /// Clears this device's local ReminderItem data (Hive box + in-memory
  /// list), cancelling any scheduled notifications first. Used when an
  /// authenticated session ends (sign-out or account deletion) so the
  /// next guest/account on this device never sees the departed account's
  /// reminders. Does NOT touch Firestore — the account's cloud data is
  /// untouched by this.
  Future<void> clearAllLocalData() async {
    for (final r in List<ReminderItem>.from(_reminders)) {
      await _cancelNotification(r.id);
    }
    await _local.clearReminderItems();
    _reminders.clear();
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Queries
  // ─────────────────────────────────────────────────────────────────────────

  List<ReminderItem> remindersForPet(String? petId) {
    if (petId == null || petId.isEmpty) {
      return List.unmodifiable(_reminders);
    }

    return _reminders.where((r) => r.petId == petId).toList(growable: false);
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
    final existingIndex = _reminders.indexWhere((r) => r.id == reminder.id);

    if (existingIndex >= 0) {
      await updateReminder(reminder);
      return;
    }

    _reminders.add(reminder);
    notifyListeners();

    await _local.saveReminderItem(reminder);
    unawaited(_uploadToCloud(reminder));

    await _syncNotification(reminder);

    await _activityLog.logReminderAdded(
      reminder.title,
      reminder.type,
      petId: reminder.petId ?? '',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Update
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> updateReminder(ReminderItem updated) async {
    final index = _reminders.indexWhere((r) => r.id == updated.id);

    if (index < 0) {
      await addReminder(updated);
      return;
    }

    _reminders[index] = updated;

    notifyListeners();

    await _local.saveReminderItem(updated);
    unawaited(_uploadToCloud(updated));

    // _syncNotification handles:
    //   • new date
    //   • changed title
    //   • completed reminder
    //   • past reminder
    await _syncNotification(updated);

    await _activityLog.logReminderEdited(
      updated.title,
      petId: updated.petId ?? '',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Delete
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> deleteReminder(String id) async {
    final index = _reminders.indexWhere((r) => r.id == id);

    if (index < 0) {
      // Still make sure a stale notification is removed.
      await _cancelNotification(id);
      return;
    }

    final removedTitle = _reminders[index].title;
    final removedPetId = _reminders[index].petId ?? '';

    _reminders.removeAt(index);

    notifyListeners();

    await _local.deleteReminderItem(id);
    unawaited(_deleteFromCloud(id));

    await _cancelNotification(id);

    await _activityLog.logReminderDeleted(
      removedTitle,
      petId: removedPetId,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Complete
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> markReminderDone(String id) async {
    final index = _reminders.indexWhere((r) => r.id == id);

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
    unawaited(_uploadToCloud(updated));

    // Completed reminders remain in the list / Done tab,
    // but their notification must disappear.
    await _cancelNotification(id);

    await _activityLog.logReminderCompleted(
      updated.title,
      petId: updated.petId ?? '',
    );
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
    final notificationId = NotificationService.careNotifId(reminder.id);

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
        final nextMonth = from.month == 12 ? 1 : from.month + 1;

        final nextYear = from.month == 12 ? from.year + 1 : from.year;

        // Avoid invalid dates such as:
        // January 31 -> February 31.
        final lastDayOfNextMonth = DateTime(nextYear, nextMonth + 1, 0).day;

        final day =
            from.day > lastDayOfNextMonth ? lastDayOfNextMonth : from.day;

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
    return DateTime.now().microsecondsSinceEpoch.toString();
  }
}
