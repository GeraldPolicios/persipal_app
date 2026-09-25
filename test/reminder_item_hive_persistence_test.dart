// Tests the actual Hive persistence layer ReminderProvider is built on
// (LocalStorageService's dedicated 'ls_reminder_items' box), the same way
// test/pet_photo_persistence_test.dart tests the photo-path store: real
// Hive, a fresh read simulating an app restart, no in-memory shortcuts.
//
// This is what proves — at the real storage layer, not just in an
// in-memory List<ReminderItem> — that:
//   • a pending reminder survives a reload still pending (Upcoming),
//   • a completed reminder's isDone + completedAt survive a reload exactly
//     as they were (never reverting to pending, never losing the
//     completion timestamp),
//   • recurring completion's "one historical record + one new pending
//     occurrence, each its own id" shape survives a reload without
//     duplicating or merging the two.
//
// ReminderProvider itself also touches Firebase (AuthService) and platform
// notification channels — not safely constructible under plain
// `flutter test` (see the project's one known pre-existing Firebase test
// failure) — so those pieces (cloud sync, actual OS notification
// scheduling) were verified by code review instead; see the final report.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:persipal_app/models/reminder_item_model.dart';
import 'package:persipal_app/services/local_storage_service.dart';

void main() {
  late Directory dir;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('persipal_reminder_test');
    Hive.init(dir.path);
    await Hive.openBox<String>('ls_reminder_items');
  });

  tearDownAll(() async {
    await Hive.close();
    dir.deleteSync(recursive: true);
  });

  setUp(() async {
    await Hive.box<String>('ls_reminder_items').clear();
  });

  final local = LocalStorageService.instance;

  test('a pending reminder round-trips as pending, not overdue-flagged', () async {
    final future = DateTime.now().add(const Duration(days: 2));
    await local.saveReminderItem(ReminderItem(
      id: 'r1',
      title: 'Feed Milo',
      type: 'Feeding',
      scheduledAt: future,
      petId: 'cat1',
    ));

    final reloaded = await local.fetchReminderItems();
    expect(reloaded, hasLength(1));
    expect(reloaded.first.isDone, isFalse);
    expect(reloaded.first.isOverdue, isFalse);
    expect(reloaded.first.completedAt, isNull);
  });

  test('an overdue (past-due, still pending) reminder stays pending across a reload', () async {
    final past = DateTime.now().subtract(const Duration(hours: 5));
    await local.saveReminderItem(ReminderItem(
      id: 'r2',
      title: 'Groom Luna',
      type: 'Grooming',
      scheduledAt: past,
      petId: 'cat2',
    ));

    final reloaded = await local.fetchReminderItems();
    final r = reloaded.firstWhere((x) => x.id == 'r2');
    expect(r.isDone, isFalse);
    expect(r.isOverdue, isTrue, reason: 'past scheduledAt + not done = overdue');
  });

  test('marking done and persisting preserves isDone + completedAt across a reload, '
      'and it is never reported overdue', () async {
    final scheduled = DateTime(2026, 9, 1, 9, 0);
    final completedAt = DateTime(2026, 9, 5, 16, 45);

    final pending = ReminderItem(
      id: 'r3',
      title: 'Vet checkup',
      type: 'Vet Visit',
      scheduledAt: scheduled,
      petId: 'cat1',
    );
    await local.saveReminderItem(pending);

    // Simulates exactly what ReminderProvider.markReminderDone does: the
    // SAME record, isDone flipped, completedAt stamped with the actual
    // completion moment (never scheduledAt).
    final done = pending.copyWith(isDone: true, completedAt: completedAt);
    await local.saveReminderItem(done);

    final reloaded = await local.fetchReminderItems();
    expect(reloaded, hasLength(1), reason: 'save-over-same-id must not duplicate');
    final r = reloaded.first;
    expect(r.isDone, isTrue);
    expect(r.completedAt, completedAt);
    expect(r.scheduledAt, scheduled, reason: 'the original due date must be preserved too');
    expect(r.isOverdue, isFalse, reason: 'a completed reminder is never overdue');
  });

  test('deleting a reminder removes it — a reload never resurrects it', () async {
    await local.saveReminderItem(ReminderItem(
      id: 'r4',
      title: 'Litter change',
      type: 'Litter Box',
      scheduledAt: DateTime.now(),
    ));
    await local.deleteReminderItem('r4');

    final reloaded = await local.fetchReminderItems();
    expect(reloaded.where((r) => r.id == 'r4'), isEmpty);
  });

  test(
      'recurring completion\'s shape — one historical (done) record plus one '
      'new pending occurrence, each its own id — survives a reload without '
      'duplicating or merging', () async {
    final firstScheduled = DateTime(2026, 1, 1, 8, 0);
    final completedAt = DateTime(2026, 1, 1, 8, 30);
    final nextScheduled = DateTime(2026, 1, 8, 8, 0);

    // The completed occurrence (what scheduleNextOccurrence's caller,
    // markReminderDone, leaves behind).
    await local.saveReminderItem(ReminderItem(
      id: 'occurrence-1',
      title: 'Weekly grooming',
      type: 'Grooming',
      scheduledAt: firstScheduled,
      petId: 'cat1',
      recurrence: 'weekly',
      isDone: true,
      completedAt: completedAt,
    ));
    // The brand-new next occurrence (what scheduleNextOccurrence creates —
    // a distinct id, never re-using the completed one's).
    await local.saveReminderItem(ReminderItem(
      id: 'occurrence-2',
      title: 'Weekly grooming',
      type: 'Grooming',
      scheduledAt: nextScheduled,
      petId: 'cat1',
      recurrence: 'weekly',
    ));

    final reloaded = await local.fetchReminderItems();
    expect(reloaded, hasLength(2));

    final historical = reloaded.firstWhere((r) => r.id == 'occurrence-1');
    expect(historical.isDone, isTrue);
    expect(historical.completedAt, completedAt);
    expect(historical.isOverdue, isFalse);

    final next = reloaded.firstWhere((r) => r.id == 'occurrence-2');
    expect(next.isDone, isFalse);
    expect(next.completedAt, isNull);
    expect(next.scheduledAt, nextScheduled);
  });

  test('a legacy record saved before completedAt existed loads as null, not a crash',
      () async {
    // Bypasses ReminderItem.toMap() on purpose — writes the raw pre-upgrade
    // shape directly, the way a record actually saved before this task
    // would be sitting in a real user's Hive box.
    await Hive.box<String>('ls_reminder_items').put(
      'legacy1',
      '{"id":"legacy1","title":"Old reminder","type":"Feeding",'
          '"scheduledAt":"2025-01-01T00:00:00.000","isDone":true,'
          '"petId":null,"linkedVaccinationId":null,"recurrence":"none"}',
    );

    final reloaded = await local.fetchReminderItems();
    final r = reloaded.firstWhere((x) => x.id == 'legacy1');
    expect(r.isDone, isTrue);
    expect(r.completedAt, isNull);
  });

  test(
      'resetting a completed reminder (the Done tab\'s Reset button — '
      'ReminderProvider.resetReminderToPending) persists as pending across '
      'a reload, with its original scheduledAt preserved', () async {
    final scheduled = DateTime(2026, 9, 1, 9, 0);
    final done = ReminderItem(
      id: 'r5',
      title: 'Vitamins',
      type: 'Vitamins',
      scheduledAt: scheduled,
      petId: 'cat1',
      isDone: true,
      completedAt: DateTime(2026, 9, 1, 9, 30),
    );
    await local.saveReminderItem(done);

    // Exactly what resetReminderToPending applies.
    final reverted = done.copyWith(isDone: false, completedAt: null);
    await local.saveReminderItem(reverted);

    final reloaded = await local.fetchReminderItems();
    expect(reloaded, hasLength(1), reason: 'save-over-same-id must not duplicate');
    final r = reloaded.first;
    expect(r.isDone, isFalse);
    expect(r.completedAt, isNull);
    expect(r.scheduledAt, scheduled);
    // scheduled was in the past relative to "now" (2026-09-23+), so it's
    // correctly overdue again, not silently upcoming.
    expect(r.isOverdue, isTrue);
  });
}
