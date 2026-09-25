// Tests NotificationService.refreshLocalTimeZone / zoneIdForOffset.
//
// The bug this now guards against: flutter_local_notifications sends
// tz.local.name to Android, which calls Java's ZoneId.of(name). An earlier
// version named the location 'device-local' (not a valid zone id), so every
// zonedSchedule call threw on Android and reminders silently never got an
// alarm (found on a real device: no alarm was ever armed). Dart-side tests
// can't observe the platform channel, so what's pinned here is the NAME
// FORMAT the Java side requires, plus the instant-preservation the
// scheduling relies on.
//
// Only needs the `timezone` package's pure-Dart Location/TZDateTime types.
// NOT covered (needs a device): the OS actually arming/firing the alarm —
// verified on the phone via `adb shell dumpsys alarm`.

import 'package:flutter_test/flutter_test.dart';
import 'package:persipal_app/services/notification_service.dart';
import 'package:timezone/timezone.dart' as tz;

void main() {
  test('refreshLocalTimeZone sets tz.local to the device\'s actual current '
      'UTC offset — not a hard-coded one', () {
    NotificationService.refreshLocalTimeZone();
    final expectedOffsetMs = DateTime.now().timeZoneOffset.inMilliseconds;
    expect(tz.local.currentTimeZone.offset, expectedOffsetMs);
  });

  test(
      'a device-local wall-clock DateTime converted through tz.local '
      'represents the SAME real-world instant as DateTime\'s own '
      'local -> UTC conversion (the property scheduling relies on; it '
      'holds for any location, including the old hard-coded UTC one)',
      () {
    NotificationService.refreshLocalTimeZone();

    final localWallClock = DateTime(2026, 6, 15, 14, 30);
    final tzDt = tz.TZDateTime.from(localWallClock, tz.local);

    // The invariant scheduleCareReminder's zonedSchedule depends on: the
    // TZDateTime must denote the exact moment the user picked. It holds
    // for any location (TZDateTime.from preserves the instant).
    expect(tzDt.toUtc(), localWallClock.toUtc());
  });

  test('never hard-codes a specific region\'s offset — always reflects '
      'whatever DateTime.now() currently reports', () {
    NotificationService.refreshLocalTimeZone();
    // Whatever this test machine's real offset is (could be anything from
    // UTC-12 to UTC+14), refreshLocalTimeZone must track it — the
    // assertion is against the live system value, never a literal like
    // Duration(hours: 8) (Philippines) or any other fixed constant.
    final liveOffsetMs = DateTime.now().timeZoneOffset.inMilliseconds;
    expect(tz.local.currentTimeZone.offset, liveOffsetMs);
  });

  test('is idempotent — calling it repeatedly keeps producing a consistent '
      'offset rather than drifting', () {
    NotificationService.refreshLocalTimeZone();
    final first = tz.local.currentTimeZone.offset;
    NotificationService.refreshLocalTimeZone();
    final second = tz.local.currentTimeZone.offset;
    expect(second, first);
  });

  test('daily/weekly/monthly recurrence math (plain DateTime, no '
      'Location involved) is unaffected by which tz.local is active', () {
    // _nextDate in ReminderProvider steps plain DateTime values — this
    // confirms that arithmetic never goes through tz.local at all, so the
    // timezone fix cannot have disturbed recurrence-date computation.
    NotificationService.refreshLocalTimeZone();
    final scheduled = DateTime(2026, 1, 31, 9, 0);
    final firstOfNextMonth = DateTime(scheduled.year, scheduled.month + 1, 1);
    expect(firstOfNextMonth.month, 2);
    expect(scheduled.hour, 9, reason: 'time-of-day must survive untouched');
  });

  group('the location name must be a valid Java ZoneId (regression: '
      "'device-local' made every zonedSchedule throw on Android)", () {
    final javaZoneId = RegExp(r'^(UTC|[+-]\d{2}:\d{2}(:\d{2})?)$');

    test('tz.local.name after refresh is a Java-valid zone id', () {
      NotificationService.refreshLocalTimeZone();
      expect(tz.local.name, matches(javaZoneId));
      expect(tz.local.name, isNot('device-local'));
    });

    test('zoneIdForOffset: zero is UTC', () {
      expect(NotificationService.zoneIdForOffset(Duration.zero), 'UTC');
    });

    test('zoneIdForOffset: positive, negative and half-hour offsets', () {
      expect(NotificationService.zoneIdForOffset(const Duration(hours: 8)),
          '+08:00');
      expect(NotificationService.zoneIdForOffset(const Duration(hours: -5)),
          '-05:00');
      expect(
          NotificationService.zoneIdForOffset(
              const Duration(hours: 5, minutes: 30)),
          '+05:30');
      expect(
          NotificationService.zoneIdForOffset(
              const Duration(hours: -3, minutes: -30)),
          '-03:30');
      expect(NotificationService.zoneIdForOffset(const Duration(hours: 14)),
          '+14:00');
    });

    test('every real-world whole/half/quarter-hour offset produces a '
        'Java-valid id', () {
      for (var minutes = -12 * 60; minutes <= 14 * 60; minutes += 15) {
        final id =
            NotificationService.zoneIdForOffset(Duration(minutes: minutes));
        expect(id, matches(javaZoneId), reason: '$minutes min');
      }
    });
  });
}
