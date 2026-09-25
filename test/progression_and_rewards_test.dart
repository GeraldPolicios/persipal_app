import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:persipal_app/models/lesson_content_model.dart';
import 'package:persipal_app/services/lesson_progress_service.dart';
import 'package:persipal_app/services/reward_service.dart';

void main() {
  late Directory dir;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('persipal_test');
    Hive.init(dir.path);
    await Hive.openBox<String>('ls_settings');
  });

  tearDownAll(() async {
    await Hive.close();
    dir.deleteSync(recursive: true);
  });

  setUp(() async {
    await Hive.box<String>('ls_settings').clear();
    RewardService.instance.resetInMemory();
    LessonProgressService.instance.resetInMemory();
  });

  group('lesson access (no locking)', () {
    test('every lesson is immediately accessible with zero completions', () {
      final p = LessonProgressService.instance;
      for (final t in LessonProgressService.order) {
        expect(p.isCompleted(t), isFalse, reason: t);
      }
      // There is no unlock-gating method left on the service at all —
      // access was never conditional on anything reachable here.
    });

    test('completing one lesson has no bearing on any other lesson\'s '
        'accessibility — completion is tracked, never gates', () async {
      final p = LessonProgressService.instance;
      await p.markCompleted('feeding');
      expect(p.isCompleted('feeding'), isTrue);
      expect(p.isCompleted('grooming'), isFalse);
      expect(p.isCompleted('environment'), isFalse);
      // Completing the first lesson doesn't imply anything about whether
      // later ones are reachable — that's a screen-level (no-guard)
      // property, exercised directly in test/lesson_access_test.dart.
    });
  });

  group('reward-unlock ledger (a spending mechanic, unrelated to access)',
      () {
    // RewardService.claimLessonUnlock/isLessonUnlockClaimed remain in the
    // points ledger for backward compatibility with already-persisted
    // data, even though no UI offers "unlock early" anymore (every lesson
    // is already open) — this just confirms the underlying spend-once
    // ledger semantics themselves still work correctly in isolation.
    test('a claim spends points once and cannot be claimed twice', () async {
      final r = RewardService.instance;
      expect(await r.claimLessonUnlock('health'), isFalse); // no points yet
      await r.awardOnce('test:big', RewardService.lessonUnlockCost);
      expect(await r.claimLessonUnlock('health'), isTrue);
      expect(r.isLessonUnlockClaimed('health'), isTrue);
      expect(await r.claimLessonUnlock('health'), isFalse); // no double claim
      expect(r.points, 0);
    });
  });

  group('reward points', () {
    test('a one-time activity is only paid once', () async {
      final r = RewardService.instance;
      expect(await r.awardOnce('lesson:feeding', 10), 10);
      expect(await r.awardOnce('lesson:feeding', 10), 0);
      expect(r.points, 10);
    });

    test('quiz retakes only pay for beating the best score', () async {
      final r = RewardService.instance;
      expect(await r.awardQuiz(4), 13); // 5 + 2*4
      expect(await r.awardQuiz(3), 0);
      expect(await r.awardQuiz(4), 0);
      expect(await r.awardQuiz(5), 2); // improvement only
      expect(r.points, 15);
    });

    test('virtual-cat points are capped per day', () async {
      final r = RewardService.instance;
      final day = DateTime(2026, 9, 20);
      for (var i = 0; i < 9; i++) {
        await r.awardVirtualAction(now: day);
      }
      expect(r.points, RewardService.virtualDailyCap);
      await r.awardVirtualAction(now: day.add(const Duration(days: 1)));
      expect(r.points, RewardService.virtualDailyCap + 1);
    });

    test('points survive a reload from storage', () async {
      final r = RewardService.instance;
      await r.awardOnce('care:abc', 3);
      r.resetInMemory();
      expect(r.points, 0);
      await r.init();
      expect(r.points, 3);
    });
  });

  group('quiz questions per lesson (QZ-4)', () {
    test('every topic has at least one real, non-fabricated question', () {
      for (final t in LessonProgressService.order) {
        final qs = quizScenarioQuestionsFor(t);
        expect(qs, isNotEmpty, reason: t);
        for (final q in qs) {
          expect(q.question.trim(), isNotEmpty, reason: t);
          expect(q.options.length, greaterThanOrEqualTo(2), reason: t);
          expect(q.correctIndex, inInclusiveRange(0, q.options.length - 1),
              reason: t);
          expect(q.explanation.trim(), isNotEmpty, reason: t);
        }
      }
    });

    test('reward points are scoped per topic, not shared globally', () async {
      final r = RewardService.instance;
      // Completing one topic's quiz must not block rewards for a
      // DIFFERENT topic's quiz, even with a lower raw score.
      expect(await r.awardQuiz(4, topic: 'feeding'), greaterThan(0));
      expect(await r.awardQuiz(1, topic: 'health'), greaterThan(0));
      // But retaking the SAME topic without improving pays nothing.
      expect(await r.awardQuiz(1, topic: 'health'), 0);
    });
  });

  group('lesson search text', () {
    test('every lesson exposes searchable content from its own data', () {
      for (final t in LessonProgressService.order) {
        expect(lessonSearchText(t).trim(), isNotEmpty, reason: t);
      }
    });

    test('finds content that is really in the lesson', () {
      expect(lessonSearchText('feeding').toLowerCase(), contains('carnivore'));
      expect(lessonSearchText('grooming').toLowerCase(), contains('brush'));
    });
  });
}
