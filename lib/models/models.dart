// lib/models/models.dart
//
// All app-wide data models.  Each model is:
//   • Serialisable to/from Map<String,dynamic> (Hive JSON + Firestore)
//   • Null-safe with sensible defaults
//   • Immutable with copyWith helpers

import 'package:flutter/material.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────

enum ActionType {
  feed,
  groom,
  play,
  lesson,
  quiz,
  reminder,
  profile,
  login,
  sync,
  other,
}

enum SessionType { authenticated, guest }

// ─── PetStats ─────────────────────────────────────────────────────────────────

class PetStats {
  final int hunger; // 0 = full, 100 = starving
  final int happiness; // 0–100
  final int cleanliness; // 0–100
  final int energy; // 0–100

  const PetStats({
    this.hunger = 30,
    this.happiness = 70,
    this.cleanliness = 80,
    this.energy = 80,
  });

  PetStats clamp() => PetStats(
        hunger: hunger.clamp(0, 100),
        happiness: happiness.clamp(0, 100),
        cleanliness: cleanliness.clamp(0, 100),
        energy: energy.clamp(0, 100),
      );

  PetStats copyWith({
    int? hunger,
    int? happiness,
    int? cleanliness,
    int? energy,
  }) =>
      PetStats(
        hunger: hunger ?? this.hunger,
        happiness: happiness ?? this.happiness,
        cleanliness: cleanliness ?? this.cleanliness,
        energy: energy ?? this.energy,
      ).clamp();

  Map<String, dynamic> toMap() => {
        'hunger': hunger,
        'happiness': happiness,
        'cleanliness': cleanliness,
        'energy': energy,
      };

  factory PetStats.fromMap(Map<String, dynamic> m) => PetStats(
        hunger: (m['hunger'] as num?)?.toInt() ?? 30,
        happiness: (m['happiness'] as num?)?.toInt() ?? 70,
        cleanliness: (m['cleanliness'] as num?)?.toInt() ?? 80,
        energy: (m['energy'] as num?)?.toInt() ?? 80,
      );
}

// ─── PetModel ─────────────────────────────────────────────────────────────────

class PetModel {
  final String id;
  final String name;
  final String age;
  final String gender;
  final String weight;
  final String furColor;
  final String notes;
  final int avatarColorValue; // stored as int (Color.value)
  final PetStats stats;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PetModel({
    required this.id,
    required this.name,
    this.age = '',
    this.gender = 'Female',
    this.weight = '',
    this.furColor = '',
    this.notes = '',
    this.avatarColorValue = 0xFFFFB3BA,
    this.stats = const PetStats(),
    required this.createdAt,
    required this.updatedAt,
  });

  Color get avatarColor => Color(avatarColorValue);

  PetModel copyWith({
    String? id,
    String? name,
    String? age,
    String? gender,
    String? weight,
    String? furColor,
    String? notes,
    int? avatarColorValue,
    PetStats? stats,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      PetModel(
        id: id ?? this.id,
        name: name ?? this.name,
        age: age ?? this.age,
        gender: gender ?? this.gender,
        weight: weight ?? this.weight,
        furColor: furColor ?? this.furColor,
        notes: notes ?? this.notes,
        avatarColorValue: avatarColorValue ?? this.avatarColorValue,
        stats: stats ?? this.stats,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'age': age,
        'gender': gender,
        'weight': weight,
        'furColor': furColor,
        'notes': notes,
        'avatarColorValue': avatarColorValue,
        'stats': stats.toMap(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory PetModel.fromMap(Map<String, dynamic> m) => PetModel(
        id: m['id'] as String,
        name: m['name'] as String? ?? '',
        age: m['age'] as String? ?? '',
        gender: m['gender'] as String? ?? 'Female',
        weight: m['weight'] as String? ?? '',
        furColor: m['furColor'] as String? ?? '',
        notes: m['notes'] as String? ?? '',
        avatarColorValue:
            (m['avatarColorValue'] as num?)?.toInt() ?? 0xFFFFB3BA,
        stats: m['stats'] != null
            ? PetStats.fromMap(m['stats'] as Map<String, dynamic>)
            : const PetStats(),
        createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(m['updatedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

// ─── ActivityLogModel ─────────────────────────────────────────────────────────

class ActivityLogModel {
  final String id;
  final String petId;
  final String petName;
  final ActionType actionType;
  final String description;
  final Map<String, int> statChanges;
  final DateTime timestamp;

  const ActivityLogModel({
    required this.id,
    required this.petId,
    required this.petName,
    required this.actionType,
    required this.description,
    this.statChanges = const {},
    required this.timestamp,
  });

  IconData get icon {
    switch (actionType) {
      case ActionType.feed:
        return Icons.restaurant;
      case ActionType.groom:
        return Icons.content_cut;
      case ActionType.play:
        return Icons.sports_esports;
      case ActionType.lesson:
        return Icons.menu_book;
      case ActionType.quiz:
        return Icons.quiz;
      case ActionType.reminder:
        return Icons.alarm;
      case ActionType.profile:
        return Icons.pets;
      case ActionType.login:
        return Icons.login;
      case ActionType.sync:
        return Icons.sync;
      case ActionType.other:
        return Icons.info_outline;
    }
  }

  Color get iconColor {
    switch (actionType) {
      case ActionType.feed:
        return const Color(0xFFFF8C69);
      case ActionType.groom:
        return const Color(0xFF7B68EE);
      case ActionType.play:
        return const Color(0xFF20B2AA);
      case ActionType.lesson:
        return const Color(0xFF4682B4);
      case ActionType.quiz:
        return const Color(0xFF7B68EE);
      case ActionType.reminder:
        return const Color(0xFFFFA500);
      case ActionType.profile:
        return const Color(0xFF32CD32);
      case ActionType.login:
        return const Color(0xFF4682B4);
      case ActionType.sync:
        return const Color(0xFF20B2AA);
      case ActionType.other:
        return Colors.grey;
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'petId': petId,
        'petName': petName,
        'actionType': actionType.name,
        'description': description,
        'statChanges': statChanges,
        'timestamp': timestamp.toIso8601String(),
      };

  factory ActivityLogModel.fromMap(Map<String, dynamic> m) {
    ActionType type;
    try {
      type = ActionType.values.byName(m['actionType'] as String? ?? 'other');
    } catch (_) {
      type = ActionType.other;
    }
    return ActivityLogModel(
      id: m['id'] as String,
      petId: m['petId'] as String? ?? '',
      petName: m['petName'] as String? ?? '',
      actionType: type,
      description: m['description'] as String? ?? '',
      statChanges: (m['statChanges'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, (v as num).toInt())),
      timestamp:
          DateTime.tryParse(m['timestamp'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

// ─── ReminderModel ────────────────────────────────────────────────────────────

class ReminderModel {
  final String id;
  final String title;
  final String type;
  final DateTime scheduledTime;
  final bool isCompleted;
  final DateTime createdAt;

  const ReminderModel({
    required this.id,
    required this.title,
    required this.type,
    required this.scheduledTime,
    this.isCompleted = false,
    required this.createdAt,
  });

  bool get isOverdue => !isCompleted && scheduledTime.isBefore(DateTime.now());

  ReminderModel copyWith({
    String? id,
    String? title,
    String? type,
    DateTime? scheduledTime,
    bool? isCompleted,
    DateTime? createdAt,
  }) =>
      ReminderModel(
        id: id ?? this.id,
        title: title ?? this.title,
        type: type ?? this.type,
        scheduledTime: scheduledTime ?? this.scheduledTime,
        isCompleted: isCompleted ?? this.isCompleted,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'type': type,
        'scheduledTime': scheduledTime.toIso8601String(),
        'isCompleted': isCompleted,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ReminderModel.fromMap(Map<String, dynamic> m) => ReminderModel(
        id: m['id'] as String,
        title: m['title'] as String? ?? '',
        type: m['type'] as String? ?? 'Other',
        scheduledTime: DateTime.tryParse(m['scheduledTime'] as String? ?? '') ??
            DateTime.now(),
        isCompleted: m['isCompleted'] as bool? ?? false,
        createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

// ─── QuizResult ───────────────────────────────────────────────────────────────

class QuizResult {
  final String id;
  final int score;
  final int total;
  final DateTime completedAt;

  const QuizResult({
    required this.id,
    required this.score,
    required this.total,
    required this.completedAt,
  });

  double get percentage => total > 0 ? score / total : 0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'score': score,
        'total': total,
        'completedAt': completedAt.toIso8601String(),
      };

  factory QuizResult.fromMap(Map<String, dynamic> m) => QuizResult(
        id: m['id'] as String,
        score: (m['score'] as num?)?.toInt() ?? 0,
        total: (m['total'] as num?)?.toInt() ?? 0,
        completedAt: DateTime.tryParse(m['completedAt'] as String? ?? '') ??
            DateTime.now(),
      );
}

// ─── AppSettings ──────────────────────────────────────────────────────────────

class AppSettings {
  final bool notificationsEnabled;
  final bool soundEnabled;
  final String selectedPetId;
  final DateTime updatedAt;

  const AppSettings({
    this.notificationsEnabled = true,
    this.soundEnabled = true,
    this.selectedPetId = '',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? const _NowPlaceholder();

  AppSettings copyWith({
    bool? notificationsEnabled,
    bool? soundEnabled,
    String? selectedPetId,
  }) =>
      AppSettings(
        notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
        soundEnabled: soundEnabled ?? this.soundEnabled,
        selectedPetId: selectedPetId ?? this.selectedPetId,
        updatedAt: DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'notificationsEnabled': notificationsEnabled,
        'soundEnabled': soundEnabled,
        'selectedPetId': selectedPetId,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory AppSettings.fromMap(Map<String, dynamic> m) => AppSettings(
        notificationsEnabled: m['notificationsEnabled'] as bool? ?? true,
        soundEnabled: m['soundEnabled'] as bool? ?? true,
        selectedPetId: m['selectedPetId'] as String? ?? '',
        updatedAt: DateTime.tryParse(m['updatedAt'] as String? ?? ''),
      );
}

// Workaround for const constructor with DateTime.now()
class _NowPlaceholder implements DateTime {
  const _NowPlaceholder();
  @override
  dynamic noSuchMethod(Invocation i) => DateTime.now().noSuchMethod(i);
}

// ─── SessionModel ─────────────────────────────────────────────────────────────

class SessionModel {
  final String userId;
  final SessionType type;
  final String? displayName;
  final String? email;
  final DateTime createdAt;
  final DateTime lastActiveAt;

  const SessionModel({
    required this.userId,
    required this.type,
    this.displayName,
    this.email,
    required this.createdAt,
    required this.lastActiveAt,
  });

  bool get isGuest => type == SessionType.guest;
  bool get isAuthenticated => type == SessionType.authenticated;

  SessionModel copyWith({DateTime? lastActiveAt, String? displayName}) =>
      SessionModel(
        userId: userId,
        type: type,
        displayName: displayName ?? this.displayName,
        email: email,
        createdAt: createdAt,
        lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      );

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'type': type.name,
        'displayName': displayName,
        'email': email,
        'createdAt': createdAt.toIso8601String(),
        'lastActiveAt': lastActiveAt.toIso8601String(),
      };

  factory SessionModel.fromMap(Map<String, dynamic> m) => SessionModel(
        userId: m['userId'] as String,
        type: SessionType.values.byName(m['type'] as String? ?? 'guest'),
        displayName: m['displayName'] as String?,
        email: m['email'] as String?,
        createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ??
            DateTime.now(),
        lastActiveAt: DateTime.tryParse(m['lastActiveAt'] as String? ?? '') ??
            DateTime.now(),
      );
}
