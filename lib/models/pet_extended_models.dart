// lib/models/pet_extended_models.dart
//
// Sub-models for the extended Pet Profile module:
//   • GrowthEntry      — monthly weight / growth notes
//   • VaccinationRecord — vaccine history + next schedule
//   • PetAchievement   — badge system
//   • FullPetModel     — extends PetModel with all profile fields

import 'package:flutter/material.dart';

// ─── GrowthEntry ──────────────────────────────────────────────────────────────

class GrowthEntry {
  final String id;
  final double weightKg;
  final String notes;
  final DateTime recordedAt;

  const GrowthEntry({
    required this.id,
    required this.weightKg,
    this.notes = '',
    required this.recordedAt,
  });

  GrowthEntry copyWith({
    double? weightKg,
    String? notes,
    DateTime? recordedAt,
  }) =>
      GrowthEntry(
        id: id,
        weightKg: weightKg ?? this.weightKg,
        notes: notes ?? this.notes,
        recordedAt: recordedAt ?? this.recordedAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'weightKg': weightKg,
        'notes': notes,
        'recordedAt': recordedAt.toIso8601String(),
      };

  factory GrowthEntry.fromMap(Map<String, dynamic> m) => GrowthEntry(
        id: m['id'] as String,
        weightKg: (m['weightKg'] as num?)?.toDouble() ?? 0,
        notes: m['notes'] as String? ?? '',
        recordedAt: DateTime.tryParse(m['recordedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

// ─── VaccinationRecord ────────────────────────────────────────────────────────

class VaccinationRecord {
  final String id;
  final String vaccineName;
  final DateTime completedDate;
  final DateTime? nextSchedule;
  final String vetNotes;
  final bool reminderEnabled;

  const VaccinationRecord({
    required this.id,
    required this.vaccineName,
    required this.completedDate,
    this.nextSchedule,
    this.vetNotes = '',
    this.reminderEnabled = false,
  });

  bool get isUpcoming =>
      nextSchedule != null && nextSchedule!.isAfter(DateTime.now());

  bool get isOverdue =>
      nextSchedule != null && nextSchedule!.isBefore(DateTime.now());

  VaccinationRecord copyWith({
    String? vaccineName,
    DateTime? completedDate,
    DateTime? nextSchedule,
    String? vetNotes,
    bool? reminderEnabled,
  }) =>
      VaccinationRecord(
        id: id,
        vaccineName: vaccineName ?? this.vaccineName,
        completedDate: completedDate ?? this.completedDate,
        nextSchedule: nextSchedule ?? this.nextSchedule,
        vetNotes: vetNotes ?? this.vetNotes,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'vaccineName': vaccineName,
        'completedDate': completedDate.toIso8601String(),
        'nextSchedule': nextSchedule?.toIso8601String(),
        'vetNotes': vetNotes,
        'reminderEnabled': reminderEnabled,
      };

  factory VaccinationRecord.fromMap(Map<String, dynamic> m) =>
      VaccinationRecord(
        id: m['id'] as String,
        vaccineName: m['vaccineName'] as String? ?? '',
        completedDate: DateTime.tryParse(m['completedDate'] as String? ?? '') ??
            DateTime.now(),
        nextSchedule: m['nextSchedule'] != null
            ? DateTime.tryParse(m['nextSchedule'] as String)
            : null,
        vetNotes: m['vetNotes'] as String? ?? '',
        reminderEnabled: m['reminderEnabled'] as bool? ?? false,
      );
}

// ─── AchievementType ──────────────────────────────────────────────────────────

enum AchievementType {
  feedStreak,
  groomStreak,
  playStreak,
  vaccinationComplete,
  firstProfile,
  quizMaster,
  weeklyPlayer,
}

class PetAchievement {
  final AchievementType type;
  final String title;
  final String description;
  final String emoji;
  final bool unlocked;
  final DateTime? unlockedAt;
  final int progressCurrent;
  final int progressTarget;

  const PetAchievement({
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

  PetAchievement copyWith({
    bool? unlocked,
    DateTime? unlockedAt,
    int? progressCurrent,
  }) =>
      PetAchievement(
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
        'progressTarget': progressTarget,
      };

  factory PetAchievement.fromMap(Map<String, dynamic> m, PetAchievement base) {
    return base.copyWith(
      unlocked: m['unlocked'] as bool? ?? false,
      unlockedAt: m['unlockedAt'] != null
          ? DateTime.tryParse(m['unlockedAt'] as String)
          : null,
      progressCurrent: (m['progressCurrent'] as num?)?.toInt() ?? 0,
    );
  }
}

// ─── Default achievement catalogue ───────────────────────────────────────────

const kDefaultAchievements = [
  PetAchievement(
    type: AchievementType.firstProfile,
    title: 'New Family Member',
    description: 'Added your first cat profile.',
    emoji: '🐱',
    progressTarget: 1,
  ),
  PetAchievement(
    type: AchievementType.feedStreak,
    title: 'Top Chef',
    description: 'Feed your cat 20 times.',
    emoji: '🍗',
    progressTarget: 20,
  ),
  PetAchievement(
    type: AchievementType.groomStreak,
    title: 'Salon Star',
    description: 'Groom your cat 10 times.',
    emoji: '✂️',
    progressTarget: 10,
  ),
  PetAchievement(
    type: AchievementType.playStreak,
    title: '7-Day Playmate',
    description: 'Play with your cat for 7 days in a row.',
    emoji: '🎾',
    progressTarget: 7,
  ),
  PetAchievement(
    type: AchievementType.vaccinationComplete,
    title: 'Vaccine Hero',
    description: 'Log your first vaccination record.',
    emoji: '💉',
    progressTarget: 1,
  ),
  PetAchievement(
    type: AchievementType.quizMaster,
    title: 'Quiz Master',
    description: 'Score 100% on a quiz.',
    emoji: '🏆',
    progressTarget: 1,
  ),
  PetAchievement(
    type: AchievementType.weeklyPlayer,
    title: 'Weekly Warrior',
    description: 'Open the app 7 days in a row.',
    emoji: '📅',
    progressTarget: 7,
  ),
];

// ─── FullPetProfile — all fields shown on Pet Details Screen ─────────────────

class FullPetProfile {
  final String id; // matches PetModel.id
  final String name;
  final String breed;
  final String age;
  final String gender;
  final String weightKg;
  final String furColor;
  final String birthday; // ISO date string
  final String adoptionDate; // ISO date string
  final String notes;
  final int avatarColorValue;
  final List<GrowthEntry> growthEntries;
  final List<VaccinationRecord> vaccinations;
  final List<PetAchievement> achievements;
  final int feedCount;
  final int groomCount;
  final int playCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const FullPetProfile({
    required this.id,
    required this.name,
    this.breed = 'Persian',
    this.age = '',
    this.gender = 'Female',
    this.weightKg = '',
    this.furColor = '',
    this.birthday = '',
    this.adoptionDate = '',
    this.notes = '',
    this.avatarColorValue = 0xFFFFB3BA,
    this.growthEntries = const [],
    this.vaccinations = const [],
    this.achievements = const [],
    this.feedCount = 0,
    this.groomCount = 0,
    this.playCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Color get avatarColor => Color(avatarColorValue);

  FullPetProfile copyWith({
    String? name,
    String? breed,
    String? age,
    String? gender,
    String? weightKg,
    String? furColor,
    String? birthday,
    String? adoptionDate,
    String? notes,
    int? avatarColorValue,
    List<GrowthEntry>? growthEntries,
    List<VaccinationRecord>? vaccinations,
    List<PetAchievement>? achievements,
    int? feedCount,
    int? groomCount,
    int? playCount,
    DateTime? updatedAt,
  }) =>
      FullPetProfile(
        id: id,
        name: name ?? this.name,
        breed: breed ?? this.breed,
        age: age ?? this.age,
        gender: gender ?? this.gender,
        weightKg: weightKg ?? this.weightKg,
        furColor: furColor ?? this.furColor,
        birthday: birthday ?? this.birthday,
        adoptionDate: adoptionDate ?? this.adoptionDate,
        notes: notes ?? this.notes,
        avatarColorValue: avatarColorValue ?? this.avatarColorValue,
        growthEntries: growthEntries ?? this.growthEntries,
        vaccinations: vaccinations ?? this.vaccinations,
        achievements: achievements ?? this.achievements,
        feedCount: feedCount ?? this.feedCount,
        groomCount: groomCount ?? this.groomCount,
        playCount: playCount ?? this.playCount,
        createdAt: createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'breed': breed,
        'age': age,
        'gender': gender,
        'weightKg': weightKg,
        'furColor': furColor,
        'birthday': birthday,
        'adoptionDate': adoptionDate,
        'notes': notes,
        'avatarColorValue': avatarColorValue,
        'growthEntries': growthEntries.map((e) => e.toMap()).toList(),
        'vaccinations': vaccinations.map((v) => v.toMap()).toList(),
        'achievements': achievements.map((a) => a.toMap()).toList(),
        'feedCount': feedCount,
        'groomCount': groomCount,
        'playCount': playCount,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory FullPetProfile.fromMap(Map<String, dynamic> m) {
    final rawAchievements = (m['achievements'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();

    final achievements = kDefaultAchievements.map((base) {
      final saved = rawAchievements.firstWhere(
        (a) => a['type'] == base.type.name,
        orElse: () => <String, dynamic>{},
      );
      return saved.isEmpty ? base : PetAchievement.fromMap(saved, base);
    }).toList();

    return FullPetProfile(
      id: m['id'] as String,
      name: m['name'] as String? ?? '',
      breed: m['breed'] as String? ?? 'Persian',
      age: m['age'] as String? ?? '',
      gender: m['gender'] as String? ?? 'Female',
      weightKg: m['weightKg'] as String? ?? '',
      furColor: m['furColor'] as String? ?? '',
      birthday: m['birthday'] as String? ?? '',
      adoptionDate: m['adoptionDate'] as String? ?? '',
      notes: m['notes'] as String? ?? '',
      avatarColorValue: (m['avatarColorValue'] as num?)?.toInt() ?? 0xFFFFB3BA,
      growthEntries: (m['growthEntries'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(GrowthEntry.fromMap)
          .toList(),
      vaccinations: (m['vaccinations'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(VaccinationRecord.fromMap)
          .toList(),
      achievements: achievements,
      feedCount: (m['feedCount'] as num?)?.toInt() ?? 0,
      groomCount: (m['groomCount'] as num?)?.toInt() ?? 0,
      playCount: (m['playCount'] as num?)?.toInt() ?? 0,
      createdAt:
          DateTime.tryParse(m['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt:
          DateTime.tryParse(m['updatedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  /// Create a brand-new profile with default achievements
  factory FullPetProfile.create({
    required String id,
    required String name,
    String breed = 'Persian',
    int avatarColorValue = 0xFFFFB3BA,
  }) =>
      FullPetProfile(
        id: id,
        name: name,
        breed: breed,
        avatarColorValue: avatarColorValue,
        achievements: List.of(kDefaultAchievements),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
}
