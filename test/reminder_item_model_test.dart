// Model-level tests for the reminder-system fixes: ReminderItem.completedAt
// (added so completion can be timestamped separately from scheduledAt — see
// the Done-tab date filter in reminder_screen.dart) and the isOverdue/
// isDone invariants the rest of the lifecycle depends on. Pure Dart, no
// Hive/Firebase/platform channel involved.

import 'package:flutter_test/flutter_test.dart';
import 'package:persipal_app/models/reminder_item_model.dart';

ReminderItem _pending({DateTime? scheduledAt, String recurrence = 'none'}) =>
    ReminderItem(
      id: 'r1',
      title: 'Feed Milo',
      type: 'Feeding',
      scheduledAt: scheduledAt ?? DateTime.now().add(const Duration(hours: 1)),
      recurrence: recurrence,
    );

void main() {
  group('completedAt', () {
    test('defaults to null for a brand-new (pending) reminder', () {
      final r = _pending();
      expect(r.completedAt, isNull);
      expect(r.isDone, isFalse);
    });

    test('copyWith sets completedAt independently of scheduledAt', () {
      final scheduled = DateTime(2026, 9, 1, 9, 0);
      final completed = DateTime(2026, 9, 5, 14, 30);
      final r = _pending(scheduledAt: scheduled)
          .copyWith(isDone: true, completedAt: completed);

      // The exact scenario the task's requirement spells out: scheduled
      // Sept 1, completed Sept 5 — the two must never collapse into one.
      expect(r.scheduledAt, scheduled);
      expect(r.completedAt, completed);
      expect(r.isDone, isTrue);
    });

    test('copyWith without completedAt leaves the existing value untouched',
        () {
      final completed = DateTime(2026, 1, 1);
      final r = _pending().copyWith(isDone: true, completedAt: completed);
      final r2 = r.copyWith(title: 'Feed Milo (renamed)');
      expect(r2.completedAt, completed);
    });

    test('copyWith can explicitly clear completedAt back to null', () {
      final r = _pending()
          .copyWith(isDone: true, completedAt: DateTime(2026, 1, 1));
      final cleared = r.copyWith(completedAt: null);
      expect(cleared.completedAt, isNull);
    });

    test('toMap/fromMap round-trips completedAt', () {
      final completed = DateTime(2026, 3, 14, 8, 5);
      final r = _pending().copyWith(isDone: true, completedAt: completed);
      final restored = ReminderItem.fromMap(r.toMap());
      expect(restored.completedAt, completed);
      expect(restored.isDone, isTrue);
    });

    test('toMap stores null for a pending reminder\'s completedAt', () {
      final r = _pending();
      expect(r.toMap()['completedAt'], isNull);
    });

    test(
        'fromMap parses a pre-existing record with no completedAt key as '
        'null, not a crash', () {
      final legacyMap = {
        'id': 'legacy1',
        'title': 'Old record',
        'type': 'Feeding',
        'scheduledAt': DateTime(2025, 1, 1).toIso8601String(),
        'isDone': true,
        // no 'completedAt' key at all — simulates a record saved before
        // this field existed.
      };
      final restored = ReminderItem.fromMap(legacyMap);
      expect(restored.completedAt, isNull);
      expect(restored.isDone, isTrue);
    });

    test('fromMap tolerates a malformed completedAt string', () {
      final map = _pending().toMap();
      map['completedAt'] = 'not-a-date';
      final restored = ReminderItem.fromMap(map);
      expect(restored.completedAt, isNull);
    });
  });

  group('isOverdue', () {
    test('a future, pending reminder is not overdue', () {
      final r = _pending(
          scheduledAt: DateTime.now().add(const Duration(days: 1)));
      expect(r.isOverdue, isFalse);
    });

    test('a past, pending reminder is overdue', () {
      final r = _pending(
          scheduledAt: DateTime.now().subtract(const Duration(hours: 1)));
      expect(r.isOverdue, isTrue);
    });

    test('a completed reminder is never overdue, even if its scheduled '
        'time is in the past', () {
      final r = _pending(
        scheduledAt: DateTime.now().subtract(const Duration(days: 3)),
      ).copyWith(isDone: true, completedAt: DateTime.now());
      expect(r.isOverdue, isFalse);
    });
  });

  group('isDue — the "can this be marked done right now" rule', () {
    test('a future-scheduled reminder is not due', () {
      final r = _pending(
          scheduledAt: DateTime.now().add(const Duration(days: 1)));
      expect(r.isDue, isFalse);
    });

    test('an overdue (past-scheduled) reminder is due', () {
      final r = _pending(
          scheduledAt: DateTime.now().subtract(const Duration(hours: 1)));
      expect(r.isDue, isTrue);
    });

    test('a reminder scheduled for right now is due (inclusive boundary)',
        () {
      final now = DateTime.now();
      final r = _pending(scheduledAt: now);
      // isDue is evaluated against "now" at call time, which has moved on
      // by microseconds — still never in the future relative to `now`.
      expect(r.isDue, isTrue);
    });

    test('isDue is the exact logical inverse of "not yet due" used to '
        'gate the Done button/completion', () {
      final future = _pending(
          scheduledAt: DateTime.now().add(const Duration(minutes: 5)));
      final overdue = _pending(
          scheduledAt: DateTime.now().subtract(const Duration(minutes: 5)));
      expect(future.isDue, isFalse);
      expect(overdue.isDue, isTrue);
    });
  });

  group('petId / linkedVaccinationId sentinel clearing (regression guard)',
      () {
    test('copyWith(completedAt: ...) does not accidentally disturb petId',
        () {
      final r = _pending().copyWith(petId: 'cat1');
      final done = r.copyWith(isDone: true, completedAt: DateTime.now());
      expect(done.petId, 'cat1');
    });
  });
}
