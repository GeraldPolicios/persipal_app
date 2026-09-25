// screens/pet_health_dashboard_screen.dart
//
// Answers one question for the selected pet: "What is the current overall
// health and care status of THIS cat?" It is a status summary, not a second
// Activity History screen.
//
// Read-only aggregation of existing real-pet data for one pet:
//   • Pet Profile        -> PetProfileProvider.instance.getById(petId)
//   • Vaccination status  -> VaccinationRecord's existing computed getters
//   • Reminders           -> ReminderProvider.reminders, filtered by petId
//   • Growth               -> FullPetProfile.growthEntries
//
// This screen creates NO new storage, NO new providers, and does not
// duplicate or modify any existing scheduling/achievement/activity logic.
// It only reads and displays what already exists. Every value shown is
// synthesized from real app data — never a medical diagnosis.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/pet_extended_models.dart';
import '../../models/reminder_item_model.dart';
import '../../providers/pet_profile_provider.dart';
import '../../providers/reminder_provider.dart';
import '../../services/completed_care_history.dart';
import '../../services/pet_photo_service.dart';
import '../../utils/cat_weight_status.dart';
import '../../widgets/growth_chart.dart';
import '../../widgets/pet_photo_avatar.dart';
import 'completed_history_screen.dart';
import 'growth_tracker_screen.dart';

class PetHealthDashboardScreen extends StatefulWidget {
  final String petId;

  const PetHealthDashboardScreen({super.key, required this.petId});

  @override
  State<PetHealthDashboardScreen> createState() =>
      _PetHealthDashboardScreenState();
}

class _PetHealthDashboardScreenState extends State<PetHealthDashboardScreen> {
  final _provider = PetProfileProvider.instance;

  @override
  void initState() {
    super.initState();
    _provider.addListener(_refresh);
    PetPhotoService.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    _provider.removeListener(_refresh);
    PetPhotoService.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  FullPetProfile? get _pet => _provider.getById(widget.petId);

  // ── Add / edit a health/checkup note (PET-8) ───────────────────────────
  // One dialog for both: [existing] == null adds a new note, otherwise the
  // note is edited IN PLACE (same id — the provider replaces it, never
  // appends a second one).
  Future<void> _addHealthRecord(FullPetProfile pet) =>
      _showHealthRecordDialog(pet);

  Future<void> _showHealthRecordDialog(
    FullPetProfile pet, {
    HealthRecord? existing,
  }) async {
    final isEdit = existing != null;
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    DateTime selectedDate = existing?.date ?? DateTime.now();
    // An older note may pre-date the picker's normal 2020 lower bound —
    // widen it rather than assert on the initial date.
    final firstDate = selectedDate.isBefore(DateTime(2020))
        ? DateTime(selectedDate.year)
        : DateTime(2020);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          backgroundColor: const Color(0xFFFFF8F2),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC143C).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.health_and_safety,
                          color: Color(0xFFDC143C), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                          isEdit
                              ? 'Edit Health/Checkup Note'
                              : 'Add Health/Checkup Note',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  GestureDetector(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: firstDate,
                        lastDate: DateTime.now().isBefore(selectedDate)
                            ? selectedDate
                            : DateTime.now(),
                        builder: (c, child) => Theme(
                          data: Theme.of(c).copyWith(
                              colorScheme: const ColorScheme.light(
                                  primary: Color(0xFFDC143C))),
                          child: child!,
                        ),
                      );
                      if (d != null) setD(() => selectedDate = d);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                const Color(0xFFDC143C).withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.calendar_today,
                            size: 16, color: Color(0xFFDC143C)),
                        const SizedBox(width: 10),
                        Text(DateFormat('MMMM d, yyyy').format(selectedDate),
                            style: const TextStyle(fontSize: 13)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesCtrl,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Notes (symptoms, checkup findings, etc.) *',
                      labelStyle: const TextStyle(
                          fontSize: 12, color: Color(0xFFAA7755)),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel',
                            style: TextStyle(color: Colors.grey)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC143C),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        onPressed: () {
                          if (notesCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Enter a note.')));
                            return;
                          }
                          Navigator.pop(ctx, true);
                        },
                        child: Text(isEdit ? 'Save' : 'Add'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // (Not disposed here: the dialog's field is still animating out.)
    final notes = notesCtrl.text.trim();
    if (saved != true || !mounted) return;

    if (existing != null) {
      await _provider.updateHealthRecord(
        pet.id,
        existing.copyWith(date: selectedDate, notes: notes),
      );
    } else {
      await _provider.addHealthRecord(
        pet.id,
        HealthRecord(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          date: selectedDate,
          notes: notes,
        ),
      );
    }
  }

  // ── Delete a health/checkup note ───────────────────────────────────────
  Future<void> _deleteHealthRecord(
      FullPetProfile pet, HealthRecord record) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFFFFF8F2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Delete this note?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(
          'The health/checkup note from '
          '${DateFormat('MMMM d, yyyy').format(record.date)} will be '
          "permanently removed from ${pet.name}'s records.",
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _provider.deleteHealthRecord(pet.id, record.id);
  }

  @override
  Widget build(BuildContext context) {
    final pet = _pet;

    if (pet == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFE6CC),
        body: Center(child: Text('Profile not found.')),
      );
    }

    // ── Vaccinations — same computed getters/categorization already used
    // by vaccination_screen.dart. No new vaccination logic. ────────────────
    final completedVaccines =
        pet.vaccinations.where((v) => !v.isPlanned).toList();

    // Doses still to be given: planned series doses AND completed records
    // that carry a next-dose date (the same records the profile card's
    // "overdue" badge counts). Read only from THIS pet.
    final now = DateTime.now();
    final pendingVaccines = pendingVaccinationsFor(pet);
    final upcomingVaccines =
        pendingVaccines.where((p) => !p.isOverdueAt(now)).toList();
    final overdueVaccines =
        pendingVaccines.where((p) => p.isOverdueAt(now)).toList();

    final nextVaccine = overdueVaccines.isNotEmpty
        ? overdueVaccines.first
        : (upcomingVaccines.isNotEmpty ? upcomingVaccines.first : null);

    // ── Reminders — filtered from the existing ReminderProvider list.
    // ReminderProvider itself is untouched. ────────────────────────────────
    final allReminders = context.watch<ReminderProvider>().reminders;

    final petReminders =
        allReminders.where((r) => r.petId == widget.petId).toList();

    final overdueReminders = petReminders.where((r) => r.isOverdue).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final upcomingReminders = petReminders
        .where((r) => !r.isDone && !r.isOverdue)
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    // ── Veterinary Care — standalone vet-visit reminders only (excludes
    // reminders auto-linked to a vaccination dose, which are already
    // summarized under Preventive Care). Same source list (petReminders)
    // as above, just filtered further — no new data. ───────────────────────
    final vetVisitReminders = petReminders
        .where((r) => r.type == 'Vet Visit' && r.linkedVaccinationId == null)
        .toList();

    final upcomingVetVisits = vetVisitReminders
        .where((r) => !r.isDone && !r.isOverdue)
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final overdueVetVisits = vetVisitReminders.where((r) => r.isOverdue).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    final nextVetVisit = overdueVetVisits.isNotEmpty
        ? overdueVetVisits.first
        : (upcomingVetVisits.isNotEmpty ? upcomingVetVisits.first : null);

    // ── Completed care — ONE shared definition (services/
    // completed_care_history.dart, also behind the Completed History
    // screen): checkup notes + completed vet visits, doses actually given,
    // completed reminders — this pet only, never pending items. ─────────────
    final history = buildCompletedCareHistory(
      pet: pet,
      reminders: petReminders,
    );
    final completedCare = history.all;

    // ── Growth — existing model only, no new growth logic. ─────────────────
    GrowthEntry? latestGrowth;
    for (final entry in pet.growthEntries) {
      if (latestGrowth == null ||
          entry.recordedAt.isAfter(latestGrowth.recordedAt)) {
        latestGrowth = entry;
      }
    }

    // Compact "recorded period" summary for the collapsed preview only —
    // derived from the same pet.growthEntries already read above, no new
    // data source. Doesn't touch classifyCatWeight or the chart itself.
    String? growthPeriodSummary;
    if (pet.growthEntries.length >= 2) {
      var earliest = pet.growthEntries.first;
      var latest = pet.growthEntries.first;
      for (final e in pet.growthEntries) {
        if (e.recordedAt.isBefore(earliest.recordedAt)) earliest = e;
        if (e.recordedAt.isAfter(latest.recordedAt)) latest = e;
      }
      growthPeriodSummary = '${pet.growthEntries.length} entries · '
          '${DateFormat('MMM yyyy').format(earliest.recordedAt)} – '
          '${DateFormat('MMM yyyy').format(latest.recordedAt)}';
    }

    // Same entries, just newest-first — for the expanded, read-only
    // records list. No new data source.
    final growthEntriesNewestFirst = [...pet.growthEntries]
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));

    // ── Health & checkup notes (PET-8) — existing model field only. ────────
    final healthRecordsNewestFirst = [...pet.healthRecords]
      ..sort((a, b) => b.date.compareTo(a.date));

    // ── Overall Health & Care — a synthesized status headline, built only
    // from values already computed above (never a new data source, never a
    // medical diagnosis). Reminders linked to a vaccination dose are
    // excluded from the reminder-overdue/-upcoming counts here so a single
    // vaccine due date isn't counted twice against the vaccination counts
    // above it. ─────────────────────────────────────────────────────────────
    final unlinkedOverdueReminders =
        overdueReminders.where((r) => r.linkedVaccinationId == null).length;
    final unlinkedUpcomingReminders =
        upcomingReminders.where((r) => r.linkedVaccinationId == null).length;

    final overdueCareCount = overdueVaccines.length + unlinkedOverdueReminders;
    final upcomingCareCount =
        upcomingVaccines.length + unlinkedUpcomingReminders;

    final latestWeightStatus = latestGrowth == null
        ? null
        : classifyCatWeight(
            weightKg: latestGrowth.weightKg,
            birthDate: pet.birthDate,
            gender: pet.gender,
            asOf: latestGrowth.recordedAt,
          );

    return Scaffold(
      backgroundColor: const Color(0xFFFFE6CC),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.10,
              child: Image.asset(
                'assets/images/paws_bg.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // ── Header ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          '🩺  Health & Care',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      _OverviewCard(
                        pet: pet,
                        photoPath: PetPhotoService.instance.pathFor(pet.id),
                      ),
                      const SizedBox(height: 18),
                      const _SectionLabel('OVERALL HEALTH & CARE'),
                      const SizedBox(height: 8),
                      _OverallHealthCard(
                        overdueCount: overdueCareCount,
                        upcomingCount: upcomingCareCount,
                        weightStatusLabel: latestWeightStatus?.label,
                      ),
                      const SizedBox(height: 18),
                      _CollapsibleSection(
                        title: 'WEIGHT & GROWTH',
                        trailing: IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Open Growth Tracker',
                          icon: const Icon(Icons.show_chart,
                              size: 20, color: Color(0xFF20B2AA)),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  GrowthTrackerScreen(petId: widget.petId),
                            ),
                          ),
                        ),
                        collapsedPreview: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _GrowthCard(
                              entry: latestGrowth,
                              birthDate: pet.birthDate,
                              gender: pet.gender,
                            ),
                            if (pet.growthEntries.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              GrowthChart(
                                entries: pet.growthEntries,
                                statusForEntry: (e) => classifyCatWeight(
                                  weightKg: e.weightKg,
                                  birthDate: pet.birthDate,
                                  gender: pet.gender,
                                  asOf: e.recordedAt,
                                ).status,
                              ),
                            ],
                            if (growthPeriodSummary != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                '📈 $growthPeriodSummary',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFAA7755),
                                ),
                              ),
                            ],
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _GrowthCard(
                              entry: latestGrowth,
                              birthDate: pet.birthDate,
                              gender: pet.gender,
                            ),
                            if (pet.growthEntries.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              GrowthChart(
                                entries: pet.growthEntries,
                                statusForEntry: (e) => classifyCatWeight(
                                  weightKg: e.weightKg,
                                  birthDate: pet.birthDate,
                                  gender: pet.gender,
                                  asOf: e.recordedAt,
                                ).status,
                              ),
                            ],
                            if (growthPeriodSummary != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                '📈 $growthPeriodSummary',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFAA7755),
                                ),
                              ),
                            ],
                            if (growthEntriesNewestFirst.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              const _SectionLabel('ALL RECORDS'),
                              const SizedBox(height: 8),
                              _GrowthRecordsCard(
                                  entries: growthEntriesNewestFirst),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _SectionLabel('PREVENTIVE CARE'),
                      const SizedBox(height: 8),
                      _VaccinationCard(
                        completed: completedVaccines.length,
                        upcoming: upcomingVaccines.length,
                        overdue: overdueVaccines.length,
                        next: nextVaccine,
                      ),
                      const SizedBox(height: 18),
                      const _SectionLabel('VETERINARY CARE'),
                      const SizedBox(height: 8),
                      _VetVisitCard(
                        completed: history.vetVisits.length,
                        upcoming: upcomingVetVisits.length,
                        overdue: overdueVetVisits.length,
                        next: nextVetVisit,
                      ),
                      const SizedBox(height: 18),
                      _CollapsibleSection(
                        title: 'HEALTH & CHECKUP NOTES',
                        trailing: IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Add health/checkup note',
                          icon: const Icon(Icons.add_circle_outline,
                              size: 20, color: Color(0xFFDC143C)),
                          onPressed: () => _addHealthRecord(pet),
                        ),
                        headerSummary: Text(
                          '${pet.healthRecords.length} notes',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFAA7755),
                          ),
                        ),
                        collapsedPreview: healthRecordsNewestFirst.isEmpty
                            ? null
                            : _Card(
                                child: _HealthRecordRow(
                                    record: healthRecordsNewestFirst.first)),
                        child: _HealthRecordsCard(
                          entries: healthRecordsNewestFirst,
                          onEdit: (r) =>
                              _showHealthRecordDialog(pet, existing: r),
                          onDelete: (r) => _deleteHealthRecord(pet, r),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _SectionLabel('UPCOMING & OVERDUE CARE'),
                      const SizedBox(height: 8),
                      _ReminderBoxesSection(
                        upcoming: upcomingReminders,
                        overdue: overdueReminders,
                      ),
                      const SizedBox(height: 18),
                      _CollapsibleSection(
                        title: 'COMPLETED HISTORY',
                        trailing: IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Open Completed History',
                          icon: const Icon(Icons.history,
                              size: 20, color: Color(0xFF32CD32)),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CompletedHistoryScreen(petId: widget.petId),
                            ),
                          ),
                        ),
                        headerSummary: Text(
                          '${completedCare.length} completed',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFAA7755),
                          ),
                        ),
                        collapsedPreview: completedCare.isEmpty
                            ? null
                            : _Card(
                                child: _CompletedCareRow(
                                    entry: completedCare.first),
                              ),
                        child: _CompletedCareCard(entries: completedCare),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared card shell ────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.4,
        color: Color(0xFFAA7755),
      ),
    );
  }
}

// ─── Collapsible section wrapper ────────────────────────────────────────
//
// Wraps an existing section card (unchanged) with a tappable header.
// Collapsed by default. Owns its own expand/collapse state so no changes
// are needed to the parent screen's state class. Optional [collapsedPreview]
// renders a compact summary in place of [child] while the section is
// collapsed — sections that don't pass it behave exactly as before.
//
// No chevron: expansion is communicated by the collapsedPreview box
// itself being tappable (the primary trigger), with the header row kept
// tappable too as a secondary way to toggle/collapse.

class _CollapsibleSection extends StatefulWidget {
  final String title;
  final Widget child;
  final Widget? headerSummary;
  final Widget? collapsedPreview;
  // Rendered as a sibling of the toggle row (not inside its InkWell), so it
  // can carry its own onTap (e.g. "open Growth Tracker") without being
  // swallowed by the section's expand/collapse gesture.
  final Widget? trailing;

  const _CollapsibleSection({
    required this.title,
    required this.child,
    this.headerSummary,
    this.collapsedPreview,
    this.trailing,
  });

  @override
  State<_CollapsibleSection> createState() => _CollapsibleSectionState();
}

class _CollapsibleSectionState extends State<_CollapsibleSection> {
  bool _expanded = false;

  void _toggle() => setState(() => _expanded = !_expanded);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _toggle,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(child: _SectionLabel(widget.title)),
                      if (widget.headerSummary != null) widget.headerSummary!,
                    ],
                  ),
                ),
              ),
            ),
            if (widget.trailing != null) widget.trailing!,
          ],
        ),
        if (!_expanded && widget.collapsedPreview != null) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(18),
            child: widget.collapsedPreview!,
          ),
        ],
        if (_expanded) ...[
          const SizedBox(height: 8),
          InkWell(
            onTap: _toggle,
            borderRadius: BorderRadius.circular(18),
            child: widget.child,
          ),
        ],
      ],
    );
  }
}

// ─── Pet Overview ─────────────────────────────────────────────────────────

class _OverviewCard extends StatelessWidget {
  final FullPetProfile pet;
  final String? photoPath;

  const _OverviewCard({required this.pet, required this.photoPath});

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (pet.breed.isNotEmpty) pet.breed,
      if (pet.ageLabel.isNotEmpty) pet.ageLabel,
      if (pet.gender.isNotEmpty) pet.gender,
    ];

    return _Card(
      child: Row(
        children: [
          PetPhotoAvatar(
            photoPath: photoPath,
            color: pet.avatarColor,
            size: 64,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pet.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (details.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    details.join(' • '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFAA7755),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Overall Health & Care ────────────────────────────────────────────────
//
// A synthesized status headline built only from already-computed counts
// (overdue/upcoming vaccination + reminder totals, latest weight-status
// label). No new data source, no medical diagnosis — a summary of the
// app's own records, labeled as such.

class _OverallHealthCard extends StatelessWidget {
  final int overdueCount;
  final int upcomingCount;
  final String? weightStatusLabel;

  const _OverallHealthCard({
    required this.overdueCount,
    required this.upcomingCount,
    required this.weightStatusLabel,
  });

  @override
  Widget build(BuildContext context) {
    final hasOverdue = overdueCount > 0;
    final headline = hasOverdue
        ? '$overdueCount care item${overdueCount == 1 ? '' : 's'} need attention'
        : 'All caught up — no overdue care';
    final headlineColor =
        hasOverdue ? Colors.redAccent : const Color(0xFF32CD32);
    final headlineIcon = hasOverdue ? Icons.warning_amber_rounded : Icons.check_circle;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(headlineIcon, size: 20, color: headlineColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  headline,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: headlineColor,
                  ),
                ),
              ),
            ],
          ),
          if (upcomingCount > 0) ...[
            const SizedBox(height: 8),
            Text(
              '$upcomingCount upcoming care item${upcomingCount == 1 ? '' : 's'} on the way.',
              style: const TextStyle(fontSize: 12, color: Color(0xFFAA7755)),
            ),
          ],
          if (weightStatusLabel != null) ...[
            const SizedBox(height: 8),
            Text(
              '⚖️ Weight status: $weightStatusLabel',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF20B2AA),
              ),
            ),
          ],
          const SizedBox(height: 10),
          const Text(
            'Based on your logged care data only — not a medical diagnosis. '
            'Always consult your veterinarian for health concerns.',
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Vaccinations ─────────────────────────────────────────────────────────

class _VaccinationCard extends StatelessWidget {
  final int completed;
  final int upcoming;
  final int overdue;
  final PendingVaccination? next;

  const _VaccinationCard({
    required this.completed,
    required this.upcoming,
    required this.overdue,
    required this.next,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatChip(
                label: 'Completed',
                value: completed,
                color: const Color(0xFF32CD32),
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Upcoming',
                value: upcoming,
                color: const Color(0xFF4682B4),
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Overdue',
                value: overdue,
                color: overdue > 0 ? Colors.redAccent : const Color(0xFFAAAAAA),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (next != null)
            _NextItemRow(
              icon: Icons.vaccines,
              iconColor: next!.isOverdueAt(DateTime.now())
                  ? Colors.redAccent
                  : const Color(0xFF7B68EE),
              title: next!.record.vaccineName,
              subtitle: next!.isOverdueAt(DateTime.now())
                  ? 'Overdue since ${DateFormat('MMM d, yyyy').format(next!.dueAt)}'
                  : 'Due ${DateFormat('MMM d, yyyy').format(next!.dueAt)}',
            )
          else
            const _EmptyRow(text: 'No upcoming or overdue vaccinations.'),
        ],
      ),
    );
  }
}

// ─── Veterinary Care ──────────────────────────────────────────────────────
//
// Standalone vet-visit reminders (checkups, etc.) — excludes reminders
// auto-linked to a vaccination dose, which are already summarized under
// Preventive Care above. Same _StatChip/_NextItemRow/_EmptyRow shell as
// _VaccinationCard.

class _VetVisitCard extends StatelessWidget {
  final int completed;
  final int upcoming;
  final int overdue;
  final ReminderItem? next;

  const _VetVisitCard({
    required this.completed,
    required this.upcoming,
    required this.overdue,
    required this.next,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatChip(
                label: 'Completed',
                value: completed,
                color: const Color(0xFF32CD32),
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Upcoming',
                value: upcoming,
                color: const Color(0xFF4682B4),
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Overdue',
                value: overdue,
                color: overdue > 0 ? Colors.redAccent : const Color(0xFFAAAAAA),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (next != null)
            _NextItemRow(
              icon: Icons.local_hospital,
              iconColor:
                  next!.isOverdue ? Colors.redAccent : const Color(0xFF20B2AA),
              title: next!.title,
              subtitle: next!.isOverdue
                  ? 'Overdue since ${DateFormat('MMM d, yyyy').format(next!.scheduledAt)}'
                  : 'Due ${DateFormat('MMM d, yyyy').format(next!.scheduledAt)}',
            )
          else
            const _EmptyRow(text: 'No upcoming or overdue vet visits.'),
        ],
      ),
    );
  }
}

// ─── Completed History (dashboard summary) ────────────────────────────────
//
// Renders CompletedCareEntry items from buildCompletedCareHistory — the same
// list the full Completed History screen shows (this one is unfiltered).

class _CompletedCareCard extends StatelessWidget {
  final List<CompletedCareEntry> entries;

  const _CompletedCareCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: entries.isEmpty
          ? const _EmptyRow(text: 'No completed care yet.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _CompletedCareRow(entry: entries[i]),
                ],
              ],
            ),
    );
  }
}

class _CompletedCareRow extends StatelessWidget {
  final CompletedCareEntry entry;

  const _CompletedCareRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (entry.kind) {
      CompletedCareKind.vaccination => (
          Icons.vaccines,
          const Color(0xFF7B68EE)
        ),
      CompletedCareKind.vetVisit => (
          Icons.local_hospital,
          const Color(0xFF20B2AA)
        ),
      CompletedCareKind.reminder => (
          Icons.check_circle,
          const Color(0xFF32CD32)
        ),
    };
    final verb = switch (entry.kind) {
      CompletedCareKind.vaccination => 'Given',
      _ => 'Completed',
    };
    return _VetCareRow(
      icon: icon,
      iconColor: color,
      title: entry.title,
      dateLabel: '$verb: ${DateFormat('MMM d, yyyy').format(entry.date)}',
      notes: entry.notes,
      doseInfo: entry.doseInfo,
    );
  }
}

class _VetCareRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String dateLabel;
  final String? notes;
  final String? doseInfo;

  const _VetCareRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.dateLabel,
    this.notes,
    this.doseInfo,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 17, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                dateLabel,
                style: const TextStyle(fontSize: 11, color: Color(0xFFAA7755)),
              ),
              if (doseInfo != null) ...[
                const SizedBox(height: 2),
                Text(
                  doseInfo!,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFFAA7755)),
                ),
              ],
              if (notes != null && notes!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  notes!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF7A3B1E),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Reminders ────────────────────────────────────────────────────────────
//
// Two independently-tappable boxes (Upcoming / Overdue), each owning its
// own expand state. Tapping a box shows that category's FULL list
// (reusing the already-computed upcomingReminders/overdueReminders lists
// passed in from build() — no new filtering/sorting). Both boxes may be
// expanded at the same time.

class _ReminderBoxesSection extends StatefulWidget {
  final List<ReminderItem> upcoming;
  final List<ReminderItem> overdue;

  const _ReminderBoxesSection({required this.upcoming, required this.overdue});

  @override
  State<_ReminderBoxesSection> createState() => _ReminderBoxesSectionState();
}

class _ReminderBoxesSectionState extends State<_ReminderBoxesSection> {
  bool _upcomingExpanded = false;
  bool _overdueExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _ReminderBox(
                label: 'UPCOMING',
                count: widget.upcoming.length,
                color: const Color(0xFF4682B4),
                expanded: _upcomingExpanded,
                onTap: () =>
                    setState(() => _upcomingExpanded = !_upcomingExpanded),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ReminderBox(
                label: 'OVERDUE',
                count: widget.overdue.length,
                color: widget.overdue.isNotEmpty
                    ? Colors.redAccent
                    : const Color(0xFFAAAAAA),
                expanded: _overdueExpanded,
                onTap: () =>
                    setState(() => _overdueExpanded = !_overdueExpanded),
              ),
            ),
          ],
        ),
        if (_upcomingExpanded) ...[
          const SizedBox(height: 10),
          _ReminderListPanel(
            title: 'Upcoming Reminders',
            emptyText: 'No upcoming reminders.',
            items: widget.upcoming,
          ),
        ],
        if (_overdueExpanded) ...[
          const SizedBox(height: 10),
          _ReminderListPanel(
            title: 'Overdue Reminders',
            emptyText: 'No overdue reminders.',
            items: widget.overdue,
          ),
        ],
      ],
    );
  }
}

class _ReminderBox extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool expanded;
  final VoidCallback onTap;

  const _ReminderBox({
    required this.label,
    required this.count,
    required this.color,
    required this.expanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: expanded ? 0.22 : 0.12),
          borderRadius: BorderRadius.circular(16),
          border: expanded ? Border.all(color: color, width: 1.5) : null,
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderListPanel extends StatelessWidget {
  final String title;
  final String emptyText;
  final List<ReminderItem> items;

  const _ReminderListPanel({
    required this.title,
    required this.emptyText,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFFAA7755),
            ),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            _EmptyRow(text: emptyText)
          else
            for (final r in items) ...[
              _NextItemRow(
                icon: Icons.alarm,
                iconColor:
                    r.isOverdue ? Colors.redAccent : const Color(0xFF7B68EE),
                title: r.title,
                subtitle: r.isOverdue
                    ? 'Overdue since ${DateFormat('MMM d, yyyy').format(r.scheduledAt)}'
                    : 'Due ${DateFormat('MMM d, yyyy').format(r.scheduledAt)}',
              ),
              if (r != items.last) const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

// ─── Growth ───────────────────────────────────────────────────────────────

class _GrowthCard extends StatelessWidget {
  final GrowthEntry? entry;
  final DateTime? birthDate;
  final String gender;

  const _GrowthCard({
    required this.entry,
    required this.birthDate,
    required this.gender,
  });

  @override
  Widget build(BuildContext context) {
    final statusResult = entry == null
        ? null
        : classifyCatWeight(
            weightKg: entry!.weightKg,
            birthDate: birthDate,
            gender: gender,
            asOf: entry!.recordedAt,
          );

    return _Card(
      child: entry == null
          ? const _EmptyRow(text: 'No growth entries logged yet.')
          : Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF20B2AA).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('⚖️', style: TextStyle(fontSize: 20)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${entry!.weightKg} kg',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Recorded ${DateFormat('MMM d, yyyy').format(entry!.recordedAt)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFFAA7755),
                        ),
                      ),
                      if (entry!.notes.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          entry!.notes,
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF7A3B1E),
                          ),
                        ),
                      ],
                      if (statusResult != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          statusResult.label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF20B2AA),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          statusResult.detail,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFAA7755),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          kCatWeightStatusDisclaimer,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// Read-only list of individual growth records, newest-first — shown only
// in the expanded Growth section. No edit/delete actions (this dashboard
// is read-only); full CRUD history already lives in Growth Tracker.
// List of individual health/checkup notes, newest-first. Each note can be
// edited (in place) or deleted (after a confirmation dialog).
class _HealthRecordsCard extends StatelessWidget {
  final List<HealthRecord> entries;
  final void Function(HealthRecord) onEdit;
  final void Function(HealthRecord) onDelete;

  const _HealthRecordsCard({
    required this.entries,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: entries.isEmpty
          ? const _EmptyRow(text: 'No health or checkup notes yet.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final e in entries) ...[
                  _HealthRecordRow(
                    record: e,
                    onEdit: () => onEdit(e),
                    onDelete: () => onDelete(e),
                  ),
                  if (e != entries.last) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1),
                    ),
                  ],
                ],
              ],
            ),
    );
  }
}

class _HealthRecordRow extends StatelessWidget {
  final HealthRecord record;

  /// Null on the collapsed preview row, which has no actions.
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _HealthRecordRow({required this.record, this.onEdit, this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFDC143C).withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.health_and_safety,
              size: 17, color: Color(0xFFDC143C)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('MMM d, yyyy').format(record.date),
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                record.notes,
                style: const TextStyle(fontSize: 12, color: Color(0xFF7A3B1E)),
              ),
            ],
          ),
        ),
        if (onEdit != null)
          IconButton(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
            tooltip: 'Edit note',
            icon: const Icon(Icons.edit_outlined,
                size: 18, color: Color(0xFFAA7755)),
            onPressed: onEdit,
          ),
        if (onDelete != null)
          IconButton(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
            tooltip: 'Delete note',
            icon: const Icon(Icons.delete_outline,
                size: 18, color: Colors.redAccent),
            onPressed: onDelete,
          ),
      ],
    );
  }
}

class _GrowthRecordsCard extends StatelessWidget {
  final List<GrowthEntry> entries;

  const _GrowthRecordsCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final e in entries) ...[
            _GrowthRecordRow(entry: e),
            if (e != entries.last) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _GrowthRecordRow extends StatelessWidget {
  final GrowthEntry entry;

  const _GrowthRecordRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFF20B2AA).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text('⚖️', style: TextStyle(fontSize: 14)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${entry.weightKg} kg',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('MMM d, yyyy').format(entry.recordedAt),
                style: const TextStyle(fontSize: 11, color: Color(0xFFAA7755)),
              ),
              if (entry.notes.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  entry.notes,
                  style: const TextStyle(
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF7A3B1E),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Small shared pieces ──────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextItemRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  const _NextItemRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 17, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 11, color: Color(0xFFAA7755)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyRow extends StatelessWidget {
  final String text;

  const _EmptyRow({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontStyle: FontStyle.italic,
        color: Color(0xFFAA7755),
      ),
    );
  }
}
