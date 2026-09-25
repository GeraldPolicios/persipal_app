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
import 'package:flutter/widgets.dart';

import '../models/reminder_item_model.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../services/local_storage_service.dart';
import '../services/care_notification_plan.dart';
import '../services/notification_service.dart';
import '../services/activity_log_service.dart';
import '../services/reward_service.dart';

class ReminderProvider extends ChangeNotifier with WidgetsBindingObserver {
  ReminderProvider();

  /// Resolves a pet's display name for notification text (e.g. "Milo").
  /// Injected externally (see main.dart) instead of importing
  /// PetProfileProvider directly, since PetProfileProvider already imports
  /// this file (for its ReminderProvider-typed method parameters) — a
  /// direct import back would be circular.
  static String? Function(String petId)? petNameResolver;

  /// Called after a reminder occurrence is completed so real-pet
  /// achievement progress can be checked — same circular-import reason as
  /// [petNameResolver] above. Injected once from main.dart as
  /// `PetProfileProvider.instance.checkCareAchievements`.
  static Future<void> Function(String petId)? onReminderCompleted;

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

      // One-time-per-load data correction — see its own doc comment. Runs
      // before notification reconciliation so a reverted reminder's
      // notification is correctly resumed by the step right after this.
      await _correctPrematureCompletions();

      // Reconcile all stored reminders with notifications. Safe to execute
      // every time — see _reconcileAllNotifications.
      await _reconcileAllNotifications();
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

    // Resuming from background counts as "reopening" for the purposes of
    // keeping an overdue reminder's notification cycle alive — see
    // didChangeAppLifecycleState below.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _auth.removeListener(_onAuthChanged);
    _connectivity.removeListener(_onConnectivityChanged);
    super.dispose();
  }

  /// Reverts any reminder that ended up marked done BEFORE it was ever due
  /// — a bug (now fixed — see markReminderDone/completeReminderOccurrence's
  /// own guards, and ReminderScreen's Done button, which no longer offers
  /// this at all) let "Mark Done" complete a reminder whose scheduledAt
  /// hadn't arrived yet. `completedAt` earlier than `scheduledAt` is a
  /// logical impossibility for a correct completion, so this detects
  /// exactly (and only) the reminders that bug actually produced —
  /// legitimately-completed history (completedAt at/after scheduledAt) is
  /// never touched. Reverting also removes it from the Done tab's history
  /// and (via _reconcileAllNotifications right after this) correctly
  /// resumes its notification, restoring it to Upcoming/Overdue exactly
  /// where it belongs.
  ///
  /// Deliberately does NOT try to find/delete a "phantom" next occurrence
  /// that a premature recurring completion may have already spawned
  /// (scheduleNextOccurrence creates a fresh id, so there's no reliable
  /// link back to it without guessing by title/type/date — too easy to
  /// delete the wrong, legitimately separate reminder). If a recurring
  /// reminder was affected, check for and manually remove any obviously
  /// duplicate future occurrence it left behind.
  /// True iff [r] is marked done with a completion timestamp earlier than
  /// its own scheduled time — a logical impossibility for a correct
  /// completion, and exactly what [_correctPrematureCompletions] reverts.
  /// Pulled out as its own pure, public function specifically so this
  /// detection rule is unit-testable without a live ReminderProvider —
  /// see test/reminder_premature_completion_test.dart.
  @visibleForTesting
  static bool wasCompletedPrematurely(ReminderItem r) {
    final completedAt = r.completedAt;
    return r.isDone && completedAt != null && completedAt.isBefore(r.scheduledAt);
  }

  Future<void> _correctPrematureCompletions() async {
    final toRevert = _reminders.where(wasCompletedPrematurely).toList();

    if (toRevert.isEmpty) return;

    for (final reminder in toRevert) {
      final index = _reminders.indexWhere((r) => r.id == reminder.id);
      if (index < 0) continue;
      final reverted = reminder.copyWith(isDone: false, completedAt: null);
      _reminders[index] = reverted;
      await _local.saveReminderItem(reverted);
      unawaited(_uploadToCloud(reverted));
    }

    notifyListeners();
  }

  /// Re-syncs every stored reminder's notifications against its current
  /// isDone/scheduledAt state (the rules live in planCareNotifications):
  ///   • Future + pending  → exact due-time alarm PLUS the pre-scheduled
  ///     follow-up chain (every 5 minutes for 1 hour after it), so a
  ///     reminder keeps notifying even if the app is never opened.
  ///   • Overdue + pending → the endless ~5-minute repeat cycle takes over
  ///     (started only if none is running) and the pre-scheduled follow-ups
  ///     are cancelled, so the two never both notify.
  ///   • Done              → every notification cancelled.
  /// Idempotent and cheap to repeat (app start, app resume, Settings
  /// toggle): it reads what the OS already has scheduled ONCE and arms only
  /// what is missing, so it never duplicates a chain or resets a running
  /// countdown, and never issues cancel calls for the (ever-growing) history
  /// of completed reminders that have nothing scheduled.
  Future<void> _reconcileAllNotifications() async {
    // Re-reads the device's current UTC offset before (re)scheduling
    // anything below — see NotificationService.refreshLocalTimeZone's doc
    // comment for exactly what this does/doesn't guarantee. Cheap and
    // idempotent, so doing it on every reconcile (app start + every
    // resume) keeps it fresh without needing a dedicated timer.
    NotificationService.refreshLocalTimeZone();

    final pending = await _notifications.pendingNotificationIds();
    final shown = await _notifications.shownNotificationIds();
    final chained = _chainedReminderIds(DateTime.now());

    for (final reminder in List<ReminderItem>.from(_reminders)) {
      await _syncNotification(
        reminder,
        pendingIds: pending,
        shownIds: shown,
        chained: chained,
      );
    }
  }

  /// Reminders allowed a follow-up chain right now — see
  /// pickChainedReminderIds (bounded so the chains can never exhaust
  /// Android's per-app alarm limit).
  Set<String> _chainedReminderIds(DateTime now) => pickChainedReminderIds([
        for (final r in _reminders)
          if (!r.isDone) (id: r.id, scheduledAt: r.scheduledAt),
      ], now);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_reconcileAllNotifications());
    }
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

  /// Reminder ids with an [_uploadToCloud] write currently in flight —
  /// checked by [_downloadFromCloud] so a concurrent download can never
  /// race a local upload that hasn't committed (or failed and queued)
  /// yet. In-memory only (this process only, cleared as soon as the write
  /// settles either way): the persisted pending-ops queue is what
  /// protects the equivalent case across an app restart/offline gap — see
  /// [_downloadFromCloud]'s doc comment for the full conflict-ordering
  /// rule this and the queue together implement.
  final Set<String> _uploadsInFlight = {};

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

    _uploadsInFlight.add(item.id);
    try {
      await collection
          .doc(item.id)
          .set(item.toMap(), SetOptions(merge: true));
    } catch (_) {
      await _local.queuePendingOp('reminder_item:${item.id}');
    } finally {
      _uploadsInFlight.remove(item.id);
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

  /// Merges by id: a cloud reminder new to this device is added; a cloud
  /// reminder this device already has is UPDATED IN PLACE (same id, never
  /// a duplicate) whenever its fields actually differ — this is what lets
  /// a completion (isDone/completedAt) or an edit made on another device
  /// reach this one. (Previously this only ever added brand-new ids and
  /// silently ignored any cloud change to an id already present locally —
  /// so a completion on Device A, once uploaded, would never reach Device
  /// B's already-downloaded copy of that same occurrence.)
  ///
  /// Conflict ordering — cloud must never clobber a local change that
  /// hasn't made it to the cloud yet:
  ///   • [_uploadsInFlight] — an upload for this exact id is being written
  ///     right now, on this device, in this process.
  ///   • the persisted 'reminder_item:{id}' pending-sync-op token — an
  ///     earlier upload for this id failed or was made offline and is
  ///     still queued (see [_uploadToCloud]/[_flushPendingOps]); the token
  ///     is only removed once that write actually succeeds, so it's still
  ///     present for a download that races an in-progress flush too.
  /// A cloud doc for an id caught by either check is skipped entirely for
  /// this download pass — local wins, and reconciles on its own once that
  /// pending write actually lands (a later download then finds no reason
  /// left to skip it, and pulls whatever's now in the cloud — which, if
  /// nothing else changed it in between, is exactly this same local
  /// state, making that pull a harmless no-op).
  ///
  /// Recurrence is unaffected by any of this: a completed occurrence and
  /// its freshly-scheduled next occurrence are always two separate ids
  /// (see scheduleNextOccurrence), so they're never merged into each
  /// other here — one updates in place, the other is added as new.
  Future<void> _downloadFromCloud() async {
    final collection = _collection;
    if (collection == null) return;

    try {
      final snap = await collection.get();
      if (snap.docs.isEmpty) return;

      final pendingIds = (await _local.fetchPendingOps())
          .where((token) => token.startsWith('reminder_item:'))
          .map((token) => token.substring('reminder_item:'.length))
          .toSet();

      var changed = false;

      for (final doc in snap.docs) {
        try {
          final cloudItem = ReminderItem.fromMap(doc.data());
          final index = _reminders.indexWhere((r) => r.id == cloudItem.id);

          final decision = resolveMergeDecision(
            cloudItem: cloudItem,
            existingLocal: index < 0 ? null : _reminders[index],
            hasPendingLocalChange: pendingIds.contains(cloudItem.id) ||
                _uploadsInFlight.contains(cloudItem.id),
          );

          switch (decision) {
            case ReminderMergeDecision.skipLocalWins:
            case ReminderMergeDecision.noopAlreadySame:
              break;
            case ReminderMergeDecision.addNew:
              _reminders.add(cloudItem);
              await _local.saveReminderItem(cloudItem);
              await _syncNotification(cloudItem, restartOverdueRepeat: true);
              changed = true;
            case ReminderMergeDecision.updateInPlace:
              // Already present, nothing of this device's own still
              // unsynced for it — the cloud reflects the more recent
              // state (e.g. a completion made on another device). Same
              // id (index found above), so this can never create a
              // duplicate.
              _reminders[index] = cloudItem;
              await _local.saveReminderItem(cloudItem);
              await _syncNotification(cloudItem, restartOverdueRepeat: true);
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

  /// Pure decision for how one cloud doc should be merged against whatever
  /// this device already has for the same id — the entire conflict-
  /// ordering rule described in [_downloadFromCloud]'s doc comment,
  /// pulled out on its own specifically so it's unit-testable without
  /// Firebase/a live ReminderProvider — see
  /// test/reminder_sync_merge_test.dart.
  @visibleForTesting
  static ReminderMergeDecision resolveMergeDecision({
    required ReminderItem cloudItem,
    required ReminderItem? existingLocal,
    required bool hasPendingLocalChange,
  }) {
    if (hasPendingLocalChange) return ReminderMergeDecision.skipLocalWins;
    if (existingLocal == null) return ReminderMergeDecision.addNew;
    return _reminderFieldsDiffer(existingLocal, cloudItem)
        ? ReminderMergeDecision.updateInPlace
        : ReminderMergeDecision.noopAlreadySame;
  }

  /// True if any field [resolveMergeDecision] cares about differs — used
  /// to skip a no-op local write/notifyListeners when a downloaded doc is
  /// already identical to what's stored locally (e.g. re-downloading
  /// exactly what this same device just uploaded).
  static bool _reminderFieldsDiffer(ReminderItem a, ReminderItem b) =>
      a.title != b.title ||
      a.type != b.type ||
      a.scheduledAt != b.scheduledAt ||
      a.isDone != b.isDone ||
      a.completedAt != b.completedAt ||
      a.petId != b.petId ||
      a.linkedVaccinationId != b.linkedVaccinationId ||
      a.recurrence != b.recurrence;

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

    await _syncNotification(reminder, restartOverdueRepeat: true);

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

    // Completed occurrences are historical and immutable — this is the
    // only place any edit (title/date/pet/recurrence) could reach a
    // reminder, so this one guard closes every edit entry point at once.
    // The sole legitimate way isDone ever flips is markReminderDone() /
    // completeReminderOccurrence(), never this method.
    if (_reminders[index].isDone) return;

    _reminders[index] = updated;

    notifyListeners();

    await _local.saveReminderItem(updated);
    unawaited(_uploadToCloud(updated));

    // _syncNotification handles:
    //   • new date
    //   • changed title
    //   • completed reminder
    //   • past reminder
    await _syncNotification(updated, restartOverdueRepeat: true);

    await _activityLog.logReminderEdited(
      updated.title,
      petId: updated.petId ?? '',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Delete
  // ─────────────────────────────────────────────────────────────────────────

  /// Deletes every reminder associated with [petId]. Called when a real
  /// pet profile is deleted, so its reminders don't survive as orphaned
  /// entries that still count toward "Reminders Due" and still fire
  /// notifications for a pet that no longer exists. Reuses [deleteReminder]
  /// so Hive/cloud/notification/activity-log cleanup stays identical to a
  /// normal single-reminder delete.
  Future<void> deleteRemindersForPet(String petId) async {
    final ids = _reminders
        .where((r) => r.petId == petId)
        .map((r) => r.id)
        .toList();

    for (final id in ids) {
      await deleteReminder(id);
    }
  }

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

  /// Marks one reminder occurrence done "now", stamping [ReminderItem.
  /// completedAt] with the actual completion moment (never the original
  /// [scheduledAt]) — this is what the Done tab's date filter and every
  /// "completion timestamp" requirement key off. Idempotent: calling it
  /// again on an already-done reminder only re-cancels its notification
  /// (defensive — should already be cancelled) and does nothing else, so a
  /// duplicate call (e.g. a stale/duplicate notification action) can never
  /// overwrite a real completedAt with a later, wrong one.
  ///
  /// [logActivity] defaults to true (the normal "Mark Done" path — either
  /// from the Reminder Screen or a notification's Mark Done action — should
  /// always leave an Activity History trail). It is set to false only by
  /// the vaccination-completion flow (PetProfileProvider.
  /// completeVaccinationDose), which already logs its own, more specific
  /// "vaccination completed" entry for the same single user action — logging
  /// both here would be a duplicate entry for one completion.
  ///
  /// Refuses to complete a reminder before its own [ReminderItem.
  /// scheduledAt] actually arrives — completing something early isn't
  /// "done," it just hides a reminder before the thing it's for could have
  /// happened yet. This is the single, authoritative place that rule is
  /// enforced (in the provider, not just the UI), so it holds no matter
  /// which entry point reaches it — the Reminder Screen's Done button, a
  /// notification's Mark Done action, or any future caller.
  Future<void> markReminderDone(String id, {bool logActivity = true}) async {
    final index = _reminders.indexWhere((r) => r.id == id);

    if (index < 0) return;

    final current = _reminders[index];

    // Already completed.
    if (current.isDone) {
      await _cancelNotification(id);
      return;
    }

    // Not due yet — never allow completing it early.
    if (!current.isDue) return;

    final updated = current.copyWith(
      isDone: true,
      completedAt: DateTime.now(),
    );

    _reminders[index] = updated;

    notifyListeners();

    await _local.saveReminderItem(updated);
    unawaited(_uploadToCloud(updated));

    // Completed reminders remain in the list / Done tab,
    // but their notification must disappear.
    await _cancelNotification(id);

    if (logActivity) {
      await _activityLog.logReminderCompleted(
        updated.title,
        petId: updated.petId ?? '',
      );
    }

    // Reward points: completing a care task (once per reminder occurrence).
    unawaited(
        RewardService.instance.awardOnce('care:$id', RewardService.carePoints));
  }

  /// Fully completes one reminder occurrence exactly the way the in-app
  /// "Mark Done" button does: marks it done (which also cancels its entire
  /// repeat-notification chain — see [_cancelNotification]), checks
  /// real-pet achievement progress via [onReminderCompleted], and schedules
  /// the next occurrence if the reminder recurs. Used by both
  /// ReminderScreen's Done button and the "Mark Done" notification action,
  /// so both paths log/unlock/reschedule identically and a repeated
  /// notification can never itself be mistaken for a completion.
  ///
  /// Vaccine-linked reminders are NOT handled here — completing those must
  /// go through `showVaccinationCompleteDialog` to keep the vaccination
  /// record in sync, so this is a no-op for them (callers should check
  /// `linkedVaccinationId` first and route there instead).
  Future<void> completeReminderOccurrence(String id) async {
    final reminder = getById(id);

    if (reminder == null || reminder.isDone) return;
    if (reminder.linkedVaccinationId != null) return;
    // Not due yet — bail out before any of markReminderDone's completion
    // side effects (which itself also refuses, redundantly) AND before the
    // achievement callback / next-occurrence scheduling below, neither of
    // which should ever fire for a completion that didn't actually happen.
    if (!reminder.isDue) return;

    await markReminderDone(id);

    if (reminder.petId != null) {
      await onReminderCompleted?.call(reminder.petId!);
    }

    if (reminder.recurrence != 'none') {
      await scheduleNextOccurrence(reminder);
    }
  }

  /// User-facing "Reset" action for the Done tab — reverts a completed
  /// reminder back to pending (clears isDone/completedAt), so it moves
  /// back out of Done and into Upcoming/Overdue, and its notification
  /// resumes (via the same _syncNotification path everything else uses).
  /// The manual counterpart to [wasCompletedPrematurely]/
  /// [_correctPrematureCompletions]'s automatic correction — for when a
  /// reminder was marked done in error for any other reason and the user
  /// wants to undo it themselves.
  ///
  /// Not available for a vaccine-linked reminder: completing one of those
  /// also updates a separate vaccination record (see
  /// PetProfileProvider.completeVaccinationDose), and resetting only the
  /// reminder half would leave the two out of sync — undo that from the
  /// Vaccinations screen instead.
  ///
  /// Reward points already earned for the original completion are NOT
  /// clawed back — this only ever changes the reminder's own pending/done
  /// state, never the points ledger.
  Future<void> resetReminderToPending(String id) async {
    final index = _reminders.indexWhere((r) => r.id == id);
    if (index < 0) return;

    final current = _reminders[index];
    if (!current.isDone) return;
    if (current.linkedVaccinationId != null) return;

    final reverted = current.copyWith(isDone: false, completedAt: null);
    _reminders[index] = reverted;

    notifyListeners();

    await _local.saveReminderItem(reverted);
    unawaited(_uploadToCloud(reverted));

    // Pending again, so its notification needs to resume — future one-shot
    // or overdue-repeat, whichever its scheduledAt now calls for.
    await _syncNotification(reverted, restartOverdueRepeat: true);

    await _activityLog.logReminderReset(
      reverted.title,
      petId: reverted.petId ?? '',
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

    // Step from the completed occurrence's own schedule, but never land in
    // the past: a reminder completed while overdue would otherwise spawn a
    // next occurrence that is already overdue (one per missed period),
    // instead of the next genuinely upcoming one.
    var nextDate = _nextDate(
      completed.scheduledAt,
      completed.recurrence,
    );
    final now = DateTime.now();
    for (var i = 0; i < 1000 && !nextDate.isAfter(now); i++) {
      nextDate = _nextDate(nextDate, completed.recurrence);
    }

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

  // ─────────────────────────────────────────────────────────────────────────
  // Notification synchronization
  // ─────────────────────────────────────────────────────────────────────────

  /// Re-syncs every reminder's notification(s) — called after the user
  /// flips the Notifications switch in Settings so it takes effect at once.
  Future<void> refreshNotifications() => _reconcileAllNotifications();

  /// [restartOverdueRepeat] (true for add / edit / reset / cloud update):
  /// this reminder's schedule or text may have changed, so everything is
  /// re-armed and a running overdue repeat is replaced. Leave false for
  /// plain reconciliation (app start/resume, Settings toggle), which arms
  /// only what is missing — see planCareNotifications.
  /// [pendingIds]/[shownIds]/[chained] let reconciliation share one read of
  /// the OS state across all reminders.
  Future<void> _syncNotification(
    ReminderItem reminder, {
    bool restartOverdueRepeat = false,
    Set<int>? pendingIds,
    Set<int>? shownIds,
    Set<String>? chained,
  }) async {
    try {
      await _syncNotificationOrThrow(
        reminder,
        restartOverdueRepeat: restartOverdueRepeat,
        pendingIds: pendingIds,
        shownIds: shownIds,
        chained: chained,
      );
    } catch (e) {
      // A notification problem (e.g. the OS denying exact alarms) must never
      // break reminder add/edit/complete or stop the app from starting — the
      // reminder itself is already saved.
      debugPrint(
        'ReminderProvider: notification sync failed for ${reminder.id}: $e',
      );
    }
  }

  Future<void> _syncNotificationOrThrow(
    ReminderItem reminder, {
    bool restartOverdueRepeat = false,
    Set<int>? pendingIds,
    Set<int>? shownIds,
    Set<String>? chained,
  }) async {
    final now = DateTime.now();
    final notificationId = NotificationService.careNotifId(reminder.id);

    // Settings › Notifications off: keep the reminder, drop its alerts. (A
    // done reminder's plan is "cancel everything" either way, so skip the
    // settings read for the whole history of completed reminders.)
    final enabled = reminder.isDone
        ? true
        : (await _local.fetchSettings()).notificationsEnabled;

    final plan = planCareNotifications(
      notificationId: notificationId,
      now: now,
      scheduledAt: reminder.scheduledAt,
      isDone: reminder.isDone,
      notificationsEnabled: enabled,
      chainAllowed:
          (chained ?? _chainedReminderIds(now)).contains(reminder.id),
      replaceExisting: restartOverdueRepeat,
      pendingIds: pendingIds,
      shownIds: shownIds,
    );

    await _notifications.cancelIds(plan.cancelIds);

    final title = _titleFor(reminder);
    final body = _bodyFor(reminder);
    final payload = 'care:${reminder.id}';
    // Vaccine-linked reminders must be completed through the vaccination
    // dialog (keeps the vaccination record in sync) — never directly from a
    // notification action.
    final allowMarkDone = reminder.linkedVaccinationId == null;

    final dueAt = plan.dueAt;
    if (dueAt != null) {
      await _notifications.scheduleCareReminder(
        notificationId: notificationId,
        title: title,
        body: body,
        scheduledDate: dueAt,
        payload: payload,
        allowMarkDoneAction: allowMarkDone,
      );
    }

    for (final slot in plan.followUps) {
      await _notifications.scheduleCareFollowUp(
        id: slot.id,
        title: title,
        body: body,
        at: slot.at,
        payload: payload,
        allowMarkDoneAction: allowMarkDone,
      );
    }

    // Overdue and not done: the endless repeat (an OS-level repeating
    // notification that keeps firing with the app closed once started).
    // Started only if none is running, so reopening the app never resets
    // its countdown; replaced only when the content changed. It takes over
    // from the pre-scheduled follow-ups, which the plan just cancelled.
    if (plan.ensureRepeat) {
      await _notifications.startOverdueRepeat(
        notificationId: notificationId,
        title: title,
        body: body,
        payload: payload,
        allowMarkDoneAction: allowMarkDone,
        restartIfActive: restartOverdueRepeat,
      );
    }
  }

  Future<void> _cancelNotification(
    String reminderId,
  ) async {
    await _notifications.cancelCareReminder(
      NotificationService.careNotifId(reminderId),
    );
  }

  String? _petNameFor(ReminderItem reminder) {
    final petId = reminder.petId;
    if (petId == null || petId.isEmpty) return null;
    final name = petNameResolver?.call(petId);
    return (name == null || name.trim().isEmpty) ? null : name.trim();
  }

  String _titleFor(ReminderItem reminder) {
    final type = reminder.type.trim().isEmpty ? 'Care' : reminder.type.trim();
    final petName = _petNameFor(reminder);
    return petName != null ? '🐱 $petName — $type Reminder' : '⏰ $type Reminder';
  }

  String _bodyFor(ReminderItem reminder) {
    final what = reminder.title.trim().isEmpty
        ? '${reminder.type.trim().isEmpty ? 'care' : reminder.type.trim()} reminder'
        : reminder.title.trim();
    final petName = _petNameFor(reminder);
    return petName != null ? "It's time for $petName's $what." : what;
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

/// What [ReminderProvider.resolveMergeDecision] decided to do with one
/// downloaded cloud doc.
@visibleForTesting
enum ReminderMergeDecision {
  /// This id has an unsynced local change (queued or actively uploading)
  /// — the cloud doc is ignored for this pass; local wins.
  skipLocalWins,

  /// This device has never seen this id before — add it.
  addNew,

  /// This device already has this id, no local change is still unsynced
  /// for it, and the cloud's fields differ — overwrite the local copy in
  /// place (same id, never a duplicate).
  updateInPlace,

  /// This device already has this id and every field already matches —
  /// nothing to do.
  noopAlreadySame,
}
