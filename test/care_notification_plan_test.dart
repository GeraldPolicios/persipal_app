// Tests the closed-app follow-up chain for reminder notifications
// (lib/services/care_notification_plan.dart): a pending reminder gets its
// exact due-time alarm PLUS 12 fixed-time follow-ups (every 5 minutes for
// 1 hour), so it keeps notifying with PersiPal completely closed.
//
// The plan is pure, so a tiny fake "OS" (id -> fire time) applies plans the
// same way ReminderProvider executes them, letting each lifecycle rule —
// cancel, Mark Done, edit, Reset, recurrence, repeated reconciliation — be
// checked end to end. What ISN'T covered here (needs a device): the OS
// actually delivering the alarms; verified on a phone with
// `adb shell dumpsys alarm`.

import 'package:flutter_test/flutter_test.dart';
import 'package:persipal_app/services/care_notification_plan.dart';
import 'package:persipal_app/services/notification_service.dart';

/// Stand-in for what the OS has armed: alarm id -> when it fires. The
/// endless overdue repeat is recorded with a null time.
class FakeOs {
  final Map<int, DateTime?> armed = {};

  void apply(CareNotificationPlan plan, int n) {
    for (final id in plan.cancelIds) {
      armed.remove(id);
    }
    if (plan.dueAt != null) armed[n] = plan.dueAt; // re-arming replaces
    for (final f in plan.followUps) {
      armed[f.id] = f.at; // same id => replaced, never duplicated
    }
    if (plan.ensureRepeat) armed.putIfAbsent(repeatNotifId(n), () => null);
  }

  /// Mark Done / delete: NotificationService.cancelCareReminder cancels
  /// allCareNotifIds(n).
  void cancelAll(int n) {
    for (final id in allCareNotifIds(n)) {
      armed.remove(id);
    }
  }

  Set<int> get ids => armed.keys.toSet();
}

CareNotificationPlan plan(
  int n, {
  required DateTime now,
  required DateTime due,
  bool done = false,
  bool enabled = true,
  bool chain = true,
  bool replace = true,
  Set<int>? pending,
  Set<int>? shown,
}) =>
    planCareNotifications(
      notificationId: n,
      now: now,
      scheduledAt: due,
      isDone: done,
      notificationsEnabled: enabled,
      chainAllowed: chain,
      replaceExisting: replace,
      pendingIds: pending,
      shownIds: shown,
    );

void main() {
  final now = DateTime(2026, 9, 24, 22, 40);
  final due = DateTime(2026, 9, 24, 22, 46);
  const n = 100000;

  group('1–2. follow-up timestamps and count', () {
    test('12 follow-ups, every 5 minutes for 1 hour after the due time', () {
      final p = plan(n, now: now, due: due);
      expect(p.followUps, hasLength(12));
      expect(kFollowUpCount, 12);
      expect(kFollowUpInterval, const Duration(minutes: 5));
      // The worked example from the requirement: due 22:46 ->
      // 22:51, 22:56, 23:01, ... 23:46.
      expect(p.followUps.first.at, DateTime(2026, 9, 24, 22, 51));
      expect(p.followUps[1].at, DateTime(2026, 9, 24, 22, 56));
      expect(p.followUps[2].at, DateTime(2026, 9, 24, 23, 1));
      expect(p.followUps.last.at, DateTime(2026, 9, 24, 23, 46));
      for (var k = 0; k < 12; k++) {
        expect(p.followUps[k].at, due.add(Duration(minutes: 5 * (k + 1))));
      }
    });

    test('the due-time alarm is still armed, at the due time', () {
      expect(plan(n, now: now, due: due).dueAt, due);
    });

    test('never more than 12 follow-ups, however far in the future the '
        'reminder is', () {
      final far = now.add(const Duration(days: 400));
      expect(plan(n, now: now, due: far).followUps.length, lessThanOrEqualTo(12));
    });

    test('only follow-ups that are still in the future are armed (none in '
        'the past)', () {
      // Due 5 minutes from now, but "now" is later than the first follow-up
      // of an earlier-due reminder: simulate by an already-overdue-by-3min
      // reminder is the overdue case; here a future reminder always has all
      // 12 future.
      final p = plan(n, now: now, due: now.add(const Duration(minutes: 1)));
      expect(p.followUps.every((f) => f.at.isAfter(now)), isTrue);
    });
  });

  group('3–4. deterministic, non-colliding ids', () {
    test('a reminder owns exactly 14 distinct consecutive ids: due, repeat, '
        '12 follow-ups', () {
      final ids = allCareNotifIds(n);
      expect(ids, hasLength(14));
      expect(ids.toSet(), hasLength(14));
      expect(ids.first, n); // due
      expect(repeatNotifId(n), n + 1);
      expect(followUpNotifIds(n), [for (var i = 2; i <= 13; i++) n + i]);
      expect(kCareIdsPerReminder, 14);
    });

    test('ids are deterministic — the same reminder id always maps to the '
        'same set', () {
      final a = NotificationService.careNotifId('1758000000000001');
      final b = NotificationService.careNotifId('1758000000000001');
      expect(a, b);
      expect(allCareNotifIds(a), allCareNotifIds(b));
    });

    test('follow-up ids are within the 32-bit notification id range', () {
      for (final rid in ['a', 'b', '1758000000000001', 'x' * 60]) {
        final id = NotificationService.careNotifId(rid);
        for (final f in allCareNotifIds(id)) {
          expect(f, inInclusiveRange(0, 2147483647));
        }
      }
    });

    test('different reminders cannot collide — ids for many realistic '
        'reminders (timestamp-style and uuid-style) never overlap', () {
      final ids = <String>[
        for (var i = 0; i < 300; i++)
          (1758000000000000 + i * 7919).toString(), // microsecond-style
        for (var i = 0; i < 100; i++) 'f47ac10b-58cc-4372-a567-0e02b2c3d${i.toString().padLeft(3, '0')}',
      ];
      final owner = <int, String>{};
      for (final rid in ids) {
        for (final id
            in allCareNotifIds(NotificationService.careNotifId(rid))) {
          final prev = owner[id];
          expect(prev == null || prev == rid, isTrue,
              reason: 'id $id owned by both "$prev" and "$rid"');
          owner[id] = rid;
        }
      }
    });
  });

  group('5–6. cancelling a reminder / Mark Done cancels every notification',
      () {
    test('after arming, cancelAll leaves nothing — due, repeat and all 12 '
        'follow-ups', () {
      final os = FakeOs();
      os.apply(plan(n, now: now, due: due), n);
      expect(os.ids.length, 13); // due + 12 follow-ups
      os.cancelAll(n);
      expect(os.ids, isEmpty);
    });

    test('Mark Done also cancels an ACTIVE overdue repeat', () {
      final os = FakeOs();
      final later = due.add(const Duration(minutes: 10));
      os.apply(plan(n, now: later, due: due), n); // overdue -> repeat
      expect(os.ids, contains(repeatNotifId(n)));
      os.cancelAll(n);
      expect(os.ids, isEmpty);
    });

    test('a done reminder\'s plan cancels all 14 ids and arms nothing', () {
      final p = plan(n, now: now, due: due, done: true);
      expect(p.cancelIds.toSet(), allCareNotifIds(n).toSet());
      expect(p.dueAt, isNull);
      expect(p.followUps, isEmpty);
      expect(p.ensureRepeat, isFalse);
    });

    test('a done reminder reconciled with a known OS state cancels exactly '
        'the ids that are scheduled or showing — no wasted calls for a '
        'long history of completed reminders', () {
      final p = plan(n,
          now: now,
          due: due,
          done: true,
          replace: false,
          pending: {n + 3, n + 4},
          shown: {n + 1});
      expect(p.cancelIds.toSet(), {n + 1, n + 3, n + 4});

      final nothing = plan(n,
          now: now, due: due, done: true, replace: false, pending: {}, shown: {});
      expect(nothing.cancelIds, isEmpty);
    });

    test('notifications switched off in Settings cancels everything too',
        () {
      final p = plan(n, now: now, due: due, enabled: false);
      expect(p.cancelIds.toSet(), allCareNotifIds(n).toSet());
      expect(p.followUps, isEmpty);
    });
  });

  group('7. Reset recreates the chain', () {
    test('done -> pending again restores the due alarm and all 12 '
        'follow-ups', () {
      final os = FakeOs();
      os.apply(plan(n, now: now, due: due), n);
      os.cancelAll(n); // marked done
      expect(os.ids, isEmpty);

      // Reset: back to pending, same due time (still in the future).
      os.apply(plan(n, now: now, due: due, replace: true), n);
      expect(os.ids.length, 13);
      expect(os.armed[n], due);
      expect(os.armed[followUpNotifId(n, 12)], DateTime(2026, 9, 24, 23, 46));
    });
  });

  group('8. editing a reminder replaces the old chain', () {
    test('a new future time re-times every follow-up on the same ids — no '
        'old alarm is left behind and none is duplicated', () {
      final os = FakeOs();
      os.apply(plan(n, now: now, due: due), n);
      final newDue = DateTime(2026, 9, 25, 8, 0);
      os.apply(plan(n, now: now, due: newDue, replace: true), n);

      expect(os.ids.length, 13); // still exactly one chain
      expect(os.armed[n], newDue);
      for (var k = 1; k <= 12; k++) {
        expect(os.armed[followUpNotifId(n, k)],
            newDue.add(Duration(minutes: 5 * k)));
      }
      // Nothing left at the old times.
      expect(os.armed.values.any((t) => t == due), isFalse);
    });

    test('editing a future reminder to a time that is already past cancels '
        'the old due alarm and chain and hands over to the repeat', () {
      final os = FakeOs();
      os.apply(plan(n, now: now, due: due), n);
      final pastDue = now.subtract(const Duration(minutes: 10));
      os.apply(plan(n, now: now, due: pastDue, replace: true), n);

      expect(os.armed.containsKey(n), isFalse); // old due alarm gone
      for (final id in followUpNotifIds(n)) {
        expect(os.armed.containsKey(id), isFalse);
      }
      expect(os.ids, {repeatNotifId(n)});
    });

    test('editing to a nearer time drops follow-ups that would now be in the '
        'past (no stale alarm stays armed)', () {
      // Only possible when the new due is past; covered above. Here: the
      // plan for an overdue reminder cancels every follow-up id.
      final p = plan(n,
          now: now, due: now.subtract(const Duration(minutes: 1)));
      expect(p.cancelIds.toSet(),
          {n, ...followUpNotifIds(n)});
    });
  });

  group('9. recurrence never reuses the completed occurrence\'s ids', () {
    test('the next occurrence (a new reminder id) gets its own id block; '
        'cancelling the completed one cannot touch it', () {
      final oldN = NotificationService.careNotifId('1758000000000001');
      final newN = NotificationService.careNotifId('1758000086400009');
      expect(allCareNotifIds(oldN).toSet().intersection(allCareNotifIds(newN).toSet()),
          isEmpty);

      final os = FakeOs();
      os.apply(plan(oldN, now: now, due: due), oldN);
      // Occurrence completed: cancel its set, create the next one.
      os.cancelAll(oldN);
      final nextDue = due.add(const Duration(days: 1));
      os.apply(plan(newN, now: now, due: nextDue), newN);

      expect(os.ids.intersection(allCareNotifIds(oldN).toSet()), isEmpty);
      expect(os.armed[newN], nextDue);
      expect(os.ids.length, 13);

      // Cancelling the OLD occurrence again (e.g. a stale duplicate Mark
      // Done) leaves the new occurrence's chain fully intact.
      os.cancelAll(oldN);
      expect(os.ids.length, 13);
    });
  });

  group('10. repeated reconciliation never duplicates a chain', () {
    test('re-running with the same pending reminder and a known OS state '
        'arms nothing new', () {
      final os = FakeOs();
      os.apply(plan(n, now: now, due: due), n); // created
      final before = Map<int, DateTime?>.of(os.armed);

      for (var i = 0; i < 5; i++) {
        final p = plan(n,
            now: now, due: due, replace: false, pending: os.ids);
        expect(p.dueAt, isNull);
        expect(p.followUps, isEmpty);
        os.apply(p, n);
      }
      expect(os.armed, before);
    });

    test('reconciliation re-arms ONLY what went missing (e.g. after the OS '
        'dropped some alarms)', () {
      final os = FakeOs();
      os.apply(plan(n, now: now, due: due), n);
      final lost = {n + 4, n + 9};
      lost.forEach(os.armed.remove);

      final p = plan(n, now: now, due: due, replace: false, pending: os.ids);
      expect(p.followUps.map((f) => f.id).toSet(), lost);
      expect(p.dueAt, isNull);
      os.apply(p, n);
      expect(os.ids.length, 13);
    });

    test('with the OS state unknown, everything is armed — and because ids '
        'are fixed, arming twice still yields exactly one chain', () {
      final os = FakeOs();
      final p = plan(n, now: now, due: due, replace: false, pending: null);
      os.apply(p, n);
      os.apply(p, n);
      expect(os.ids.length, 13);
    });
  });

  group('overdue boundary — the endless repeat takes over', () {
    test('a reminder already overdue gets the repeat and NO follow-ups', () {
      final p = plan(n, now: now, due: now.subtract(const Duration(minutes: 3)));
      expect(p.ensureRepeat, isTrue);
      expect(p.followUps, isEmpty);
      expect(p.dueAt, isNull);
    });

    test('due exactly now is treated as overdue (no due alarm in the past)',
        () {
      final p = plan(n, now: now, due: now);
      expect(p.ensureRepeat, isTrue);
      expect(p.dueAt, isNull);
    });

    test('opening the app mid-chain: pending follow-ups are cancelled and '
        'the repeat starts — the two never both notify', () {
      final os = FakeOs();
      os.apply(plan(n, now: now, due: due), n);
      // 22:48 — the due alarm has fired (no longer armed) and the app opens.
      os.armed.remove(n);
      final opened = DateTime(2026, 9, 24, 22, 48);
      final p = plan(n,
          now: opened, due: due, replace: false, pending: os.ids);
      os.apply(p, n);
      expect(os.ids, {repeatNotifId(n)});
    });

    test('reconciling an overdue reminder whose repeat already runs leaves '
        'it alone (does not re-arm)', () {
      final os = FakeOs()..armed[repeatNotifId(n)] = null;
      final p = plan(n,
          now: now.add(const Duration(hours: 5)),
          due: due,
          replace: false,
          pending: os.ids);
      expect(p.ensureRepeat, isTrue); // ensure, not restart
      expect(p.cancelIds, isEmpty);
    });
  });

  group('follow-up chain budget (Android alarm limit)', () {
    test('only the soonest kMaxChainedReminders pending reminders are '
        'chained', () {
      final pending = [
        for (var i = 0; i < 50; i++)
          (id: 'r$i', scheduledAt: now.add(Duration(hours: i + 1))),
      ];
      final chosen = pickChainedReminderIds(pending, now);
      expect(chosen, hasLength(kMaxChainedReminders));
      expect(chosen.contains('r0'), isTrue);
      expect(chosen.contains('r${kMaxChainedReminders - 1}'), isTrue);
      expect(chosen.contains('r$kMaxChainedReminders'), isFalse);
    });

    test('a reminder whose whole hour has already passed no longer takes a '
        'slot', () {
      final chosen = pickChainedReminderIds([
        (id: 'old', scheduledAt: now.subtract(const Duration(hours: 3))),
        (id: 'soon', scheduledAt: now.add(const Duration(minutes: 5))),
      ], now);
      expect(chosen, {'soon'});
    });

    test('a reminder outside the budget gets no follow-ups and has any '
        'pending ones cancelled', () {
      final p = plan(n,
          now: now,
          due: due,
          chain: false,
          replace: false,
          pending: {n + 2, n + 3});
      expect(p.followUps, isEmpty);
      expect(p.cancelIds, containsAll([n + 2, n + 3]));
      expect(p.dueAt, due); // the due-time alarm itself is never skipped
    });
  });
}
