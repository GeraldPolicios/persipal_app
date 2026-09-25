// lib/services/lesson_progress_service.dart
//
// Tracks which Learn Cat Care topics the user has actually completed.
// Mirrors the exact singleton/ChangeNotifier/LocalStorageService pattern
// already used by ActivityLogService/ActivityService/VirtualAchievementService
// — the smallest persistence addition the existing architecture needs,
// not a new database or external service.
//
// Binary state only (completed / not completed) — there is no supported
// "in progress" granularity, matching LessonDetailScreen's single explicit
// completion point (the "Mark as Complete" button).

import 'package:flutter/foundation.dart';
import 'local_storage_service.dart';

class LessonProgressService extends ChangeNotifier {
  LessonProgressService._();
  static final LessonProgressService instance = LessonProgressService._();

  final _local = LocalStorageService.instance;

  Set<String> _completed = {};

  Set<String> get completedTypes => Set.unmodifiable(_completed);

  bool isCompleted(String type) => _completed.contains(type);

  /// Display/learning-topic order. Every lesson is immediately accessible
  /// regardless of this order or of any other lesson's completion state —
  /// PersiPal's lessons are reference information a user may need right
  /// away, so access was deliberately never gated on progress (see
  /// LearnScreen/LessonDetailScreen/QuizScreen, none of which check
  /// completion before opening a lesson or its quiz). This list exists
  /// purely for consistent display ordering and iteration (e.g. "every
  /// known lesson type", tests), not for any unlock sequencing.
  static const order = [
    'feeding',
    'grooming',
    'behavior',
    'vitamins',
    'health',
    'environment',
  ];

  /// Adds lessons completed on another device / restored from the cloud.
  Future<void> mergeCompleted(Iterable<String> types) async {
    final extra = types.where((t) => !_completed.contains(t)).toSet();
    if (extra.isEmpty) return;
    _completed = {..._completed, ...extra};
    await _local.saveCompletedLessonTypes(_completed);
    notifyListeners();
  }

  Future<void> init() async {
    _completed = (await _local.fetchCompletedLessonTypes()).toSet();
    notifyListeners();
  }

  /// Marks [type] as completed. Idempotent — a lesson already marked
  /// complete is left untouched (no redundant write, no extra notify), so
  /// repeatedly reviewing a completed lesson never re-triggers this.
  /// Forgets all in-memory completion state. The persisted copy lives in
  /// LocalStorageService's settings box, which LocalStorageService.clearAll()
  /// already wipes — this just keeps the in-memory copy from outliving it.
  void resetInMemory() {
    if (_completed.isEmpty) return;
    _completed = {};
    notifyListeners();
  }

  /// Discards local completion state AND persists the empty state (unlike
  /// [resetInMemory]). Used by "Use Cloud Data" during guest→account sign-in
  /// so a guest's local lesson progress can never silently survive next to,
  /// or get merged into, the account's real cloud progress — call this,
  /// then let RewardService.syncProgress() pull the account's actual state.
  Future<void> discardLocal() async {
    _completed = {};
    await _local.saveCompletedLessonTypes(_completed);
    notifyListeners();
  }

  Future<void> markCompleted(String type) async {
    if (_completed.contains(type)) return;
    _completed = {..._completed, type};
    await _local.saveCompletedLessonTypes(_completed);
    notifyListeners();
  }
}
