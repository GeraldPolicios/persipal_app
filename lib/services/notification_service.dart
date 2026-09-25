// lib/services/notification_service.dart
//
// Real local push notifications — works 100% offline, zero Firebase needed.
//
// Uses:
//   flutter_local_notifications: ^17.0.0
//   timezone: ^0.9.0
//
// Add to pubspec.yaml:
//   dependencies:
//     flutter_local_notifications: ^17.0.0
//     timezone: ^0.9.0
//
// Android setup (android/app/src/main/AndroidManifest.xml) — add inside <manifest>:
//   <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
//   <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
//   <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
//
// iOS setup (ios/Runner/AppDelegate.swift) — already handled by the plugin.
// iOS Info.plist — no extra keys needed for local notifications.
//
// Notification ID strategy — one care reminder owns 14 consecutive ids
// (see care_notification_plan.dart for the full rationale):
//   N          exact due-time notification   (careNotifId)
//   N + 1      endless overdue-repeat cycle  (see startOverdueRepeat)
//   N + 2..13  12 pre-scheduled follow-ups, +5 … +60 minutes after due
// Vaccine-linked reminders are ordinary care reminders too, so they share
// this scheme — see ReminderProvider.
//
// All scheduled notifications survive app restarts on Android via
// the RECEIVE_BOOT_COMPLETED permission + plugin's boot receiver.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'care_notification_plan.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  // Cold-start action/tap: if the app was fully closed and the user tapped
  // a notification (or its "Mark Done" action), the plugin only surfaces
  // that response via getNotificationAppLaunchDetails() — NOT through
  // onDidReceiveNotificationResponse during initialize(). We stash it here
  // and require callers to explicitly [consumeStartupAction] once their own
  // callbacks (e.g. onMarkDoneAction) are wired, so a cold-start action can
  // never be silently dropped just because it arrived before setup finished.
  NotificationResponse? _pendingLaunchResponse;

  /// Called when the user taps "Mark Done" directly on a care-reminder
  /// notification (payload "care:{reminderId}"). Injected externally (see
  /// main.dart) instead of importing ReminderProvider directly here, since
  /// ReminderProvider already imports this service.
  static void Function(String reminderId)? onMarkDoneAction;

  /// Called on a plain (non-action) tap of a care-reminder notification, so
  /// the app can open straight to the exact reminder that generated it
  /// instead of just a generic Home/Reminder screen. Injected from
  /// main.dart once a real Navigator exists (see the module doc there) —
  /// same circular-import reason as [onMarkDoneAction]. Left null during
  /// the brief cold-start window before runApp(): a tap that arrives then
  /// (via [consumeStartupAction]) is still captured, just via
  /// [_pendingReminderNavigationId]/[consumePendingReminderNavigation]
  /// instead, since nothing can navigate before the widget tree exists.
  static void Function(String reminderId)? onReminderNotificationTap;

  /// Restart-safe stash for a plain reminder-notification tap:
  /// [_onNotificationTap] always writes the reminder id here first (before
  /// trying [onReminderNotificationTap]), so a tap that cold-starts the app
  /// (processed via [consumeStartupAction] before runApp(), when no
  /// Navigator exists yet to call [onReminderNotificationTap] with) is never
  /// silently dropped — main.dart flushes it via
  /// [consumePendingReminderNavigation] right after the first frame. Only
  /// the reminder's id is kept (a stable string), not the raw
  /// NotificationResponse — by the time this is consumed, the id is the
  /// only part still guaranteed to mean anything.
  String? _pendingReminderNavigationId;

  /// Returns and clears the reminder id stashed by a plain notification
  /// tap, or null if nothing is pending. See
  /// [_pendingReminderNavigationId].
  String? consumePendingReminderNavigation() {
    final id = _pendingReminderNavigationId;
    _pendingReminderNavigationId = null;
    return id;
  }

  // ── Channel constants ─────────────────────────────────────────────────────

  static const _careChannelId = 'persipal_care';
  static const _careChannelName = 'Care Reminders';
  static const _careChannelDesc =
      'Feeding, grooming, vitamin, and vet visit reminders';

  static const _markDoneActionId = 'mark_done';
  static const _careCategoryId = 'persipal_care_category';

  // ── Persistent-reminder tuning ───────────────────────────────────────────
  // A care reminder that isn't marked done keeps re-notifying every
  // [reminderOverdueRepeatInterval] for as long as it stays overdue — an
  // indefinite OS-level repeating notification (see startOverdueRepeat),
  // not a fixed-length chain, so it never silently stops on its own after
  // some number of repeats. It only stops when explicitly cancelled
  // (completion) — see cancelCareReminder.
  static const Duration reminderOverdueRepeatInterval = Duration(minutes: 5);

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;

    // Load timezone data (needed for scheduled notifications)
    tz_data.initializeTimeZones();

    // Local timezone — see refreshLocalTimeZone()'s doc comment for exactly
    // what this does and does not guarantee (was previously hard-coded to
    // UTC, silently misfiring every scheduled reminder for any device not
    // actually on UTC).
    refreshLocalTimeZone();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          _careCategoryId,
          actions: [
            DarwinNotificationAction.plain(
              _markDoneActionId,
              '✓ Mark Done',
              options: {DarwinNotificationActionOption.foreground},
            ),
          ],
        ),
      ],
    );

    await _plugin.initialize(
      InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Request permissions (Android 13+, iOS)
    await _requestPermissions();

    _initialized = true;

    // Stash (don't process yet) any action/tap that just cold-started the
    // app — see consumeStartupAction().
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true) {
      _pendingLaunchResponse = launchDetails!.notificationResponse;
    }
  }

  /// Sets [tz.local] to a fixed-offset location matching the device's
  /// CURRENT UTC offset (`DateTime.now().timeZoneOffset`, pure `dart:core`,
  /// no plugin or new dependency), so the wall-clock time the plugin sees
  /// is the device's local time.
  ///
  /// CRITICAL CONSTRAINT: flutter_local_notifications sends this location's
  /// NAME to Android, which calls Java's `ZoneId.of(name)` — so the name
  /// must be a valid Java zone id (see [zoneIdForOffset]). An arbitrary
  /// label makes every `zonedSchedule` call throw on Android; the app only
  /// logs that failure, so reminders silently never get an alarm. (An
  /// earlier version of this method named the location 'device-local',
  /// which did exactly that.)
  ///
  /// Note the scheduled INSTANT is correct either way: [_toTZ] uses
  /// `TZDateTime.from(dt, tz.local)`, which preserves the exact moment in
  /// whatever location is used, so even the original hard-coded UTC
  /// location fired reminders at the right real-world moment. The offset
  /// location only keeps the plugin's wall-clock view local.
  ///
  /// KNOWN LIMITATION: this is a FIXED offset, not a DST-aware named zone
  /// like "Asia/Manila" — `dart:core` can't resolve the device's IANA zone
  /// name, only its current offset. Because the instant itself is
  /// preserved, this only matters for wall-clock-based features, which the
  /// app doesn't use (recurrence is rescheduled by the app itself).
  ///
  /// Refreshed on every [init] (app start) and, via
  /// ReminderProvider._reconcileAllNotifications, on every app resume.
  static void refreshLocalTimeZone() {
    final offset = DateTime.now().timeZoneOffset;
    tz.setLocalLocation(tz.Location(
      zoneIdForOffset(offset),
      [tz.minTime],
      [0],
      [
        tz.TimeZone(offset.inMilliseconds, isDst: false, abbreviation: 'LOCAL'),
      ],
    ));
  }

  /// A zone id Java's `ZoneId.of` accepts for a fixed UTC [offset]: "UTC"
  /// for zero, otherwise "+HH:MM" / "-HH:MM" (plus ":SS" for the rare
  /// offset with seconds). Public only so a test can pin the format — the
  /// name is what the plugin hands to Android (see [refreshLocalTimeZone]).
  @visibleForTesting
  static String zoneIdForOffset(Duration offset) {
    final totalSeconds = offset.inSeconds;
    if (totalSeconds == 0) return 'UTC';
    final sign = totalSeconds < 0 ? '-' : '+';
    final abs = totalSeconds.abs();
    final hh = (abs ~/ 3600).toString().padLeft(2, '0');
    final mm = ((abs % 3600) ~/ 60).toString().padLeft(2, '0');
    final ss = abs % 60;
    return ss == 0
        ? '$sign$hh:$mm'
        : '$sign$hh:$mm:${ss.toString().padLeft(2, '0')}';
  }

  /// Processes a notification action/tap that cold-started the app, if any.
  /// Must be called once [onMarkDoneAction] has been wired (see main.dart —
  /// it's called right after that wiring, before runApp()) so a "Mark Done"
  /// tap that launched PersiPal from fully closed is never silently lost.
  /// Safe to call even when there's nothing pending.
  void consumeStartupAction() {
    final response = _pendingLaunchResponse;
    _pendingLaunchResponse = null;
    if (response != null) _onNotificationTap(response);
  }

  Future<void> _requestPermissions() async {
    // Android 13+
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();

    // iOS
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Pure parse of a raw plugin response into what to do, if anything —
  /// split out from [_onNotificationTap] specifically so this logic (which
  /// reminder id a payload identifies, and whether the tap was the
  /// "Mark Done" action vs. a plain tap) is unit-testable without a live
  /// plugin/platform channel — see test/notification_tap_routing_test.dart.
  /// "care:{reminderId}" is the only payload format ever actually scheduled
  /// (see scheduleCareReminder/startOverdueRepeat call sites in
  /// ReminderProvider) — vaccine-linked reminders are plain ReminderItems
  /// too and use this exact same payload, never a separate "vaccine:" one.
  @visibleForTesting
  static NotificationTapAction? parseTapAction(
    String? payload,
    String? actionId,
  ) {
    if (payload == null || !payload.startsWith('care:')) return null;
    final reminderId = payload.substring('care:'.length);
    if (reminderId.isEmpty) return null;
    return NotificationTapAction(
      reminderId: reminderId,
      isMarkDone: actionId == _markDoneActionId,
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    final action = parseTapAction(response.payload, response.actionId);
    if (action == null) {
      debugPrint(
        'Notification tapped: unrecognized payload "${response.payload}"',
      );
      return;
    }

    if (action.isMarkDone) {
      onMarkDoneAction?.call(action.reminderId);
      return;
    }

    // Plain tap — open the exact reminder that generated this notification.
    // Always stash first (restart-safe — see _pendingReminderNavigationId),
    // then, if a live Navigator is already wired (the app was already
    // running — foreground, or brought back from background — when the tap
    // arrived), jump straight there too. During the brief cold-start window
    // before runApp() (see main.dart's consumeStartupAction() call),
    // onReminderNotificationTap is still null, so the stash alone carries
    // the id through to main()'s one-time post-first-frame flush.
    _pendingReminderNavigationId = action.reminderId;
    onReminderNotificationTap?.call(action.reminderId);
  }

  /// Test-only entry point for the exact same dispatch a real plugin tap
  /// goes through — lets test/notification_tap_routing_test.dart exercise
  /// [onMarkDoneAction]/[onReminderNotificationTap]/the pending-navigation
  /// stash via the real production code path instead of a re-implemented
  /// stand-in, without needing a live plugin/platform channel (constructing
  /// a plain [NotificationResponse] needs neither).
  @visibleForTesting
  void handleNotificationResponseForTest(NotificationResponse response) =>
      _onNotificationTap(response);

  // ── Care reminder notifications ───────────────────────────────────────────

  /// Schedules the single, exact, one-shot notification for a care
  /// reminder's real due time ([scheduledDate]). This is ONLY the "on
  /// time" notification — it does NOT start the overdue repeat cycle
  /// (there is nothing to repeat yet if the reminder isn't due). Once the
  /// due time actually passes, the caller (ReminderProvider's
  /// reconciliation) is responsible for switching to [startOverdueRepeat]
  /// instead.
  ///
  /// Also defensively cancels any overdue-repeat cycle already running
  /// under [notificationId] (id+1) — covers the case where a previously
  /// overdue reminder's due date is edited back into the future,
  /// so the old repeat cycle doesn't keep firing alongside the new
  /// one-shot.
  ///
  /// Calling this again with the same [notificationId] (e.g. on every
  /// app-start/resume reconciliation) safely REPLACES the existing
  /// one-shot rather than duplicating it — flutter_local_notifications
  /// scheduling with an existing id overwrites that id's alarm.
  ///
  /// [allowMarkDoneAction] adds a "✓ Mark Done" action button — omit it for
  /// vaccine-linked reminders, which must be completed through the
  /// vaccination dialog instead so the vaccination record stays in sync.
  Future<void> scheduleCareReminder({
    required int notificationId,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String payload,
    bool allowMarkDoneAction = true,
  }) async {
    if (!_initialized) await init();
    // Preserve the existing policy: a reminder whose due time has already
    // passed is never (re)scheduled here — it just stays "Overdue" in the
    // UI and goes through startOverdueRepeat instead.
    if (!scheduledDate.isAfter(DateTime.now())) return;

    await _plugin.cancel(notificationId + 1);

    await _zonedCare(
      id: notificationId,
      title: title,
      body: body,
      when: scheduledDate,
      payload: payload,
      allowMarkDoneAction: allowMarkDoneAction,
    );
  }

  /// Arms ONE pre-scheduled follow-up (a plain one-shot at a fixed future
  /// moment, so it fires with the app completely closed). Same channel,
  /// payload (`care:{reminderId}` → tap navigation), Mark Done action and
  /// exact-alarm mode as the due-time notification. Re-arming the same id
  /// REPLACES that alarm rather than adding a second one.
  Future<void> scheduleCareFollowUp({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    required String payload,
    bool allowMarkDoneAction = true,
  }) async {
    if (!_initialized) await init();
    if (!at.isAfter(DateTime.now())) return;
    await _zonedCare(
      id: id,
      title: title,
      body: body,
      when: at,
      payload: payload,
      allowMarkDoneAction: allowMarkDoneAction,
    );
  }

  /// One exact one-shot care notification at [when] — shared by the
  /// due-time alarm and every follow-up so they behave identically.
  Future<void> _zonedCare({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
    required bool allowMarkDoneAction,
  }) async {
    Future<void> schedule(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          id,
          title,
          body,
          _toTZ(when),
          _careDetails(allowMarkDoneAction: allowMarkDoneAction),
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );

    try {
      // alarmClock (AlarmManager.setAlarmClock) rather than
      // exactAllowWhileIdle: on the test device (Realme/ColorOS, Android
      // 13) an exactAllowWhileIdle request was still armed as a FLEXIBLE
      // alarm — a delivery window of minutes to an hour (seen in `adb shell
      // dumpsys alarm`: nonzero window, no STANDALONE flag) — so a "due at
      // 08:00" reminder could arrive late, and 5-minute-spaced follow-ups
      // could bunch together. setAlarmClock is the one exact trigger the OS
      // neither batches nor defers (it also exempts the alarm from Doze).
      // Side effect: Android may show a small alarm icon / "next alarm"
      // entry for the upcoming reminder.
      await schedule(AndroidScheduleMode.alarmClock);
    } on PlatformException catch (e) {
      // Android 12+/14+ can deny exact alarms (special "Alarms & reminders"
      // access). Fall back to an approximate alarm so the reminder still
      // fires, rather than failing to schedule anything.
      if (e.code != 'exact_alarms_not_permitted') rethrow;
      await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  /// Ensures an INDEFINITE repeat cycle is running for a care reminder that
  /// is overdue and not done: a notification every
  /// [reminderOverdueRepeatInterval], until explicitly cancelled. It is a
  /// single OS-level repeating notification (id = notificationId + 1) that
  /// keeps firing while the app is backgrounded or closed and never runs
  /// out on its own.
  ///
  /// If a cycle is ALREADY running it is left completely alone (see
  /// [shouldStartOverdueRepeat]) — re-arming resets the interval countdown
  /// to a full [reminderOverdueRepeatInterval] from now, so re-arming on
  /// every app start/resume meant a user who reopened the app at least
  /// every few minutes would never actually be notified. Pass
  /// [restartIfActive] only when the notification's CONTENT changed (a
  /// title/pet edit) and the running cycle must be replaced.
  ///
  /// Delivery timing (Android): each repeat is a chained one-shot alarm.
  /// On some devices the OS arms it as a flexible alarm, so a repeat can
  /// arrive up to a few minutes after its nominal time. If exact alarms
  /// aren't permitted at all (Android 14+ default), falls back to an
  /// approximate alarm instead of failing to schedule anything.
  Future<void> startOverdueRepeat({
    required int notificationId,
    required String title,
    required String body,
    required String payload,
    bool allowMarkDoneAction = true,
    bool restartIfActive = false,
  }) async {
    if (!_initialized) await init();

    final repeatId = notificationId + 1;
    final pending = await _plugin.pendingNotificationRequests();
    final alreadyActive = pending.any((p) => p.id == repeatId);
    if (!shouldStartOverdueRepeat(
      alreadyActive: alreadyActive,
      restartIfActive: restartIfActive,
    )) {
      return;
    }

    Future<void> start(AndroidScheduleMode mode) =>
        _plugin.periodicallyShowWithDuration(
          repeatId,
          title,
          body,
          reminderOverdueRepeatInterval,
          _careDetails(allowMarkDoneAction: allowMarkDoneAction),
          payload: payload,
          androidScheduleMode: mode,
        );

    try {
      await start(AndroidScheduleMode.exactAllowWhileIdle);
    } on PlatformException catch (e) {
      if (e.code != 'exact_alarms_not_permitted') rethrow;
      await start(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  /// Whether [startOverdueRepeat] should (re)arm the repeat cycle: yes when
  /// none is running, or when the caller explicitly asked to replace it;
  /// no when one is already running (re-arming would reset its countdown).
  /// Pure and public only so the rule is unit-tested.
  @visibleForTesting
  static bool shouldStartOverdueRepeat({
    required bool alreadyActive,
    required bool restartIfActive,
  }) =>
      !alreadyActive || restartIfActive;

  /// Cancels EVERYTHING a care reminder can have: the due-time notification
  /// (N), the overdue repeat (N+1) and all 12 pre-scheduled follow-ups
  /// (N+2..N+13) — see care_notification_plan.dart. Cancelling an id that was
  /// never scheduled is a safe no-op, so this is always safe to call. It also
  /// removes any of these notifications currently showing in the shade.
  Future<void> cancelCareReminder(int notificationId) =>
      cancelIds(allCareNotifIds(notificationId));

  /// Cancels exactly [ids] (alarm + any displayed notification).
  Future<void> cancelIds(Iterable<int> ids) async {
    for (final id in ids) {
      await _plugin.cancel(id);
    }
  }

  /// Ids the OS currently has SCHEDULED for this app, or null if that can't
  /// be read (callers then fall back to unconditional cancel/arm).
  Future<Set<int>?> pendingNotificationIds() async {
    try {
      return (await _plugin.pendingNotificationRequests())
          .map((p) => p.id)
          .toSet();
    } catch (_) {
      return null;
    }
  }

  /// Ids of this app's notifications currently DISPLAYED, or null if unknown.
  Future<Set<int>?> shownNotificationIds() async {
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final active = await android?.getActiveNotifications();
      if (active == null) return null;
      return {for (final a in active) if (a.id != null) a.id!};
    } catch (_) {
      return null;
    }
  }

  // ── Immediate notification (for testing / instant alerts) ─────────────────

  Future<void> showImmediate({
    required int notificationId,
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) await init();
    await _plugin.show(
      notificationId,
      title,
      body,
      _careDetails(),
      payload: payload,
    );
  }

  // ── Cancel all ────────────────────────────────────────────────────────────

  Future<void> cancelAll() async => _plugin.cancelAll();

  // ── List all pending ──────────────────────────────────────────────────────

  Future<List<PendingNotificationRequest>> pendingNotifications() =>
      _plugin.pendingNotificationRequests();

  // ── Helpers ───────────────────────────────────────────────────────────────

  tz.TZDateTime _toTZ(DateTime dt) => tz.TZDateTime.from(dt, tz.local);

  NotificationDetails _careDetails({bool allowMarkDoneAction = true}) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          _careChannelId,
          _careChannelName,
          channelDescription: _careChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFFFF8C69),
          enableVibration: true,
          playSound: true,
          actions: allowMarkDoneAction
              ? const [
                  AndroidNotificationAction(
                    _markDoneActionId,
                    '✓ Mark Done',
                    showsUserInterface: true,
                    cancelNotification: true,
                  ),
                ]
              : null,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          categoryIdentifier: allowMarkDoneAction ? _careCategoryId : null,
        ),
      );

  // ── ID generation helpers ─────────────────────────────────────────────────

  /// Stable int ID from a string ID (UUID). Keeps it within 32-bit int range.
  static int stableId(String id, {int base = 0}) =>
      (base + id.hashCode.abs()) % 2000000000;

  static int careNotifId(String reminderId) => stableId(reminderId, base: 3000);
}

/// The result of parsing a tapped/actioned notification's payload — see
/// [NotificationService.parseTapAction].
@visibleForTesting
class NotificationTapAction {
  final String reminderId;
  final bool isMarkDone;

  const NotificationTapAction({
    required this.reminderId,
    required this.isMarkDone,
  });
}
