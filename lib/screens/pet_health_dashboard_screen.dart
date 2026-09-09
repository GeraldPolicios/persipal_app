// screens/pet_health_dashboard_screen.dart
//
// Read-only aggregation of existing real-pet data for one pet:
//   • Pet Profile        -> PetProfileProvider.instance.getById(petId)
//   • Vaccination status  -> VaccinationRecord's existing computed getters
//   • Reminders           -> ReminderProvider.reminders, filtered by petId
//   • Growth               -> FullPetProfile.growthEntries
//   • Recent Activity     -> ActivityLogService.instance.logs, filtered by petId
//
// This screen creates NO new storage, NO new providers, and does not
// duplicate or modify any existing scheduling/achievement/activity logic.
// It only reads and displays what already exists.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/models.dart';
import '../../models/pet_extended_models.dart';
import '../../models/reminder_item_model.dart';
import '../../providers/pet_profile_provider.dart';
import '../../providers/reminder_provider.dart';
import '../../services/activity_log_service.dart';
import '../../utils/cat_weight_status.dart';
import '../../widgets/growth_chart.dart';

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
  }

  @override
  void dispose() {
    _provider.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  FullPetProfile? get _pet => _provider.getById(widget.petId);

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

    final upcomingVaccines =
        pet.vaccinations.where((v) => v.isFuturePlanned).toList()
          ..sort(
            (a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime),
          );

    final overdueVaccines = pet.vaccinations.where((v) => v.isDueNow).toList()
      ..sort(
        (a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime),
      );

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

    // ── Completed Veterinary Care — completed vaccinations (existing data)
    // plus standalone completed Vet Visit reminders. Reminders linked to a
    // vaccination dose (linkedVaccinationId != null) are excluded so the
    // same event isn't shown twice.
    //
    // Only FULLY completed vaccination series are shown here — a dose is
    // included only if it's the final dose of its series (doseNumber ==
    // totalDosesInSeries) or isn't part of a series at all (both fields
    // null, i.e. a single-dose vaccination). This filter applies ONLY to
    // this dashboard section — completedVaccines itself (used above by
    // _VaccinationCard's "Completed" stat) is untouched. ───────────────────
    final fullyCompletedVaccines = completedVaccines.where((v) {
      if (v.doseNumber == null || v.totalDosesInSeries == null) return true;
      return v.doseNumber == v.totalDosesInSeries;
    }).toList();

    final completedVetVisitReminders = petReminders
        .where((r) =>
            r.type == 'Vet Visit' && r.isDone && r.linkedVaccinationId == null)
        .toList();

    final completedVetCare = <_VetCareEntry>[
      ...fullyCompletedVaccines.map(_VetCareEntry.vaccination),
      ...completedVetVisitReminders.map(_VetCareEntry.vetVisit),
    ]..sort((a, b) => b.date.compareTo(a.date));

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

    // ── Recent activity — filtered by the now-correct petId. ───────────────
    final recentActivity = context
        .watch<ActivityLogService>()
        .logs
        .where((a) => a.petId == widget.petId)
        .take(6)
        .toList();

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
                      _OverviewCard(pet: pet),
                      const SizedBox(height: 18),
                      const _SectionLabel('VACCINATIONS'),
                      const SizedBox(height: 8),
                      _VaccinationCard(
                        completed: completedVaccines.length,
                        upcoming: upcomingVaccines.length,
                        overdue: overdueVaccines.length,
                        next: nextVaccine,
                      ),
                      const SizedBox(height: 18),
                      _CollapsibleSection(
                        title: 'COMPLETED VETERINARY CARE',
                        headerSummary: Text(
                          '${completedVetCare.length} completed',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFAA7755),
                          ),
                        ),
                        collapsedPreview: completedVetCare.isEmpty
                            ? null
                            : _Card(
                                child: completedVetCare.first.isVaccination
                                    ? _VetCareRow(
                                        icon: Icons.vaccines,
                                        iconColor: const Color(0xFF7B68EE),
                                        title: completedVetCare
                                            .first.vaccination!.vaccineName,
                                        dateLabel:
                                            'Completed: ${DateFormat('MMM d, yyyy').format(completedVetCare.first.vaccination!.completedDate)}',
                                      )
                                    : _VetCareRow(
                                        icon: Icons.local_hospital,
                                        iconColor: const Color(0xFF20B2AA),
                                        title: completedVetCare
                                            .first.reminder!.title,
                                        dateLabel:
                                            'Scheduled: ${DateFormat('MMM d, yyyy').format(completedVetCare.first.reminder!.scheduledAt)}',
                                      ),
                              ),
                        child: _CompletedVetCareCard(entries: completedVetCare),
                      ),
                      const SizedBox(height: 18),
                      const _SectionLabel('REMINDERS'),
                      const SizedBox(height: 8),
                      _ReminderBoxesSection(
                        upcoming: upcomingReminders,
                        overdue: overdueReminders,
                      ),
                      const SizedBox(height: 18),
                      _CollapsibleSection(
                        title: 'GROWTH',
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
                      _CollapsibleSection(
                        title: 'RECENT ACTIVITY',
                        maxHeight: 250,
                        collapsedPreview: recentActivity.isEmpty
                            ? null
                            : _Card(
                                child: _ActivityRow(a: recentActivity.first)),
                        child: _RecentActivityCard(activities: recentActivity),
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
// are needed to the parent screen's state class. Optional [maxHeight]
// bounds the expanded content in a scrollable box — used only by Recent
// Activity. Optional [collapsedPreview] renders a compact summary in
// place of [child] while the section is collapsed — sections that don't
// pass it behave exactly as before.
//
// No chevron: expansion is communicated by the collapsedPreview box
// itself being tappable (the primary trigger), with the header row kept
// tappable too as a secondary way to toggle/collapse.

class _CollapsibleSection extends StatefulWidget {
  final String title;
  final Widget child;
  final double? maxHeight;
  final Widget? headerSummary;
  final Widget? collapsedPreview;

  const _CollapsibleSection({
    required this.title,
    required this.child,
    this.maxHeight,
    this.headerSummary,
    this.collapsedPreview,
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
        InkWell(
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
            child: widget.maxHeight != null
                ? SizedBox(
                    height: widget.maxHeight,
                    child: SingleChildScrollView(child: widget.child),
                  )
                : widget.child,
          ),
        ],
      ],
    );
  }
}

// ─── Pet Overview ─────────────────────────────────────────────────────────

class _OverviewCard extends StatelessWidget {
  final FullPetProfile pet;

  const _OverviewCard({required this.pet});

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (pet.breed.isNotEmpty) pet.breed,
      if (pet.age.isNotEmpty) pet.age,
      if (pet.gender.isNotEmpty) pet.gender,
    ];

    return _Card(
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: pet.avatarColor,
            child: Text(
              pet.name.isNotEmpty ? pet.name[0].toUpperCase() : '🐱',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
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

// ─── Vaccinations ─────────────────────────────────────────────────────────

class _VaccinationCard extends StatelessWidget {
  final int completed;
  final int upcoming;
  final int overdue;
  final VaccinationRecord? next;

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
              iconColor:
                  next!.isDueNow ? Colors.redAccent : const Color(0xFF7B68EE),
              title: next!.vaccineName,
              subtitle: next!.isDueNow
                  ? 'Overdue since ${DateFormat('MMM d, yyyy').format(next!.scheduledDateTime)}'
                  : 'Due ${DateFormat('MMM d, yyyy').format(next!.scheduledDateTime)}',
            )
          else
            const _EmptyRow(text: 'No upcoming or overdue vaccinations.'),
        ],
      ),
    );
  }
}

// ─── Completed Veterinary Care ────────────────────────────────────────────
//
// Combines completed vaccinations (existing VaccinationRecord data) with
// standalone completed 'Vet Visit' reminders (existing ReminderProvider
// data). Vet Visit reminders auto-linked to a vaccination dose are
// excluded to avoid showing the same event twice.

class _VetCareEntry {
  final DateTime date;
  final VaccinationRecord? vaccination;
  final ReminderItem? reminder;

  _VetCareEntry.vaccination(VaccinationRecord v)
      : vaccination = v,
        reminder = null,
        date = v.completedDate;

  _VetCareEntry.vetVisit(ReminderItem r)
      : vaccination = null,
        reminder = r,
        date = r.scheduledAt;

  bool get isVaccination => vaccination != null;
}

class _CompletedVetCareCard extends StatelessWidget {
  final List<_VetCareEntry> entries;

  const _CompletedVetCareCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: entries.isEmpty
          ? const _EmptyRow(text: 'No completed veterinary care yet.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final e in entries) ...[
                  if (e.isVaccination)
                    _VetCareRow(
                      icon: Icons.vaccines,
                      iconColor: const Color(0xFF7B68EE),
                      title: e.vaccination!.vaccineName,
                      dateLabel:
                          'Completed: ${DateFormat('MMM d, yyyy').format(e.vaccination!.completedDate)}',
                      notes: e.vaccination!.vetNotes.isNotEmpty
                          ? e.vaccination!.vetNotes
                          : null,
                      doseInfo: (e.vaccination!.doseNumber != null &&
                              e.vaccination!.totalDosesInSeries != null)
                          ? 'Dose ${e.vaccination!.doseNumber} of ${e.vaccination!.totalDosesInSeries}'
                          : null,
                    )
                  else
                    _VetCareRow(
                      icon: Icons.local_hospital,
                      iconColor: const Color(0xFF20B2AA),
                      title: e.reminder!.title,
                      dateLabel:
                          'Scheduled: ${DateFormat('MMM d, yyyy').format(e.reminder!.scheduledAt)}',
                    ),
                  if (e != entries.last) const SizedBox(height: 10),
                ],
              ],
            ),
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

// ─── Recent activity ──────────────────────────────────────────────────────

class _RecentActivityCard extends StatelessWidget {
  final List<ActivityLogModel> activities;

  const _RecentActivityCard({
    required this.activities,
  });

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: activities.isEmpty
          ? const _EmptyRow(
              text: 'No recent activity for this pet yet.',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Scrollable activity area
                SizedBox(
                  height: 220,
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: activities.length,
                    separatorBuilder: (_, __) => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1),
                    ),
                    itemBuilder: (_, index) =>
                        _ActivityRow(a: activities[index]),
                  ),
                ),
              ],
            ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  final ActivityLogModel a;

  const _ActivityRow({required this.a});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: a.iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            a.icon,
            size: 17,
            color: a.iconColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                a.description,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('MMM d, h:mm a').format(a.timestamp),
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFAA7755),
                ),
              ),
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
