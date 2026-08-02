// lib/models/virtual_pet_state.dart
//
// State for the single VIRTUAL GAME PET used only by:
//   GameScreen / FeedScreen / GroomScreen / PlayScreen
//
// ── INDEPENDENCE RULE ───────────────────────────────────────────────────────
// This is NOT one of the user's real Persian cat profiles.
//   • It has no `id` field — there is exactly ONE virtual pet per
//     device/user, so it is never looked up by id or stored in a list.
//   • It must NEVER be linked to FullPetProfile / PetProfileProvider / any
//     real pet's petId.
//   • It has no vaccinations, growth records, or real-pet reminders — those
//     concepts don't apply to it.
// ─────────────────────────────────────────────────────────────────────────

// Sentinel so copyWith(simLastPlayDate: null) can explicitly CLEAR the date,
// distinct from "not passed" (which leaves it unchanged).
const Object _unset = Object();

class VirtualPetState {
  /// '' means "not yet named" — drives whether the naming dialog shows.
  final String catName;

  final int hunger; // 0 = full, 100 = starving
  final int happiness; // 0-100
  final int cleanliness; // 0-100
  final int energy; // 0-100

  /// Last time decay was calculated and applied/caught up to.
  final DateTime lastTickAt;

  final DateTime createdAt;

  // ── Simulation-only counters/streaks ──────────────────────────────────────
  // These back the virtual-game achievements (feedStreak/groomStreak/
  // playStreak) that will be wired up in a later phase. They are never used
  // by, or copied onto, any real pet profile.
  final int simFeedCount;
  final int simGroomCount;
  final int simPlayCount;

  /// Consecutive calendar days played in a row (resets if a day is missed).
  final int simPlayStreakDays;

  /// Date-only (midnight) of the last day the user played, used to compute
  /// [simPlayStreakDays].
  final DateTime? simLastPlayDate;

  const VirtualPetState({
    this.catName = '',
    this.hunger = 30,
    this.happiness = 70,
    this.cleanliness = 80,
    this.energy = 80,
    required this.lastTickAt,
    required this.createdAt,
    this.simFeedCount = 0,
    this.simGroomCount = 0,
    this.simPlayCount = 0,
    this.simPlayStreakDays = 0,
    this.simLastPlayDate,
  });

  bool get isNamed => catName.trim().isNotEmpty;

  /// Brand-new virtual pet, used the very first time the app runs.
  factory VirtualPetState.initial() {
    final now = DateTime.now();
    return VirtualPetState(lastTickAt: now, createdAt: now);
  }

  VirtualPetState clamp() => copyWith(
        hunger: hunger.clamp(0, 100),
        happiness: happiness.clamp(0, 100),
        cleanliness: cleanliness.clamp(0, 100),
        energy: energy.clamp(0, 100),
      );

  VirtualPetState copyWith({
    String? catName,
    int? hunger,
    int? happiness,
    int? cleanliness,
    int? energy,
    DateTime? lastTickAt,
    DateTime? createdAt,
    int? simFeedCount,
    int? simGroomCount,
    int? simPlayCount,
    int? simPlayStreakDays,
    Object? simLastPlayDate = _unset,
  }) =>
      VirtualPetState(
        catName: catName ?? this.catName,
        hunger: hunger ?? this.hunger,
        happiness: happiness ?? this.happiness,
        cleanliness: cleanliness ?? this.cleanliness,
        energy: energy ?? this.energy,
        lastTickAt: lastTickAt ?? this.lastTickAt,
        createdAt: createdAt ?? this.createdAt,
        simFeedCount: simFeedCount ?? this.simFeedCount,
        simGroomCount: simGroomCount ?? this.simGroomCount,
        simPlayCount: simPlayCount ?? this.simPlayCount,
        simPlayStreakDays: simPlayStreakDays ?? this.simPlayStreakDays,
        simLastPlayDate: identical(simLastPlayDate, _unset)
            ? this.simLastPlayDate
            : simLastPlayDate as DateTime?,
      );

  Map<String, dynamic> toMap() => {
        'catName': catName,
        'hunger': hunger,
        'happiness': happiness,
        'cleanliness': cleanliness,
        'energy': energy,
        'lastTickAt': lastTickAt.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'simFeedCount': simFeedCount,
        'simGroomCount': simGroomCount,
        'simPlayCount': simPlayCount,
        'simPlayStreakDays': simPlayStreakDays,
        'simLastPlayDate': simLastPlayDate?.toIso8601String(),
      };

  factory VirtualPetState.fromMap(Map<String, dynamic> m) {
    final now = DateTime.now();
    return VirtualPetState(
      catName: m['catName'] as String? ?? '',
      hunger: (m['hunger'] as num?)?.toInt() ?? 30,
      happiness: (m['happiness'] as num?)?.toInt() ?? 70,
      cleanliness: (m['cleanliness'] as num?)?.toInt() ?? 80,
      energy: (m['energy'] as num?)?.toInt() ?? 80,
      lastTickAt: DateTime.tryParse(m['lastTickAt'] as String? ?? '') ?? now,
      createdAt: DateTime.tryParse(m['createdAt'] as String? ?? '') ?? now,
      simFeedCount: (m['simFeedCount'] as num?)?.toInt() ?? 0,
      simGroomCount: (m['simGroomCount'] as num?)?.toInt() ?? 0,
      simPlayCount: (m['simPlayCount'] as num?)?.toInt() ?? 0,
      simPlayStreakDays: (m['simPlayStreakDays'] as num?)?.toInt() ?? 0,
      simLastPlayDate: m['simLastPlayDate'] != null
          ? DateTime.tryParse(m['simLastPlayDate'] as String)
          : null,
    ).clamp();
  }
}
