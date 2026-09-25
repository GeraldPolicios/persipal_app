// Tests Part 1 (lesson locking removed) and the "progress still works"
// requirement (Part 9) together: every lesson and its quiz must open with
// zero completions, and LessonProgressService's own persistence must be
// unaffected by removing the unlock gate.
//
// Widget-level checks construct LessonDetailScreen/QuizScreen directly
// (not the full app) — both build() methods only touch
// LessonProgressService/RewardService/ActivityLogService on an explicit
// user action (Mark Complete / finishing the quiz), never during a plain
// build, so pumping them needs no Firebase app and is safe under plain
// `flutter test` (see the project's one known pre-existing Firebase test
// failure in test/widget_test.dart, which happens for exactly the
// opposite reason — building the FULL app).

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:persipal_app/models/lesson_content_model.dart';
import 'package:persipal_app/screens/lesson_detail_screen.dart';
import 'package:persipal_app/screens/quiz_screen.dart';
import 'package:persipal_app/services/lesson_progress_service.dart';

void main() {
  late Directory dir;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('persipal_lesson_access_test');
    Hive.init(dir.path);
    await Hive.openBox<String>('ls_settings');
  });

  tearDownAll(() async {
    await Hive.close();
    dir.deleteSync(recursive: true);
  });

  setUp(() async {
    await Hive.box<String>('ls_settings').clear();
    LessonProgressService.instance.resetInMemory();
  });

  Future<void> pump(WidgetTester tester, Widget child) =>
      tester.pumpWidget(MaterialApp(home: child));

  group('Part 1 — every lesson opens with zero completions', () {
    for (final type in kLessonTypes) {
      testWidgets('$type: no lock message, real content is shown',
          (tester) async {
        expect(LessonProgressService.instance.isCompleted(type), isFalse);

        await pump(tester, LessonDetailScreen(type: type));
        await tester.pump();

        expect(find.textContaining('locked'), findsNothing);
        expect(find.textContaining('🔒'), findsNothing);
        expect(find.text(lessonTitle(type)), findsOneWidget);
        // At least the lesson's first InfoSection title is rendered —
        // real content, not a stub. (ListView only mounts elements near
        // the viewport, so this checks content close to the top; the
        // "Mark as Complete" button further down is confirmed reachable
        // by scrolling in a dedicated test below.)
        final firstInfo = lessonSectionsFor(type).whereType<InfoSection>().first;
        expect(find.text(firstInfo.title), findsOneWidget);
      });
    }

    testWidgets(
        'the LAST lesson in the list (environment) opens fully with zero '
        'other lessons completed — the exact "later lesson" scenario',
        (tester) async {
      for (final t in LessonProgressService.order) {
        expect(LessonProgressService.instance.isCompleted(t), isFalse,
            reason: t);
      }
      await pump(tester, const LessonDetailScreen(type: 'environment'));
      await tester.pump();
      expect(find.text(lessonTitle('environment')), findsOneWidget);
      expect(find.textContaining('locked'), findsNothing);
    });

    testWidgets(
        'scrolling all the way down reaches a real, enabled "Mark as '
        'Complete" button — never a locked/blocked state', (tester) async {
      await pump(tester, const LessonDetailScreen(type: 'feeding'));
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Mark as Complete'),
        300,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Mark as Complete'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(find.ancestor(
        of: find.text('Mark as Complete'),
        matching: find.byType(ElevatedButton),
      ));
      expect(button.onPressed, isNotNull, reason: 'must not be disabled');
    });
  });

  group('Part 9 — every lesson\'s quiz is reachable with zero completions',
      () {
    for (final type in kLessonTypes) {
      testWidgets('$type quiz: no lock message, a real question is shown',
          (tester) async {
        await pump(tester, QuizScreen(topic: type));
        await tester.pump();

        expect(find.textContaining('locked'), findsNothing);
        expect(find.textContaining('🔒'), findsNothing);
        // The quiz's own progress indicator ("1 / N") proves a real
        // question set loaded rather than an empty/blocked screen.
        expect(find.textContaining('1 / '), findsOneWidget);
      });
    }
  });

  group('Part 9 — lesson completion/progress persistence still works', () {
    test('markCompleted persists across a fresh load (simulated restart)',
        () async {
      final p = LessonProgressService.instance;
      expect(p.isCompleted('environment'), isFalse);

      await p.markCompleted('environment');
      expect(p.isCompleted('environment'), isTrue);

      // A brand-new read, exactly like a real app restart.
      p.resetInMemory();
      expect(p.isCompleted('environment'), isFalse); // in-memory only, so far
      await p.init();
      expect(p.isCompleted('environment'), isTrue);
    });

    test('marking one lesson complete does not mark any other lesson '
        'complete', () async {
      final p = LessonProgressService.instance;
      await p.markCompleted('feeding');
      for (final t in LessonProgressService.order.skip(1)) {
        expect(p.isCompleted(t), isFalse, reason: t);
      }
    });

    test('markCompleted is idempotent — completing an already-completed '
        'lesson again does not error or duplicate', () async {
      final p = LessonProgressService.instance;
      await p.markCompleted('health');
      await p.markCompleted('health');
      expect(p.isCompleted('health'), isTrue);
      expect(p.completedTypes.where((t) => t == 'health').length, 1);
    });
  });
}
