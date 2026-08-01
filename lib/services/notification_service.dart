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

  // ── Channel constants ─────────────────────────────────────────────────────

  static const _vaccineChannelId = 'persipal_vaccines';
  static const _vaccineChannelName = 'Vaccination Reminders';
  static const _vaccineChannelDesc =
      'Reminds you when your cat\'s next vaccine is due';

  static const _careChannelId = 'persipal_care';
  static const _careChannelName = 'Care Reminders';
  static const _careChannelDesc =
      'Feeding, grooming, vitamin, and vet visit reminders';

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
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Request permissions (Android 13+, iOS)
    await _requestPermissions();

    _initialized = true;
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
    // Route to the relevant screen via payload when app is opened from a tap.
    // payload format: "vaccine:{petId}:{vaccineId}" or "care:{reminderId}"
    debugPrint('Notification tapped: ${response.payload}');
    // Navigation handling can be wired here via a global navigator key.
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

  /// Schedule a single care reminder (feeding, grooming, vitamins, etc.)
  Future<void> scheduleCareReminder({
    required int notificationId,
    required String title,
    required String body,
    required DateTime scheduledDate,
    required String payload,
  }) async {
    if (!_initialized) await init();
    if (scheduledDate.isBefore(DateTime.now())) return;

    await _plugin.zonedSchedule(
      notificationId,
      title,
      body,
      _toTZ(scheduledDate),
      _careDetails(),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );
  }

  Future<void> cancelCareReminder(int notificationId) async {
    await _plugin.cancel(notificationId);
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

  NotificationDetails _careDetails() => const NotificationDetails(
        android: AndroidNotificationDetails(
          _careChannelId,
          _careChannelName,
          channelDescription: _careChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          color: Color(0xFFFF8C69),
          enableVibration: true,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

  // ── ID generation helpers ─────────────────────────────────────────────────

  /// Stable int ID from a string ID (UUID). Keeps it within 32-bit int range.
  static int stableId(String id, {int base = 0}) =>
      (base + id.hashCode.abs()) % 2000000000;

  static int vaccineNotifId(String vaccId) => stableId(vaccId, base: 2000);
  static int careNotifId(String reminderId) => stableId(reminderId, base: 3000);
}
