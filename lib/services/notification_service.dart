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
// Notification ID strategy:
//   Vaccination reminders : 2000 + index (e.g. 2000, 2001, 2002 …)
//   Care reminders        : 3000 + index
//   Day-before reminders  : original id + 10000
//
// All scheduled notifications survive app restarts on Android via
// the RECEIVE_BOOT_COMPLETED permission + plugin's boot receiver.

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

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

  // ── Channel constants ─────────────────────────────────────────────────────

  static const _vaccineChannelId = 'persipal_vaccines';
  static const _vaccineChannelName = 'Vaccination Reminders';
  static const _vaccineChannelDesc =
      'Reminds you when your cat\'s next vaccine is due';

  static const _careChannelId = 'persipal_care';
  static const _careChannelName = 'Care Reminders';
  static const _careChannelDesc =
      'Feeding, grooming, vitamin, and vet visit reminders';

  static const _markDoneActionId = 'mark_done';
  static const _careCategoryId = 'persipal_care_category';

  // ── Persistent-reminder tuning ───────────────────────────────────────────
  // Centralized so the "repeat until done" cadence can be tuned in one
  // place. A care reminder that isn't marked done re-notifies every
  // [reminderRepeatInterval] for [reminderMaxRepeats] repeats after the
  // initial due-time notification, then stops on its own (never an
  // unbounded chain, to avoid notification spam).
  static const Duration reminderRepeatInterval = Duration(minutes: 30);
  static const int reminderMaxRepeats = 3;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;

    // Load timezone data (needed for scheduled notifications)
    tz_data.initializeTimeZones();

    // Try to set local timezone — fall back to UTC silently
    try {
      // On mobile the device timezone is available via the plugin
      // For simplicity we use UTC; swap in flutter_timezone package
      // if you need exact local tz:
      //   final tzName = await FlutterTimezone.getLocalTimezone();
      //   tz.setLocalLocation(tz.getLocation(tzName));
      tz.setLocalLocation(tz.UTC);
    } catch (_) {}

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

  void _onNotificationTap(NotificationResponse response) {
    // payload format: "vaccine:{petId}:{vaccineId}" or "care:{reminderId}"
    final payload = response.payload;
    if (payload == null) return;

    if (response.actionId == _markDoneActionId && payload.startsWith('care:')) {
      final reminderId = payload.substring('care:'.length);
      onMarkDoneAction?.call(reminderId);
      return;
    }

    // Plain tap (no action) — routing to the relevant screen can be wired
    // here via a global navigator key; out of scope for this phase.
    debugPrint('Notification tapped: $payload');
  }

  // ── Vaccination notifications ─────────────────────────────────────────────

  /// Schedule two notifications for a vaccination:
  ///   1. Day before at 09:00
  ///   2. On the due date at 09:00
  Future<void> scheduleVaccinationReminder({
    required int notificationId, // unique int per record
    required String petName,
    required String vaccineName,
    required DateTime scheduledDate,
    required String payload, // "vaccine:{petId}:{vaccId}"
  }) async {
    if (!_initialized) await init();

    final now = DateTime.now();

    // ── Day-before notification ───────────────────────────────────────────
    final dayBefore = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day - 1,
      9,
      0,
      0,
    );
    if (dayBefore.isAfter(now)) {
      await _plugin.zonedSchedule(
        notificationId + 10000, // day-before ID offset
        '💉 Vaccine Due Tomorrow!',
        '$petName\'s $vaccineName vaccine is scheduled for tomorrow.',
        _toTZ(dayBefore),
        _vaccineDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    }

    // ── On-day notification ───────────────────────────────────────────────
    final onDay = DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      9,
      0,
      0,
    );
    if (onDay.isAfter(now)) {
      await _plugin.zonedSchedule(
        notificationId,
        '💉 Vaccine Due Today!',
        '$petName\'s $vaccineName vaccine is due today. Visit your vet!',
        _toTZ(onDay),
        _vaccineDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    }
  }

  /// Cancel both notifications for a vaccination record.
  Future<void> cancelVaccinationReminder(int notificationId) async {
    await _plugin.cancel(notificationId);
    await _plugin.cancel(notificationId + 10000);
  }

  // ── Care reminder notifications ───────────────────────────────────────────

  /// Schedules a care reminder (feeding, grooming, vitamins, etc.) so it
  /// keeps notifying until marked done: an initial notification at
  /// [scheduledDate], then [reminderMaxRepeats] more every
  /// [reminderRepeatInterval] after that, each as its own platform-scheduled
  /// alarm (never a runtime timer/loop) so they still fire while the app is
  /// backgrounded, killed, or the device has rebooted. Calling this again
  /// with the same [notificationId] (e.g. on every app-start reconciliation)
  /// safely replaces the existing chain rather than duplicating it, since
  /// each repeat uses a stable, deterministic id.
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
    // passed is never (re)scheduled — it just stays "Overdue" in the UI.
    if (!scheduledDate.isAfter(DateTime.now())) return;

    final details = _careDetails(allowMarkDoneAction: allowMarkDoneAction);

    for (var i = 0; i <= reminderMaxRepeats; i++) {
      await _plugin.zonedSchedule(
        notificationId + i,
        title,
        i == 0 ? body : 'Still waiting — $body',
        _toTZ(scheduledDate.add(reminderRepeatInterval * i)),
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    }
  }

  /// Cancels every notification in a care reminder's repeat chain
  /// (the initial one plus all [reminderMaxRepeats] repeats). Cancelling an
  /// id that was never scheduled is a safe no-op, so this is always safe to
  /// call regardless of how many repeats actually ended up scheduled.
  Future<void> cancelCareReminder(int notificationId) async {
    for (var i = 0; i <= reminderMaxRepeats; i++) {
      await _plugin.cancel(notificationId + i);
    }
  }

  // ── Immediate notification (for testing / instant alerts) ─────────────────

  Future<void> showImmediate({
    required int notificationId,
    required String title,
    required String body,
    String? payload,
    bool isVaccine = false,
  }) async {
    if (!_initialized) await init();
    await _plugin.show(
      notificationId,
      title,
      body,
      isVaccine ? _vaccineDetails() : _careDetails(),
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

  NotificationDetails _vaccineDetails() => const NotificationDetails(
        android: AndroidNotificationDetails(
          _vaccineChannelId,
          _vaccineChannelName,
          channelDescription: _vaccineChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFF7B68EE),
          enableVibration: true,
          playSound: true,
          styleInformation: BigTextStyleInformation(''),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

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

  static int vaccineNotifId(String vaccId) => stableId(vaccId, base: 2000);
  static int careNotifId(String reminderId) => stableId(reminderId, base: 3000);
}
