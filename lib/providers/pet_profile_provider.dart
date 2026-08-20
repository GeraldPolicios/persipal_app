// lib/providers/pet_profile_provider.dart
//
// Manages FullPetProfile CRUD.
//
// Storage:
//   • Hive = primary/offline-first storage
//   • Firestore = background synchronization
//
// Vaccination/reminder relationship:
//   • A vaccination may have one linked Care Reminder.
//   • Completing a vaccination completes the linked reminder,
//     but NEVER deletes it.
//   • Completed reminders remain in the Done tab.
//   • Vaccination history is NEVER overwritten.
//   • A completed dose can create a new completed record and,
//     optionally, a new reminder for its next dose.
//   • Recurring vaccination series creates independent records
//     and independent reminders for every dose.

import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/pet_extended_models.dart';
import '../models/reminder_item_model.dart';
import '../services/activity_log_service.dart';
import '../services/auth_service.dart';
import '../services/local_storage_service.dart';
import 'reminder_provider.dart';

const String _boxName = 'full_pet_profiles';
const int _maxProfiles = 10;

class PetProfileProvider extends ChangeNotifier {
  PetProfileProvider._();

  static final PetProfileProvider instance = PetProfileProvider._();

  final Uuid _uuid = const Uuid();

  final AuthService _auth = AuthService.instance;
  final ActivityLogService _log = ActivityLogService.instance;

  List<FullPetProfile> _profiles = [];

  bool _loading = false;

  bool _initialized = false;

  // ─────────────────────────────────────────────────────────────────────────
  // Getters
  // ─────────────────────────────────────────────────────────────────────────

  List<FullPetProfile> get profiles => List.unmodifiable(_profiles);

  bool get loading => _loading;

  bool get canAdd => _profiles.length < _maxProfiles;

  int get count => _profiles.length;

  Box<String> get _box => Hive.box<String>(_boxName);

  // ─────────────────────────────────────────────────────────────────────────
  // Initialization
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;

    _initialized = true;

    await Hive.openBox<String>(_boxName);

    await _loadFromHive();

    if (_auth.isAuthenticated) {
      unawaited(_downloadFromCloud());
    }

    _auth.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (_auth.isAuthenticated) {
      unawaited(_downloadFromCloud());
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Hive
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _loadFromHive() async {
    _loading = true;
    notifyListeners();

    try {
      final loaded = <FullPetProfile>[];

      for (final raw in _box.values) {
        try {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;

          loaded.add(
            FullPetProfile.fromMap(decoded),
          );
        } catch (e) {
          debugPrint(
            'PetProfileProvider: failed to decode profile: $e',
          );
        }
      }

      loaded.sort(
        (a, b) => a.createdAt.compareTo(b.createdAt),
      );

      _profiles = loaded;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _saveToHive(
    FullPetProfile profile,
  ) async {
    await _box.put(
      profile.id,
      jsonEncode(profile.toMap()),
    );
  }

  Future<void> _deleteFromHive(
    String id,
  ) async {
    await _box.delete(id);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Firestore
  // ─────────────────────────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>>? get _collection {
    if (!_auth.isAuthenticated) {
      return null;
    }

    final userId = _auth.userId;

    if (userId == null || userId.isEmpty) {
      return null;
    }

    return FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('full_pet_profiles');
  }

  Future<void> _uploadToCloud(
    FullPetProfile profile,
  ) async {
    try {
      final collection = _collection;

      if (collection == null) {
        return;
      }

      await collection.doc(profile.id).set(
            profile.toMap(),
            SetOptions(merge: true),
          );
    } catch (e) {
      debugPrint(
        'PetProfileProvider: cloud upload failed: $e',
      );
    }
  }

  Future<void> _deleteFromCloud(
    String id,
  ) async {
    try {
      final collection = _collection;

      if (collection == null) {
        return;
      }

      await collection.doc(id).delete();
    } catch (e) {
      debugPrint(
        'PetProfileProvider: cloud delete failed: $e',
      );
    }
  }

  Future<void> _downloadFromCloud() async {
    try {
      final collection = _collection;

      if (collection == null) {
        return;
      }

      final snapshot = await collection.get();

      if (snapshot.docs.isEmpty) {
        return;
      }

      final localMap = <String, FullPetProfile>{
        for (final profile in _profiles) profile.id: profile,
      };

      for (final doc in snapshot.docs) {
        try {
          final cloudProfile = FullPetProfile.fromMap(doc.data());

          final localProfile = localMap[cloudProfile.id];

          if (localProfile == null ||
              cloudProfile.updatedAt.isAfter(localProfile.updatedAt)) {
            localMap[cloudProfile.id] = cloudProfile;

            await _saveToHive(cloudProfile);
          }
        } catch (e) {
          debugPrint(
            'PetProfileProvider: invalid cloud profile: $e',
          );
        }
      }

      _profiles = localMap.values.toList()
        ..sort(
          (a, b) => a.createdAt.compareTo(b.createdAt),
        );

      notifyListeners();
    } catch (e) {
      debugPrint(
        'PetProfileProvider: cloud download failed: $e',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Create profile
  // ─────────────────────────────────────────────────────────────────────────

  Future<FullPetProfile?> createProfile({
    required String name,
    required String breed,
    required int avatarColorValue,
  }) async {
    if (!canAdd) {
      return null;
    }

    final base = FullPetProfile.create(
      id: _uuid.v4(),
      name: name.trim(),
      breed: breed.trim().isEmpty ? 'Persian' : breed.trim(),
      avatarColorValue: avatarColorValue,
    );

    final achievements = await _unlockAndLog(
      List.of(kDefaultAchievements),
      AchievementType.firstProfile,
      1,
      base.name,
    );

    final profile = base.copyWith(
      achievements: achievements,
    );

    _profiles.add(profile);

    notifyListeners();

    await _saveToHive(profile);

    unawaited(
      _uploadToCloud(profile),
    );

    await _log.logProfileAdded(
      profile.name,
    );

    return profile;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Update profile
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> updateDetails(
    FullPetProfile updated,
  ) async {
    final index = _profiles.indexWhere(
      (p) => p.id == updated.id,
    );

    if (index < 0) {
      return;
    }

    final saved = updated.copyWith(
      updatedAt: DateTime.now(),
    );

    _profiles[index] = saved;

    notifyListeners();

    await _saveToHive(saved);

    unawaited(
      _uploadToCloud(saved),
    );

    await _log.logProfileUpdated(
      saved.name,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Delete profile
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> deleteProfile(
    String id,
  ) async {
    final index = _profiles.indexWhere(
      (p) => p.id == id,
    );

    if (index < 0) {
      return;
    }

    final profile = _profiles[index];

    _profiles.removeAt(index);

    notifyListeners();

    await _deleteFromHive(id);

    unawaited(
      _deleteFromCloud(id),
    );

    await _log.logProfileDeleted(
      profile.name,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Growth tracker
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> addGrowthEntry(
    String petId,
    GrowthEntry entry,
  ) async {
    final profile = _getById(petId);

    if (profile == null) return;

    final entries = [
      ...profile.growthEntries,
      entry,
    ]..sort(
        (a, b) => a.recordedAt.compareTo(
          b.recordedAt,
        ),
      );

    final achievements = await _unlockAndLog(
      profile.achievements,
      AchievementType.growthMilestone,
      entries.length,
      profile.name,
    );

    await updateDetails(
      profile.copyWith(
        growthEntries: entries,
        achievements: achievements,
      ),
    );
  }

  Future<void> updateGrowthEntry(
    String petId,
    GrowthEntry entry,
  ) async {
    final profile = _getById(petId);

    if (profile == null) return;

    final entries = profile.growthEntries
        .map(
          (e) => e.id == entry.id ? entry : e,
        )
        .toList();

    await updateDetails(
      profile.copyWith(
        growthEntries: entries,
      ),
    );
  }

  Future<void> deleteGrowthEntry(
    String petId,
    String entryId,
  ) async {
    final profile = _getById(petId);

    if (profile == null) return;

    final entries = profile.growthEntries
        .where(
          (e) => e.id != entryId,
        )
        .toList();

    await updateDetails(
      profile.copyWith(
        growthEntries: entries,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Vaccination CRUD
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> addVaccination(
    String petId,
    VaccinationRecord record, {
    bool logActivity = true,
  }) async {
    final profile = _getById(petId);

    if (profile == null) return;

    final vaccinations = [
      ...profile.vaccinations,
      record,
    ];

    final updated = profile.copyWith(
      vaccinations: vaccinations,
    );

    await updateDetails(updated);

    if (logActivity) {
      await _log.logVaccinationAdded(record.vaccineName, profile.name);
    }
  }

  Future<void> updateVaccination(
    String petId,
    VaccinationRecord record, {
    bool logActivity = true,
  }) async {
    final profile = _getById(petId);

    if (profile == null) return;

    final vaccinations = profile.vaccinations
        .map(
          (v) => v.id == record.id ? record : v,
        )
        .toList();

    await updateDetails(
      profile.copyWith(
        vaccinations: vaccinations,
      ),
    );

    if (logActivity) {
      await _log.logVaccinationUpdated(record.vaccineName, profile.name);
    }
  }

  Future<void> deleteVaccination(
    String petId,
    String vaccinationId, {
    bool logActivity = true,
  }) async {
    final profile = _getById(petId);

    if (profile == null) return;

    VaccinationRecord? removed;
    for (final v in profile.vaccinations) {
      if (v.id == vaccinationId) {
        removed = v;
        break;
      }
    }

    final vaccinations = profile.vaccinations
        .where(
          (v) => v.id != vaccinationId,
        )
        .toList();

    await updateDetails(
      profile.copyWith(
        vaccinations: vaccinations,
      ),
    );

    if (logActivity && removed != null) {
      await _log.logVaccinationDeleted(removed.vaccineName, profile.name);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Complete vaccination dose
  // ─────────────────────────────────────────────────────────────────────────

  /// Completes one vaccination dose.
  ///
  /// NON-SERIES:
  ///
  /// Old pending record:
  ///     pending -> completed history
  ///
  /// Its reminder:
  ///     pending -> DONE
  ///
  /// A NEW vaccination record is created for the newly completed dose.
  ///
  /// If [nextSchedule] exists and reminders are enabled,
  /// another reminder is created and linked to the NEW record.
  ///
  /// SERIES:
  ///
  /// The upcoming record itself becomes completed.
  /// Its reminder becomes DONE.
  /// The reminder remains in the Done tab.
  ///
  /// The next dose already exists, so we do NOT create another one.

  /// Checks/unlocks Vaccine Hero and Vaccination Complete for one specific
  /// pet. Must be called AFTER the triggering vaccination update has
  /// already been persisted, so it re-fetches the pet fresh.
  ///
  /// [seriesId]/[totalDosesInSeries] should be the values from the dose
  /// that was JUST marked given — pass null for non-series doses, which
  /// simply skips the series check.
  Future<void> _checkVaccinationAchievements(
    String petId, {
    String? seriesId,
    int? totalDosesInSeries,
  }) async {
    final profile = _getById(petId);

    if (profile == null) return;

    final completedCount =
        profile.vaccinations.where((v) => v.status == 'completed').length;

    var achievements = await _unlockAndLog(
      profile.achievements,
      AchievementType.vaccinationComplete,
      completedCount,
      profile.name,
    );

    if (seriesId != null && totalDosesInSeries != null) {
      final completedInSeries = profile.vaccinations
          .where(
            (v) => v.seriesId == seriesId && v.status == 'completed',
          )
          .length;

      achievements = await _unlockAndLog(
        achievements,
        AchievementType.vaccinationSeriesComplete,
        completedInSeries >= totalDosesInSeries ? 1 : 0,
        profile.name,
      );
    }

    await updateDetails(
      profile.copyWith(achievements: achievements),
    );
  }

  Future<void> completeVaccinationDose(
    String petId,
    String oldRecordId, {
    required DateTime givenDate,
    DateTime? nextSchedule,
    bool reminderEnabled = false,
    ReminderProvider? reminderProvider,
  }) async {
    final pet = _getById(petId);

    if (pet == null) {
      return;
    }

    final old = _findVaccination(
      pet,
      oldRecordId,
    );

    if (old == null) {
      return;
    }

    // ───────────────────────────────────────────────────────────────────────
    // SERIES DOSE
    // ───────────────────────────────────────────────────────────────────────

    if (old.status == 'upcoming') {
      // Keep reminder in Done tab.
      if (old.linkedReminderId != null && reminderProvider != null) {
        await reminderProvider.markReminderDone(
          old.linkedReminderId!,
        );
      }

      // This dose is now complete.
      //
      // Clear the reminder link because the linked reminder is no longer
      // pending. The reminder itself remains in ReminderProvider's Done tab.
      final completed = old.copyWith(
        status: 'completed',
        completedDate: givenDate,
        nextSchedule: null,
        reminderEnabled: false,
        linkedReminderId: null,
      );

      await updateVaccination(
        petId,
        completed,
        logActivity: false,
      );

      await _log.logVaccinationCompleted(
        old.vaccineName,
        pet.name,
        wasPlanned: true,
      );

      await _checkVaccinationAchievements(
        petId,
        seriesId: old.seriesId,
        totalDosesInSeries: old.totalDosesInSeries,
      );

      return;
    }

    // ───────────────────────────────────────────────────────────────────────
    // NORMAL / NON-SERIES DOSE
    // ───────────────────────────────────────────────────────────────────────

    // Mark old reminder DONE.
    if (old.linkedReminderId != null && reminderProvider != null) {
      await reminderProvider.markReminderDone(
        old.linkedReminderId!,
      );
    }

    // The old pending record becomes historical.
    //
    // We clear its pending schedule and reminder relationship.
    final historical = old.copyWith(
      nextSchedule: null,
      reminderEnabled: false,
      linkedReminderId: null,
    );

    await updateVaccination(
      petId,
      historical,
      logActivity: false,
    );

    // Create a completely NEW record for this completed dose.
    final newRecordId = _uuid.v4();

    String? newReminderId;

    // Create next-dose reminder if requested.
    if (nextSchedule != null && reminderEnabled && reminderProvider != null) {
      newReminderId = _uuid.v4();

      await reminderProvider.addReminder(
        ReminderItem(
          id: newReminderId,
          title: "💉 ${old.vaccineName} — ${pet.name}'s next dose",
          type: 'Vet Visit',
          scheduledAt: nextSchedule,
          petId: petId,
          linkedVaccinationId: newRecordId,
        ),
      );
    }

    final newRecord = VaccinationRecord(
      id: newRecordId,
      vaccineName: old.vaccineName,
      completedDate: givenDate,
      nextSchedule: nextSchedule,
      vetNotes: old.vetNotes,
      reminderEnabled:
          nextSchedule != null && reminderEnabled && reminderProvider != null,
      linkedReminderId: newReminderId,
      status: 'completed',
      recurrenceType: old.recurrenceType,
      recurrenceIntervalDays: old.recurrenceIntervalDays,
      seriesId: old.seriesId,
      doseNumber: old.doseNumber,
      totalDosesInSeries: old.totalDosesInSeries,
    );

    await addVaccination(
      petId,
      newRecord,
      logActivity: false,
    );

    await _log.logVaccinationCompleted(
      old.vaccineName,
      pet.name,
    );

    await _checkVaccinationAchievements(
      petId,
      seriesId: old.seriesId,
      totalDosesInSeries: old.totalDosesInSeries,
    );
  }

  VaccinationRecord? _findVaccination(
    FullPetProfile pet,
    String id,
  ) {
    for (final record in pet.vaccinations) {
      if (record.id == id) {
        return record;
      }
    }

    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Vaccination series
  // ─────────────────────────────────────────────────────────────────────────

  /// Creates a bounded vaccination series.
  ///
  /// Example:
  ///
  /// FVRCP
  /// Dose 1 = Jan 1
  /// Dose 2 = Jan 22
  /// Dose 3 = Feb 12
  ///
  /// Each dose has:
  ///   • its own vaccination record ID
  ///   • its own reminder ID
  ///
  /// Therefore completing dose 2 can never accidentally complete dose 3.
  Future<void> addVaccinationSeries({
    required String petId,
    required String vaccineName,
    required DateTime firstGivenDate,
    required String vetNotes,
    required String recurrenceType,
    int? intervalDays,
    required int totalDoses,
    required bool reminderEnabled,
    ReminderProvider? reminderProvider,
  }) async {
    final pet = _getById(petId);

    if (pet == null) {
      return;
    }

    if (totalDoses < 1) {
      return;
    }

    final safeTotalDoses = totalDoses.clamp(1, 60);

    final safeInterval = (intervalDays ?? 7).clamp(1, 3650);

    final seriesId = _uuid.v4();

    final stepDays = recurrenceType == 'annual' ? 365 : safeInterval;

    DateTime dateForDose(
      int doseIndex,
    ) {
      return firstGivenDate.add(
        Duration(
          days: stepDays * doseIndex,
        ),
      );
    }

    // ───────────────────────────────────────────────────────────────────────
    // DOSE 1
    // ───────────────────────────────────────────────────────────────────────

    await addVaccination(
      petId,
      VaccinationRecord(
        id: _uuid.v4(),
        vaccineName: vaccineName,
        completedDate: firstGivenDate,
        vetNotes: vetNotes,
        status: 'completed',
        recurrenceType: recurrenceType,
        recurrenceIntervalDays:
            recurrenceType == 'everyXDays' ? stepDays : null,
        seriesId: seriesId,
        doseNumber: 1,
        totalDosesInSeries: safeTotalDoses,
        nextSchedule: null,
        reminderEnabled: false,
        linkedReminderId: null,
      ),
      logActivity: false,
    );

    // ───────────────────────────────────────────────────────────────────────
    // DOSES 2..N
    // ───────────────────────────────────────────────────────────────────────

    for (var index = 1; index < safeTotalDoses; index++) {
      final recordId = _uuid.v4();

      final plannedDate = dateForDose(index);

      String? reminderId;

      if (reminderEnabled && reminderProvider != null) {
        reminderId = _uuid.v4();

        await reminderProvider.addReminder(
          ReminderItem(
            id: reminderId,
            title:
                "💉 $vaccineName — ${pet.name}'s dose ${index + 1} of $safeTotalDoses",
            type: 'Vet Visit',
            scheduledAt: plannedDate,
            petId: petId,
            linkedVaccinationId: recordId,
          ),
        );
      }

      await addVaccination(
        petId,
        VaccinationRecord(
          id: recordId,
          vaccineName: vaccineName,

          // For planned records this is the planned dose date.
          // `status: upcoming` is what tells the UI that it has not
          // actually been administered yet.
          completedDate: plannedDate,

          nextSchedule: null,

          vetNotes: vetNotes,

          reminderEnabled: reminderId != null,

          linkedReminderId: reminderId,

          status: 'upcoming',

          recurrenceType: recurrenceType,

          recurrenceIntervalDays:
              recurrenceType == 'everyXDays' ? stepDays : null,

          seriesId: seriesId,

          doseNumber: index + 1,

          totalDosesInSeries: safeTotalDoses,
        ),
        logActivity: false,
      );
    }

    await _log.logVaccinationSeriesCreated(
      vaccineName,
      pet.name,
      safeTotalDoses,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Activity counters
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> incrementFeedCount(
    String petId,
  ) async {
    await _incrementCounter(
      petId,
      ActionType.feed,
    );
  }

  Future<void> incrementGroomCount(
    String petId,
  ) async {
    await _incrementCounter(
      petId,
      ActionType.groom,
    );
  }

  Future<void> incrementPlayCount(
    String petId,
  ) async {
    await _incrementCounter(
      petId,
      ActionType.play,
    );
  }

  Future<void> _incrementCounter(
    String petId,
    ActionType type,
  ) async {
    final profile = _getById(petId);

    if (profile == null) {
      return;
    }

    var feed = profile.feedCount;
    var groom = profile.groomCount;
    var play = profile.playCount;

    var achievements = List.of(profile.achievements);

    switch (type) {
      case ActionType.feed:
        feed++;

        achievements = _unlockAchievement(
          achievements,
          AchievementType.feedStreak,
          feed,
        );
        break;

      case ActionType.groom:
        groom++;

        achievements = _unlockAchievement(
          achievements,
          AchievementType.groomStreak,
          groom,
        );
        break;

      case ActionType.play:
        play++;

        achievements = _unlockAchievement(
          achievements,
          AchievementType.playStreak,
          play,
        );
        break;
    }

    await updateDetails(
      profile.copyWith(
        feedCount: feed,
        groomCount: groom,
        playCount: play,
        achievements: achievements,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Achievements
  // ─────────────────────────────────────────────────────────────────────────

  List<PetAchievement> _unlockAchievement(
    List<PetAchievement> achievements,
    AchievementType type,
    int progress,
  ) {
    return achievements.map((achievement) {
      if (achievement.type != type) {
        return achievement;
      }

      final updated = achievement.copyWith(
        progressCurrent: progress,
      );

      if (!achievement.unlocked && progress >= achievement.progressTarget) {
        return updated.copyWith(
          unlocked: true,
          unlockedAt: DateTime.now(),
        );
      }

      return updated;
    }).toList();
  }

  /// Runs [_unlockAchievement] and, if it actually flips the achievement
  /// from locked → unlocked (not just a progress update), logs exactly one
  /// ActivityLogService entry for that specific pet.
  Future<List<PetAchievement>> _unlockAndLog(
    List<PetAchievement> achievements,
    AchievementType type,
    int progress,
    String petName,
  ) async {
    final before = achievements.firstWhere((a) => a.type == type).unlocked;

    final updated = _unlockAchievement(
      achievements,
      type,
      progress,
    );

    final after = updated.firstWhere((a) => a.type == type).unlocked;

    if (!before && after) {
      final title = updated.firstWhere((a) => a.type == type).title;

      await _log.logAchievementUnlocked(title, petName);
    }

    return updated;
  }

  /// Checks/unlocks Grooming Pro, Healthy Eater, and Care Champion for one
  /// specific pet, based on that pet's own real-pet reminder completions.
  /// Reads directly from the existing persisted [ReminderItem] records
  /// (via [LocalStorageService]) rather than a separate counter, and
  /// counts ONLY reminders belonging to this [petId].
  ///
  /// Called from the reminder-completion action in the UI layer (not from
  /// ReminderProvider itself, to avoid a circular import between the two
  /// provider files).
  Future<void> checkCareAchievements(String petId) async {
    final profile = _getById(petId);

    if (profile == null) return;

    final allReminders =
        await LocalStorageService.instance.fetchReminderItems();

    final doneForThisPet = allReminders.where(
      (r) => r.petId == petId && r.isDone,
    );

    final groomingCount =
        doneForThisPet.where((r) => r.type == 'Grooming').length;

    final feedingCount =
        doneForThisPet.where((r) => r.type == 'Feeding').length;

    const careTypes = {
      'Feeding',
      'Grooming',
      'Exercise',
      'Vitamins',
    };

    final careCount =
        doneForThisPet.where((r) => careTypes.contains(r.type)).length;

    var achievements = await _unlockAndLog(
      profile.achievements,
      AchievementType.groomingCare,
      groomingCount,
      profile.name,
    );

    achievements = await _unlockAndLog(
      achievements,
      AchievementType.feedingCare,
      feedingCount,
      profile.name,
    );

    achievements = await _unlockAndLog(
      achievements,
      AchievementType.careChampion,
      careCount,
      profile.name,
    );

    await updateDetails(
      profile.copyWith(achievements: achievements),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Cloud sync
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> syncNow() async {
    if (!_auth.isAuthenticated) {
      return;
    }

    for (final profile in List<FullPetProfile>.from(_profiles)) {
      unawaited(
        _uploadToCloud(profile),
      );
    }

    await _downloadFromCloud();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  FullPetProfile? _getById(
    String id,
  ) {
    for (final profile in _profiles) {
      if (profile.id == id) {
        return profile;
      }
    }

    return null;
  }

  FullPetProfile? getById(
    String id,
  ) {
    return _getById(id);
  }

  String generateId() {
    return _uuid.v4();
  }
}

enum ActionType {
  feed,
  groom,
  play,
}
