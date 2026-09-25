// Tests the notification-tap navigation fix (Requirement 1): a plain tap
// on a care-reminder notification must open the exact reminder it came
// from, a "Mark Done" action tap must complete that exact reminder, and
// neither must ever create a new reminder.
//
// NotificationService.parseTapAction is a pure function split out of the
// private _onNotificationTap specifically so this payload/action parsing
// is unit-testable without a live plugin/platform channel (constructing a
// plain flutter_local_notifications NotificationResponse needs neither).
// handleNotificationResponseForTest exercises the exact same dispatch a
// real plugin tap goes through (still the real, private _onNotificationTap
// underneath — not a re-implemented stand-in), so the
// onMarkDoneAction/onReminderNotificationTap wiring and the restart-safe
// pending-navigation stash are all covered through production code.
//
// What ISN'T (and can't be) covered here: the plugin actually delivering a
// tap/action callback, cold-start launch-details detection, and real OS
// notification scheduling/cancellation — those need a real device/plugin
// and were verified by code review; see the final report.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:persipal_app/services/notification_service.dart';

NotificationResponse _tap({String? payload, String? actionId}) =>
    NotificationResponse(
      notificationResponseType: actionId == null
          ? NotificationResponseType.selectedNotification
          : NotificationResponseType.selectedNotificationAction,
      payload: payload,
      actionId: actionId,
    );

void main() {
  group('NotificationService.parseTapAction (pure payload parsing)', () {
    test('a plain tap on a care: payload identifies the exact reminder', () {
      final action = NotificationService.parseTapAction('care:reminder-42', null);
      expect(action, isNotNull);
      expect(action!.reminderId, 'reminder-42');
      expect(action.isMarkDone, isFalse);
    });

    test('a Mark Done action tap on a care: payload is flagged isMarkDone', () {
      final action =
          NotificationService.parseTapAction('care:reminder-42', 'mark_done');
      expect(action, isNotNull);
      expect(action!.reminderId, 'reminder-42');
      expect(action.isMarkDone, isTrue);
    });

    test('a recurring occurrence\'s fresh id (not the completed one\'s) is '
        'what gets parsed out', () {
      // scheduleNextOccurrence always mints a brand-new id per occurrence —
      // this just confirms parsing doesn't special-case/truncate it.
      final action = NotificationService.parseTapAction(
          'care:1234567890123-next-occurrence', null);
      expect(action!.reminderId, '1234567890123-next-occurrence');
    });

    test('a null payload parses to null (no action)', () {
      expect(NotificationService.parseTapAction(null, null), isNull);
    });

    test('a non-"care:" payload parses to null rather than being '
        'misinterpreted as a reminder id', () {
      expect(NotificationService.parseTapAction('vaccine:cat1:v1', null), isNull);
      expect(NotificationService.parseTapAction('garbage', null), isNull);
    });

    test('"care:" with nothing after it parses to null instead of an '
        'empty-string reminder id', () {
      expect(NotificationService.parseTapAction('care:', null), isNull);
    });
  });

  group('NotificationService dispatch (via the real private handler)', () {
    setUp(() {
      NotificationService.onMarkDoneAction = null;
      NotificationService.onReminderNotificationTap = null;
      // Drain anything left pending from a previous test.
      NotificationService.instance.consumePendingReminderNavigation();
    });

    test('a Mark Done action tap calls onMarkDoneAction with the exact '
        'reminder id, and never onReminderNotificationTap', () {
      String? completedId;
      var navCalls = 0;
      NotificationService.onMarkDoneAction = (id) => completedId = id;
      NotificationService.onReminderNotificationTap = (_) => navCalls++;

      NotificationService.instance
          .handleNotificationResponseForTest(_tap(
        payload: 'care:reminder-7',
        actionId: 'mark_done',
      ));

      expect(completedId, 'reminder-7');
      expect(navCalls, 0,
          reason: 'Mark Done must never also trigger navigation/creation');
      // Nothing should be left pending — it was fully handled live.
      expect(NotificationService.instance.consumePendingReminderNavigation(),
          isNull);
    });

    test('a plain tap with a live onReminderNotificationTap wired calls it '
        'immediately with the exact reminder id, and never Mark Done', () {
      String? openedId;
      var markDoneCalls = 0;
      NotificationService.onReminderNotificationTap = (id) => openedId = id;
      NotificationService.onMarkDoneAction = (_) => markDoneCalls++;

      NotificationService.instance
          .handleNotificationResponseForTest(_tap(payload: 'care:reminder-9'));

      expect(openedId, 'reminder-9');
      expect(markDoneCalls, 0);
    });

    test(
        'a plain tap ALWAYS stashes the id first (restart-safe), even when '
        'a live callback is also wired and handles it', () {
      NotificationService.onReminderNotificationTap = (_) {};
      NotificationService.instance
          .handleNotificationResponseForTest(_tap(payload: 'care:reminder-9'));

      // The live callback already "handled" it, but nothing consumed the
      // stash — this mirrors main.dart's own callback, which explicitly
      // consumes it once it takes over. Here we just confirm it was there.
      expect(NotificationService.instance.consumePendingReminderNavigation(),
          'reminder-9');
    });

    test(
        'a plain tap with NO live onReminderNotificationTap wired (the '
        'cold-start window, before runApp()) only stashes — it is not lost',
        () {
      // onReminderNotificationTap left null by setUp — simulates
      // consumeStartupAction() running before runApp() in main.dart.
      NotificationService.instance
          .handleNotificationResponseForTest(_tap(payload: 'care:reminder-cold-start'));

      expect(NotificationService.instance.consumePendingReminderNavigation(),
          'reminder-cold-start');
      // Consuming clears it — a second read must not "re-deliver" the same
      // stale navigation.
      expect(NotificationService.instance.consumePendingReminderNavigation(),
          isNull);
    });

    test('an unrecognized payload triggers neither callback', () {
      var markDoneCalls = 0;
      var navCalls = 0;
      NotificationService.onMarkDoneAction = (_) => markDoneCalls++;
      NotificationService.onReminderNotificationTap = (_) => navCalls++;

      NotificationService.instance
          .handleNotificationResponseForTest(_tap(payload: 'vaccine:cat1:v1'));

      expect(markDoneCalls, 0);
      expect(navCalls, 0);
      expect(NotificationService.instance.consumePendingReminderNavigation(),
          isNull);
    });
  });
}
