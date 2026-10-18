// lib/models/virtual_pet_state.dart
//
// State for the single VIRTUAL GAME PET used only by:
//   GameScreen / FeedScreen / GroomScreen / PlayScreen
//
// INDEPENDENCE RULE:
// NOT real Persian cat profiles or real-pet vaccination/growth/reminder data.
// This model owns only the single virtual game cat and its virtual-care history.

const Object _unset = Object();

class VirtualPetState {
  final String catName;

  // 0 = not hungry / satisfied
  // 100 = extremely hungry
  final int hunger;

  // 0 = very unhappy
  // 100 = very happy
  final int happiness;

  // 0 = very dirty
  // 100 = very clean
  final int cleanliness;

  // 0 = exhausted
  // 100 = fully energetic
  //
  // IMPORTANT:
  // Energy does NOT naturally decay with time.
  // It changes through gameplay/actions and sleep recovery.
  final int energy;

  // Fur growth stage: 0 = Fur0, 1 = Fur1, 2 = Fur2.
  // This is independent from hunger, cleanliness, energy, and neglect.
  final int furStage;
  final DateTime lastFurGrowthAt;
  // Independent clock for the optional no-trim fur-growth rule.
  final DateTime lastTrimAt;
  final int furStageAtLastTrim;

  // Virtual sickness is independent of hunger, cleanliness, happiness,
  // Energy, and the existing Neglected status.
  final bool isSick;

  // Medicine temporarily suppresses sickness presentation until this absolute
  // timestamp. The deadline survives app restarts.
  final DateTime? recoveryUntil;

  // Virtual-cat vaccination history; kept separate from real-pet records.
  final List<DateTime> vaccinationRecords;

  // Independent one-hour recovery window after virtual vaccination.
  final DateTime? vaccinationRecoveryUntil;

  // Timestamp when the cat first entered the Neglected state. Used to trigger
  // sickness only after prolonged neglect, and persisted across app restarts.
  final DateTime? neglectedSince;

  // Shared sleeping state.
  //
  // This is persisted so FeedScreen, GroomScreen, PlayScreen,
  // and GameScreen all know whether the virtual cat is sleeping.
  final bool isSleeping;

  // Persistent interaction need. Set by care actions and cleared by play.
  final bool wantsToPlay;

  // Persistent anti-spam state for virtual-pet notifications.
  final bool hungerNotificationSent;
  final bool cleanlinessNotificationSent;
  final bool neglectedNotificationSent;
  final bool wantsToPlayNotificationSent;

  final DateTime lastTickAt;
  final DateTime? lastSleepRecoveryAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  final int simFeedCount;
  final int simGroomCount;
  final int simPlayCount;
  final int simPlayStreakDays;
  final DateTime? simLastPlayDate;

  const VirtualPetState({
    this.catName = '',
    this.hunger = 30,
    this.happiness = 70,
    this.cleanliness = 80,
    this.energy = 80,
    this.furStage = 0,
    required this.lastFurGrowthAt,
    required this.lastTrimAt,
    this.furStageAtLastTrim = 0,
    this.isSick = false,
    this.recoveryUntil,
    this.vaccinationRecords = const [],
    this.vaccinationRecoveryUntil,
    this.neglectedSince,
    this.isSleeping = false,
    this.wantsToPlay = false,
    this.hungerNotificationSent = false,
    this.cleanlinessNotificationSent = false,
    this.neglectedNotificationSent = false,
    this.wantsToPlayNotificationSent = false,
    required this.lastTickAt,
    this.lastSleepRecoveryAt,
    required this.createdAt,
    required this.updatedAt,
    this.simFeedCount = 0,
    this.simGroomCount = 0,
    this.simPlayCount = 0,
    this.simPlayStreakDays = 0,
    this.simLastPlayDate,
  });

  bool get isNamed => catName.trim().isNotEmpty;

  factory VirtualPetState.initial() {
    final now = DateTime.now();

    return VirtualPetState(
      lastTickAt: now,
      lastFurGrowthAt: now,
      lastTrimAt: now,
      furStageAtLastTrim: 0,
      lastSleepRecoveryAt: null,
      createdAt: now,
      updatedAt: now,
      isSleeping: false,
      wantsToPlay: false,
      hungerNotificationSent: false,
      cleanlinessNotificationSent: false,
      neglectedNotificationSent: false,
      wantsToPlayNotificationSent: false,
    );
  }

  VirtualPetState clamp() {
    return copyWith(
      furStage: furStage.clamp(0, 2).toInt(),
      hunger: hunger.clamp(0, 100),
      happiness: happiness.clamp(0, 100),
      cleanliness: cleanliness.clamp(0, 100),
      energy: energy.clamp(0, 100),
    );
  }

  VirtualPetState copyWith({
    String? catName,
    int? hunger,
    int? happiness,
    int? cleanliness,
    int? energy,
    int? furStage,
    DateTime? lastFurGrowthAt,
    DateTime? lastTrimAt,
    int? furStageAtLastTrim,
    bool? isSick,
    Object? recoveryUntil = _unset,
    List<DateTime>? vaccinationRecords,
    Object? vaccinationRecoveryUntil = _unset,
    Object? neglectedSince = _unset,
    bool? isSleeping,
    bool? wantsToPlay,
    bool? hungerNotificationSent,
    bool? cleanlinessNotificationSent,
    bool? neglectedNotificationSent,
    bool? wantsToPlayNotificationSent,
    DateTime? lastTickAt,
    Object? lastSleepRecoveryAt = _unset,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? simFeedCount,
    int? simGroomCount,
    int? simPlayCount,
    int? simPlayStreakDays,
    Object? simLastPlayDate = _unset,
  }) {
    return VirtualPetState(
      catName: catName ?? this.catName,
      hunger: hunger ?? this.hunger,
      happiness: happiness ?? this.happiness,
      cleanliness: cleanliness ?? this.cleanliness,
      energy: energy ?? this.energy,
      furStage: furStage ?? this.furStage,
      lastFurGrowthAt: lastFurGrowthAt ?? this.lastFurGrowthAt,
      lastTrimAt: lastTrimAt ?? this.lastTrimAt,
      furStageAtLastTrim: furStageAtLastTrim ?? this.furStageAtLastTrim,
      isSick: isSick ?? this.isSick,
      recoveryUntil: identical(recoveryUntil, _unset)
          ? this.recoveryUntil
          : recoveryUntil as DateTime?,
      vaccinationRecords: vaccinationRecords ?? this.vaccinationRecords,
      vaccinationRecoveryUntil: identical(vaccinationRecoveryUntil, _unset)
          ? this.vaccinationRecoveryUntil
          : vaccinationRecoveryUntil as DateTime?,
      neglectedSince: identical(neglectedSince, _unset)
          ? this.neglectedSince
          : neglectedSince as DateTime?,
      isSleeping: isSleeping ?? this.isSleeping,
      wantsToPlay: wantsToPlay ?? this.wantsToPlay,
      hungerNotificationSent:
          hungerNotificationSent ?? this.hungerNotificationSent,
      cleanlinessNotificationSent:
          cleanlinessNotificationSent ?? this.cleanlinessNotificationSent,
      neglectedNotificationSent:
          neglectedNotificationSent ?? this.neglectedNotificationSent,
      wantsToPlayNotificationSent:
          wantsToPlayNotificationSent ?? this.wantsToPlayNotificationSent,
      lastTickAt: lastTickAt ?? this.lastTickAt,
      lastSleepRecoveryAt: identical(lastSleepRecoveryAt, _unset)
          ? this.lastSleepRecoveryAt
          : lastSleepRecoveryAt as DateTime?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      simFeedCount: simFeedCount ?? this.simFeedCount,
      simGroomCount: simGroomCount ?? this.simGroomCount,
      simPlayCount: simPlayCount ?? this.simPlayCount,
      simPlayStreakDays: simPlayStreakDays ?? this.simPlayStreakDays,
      simLastPlayDate: identical(simLastPlayDate, _unset)
          ? this.simLastPlayDate
          : simLastPlayDate as DateTime?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'catName': catName,
      'hunger': hunger,
      'happiness': happiness,
      'cleanliness': cleanliness,
      'energy': energy,
      'furStage': furStage,
      'lastFurGrowthAt': lastFurGrowthAt.toIso8601String(),
      'lastTrimAt': lastTrimAt.toIso8601String(),
      'furStageAtLastTrim': furStageAtLastTrim,
      'isSick': isSick,
      'recoveryUntil': recoveryUntil?.toIso8601String(),
      'vaccinationRecords':
          vaccinationRecords.map((d) => d.toIso8601String()).toList(),
      'vaccinationRecoveryUntil': vaccinationRecoveryUntil?.toIso8601String(),
      'neglectedSince': neglectedSince?.toIso8601String(),
      'isSleeping': isSleeping,
      'wantsToPlay': wantsToPlay,
      'hungerNotificationSent': hungerNotificationSent,
      'cleanlinessNotificationSent': cleanlinessNotificationSent,
      'neglectedNotificationSent': neglectedNotificationSent,
      'wantsToPlayNotificationSent': wantsToPlayNotificationSent,
      'lastTickAt': lastTickAt.toIso8601String(),
      'lastSleepRecoveryAt': lastSleepRecoveryAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'simFeedCount': simFeedCount,
      'simGroomCount': simGroomCount,
      'simPlayCount': simPlayCount,
      'simPlayStreakDays': simPlayStreakDays,
      'simLastPlayDate': simLastPlayDate?.toIso8601String(),
    };
  }

  factory VirtualPetState.fromMap(
    Map<String, dynamic> m,
  ) {
    final now = DateTime.now();

    return VirtualPetState(
      catName: m['catName'] as String? ?? '',

      hunger: (m['hunger'] as num?)?.toInt() ?? 30,

      happiness: (m['happiness'] as num?)?.toInt() ?? 70,

      cleanliness: (m['cleanliness'] as num?)?.toInt() ?? 80,

      // Existing saved Energy is preserved.
      // Only missing/invalid Energy defaults to 80.
      energy: (m['energy'] as num?)?.toInt() ?? 80,

      furStage: ((m['furStage'] as num?)?.toInt() ?? 0).clamp(0, 2).toInt(),

      // New fur system starts its growth clock when first introduced to old saves.
      lastFurGrowthAt: DateTime.tryParse(
            m['lastFurGrowthAt'] as String? ?? '',
          ) ??
          now,
      // Existing saves fall back to their fur-growth clock safely.
      lastTrimAt: DateTime.tryParse(m['lastTrimAt'] as String? ?? '') ??
          DateTime.tryParse(m['lastFurGrowthAt'] as String? ?? '') ??
          now,
      furStageAtLastTrim: ((m['furStageAtLastTrim'] as num?)?.toInt() ??
              ((m['furStage'] as num?)?.toInt() ?? 0))
          .clamp(0, 2)
          .toInt(),

      // Old saved data safely defaults to not sick / not recovering.
      isSick: m['isSick'] as bool? ?? false,
      recoveryUntil: m['recoveryUntil'] != null
          ? DateTime.tryParse(m['recoveryUntil'] as String)
          : null,
      vaccinationRecords: ((m['vaccinationRecords'] as List?) ?? const [])
          .whereType<String>()
          .map(DateTime.tryParse)
          .whereType<DateTime>()
          .toList(),
      vaccinationRecoveryUntil: m['vaccinationRecoveryUntil'] != null
          ? DateTime.tryParse(m['vaccinationRecoveryUntil'] as String)
          : null,
      neglectedSince: m['neglectedSince'] != null
          ? DateTime.tryParse(m['neglectedSince'] as String)
          : null,

      // Old saved data will simply default to false.
      isSleeping: m['isSleeping'] as bool? ?? false,

      wantsToPlay: m['wantsToPlay'] as bool? ?? false,

      hungerNotificationSent: m['hungerNotificationSent'] as bool? ?? false,
      cleanlinessNotificationSent:
          m['cleanlinessNotificationSent'] as bool? ?? false,
      neglectedNotificationSent:
          m['neglectedNotificationSent'] as bool? ?? false,
      wantsToPlayNotificationSent:
          m['wantsToPlayNotificationSent'] as bool? ?? false,

      lastTickAt: DateTime.tryParse(
            m['lastTickAt'] as String? ?? '',
          ) ??
          now,

      lastSleepRecoveryAt: m['lastSleepRecoveryAt'] != null
          ? DateTime.tryParse(m['lastSleepRecoveryAt'] as String)
          : null,

      createdAt: DateTime.tryParse(
            m['createdAt'] as String? ?? '',
          ) ??
          now,

      updatedAt: DateTime.tryParse(
            m['updatedAt'] as String? ?? '',
          ) ??
          DateTime.tryParse(
            m['lastTickAt'] as String? ?? '',
          ) ??
          now,

      simFeedCount: (m['simFeedCount'] as num?)?.toInt() ?? 0,

      simGroomCount: (m['simGroomCount'] as num?)?.toInt() ?? 0,

      simPlayCount: (m['simPlayCount'] as num?)?.toInt() ?? 0,

      simPlayStreakDays: (m['simPlayStreakDays'] as num?)?.toInt() ?? 0,

      simLastPlayDate: m['simLastPlayDate'] != null
          ? DateTime.tryParse(
              m['simLastPlayDate'] as String,
            )
          : null,
    ).clamp();
  }
}
