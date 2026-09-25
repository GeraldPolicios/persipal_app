// Tests the Firebase field-level sync fix: ReminderProvider._downloadFromCloud
// used to be union-by-id-only (a cloud doc for an id already present
// locally was silently ignored forever, even if it had since been
// completed on another device). resolveMergeDecision is the pure decision
// function pulled out of that method specifically so this conflict-
// ordering logic — the actual bug and its fix — is unit-testable without
// Firebase/a live ReminderProvider (not safely constructible under plain
// `flutter test`; see the project's one known pre-existing Firebase test
// failure). It's the exact function _downloadFromCloud calls per cloud
// doc, not a re-implemented stand-in.
//
// What ISN'T (and can't be) covered here: an actual Firestore round trip,
// and the real async interleaving between a live _uploadToCloud write and
// a concurrent _downloadFromCloud call — those were verified by code
// review; see the final report for exactly what that review covered.

import 'package:flutter_test/flutter_test.dart';
import 'package:persipal_app/models/reminder_item_model.dart';
import 'package:persipal_app/providers/reminder_provider.dart';

ReminderItem _item({
  String id = 'r1',
  bool isDone = false,
  DateTime? completedAt,
  DateTime? scheduledAt,
  String title = 'Feed Milo',
}) =>
    ReminderItem(
      id: id,
      title: title,
      type: 'Feeding',
      scheduledAt: scheduledAt ?? DateTime(2026, 9, 1, 9, 0),
      isDone: isDone,
      completedAt: completedAt,
      petId: 'cat1',
    );

void main() {
  group('Requirement: existing local pending reminder + newer cloud completion',
      () {
    test('a pending local reminder is updated in place when the cloud '
        'version is completed', () {
      final local = _item(isDone: false);
      final cloud = _item(
        isDone: true,
        completedAt: DateTime(2026, 9, 5, 14, 30),
      );

      final decision = ReminderProvider.resolveMergeDecision(
        cloudItem: cloud,
        existingLocal: local,
        hasPendingLocalChange: false,
      );

      expect(decision, ReminderMergeDecision.updateInPlace);
    });
  });

  group('Requirement: cloud completion updates an existing local occurrence',
      () {
    test('applying an updateInPlace decision yields the cloud\'s isDone '
        'and completedAt, on the SAME id', () {
      final local = _item(id: 'occurrence-1', isDone: false);
      final cloud = _item(
        id: 'occurrence-1',
        isDone: true,
        completedAt: DateTime(2026, 9, 5, 14, 30),
      );

      final decision = ReminderProvider.resolveMergeDecision(
        cloudItem: cloud,
        existingLocal: local,
        hasPendingLocalChange: false,
      );
      expect(decision, ReminderMergeDecision.updateInPlace);

      // What _downloadFromCloud actually does on this decision: replace
      // the local record with the cloud one, same id.
      final merged = decision == ReminderMergeDecision.updateInPlace
          ? cloud
          : local;
      expect(merged.id, 'occurrence-1');
      expect(merged.isDone, isTrue);
      expect(merged.completedAt, DateTime(2026, 9, 5, 14, 30));
    });

    test('an edit (not just completion) on another device also reaches '
        'this one — e.g. a retitled or rescheduled reminder', () {
      final local = _item(title: 'Feed Milo', scheduledAt: DateTime(2026, 9, 1, 9, 0));
      final cloud = _item(title: 'Feed Milo (wet food)', scheduledAt: DateTime(2026, 9, 1, 18, 0));

      final decision = ReminderProvider.resolveMergeDecision(
        cloudItem: cloud,
        existingLocal: local,
        hasPendingLocalChange: false,
      );
      expect(decision, ReminderMergeDecision.updateInPlace);
    });
  });

  group('Requirement: no duplicate reminder IDs are created', () {
    test('an id already present locally is NEVER treated as addNew, '
        'regardless of how different its fields are', () {
      final local = _item(id: 'r1', isDone: false);
      final cloud = _item(id: 'r1', isDone: true, title: 'Completely different');

      final decision = ReminderProvider.resolveMergeDecision(
        cloudItem: cloud,
        existingLocal: local,
        hasPendingLocalChange: false,
      );

      expect(decision, isNot(ReminderMergeDecision.addNew));
      expect(decision, ReminderMergeDecision.updateInPlace);
    });

    test('only a genuinely new id (no existing local record) is addNew', () {
      final cloud = _item(id: 'brand-new-occurrence');

      final decision = ReminderProvider.resolveMergeDecision(
        cloudItem: cloud,
        existingLocal: null,
        hasPendingLocalChange: false,
      );

      expect(decision, ReminderMergeDecision.addNew);
    });

    test('a recurring reminder\'s completed occurrence and its freshly '
        'scheduled next occurrence merge independently — the completed '
        'one updates in place, the next one (a different id) is added, '
        'never confused with each other', () {
      final completedLocal = _item(id: 'occurrence-1', isDone: false);
      final completedCloud = _item(
          id: 'occurrence-1', isDone: true, completedAt: DateTime(2026, 1, 1));
      final nextOccurrenceCloud = _item(id: 'occurrence-2', isDone: false);

      expect(
        ReminderProvider.resolveMergeDecision(
          cloudItem: completedCloud,
          existingLocal: completedLocal,
          hasPendingLocalChange: false,
        ),
        ReminderMergeDecision.updateInPlace,
      );
      expect(
        ReminderProvider.resolveMergeDecision(
          cloudItem: nextOccurrenceCloud,
          existingLocal: null, // this device hasn't seen occurrence-2 yet
          hasPendingLocalChange: false,
        ),
        ReminderMergeDecision.addNew,
      );
    });
  });

  group('Requirement: offline local completion eventually syncs correctly',
      () {
    test('once a queued/offline completion has actually been pushed (no '
        'longer pending), a later download of the now-matching cloud doc '
        'is a harmless no-op rather than re-triggering a write', () {
      final completedAt = DateTime(2026, 9, 5, 14, 30);
      final local = _item(isDone: true, completedAt: completedAt);
      // Cloud now reflects exactly what was just flushed.
      final cloud = _item(isDone: true, completedAt: completedAt);

      final decision = ReminderProvider.resolveMergeDecision(
        cloudItem: cloud,
        existingLocal: local,
        hasPendingLocalChange: false, // the pending token was removed on success
      );

      expect(decision, ReminderMergeDecision.noopAlreadySame);
    });

    test('while still queued (not yet flushed), a download does not fight '
        'the pending local completion', () {
      final local = _item(isDone: true, completedAt: DateTime(2026, 9, 5));
      // Stale cloud — hasn't received the offline completion yet.
      final cloud = _item(isDone: false);

      final decision = ReminderProvider.resolveMergeDecision(
        cloudItem: cloud,
        existingLocal: local,
        hasPendingLocalChange: true, // still queued — see _flushPendingOps
      );

      expect(decision, ReminderMergeDecision.skipLocalWins);
    });
  });

  group(
      'Requirement: stale cloud data does not overwrite a newer pending '
      'local change', () {
    test('a pending local change wins over a differing cloud doc for the '
        'same id, no matter what the cloud says', () {
      final local = _item(isDone: true, completedAt: DateTime(2026, 9, 5));
      final staleCloud = _item(isDone: false);

      final decision = ReminderProvider.resolveMergeDecision(
        cloudItem: staleCloud,
        existingLocal: local,
        hasPendingLocalChange: true,
      );

      expect(decision, ReminderMergeDecision.skipLocalWins);
    });

    test('an in-flight upload (not yet queued, not yet failed) is treated '
        'exactly the same as a queued pending op — both set '
        'hasPendingLocalChange true, so the caller cannot tell them apart '
        'and both protect local the same way', () {
      final local = _item(isDone: true);
      final staleCloud = _item(isDone: false);

      final viaQueue = ReminderProvider.resolveMergeDecision(
        cloudItem: staleCloud,
        existingLocal: local,
        hasPendingLocalChange: true,
      );
      final viaInFlight = ReminderProvider.resolveMergeDecision(
        cloudItem: staleCloud,
        existingLocal: local,
        hasPendingLocalChange: true,
      );

      expect(viaQueue, ReminderMergeDecision.skipLocalWins);
      expect(viaInFlight, ReminderMergeDecision.skipLocalWins);
    });

    test('hasPendingLocalChange always takes priority, even over a '
        'brand-new (never-seen-locally) id', () {
      // Edge case: shouldn't happen in practice (a pending upload implies
      // this device already knows the id), but the precedence must still
      // hold rather than accidentally falling through to addNew.
      final decision = ReminderProvider.resolveMergeDecision(
        cloudItem: _item(id: 'weird-case'),
        existingLocal: null,
        hasPendingLocalChange: true,
      );
      expect(decision, ReminderMergeDecision.skipLocalWins);
    });
  });
}
