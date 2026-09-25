// End-to-end widget test of the actual search UI (not just the pure
// searchLessons engine) — typing a query shows real results, and clearing
// the search restores the normal six-lesson grid.
//
// NOT covered here: actually tapping a tile/result through to navigation.
// Both LearnScreen's grid tap and search-result tap call
// ActivityLogService.instance.logLesson(...) before navigating — and
// ActivityLogService.instance itself throws '[core/no-app]' without a
// real Firebase app (the project's one known pre-existing Firebase test
// limitation — see test/widget_test.dart). That specific gesture is
// verified by code review instead: _openLesson's body directly maps
// hit.type/hit.sectionIndex/query to LessonDetailScreen's constructor
// arguments (see lib/screens/learn_screen.dart), and
// test/lesson_search_test.dart separately proves those exact fields are
// correct for real queries; test/lesson_access_test.dart separately
// proves LessonDetailScreen/QuizScreen open fully (no lock) once reached.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';
import 'package:persipal_app/screens/learn_screen.dart';
import 'package:persipal_app/services/lesson_progress_service.dart';
import 'package:persipal_app/services/reward_service.dart';

void main() {
  late Directory dir;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('persipal_learn_screen_test');
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
    RewardService.instance.resetInMemory();
  });

  Future<void> pumpLearnScreen(WidgetTester tester) => tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: LessonProgressService.instance),
            ChangeNotifierProvider.value(value: RewardService.instance),
          ],
          child: const MaterialApp(home: LearnScreen()),
        ),
      );

  testWidgets('typing a real content term shows matching results, not a '
      'title/category-only filter', (tester) async {
    await pumpLearnScreen(tester);
    await tester.enterText(find.byType(TextField), 'brushing');
    await tester.pump();

    expect(find.textContaining('No lesson information found'), findsNothing);
    // The Grooming group header should appear since "brushing" is real
    // Grooming content.
    expect(find.text('Grooming'), findsOneWidget);
  });

  testWidgets('an empty search restores the normal six-lesson grid, not a '
      'stale filtered state', (tester) async {
    await pumpLearnScreen(tester);
    await tester.enterText(find.byType(TextField), 'brushing');
    await tester.pump();
    expect(find.byType(GridView), findsNothing);
    expect(find.byType(ListView), findsOneWidget);

    await tester.enterText(find.byType(TextField), '');
    await tester.pump();

    // Back to the grid (GridView), not the search results ListView, and
    // at least one module tile's normal "START" badge is visible again.
    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(ListView), findsNothing);
    expect(find.text('START'), findsWidgets);
  });

  testWidgets('a nonsense query shows the exact no-results message',
      (tester) async {
    await pumpLearnScreen(tester);
    await tester.enterText(
        find.byType(TextField), 'zzzzznonexistentqueryzzzzz');
    await tester.pump();

    expect(
      find.text(
          'No lesson information found for "zzzzznonexistentqueryzzzzz".'),
      findsOneWidget,
    );
  });

  testWidgets('the first search result for "brushing" is keyed and present '
      '(reachable/tappable) — confirms the results list actually renders '
      'real, individually-targetable rows', (tester) async {
    await pumpLearnScreen(tester);
    await tester.enterText(find.byType(TextField), 'brushing');
    await tester.pump();

    expect(find.byKey(const ValueKey('search_result_0')), findsOneWidget);
  });
}
