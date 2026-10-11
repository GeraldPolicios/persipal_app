import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'activity_log_service.dart';
import 'reward_service.dart';

class AppAchievement {
  final String id, title, description, emoji, category;
  final ActionType actionType;
  final int target, coins;
  const AppAchievement(
      {required this.id,
      required this.title,
      required this.description,
      required this.emoji,
      required this.category,
      required this.actionType,
      required this.target,
      required this.coins});
}

/// App-wide milestones based on the persisted activity log. These are separate
/// from virtual-cat XP and real-pet profile achievements. Coins use RewardService's
/// persistent one-time ledger, so reopening the app cannot pay the same badge twice.
class AppAchievementService extends ChangeNotifier {
  AppAchievementService._();
  static final AppAchievementService instance = AppAchievementService._();
  final _logs = ActivityLogService.instance;
  final _rewards = RewardService.instance;
  bool _initialized = false;
  List<AppAchievement> get achievements => _definitions;
  int get totalCount => _definitions.length;
  int get unlockedCount => _definitions.where(isUnlocked).length;

  static const _milestones = <(ActionType, String, String, String, List<int>)>[
    (
      ActionType.feed,
      'Care Giver',
      'Feed real pets',
      '🍽️',
      [1, 3, 5, 10, 20, 30, 50, 75, 100, 150, 200]
    ),
    (
      ActionType.groom,
      'Fresh & Fluffy',
      'Groom real pets',
      '🧼',
      [1, 3, 5, 10, 20, 30, 50, 75, 100, 150, 200]
    ),
    (
      ActionType.play,
      'Playtime Pro',
      'Play with real pets',
      '🎾',
      [1, 3, 5, 10, 20, 30, 50, 75, 100, 150, 200]
    ),
    (
      ActionType.lesson,
      'Cat Care Learner',
      'Open or complete lessons',
      '📚',
      [1, 3, 5, 10, 15, 20, 30, 40, 50, 75, 100]
    ),
    (
      ActionType.quiz,
      'Quiz Whiz',
      'Complete quizzes',
      '🧠',
      [1, 3, 5, 10, 15, 20, 30, 40, 50, 75, 100]
    ),
    (
      ActionType.reminder,
      'Routine Keeper',
      'Create or complete reminders',
      '⏰',
      [1, 3, 5, 10, 20, 30, 50, 75, 100, 150, 200]
    ),
    (
      ActionType.growth,
      'Growing Together',
      'Record pet growth entries',
      '📈',
      [1, 3, 5, 10, 15, 20, 30, 40, 50, 75, 100]
    ),
    (
      ActionType.profile,
      'Pet Parent',
      'Manage pet profiles',
      '🐾',
      [1, 2, 3, 5, 8, 10, 15, 20, 30, 40, 50]
    ),
  ];
  static final List<AppAchievement> _definitions = _buildDefinitions();

  static List<AppAchievement> _buildDefinitions() {
    final result = <AppAchievement>[];

    // Eight core app activity categories with ten milestones each = 80.
    // Equal coverage prevents one category from receiving almost all badges.
    for (final group in _milestones) {
      final (type, name, verb, emoji, targets) = group;
      for (var i = 0; i < 10; i++) {
        final target = targets[i];
        final index = i + 1;
        result.add(AppAchievement(
          id: 'app_${type.name}_$target',
          title: index == 1 ? 'First $name' : '$name $index',
          description: '$verb ${target == 1 ? 'once' : '$target times'}.',
          emoji: emoji,
          category: type.name,
          actionType: type,
          target: target,
          coins: target <= 3
              ? 10
              : target <= 10
                  ? 20
                  : target <= 30
                      ? 35
                      : target <= 75
                          ? 50
                          : 75,
        ));
      }
    }

    // Nine additional milestones cover other app-wide activity types.
    // 80 core milestones + 9 extras = exactly 89 app-wide achievements.
    const extras = <(ActionType, String, String, String, int, int)>[
      (
        ActionType.health,
        'Health Watcher',
        'Record health activity',
        '❤️',
        1,
        15
      ),
      (
        ActionType.health,
        'Health Advocate',
        'Record health activity',
        '❤️',
        5,
        35
      ),
      (
        ActionType.vaccination,
        'Vaccine Tracker',
        'Log vaccination activity',
        '💉',
        1,
        15
      ),
      (
        ActionType.vaccination,
        'Vaccination Champion',
        'Log vaccination activity',
        '💉',
        5,
        35
      ),
      (
        ActionType.login,
        'Welcome Back',
        'Record account activity',
        '👋',
        1,
        15
      ),
      (
        ActionType.login,
        'Persipal Regular',
        'Record account activity',
        '👋',
        5,
        35
      ),
      (
        ActionType.sync,
        'Connected Companion',
        'Synchronize app data',
        '☁️',
        1,
        15
      ),
      (ActionType.sync, 'Cloud Keeper', 'Synchronize app data', '☁️', 5, 35),
      (
        ActionType.other,
        'Activity Starter',
        'Record general app activity',
        '✨',
        1,
        15
      ),
    ];

    for (final extra in extras) {
      final (type, title, description, emoji, target, coins) = extra;
      result.add(AppAchievement(
        id: 'app_${type.name}_$target',
        title: title,
        description: '$description ${target == 1 ? 'once' : '$target times'}.',
        emoji: emoji,
        category: type.name,
        actionType: type,
        target: target,
        coins: coins,
      ));
    }

    assert(result.length == 89, 'Expected exactly 89 app-wide achievements.');
    return List<AppAchievement>.unmodifiable(result);
  }

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _logs.addListener(_onLogsChanged);
    await _evaluate();
  }

  void disposeService() => _logs.removeListener(_onLogsChanged);
  void _onLogsChanged() => unawaited(_evaluate());
  int progress(AppAchievement a) =>
      _logs.logs.where((l) => l.actionType == a.actionType).length;
  bool isUnlocked(AppAchievement a) =>
      _rewards.hasAwardKey('achievement:app:${a.id}') ||
      progress(a) >= a.target;
  Future<void> _evaluate() async {
    var changed = false;
    for (final a in _definitions) {
      if (progress(a) >= a.target) {
        final paid =
            await _rewards.awardOnce('achievement:app:${a.id}', a.coins);
        if (paid > 0) changed = true;
      }
    }
    if (changed || _initialized) notifyListeners();
  }
}
