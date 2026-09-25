// Pins the overdue-repeat rule found on a real phone: NotificationService.
// startOverdueRepeat used to re-arm the repeating notification on EVERY app
// start/resume, and re-arming resets the countdown to a full interval — so
// anyone who reopened the app more often than the interval was never
// actually notified. The rule now: only arm when none is running, unless
// the caller says the notification's content changed.
//
// The decision is a pure function so it is testable without a plugin
// channel; what the OS then does with the alarm (armed, delivered, on
// time) can only be checked on a device and was verified with
// `adb shell dumpsys alarm` — see the final report.

import 'package:flutter_test/flutter_test.dart';
import 'package:persipal_app/services/notification_service.dart';

void main() {
  group('shouldStartOverdueRepeat', () {
    test('starts a cycle when none is running', () {
      expect(
        NotificationService.shouldStartOverdueRepeat(
            alreadyActive: false, restartIfActive: false),
        isTrue,
      );
    });

    test('LEAVES a running cycle alone on plain reconciliation — the fix: '
        'reopening the app must not reset the countdown', () {
      expect(
        NotificationService.shouldStartOverdueRepeat(
            alreadyActive: true, restartIfActive: false),
        isFalse,
      );
    });

    test('replaces a running cycle only when the content changed '
        '(add/edit/reset/cloud update pass restartIfActive)', () {
      expect(
        NotificationService.shouldStartOverdueRepeat(
            alreadyActive: true, restartIfActive: true),
        isTrue,
      );
    });

    test('still starts when none is running even if a restart was asked '
        'for', () {
      expect(
        NotificationService.shouldStartOverdueRepeat(
            alreadyActive: false, restartIfActive: true),
        isTrue,
      );
    });
  });
}
