// lib/services/completed_care_history.dart
//
// Pure, read-only aggregation of ONE real pet's completed care — no Hive, no
// Firestore, no providers, no new storage. Everything here is derived from
// data that already exists and is already persisted/synced:
//   • FullPetProfile.healthRecords   — checkup notes (date = visit date)
//   • FullPetProfile.vaccinations    — doses actually given (completedDate)
//   • ReminderItem                   — completed care reminders (completedAt)
//
// It is a function of (pet, reminders, filter) so the rules are unit-testable
// (test/completed_care_history_test.dart) and both the Health & Care
// dashboard and the Completed History screen share one definition of
// "completed".
//
// RULES
//   • Scoped to the given pet: reminders are matched by petId, and the pet's
//     own vaccinations/notes are the only ones read. Another pet's data can
//     never appear.
//   • Only COMPLETED items: pending/overdue/upcoming reminders, planned
//     ('upcoming') vaccination doses and deleted records are never included.
//   • A reminder linked to a vaccination dose is skipped — the vaccination
//     record IS that event, so listing both would show it twice.
//   • The date filter only decides what is listed; no record is touched.

import '../models/pet_extended_models.dart';
import '../models/reminder_item_model.dart';
import '../widgets/date_filter_control.dart';

enum CompletedCareKind { vetVisit, vaccination, reminder }

/// One completed item, normalised for display. [date] is the moment the
/// filter is applied to: visit date (checkup note), given date
/// (vaccination) or completedAt (reminder).
class CompletedCareEntry {
  final CompletedCareKind kind;

  /// Id of the source record (HealthRecord / VaccinationRecord /
  /// ReminderItem) — never a new identity.
  final String id;
  final String title;
  final DateTime date;
  final String? notes;
  final String? doseInfo;

  /// Short label for what the entry came from, e.g. 'Checkup note',
  /// 'Vet visit', or a reminder's own type ('Feeding').
  final String sourceLabel;

  const CompletedCareEntry({
    required this.kind,
    required this.id,
    required this.title,
    required this.date,
    required this.sourceLabel,
    this.notes,
    this.doseInfo,
  });
}

class CompletedCareHistory {
  /// Completed checkup notes + completed standalone Vet Visit reminders.
  final List<CompletedCareEntry> vetVisits;

  /// Doses actually given.
  final List<CompletedCareEntry> vaccinations;

  /// Every other completed care reminder.
  final List<CompletedCareEntry> reminders;

  const CompletedCareHistory({
    this.vetVisits = const [],
    this.vaccinations = const [],
    this.reminders = const [],
  });

  int get total => vetVisits.length + vaccinations.length + reminders.length;
  bool get isEmpty => total == 0;

  /// All entries, newest first.
  List<CompletedCareEntry> get all => [
        ...vetVisits,
        ...vaccinations,
        ...reminders,
      ]..sort((a, b) => b.date.compareTo(a.date));
}

/// Whether [at] falls inside a [start, end) window ([range] null = no filter).
bool completedDateInRange(DateTime at, (DateTime, DateTime)? range) {
  if (range == null) return true;
  return !at.isBefore(range.$1) && at.isBefore(range.$2);
}

/// The date a completed reminder is filed under: when it was actually
/// completed. A record saved before completedAt existed falls back to its
/// scheduled time so it isn't dropped (same rule as the Reminders Done tab).
DateTime reminderCompletionDate(ReminderItem r) => r.completedAt ?? r.scheduledAt;

/// True for a completed reminder that belongs in the history's
/// "Veterinary Visits" group (a standalone Vet Visit — not one auto-created
/// for a vaccination dose).
bool isStandaloneVetVisitReminder(ReminderItem r) =>
    r.type == 'Vet Visit' && r.linkedVaccinationId == null;

CompletedCareHistory buildCompletedCareHistory({
  required FullPetProfile pet,
  required Iterable<ReminderItem> reminders,
  DateFilterSelection filter = const DateFilterSelection.allDates(),
  DateTime? now,
}) {
  final range = dateRangeForSelection(filter, now: now);
  int newestFirst(CompletedCareEntry a, CompletedCareEntry b) =>
      b.date.compareTo(a.date);

  final vetVisits = <CompletedCareEntry>[
    for (final n in pet.healthRecords)
      if (completedDateInRange(n.date, range))
        CompletedCareEntry(
          kind: CompletedCareKind.vetVisit,
          id: n.id,
          title: 'Health / checkup note',
          date: n.date,
          notes: n.notes.trim().isEmpty ? null : n.notes,
          sourceLabel: 'Checkup note',
        ),
  ];

  final vaccinations = <CompletedCareEntry>[
    for (final v in pet.vaccinations)
      if (!v.isPlanned && completedDateInRange(v.completedDate, range))
        CompletedCareEntry(
          kind: CompletedCareKind.vaccination,
          id: v.id,
          title: v.vaccineName,
          date: v.completedDate,
          notes: v.vetNotes.trim().isEmpty ? null : v.vetNotes,
          doseInfo: (v.doseNumber != null && v.totalDosesInSeries != null)
              ? 'Dose ${v.doseNumber} of ${v.totalDosesInSeries}'
              : null,
          sourceLabel: 'Vaccination',
        ),
  ];

  final completedReminders = <CompletedCareEntry>[];
  for (final r in reminders) {
    if (r.petId != pet.id) continue; // never another pet's (or no pet's)
    if (!r.isDone) continue; // pending / overdue are not history
    if (r.linkedVaccinationId != null) continue; // the dose record is the event
    final at = reminderCompletionDate(r);
    if (!completedDateInRange(at, range)) continue;

    if (isStandaloneVetVisitReminder(r)) {
      vetVisits.add(CompletedCareEntry(
        kind: CompletedCareKind.vetVisit,
        id: r.id,
        title: r.title,
        date: at,
        sourceLabel: 'Vet visit',
      ));
    } else {
      completedReminders.add(CompletedCareEntry(
        kind: CompletedCareKind.reminder,
        id: r.id,
        title: r.title,
        date: at,
        sourceLabel: r.type,
      ));
    }
  }

  return CompletedCareHistory(
    vetVisits: vetVisits..sort(newestFirst),
    vaccinations: vaccinations..sort(newestFirst),
    reminders: completedReminders..sort(newestFirst),
  );
}

// ─── Pending vaccination doses (Health & Care dashboard) ─────────────────────

/// A vaccination dose still ahead of (or past) its due time, with the moment
/// it is/was due.
class PendingVaccination {
  final VaccinationRecord record;
  final DateTime dueAt;
  const PendingVaccination(this.record, this.dueAt);

  bool isOverdueAt(DateTime now) => !dueAt.isAfter(now);
}

/// Doses of [pet] not yet given: planned series doses (due at their planned
/// date+time) and completed records that carry a next-dose date (due then).
/// Sorted soonest first. Per-pet by construction — reads only [pet].
List<PendingVaccination> pendingVaccinationsFor(FullPetProfile pet) {
  final out = <PendingVaccination>[
    for (final v in pet.vaccinations)
      if (v.isPlanned)
        PendingVaccination(v, v.scheduledDateTime)
      else if (v.nextSchedule != null)
        PendingVaccination(v, v.nextSchedule!),
  ]..sort((a, b) => a.dueAt.compareTo(b.dueAt));
  return out;
}
