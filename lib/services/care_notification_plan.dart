// lib/services/care_notification_plan.dart
//
// Pure planning for ONE care reminder's set of notifications — no plugin,
// no platform channel, so every rule here is unit-testable
// (test/care_notification_plan_test.dart). ReminderProvider computes a plan
// and executes it through NotificationService; NotificationService never
// decides what to schedule.
//
// WHY A FOLLOW-UP CHAIN EXISTS
// The exact due-time notification is a one-shot alarm scheduled in advance,
// so it fires with the app closed. The endless 5-minute overdue repeat, by
// contrast, can only be STARTED by app code (the plugin's repeat call counts
// from the moment it is called), so with the app closed nothing started it
// and only the first alert ever appeared. To cover that gap, a bounded chain
// of ordinary one-shot alarms at fixed future times is pre-scheduled along
// with the due-time alarm: one every [kFollowUpInterval] for
// [kFollowUpCount] intervals (5 minutes for 1 hour) after the due time.
// Fixed timestamps fire with the app completely closed.
//
// HARD LIMIT (Android): the chain is deliberately finite — Android cannot
// schedule an unlimited number of alarms in advance (and caps an app at 500
// concurrent alarms). The protection lasts ONE HOUR after the due time. If
// the user ignores a reminder for longer than that without opening
// PersiPal, the pre-scheduled follow-ups end. As soon as PersiPal is opened
// or resumed while the reminder is overdue, the existing endless 5-minute
// repeat takes over (see ReminderProvider._reconcileAllNotifications).
//
// NOTIFICATION IDS — one reminder owns 14 consecutive ids, derived from its
// stable string id (never random):
//   N          exact due-time notification          (NotificationService.careNotifId)
//   N + 1      endless overdue-repeat cycle
//   N + 2..13  the 12 pre-scheduled follow-ups (+5 … +60 minutes)
// Ids of different reminders can only collide if two reminders' hash-derived
// bases land within 13 of each other (roughly 2.5e-8 per pair of reminders).

/// Follow-up notifications per reminder (12 × 5 min = 1 hour).
const int kFollowUpCount = 12;

/// Spacing between follow-ups.
const Duration kFollowUpInterval = Duration(minutes: 5);

/// Ids reserved per reminder: due, overdue repeat, and every follow-up.
const int kCareIdsPerReminder = 2 + kFollowUpCount;

/// Only this many pending reminders (the soonest due) get a follow-up
/// chain at once. Android allows an app roughly 500 concurrent alarms; each
/// chained reminder uses up to 14, so an unbounded chain could exhaust the
/// limit and make later reminders' own due-time alarms fail to schedule.
const int kMaxChainedReminders = 20;

/// The endless overdue-repeat id for a reminder whose due id is [n].
int repeatNotifId(int n) => n + 1;

/// The id of follow-up number [k] (1..[kFollowUpCount]) for due id [n].
int followUpNotifId(int n, int k) {
  assert(k >= 1 && k <= kFollowUpCount, 'follow-up index out of range: $k');
  return n + 1 + k;
}

/// Every follow-up id for due id [n], in order (+5 min … +60 min).
List<int> followUpNotifIds(int n) =>
    [for (var k = 1; k <= kFollowUpCount; k++) followUpNotifId(n, k)];

/// EVERY id a reminder can own: due, overdue repeat, all follow-ups.
List<int> allCareNotifIds(int n) =>
    [for (var i = 0; i < kCareIdsPerReminder; i++) n + i];

/// One follow-up to arm: its id and the fixed moment it should fire.
class FollowUpSlot {
  final int id;
  final DateTime at;
  const FollowUpSlot(this.id, this.at);

  @override
  bool operator ==(Object other) =>
      other is FollowUpSlot && other.id == id && other.at == at;
  @override
  int get hashCode => Object.hash(id, at);
  @override
  String toString() => 'FollowUpSlot($id, $at)';
}

/// What to do for one reminder right now. Executed by ReminderProvider.
class CareNotificationPlan {
  /// Ids to cancel first.
  final List<int> cancelIds;

  /// Arm the exact due-time notification at this moment (null = nothing to
  /// arm — already armed, done, overdue, or notifications are off).
  final DateTime? dueAt;

  /// Follow-ups to arm.
  final List<FollowUpSlot> followUps;

  /// The reminder is overdue: make sure the endless repeat cycle is running
  /// (it takes over from the pre-scheduled follow-ups, which are cancelled).
  final bool ensureRepeat;

  const CareNotificationPlan({
    this.cancelIds = const [],
    this.dueAt,
    this.followUps = const [],
    this.ensureRepeat = false,
  });
}

/// Decides the notification set for one reminder.
///
/// * [notificationId] — the reminder's due id (N).
/// * [chainAllowed] — whether this reminder is within [kMaxChainedReminders]
///   (see [pickChainedReminderIds]); when false no follow-ups are armed and
///   any pending ones are cancelled.
/// * [replaceExisting] — true when the reminder was just added/edited/reset/
///   replaced from the cloud, so everything is re-armed even if an alarm
///   with that id already exists. False for plain reconciliation (app
///   start/resume, Settings toggle): only what is MISSING is armed, so
///   repeated reconciliation never re-arms or duplicates a chain.
/// * [pendingIds] / [shownIds] — ids the OS currently has scheduled /
///   displayed, when known. Null means unknown: cancel unconditionally and
///   arm everything. Known ids let reconciliation skip work — important
///   because it runs at every start over the whole (growing) history of
///   completed reminders.
CareNotificationPlan planCareNotifications({
  required int notificationId,
  required DateTime now,
  required DateTime scheduledAt,
  required bool isDone,
  required bool notificationsEnabled,
  required bool chainAllowed,
  bool replaceExisting = true,
  Set<int>? pendingIds,
  Set<int>? shownIds,
}) {
  final n = notificationId;

  bool mayCancel(int id, {bool includeShown = false}) {
    if (pendingIds == null) return true;
    if (pendingIds.contains(id)) return true;
    return includeShown && (shownIds?.contains(id) ?? false);
  }

  bool needsArm(int id) =>
      replaceExisting || pendingIds == null || !pendingIds.contains(id);

  // Done, or notifications switched off: nothing may remain — not the due
  // alarm, the repeat, any follow-up, nor a notification already showing.
  if (isDone || !notificationsEnabled) {
    return CareNotificationPlan(cancelIds: [
      for (final id in allCareNotifIds(n))
        if (mayCancel(id, includeShown: true)) id,
    ]);
  }

  // Overdue: the endless repeat takes over. The due alarm (only pending if
  // the reminder was just edited from a future time) and the pre-scheduled
  // follow-ups are cancelled so the two mechanisms never both notify.
  if (!scheduledAt.isAfter(now)) {
    return CareNotificationPlan(
      cancelIds: [
        for (final id in [n, ...followUpNotifIds(n)])
          if (mayCancel(id)) id,
      ],
      ensureRepeat: true,
    );
  }

  // Future: exact due-time alarm plus the follow-up chain.
  final slots = <FollowUpSlot>[];
  final cancel = <int>[];
  if (mayCancel(repeatNotifId(n))) cancel.add(repeatNotifId(n));

  for (var k = 1; k <= kFollowUpCount; k++) {
    final id = followUpNotifId(n, k);
    final at = scheduledAt.add(kFollowUpInterval * k);
    if (chainAllowed && at.isAfter(now)) {
      if (needsArm(id)) slots.add(FollowUpSlot(id, at));
    } else if (mayCancel(id)) {
      cancel.add(id); // stale or not allowed: never leave it armed
    }
  }

  return CareNotificationPlan(
    cancelIds: cancel,
    dueAt: needsArm(n) ? scheduledAt : null,
    followUps: slots,
  );
}

/// The reminder ids allowed a follow-up chain: among pending reminders whose
/// chain is still relevant (its hour hasn't fully passed), the
/// [kMaxChainedReminders] soonest due.
Set<String> pickChainedReminderIds(
  Iterable<({String id, DateTime scheduledAt})> pending,
  DateTime now,
) {
  final chainEnd = kFollowUpInterval * kFollowUpCount;
  final relevant = pending
      .where((r) => r.scheduledAt.add(chainEnd).isAfter(now))
      .toList()
    ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
  return relevant.take(kMaxChainedReminders).map((r) => r.id).toSet();
}
