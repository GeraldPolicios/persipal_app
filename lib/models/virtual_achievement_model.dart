// lib/models/virtual_achievement_model.dart
//
// Achievement badges for the VIRTUAL CAT SIMULATION only (Game/Feed/Play/
// Groom). Deliberately a separate model/enum from PetAchievement /
// AchievementType (pet_extended_models.dart) — virtual achievements are
// global to the simulation and are never associated with a real pet's
// petId. Do not merge this with the real-pet achievement system.

enum VirtualAchievementType {
  firstFeed,
  feedingFriend,
  feedingRoutine,
  firstPlay,
  playtimePal,
  playtimeRegular,
  firstGroom,
  groomingBuddy,
  fluffyRoutine,
  caringCompanion,
  dedicatedPlayer,
}

class VirtualAchievement {
  final VirtualAchievementType type;
  final String title;
  final String description;
  final String emoji;
  final bool unlocked;
  final DateTime? unlockedAt;
  final int progressCurrent;
  final int progressTarget;

  const VirtualAchievement({
    required this.type,
    required this.title,
    required this.description,
    required this.emoji,
    this.unlocked = false,
    this.unlockedAt,
    this.progressCurrent = 0,
    required this.progressTarget,
  });

  double get progressPercent => progressTarget > 0
      ? (progressCurrent / progressTarget).clamp(0.0, 1.0)
      : 0;

  VirtualAchievement copyWith({
    bool? unlocked,
    DateTime? unlockedAt,
    int? progressCurrent,
  }) =>
      VirtualAchievement(
        type: type,
        title: title,
        description: description,
        emoji: emoji,
        unlocked: unlocked ?? this.unlocked,
        unlockedAt: unlockedAt ?? this.unlockedAt,
        progressCurrent: progressCurrent ?? this.progressCurrent,
        progressTarget: progressTarget,
      );

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'unlocked': unlocked,
        'unlockedAt': unlockedAt?.toIso8601String(),
        'progressCurrent': progressCurrent,
      };

  factory VirtualAchievement.fromMap(
    Map<String, dynamic> m,
    VirtualAchievement base,
  ) {
    return base.copyWith(
      unlocked: m['unlocked'] as bool? ?? false,
      unlockedAt: m['unlockedAt'] != null
          ? DateTime.tryParse(m['unlockedAt'] as String)
          : null,
      progressCurrent: (m['progressCurrent'] as num?)?.toInt() ?? 0,
    );
  }
}

const kDefaultVirtualAchievements = [
  VirtualAchievement(
    type: VirtualAchievementType.firstFeed,
    title: 'First Feed',
    description: 'Fed the virtual cat for the first time.',
    emoji: '🥉',
    progressTarget: 1,
  ),
  VirtualAchievement(
    type: VirtualAchievementType.feedingFriend,
    title: 'Feeding Friend',
    description: 'Fed the virtual cat 15 times.',
    emoji: '🥈',
    progressTarget: 15,
  ),
  VirtualAchievement(
    type: VirtualAchievementType.feedingRoutine,
    title: 'Feeding Routine',
    description: 'Fed the virtual cat on 7 different days.',
    emoji: '🥇',
    progressTarget: 7,
  ),
  VirtualAchievement(
    type: VirtualAchievementType.firstPlay,
    title: 'First Play',
    description: 'Played with the virtual cat for the first time.',
    emoji: '🥉',
    progressTarget: 1,
  ),
  VirtualAchievement(
    type: VirtualAchievementType.playtimePal,
    title: 'Playtime Pal',
    description: 'Played with the virtual cat 15 times.',
    emoji: '🥈',
    progressTarget: 15,
  ),
  VirtualAchievement(
    type: VirtualAchievementType.playtimeRegular,
    title: 'Playtime Regular',
    description: 'Played with the virtual cat on 7 different days.',
    emoji: '🥇',
    progressTarget: 7,
  ),
  VirtualAchievement(
    type: VirtualAchievementType.firstGroom,
    title: 'First Groom',
    description: 'Groomed the virtual cat for the first time.',
    emoji: '🥉',
    progressTarget: 1,
  ),
  VirtualAchievement(
    type: VirtualAchievementType.groomingBuddy,
    title: 'Grooming Buddy',
    description: 'Groomed the virtual cat 15 times.',
    emoji: '🥈',
    progressTarget: 15,
  ),
  VirtualAchievement(
    type: VirtualAchievementType.fluffyRoutine,
    title: 'Fluffy Routine',
    description: 'Groomed the virtual cat on 7 different days.',
    emoji: '🥇',
    progressTarget: 7,
  ),
  VirtualAchievement(
    type: VirtualAchievementType.caringCompanion,
    title: 'Caring Companion',
    description: 'Fed, played with, and groomed the virtual cat at least once each.',
    emoji: '🐾',
    progressTarget: 3,
  ),
  VirtualAchievement(
    type: VirtualAchievementType.dedicatedPlayer,
    title: 'Dedicated Player',
    description: 'Reached 50 combined feed, play, and groom interactions.',
    emoji: '🌟',
    progressTarget: 50,
  ),
];
