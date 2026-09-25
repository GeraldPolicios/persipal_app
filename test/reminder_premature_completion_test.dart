// Tests two related fixes:
//   1. A reminder can no longer be marked done before its own scheduledAt
//      arrives (ReminderItem.isDue / ReminderProvider.markReminderDone &
//      completeReminderOccurrence's guards, and ReminderScreen no longer
//      offering the Done button at all for a not-yet-due reminder).
//   2. "Reset the Done history": ReminderProvider.wasCompletedPrematurely
//      is the pure detection rule _correctPrematureCompletions uses to
//      find and revert exactly the reminders that bug produced —
//      completedAt earlier than scheduledAt, a state impossible under
//      correct behavior — without touching any legitimately-completed
//      history. Pulled out as its own public function specifically so
//      this rule is unit-testable without a live ReminderProvider (not
//      safely constructible under plain `flutter test` — see the
//      project's one known pre-existing Firebase test limitation).

import 'package:flutter_test/flutter_test.dart';
import 'package:persipal_app/models/reminder_item_model.dart';
import 'package:persipal_app/providers/reminder_provider.dart';

ReminderItem _item({
  bool isDone = false,
  DateTime? completedAt,
  required DateTime scheduledAt,
}) =>
    ReminderItem(
      id: 'r1',
      title: 'Feed Milo',
      type: 'Feeding',
      scheduledAt: scheduledAt,
      isDone: isDone,
      completedAt: completedAt,
    );

void main() {
  group('wasCompletedPrematurely', () {
    test('flags a reminder completed before its own scheduled time — the '
        'exact bug scenario ("next month marked as done")', () {
      final scheduledNextMonth = DateTime.now().add(const Duration(days: 30));
      final r = _item(
        isDone: true,
        completedAt: DateTime.now(), // completed today
        scheduledAt: scheduledNextMonth, // due a month from now
      );
      expect(ReminderProvider.wasCompletedPrematurely(r), isTrue);
    });

    test('does not flag a legitimately completed reminder (completed at '
        'or after its scheduled time)', () {
      final scheduled = DateTime.now().subtract(const Duration(hours: 1));
      final r = _item(
        isDone: true,
        completedAt: DateTime.now(), // completed after it was due
        scheduledAt: scheduled,
      );
      expect(ReminderProvider.wasCompletedPrematurely(r), isFalse);
    });

    test('does not flag a reminder completed at exactly its scheduled '
        'instant', () {
      final at = DateTime(2026, 9, 1, 9, 0);
      final r = _item(isDone: true, completedAt: at, scheduledAt: at);
      expect(ReminderProvider.wasCompletedPrematurely(r), isFalse);
    });

    test('never flags a pending (not done) reminder, regardless of dates',
        () {
      final r = _item(
        isDone: false,
        scheduledAt: DateTime.now().add(const Duration(days: 30)),
      );
      expect(ReminderProvider.wasCompletedPrematurely(r), isFalse);
    });

    test('never flags a legacy completed record with no completedAt — '
        'there is nothing to compare, so it is left alone rather than '
        'guessed at', () {
      final r = _item(
        isDone: true,
        completedAt: null,
        scheduledAt: DateTime.now().add(const Duration(days: 30)),
      );
      expect(ReminderProvider.wasCompletedPrematurely(r), isFalse);
    });
  });

  group('reverting a premature completion restores correct pending state',
      () {
    test('copyWith(isDone: false, completedAt: null) — what '
        '_correctPrematureCompletions actually applies — clears both '
        'flags and leaves the original scheduledAt untouched', () {
      final scheduled = DateTime.now().add(const Duration(days: 30));
      final bad = _item(
        isDone: true,
        completedAt: DateTime.now(),
        scheduledAt: scheduled,
      );
      expect(ReminderProvider.wasCompletedPrematurely(bad), isTrue);

      final reverted = bad.copyWith(isDone: false, completedAt: null);
      expect(reverted.isDone, isFalse);
      expect(reverted.completedAt, isNull);
      expect(reverted.scheduledAt, scheduled);
      expect(reverted.isDue, isFalse, reason: 'still correctly not due yet');
      expect(ReminderProvider.wasCompletedPrematurely(reverted), isFalse);
    });
  });
}
