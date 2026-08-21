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

    // ── Growth — existing model only, no new growth logic. ─────────────────
    GrowthEntry? latestGrowth;
    for (final entry in pet.growthEntries) {
      if (latestGrowth == null ||
          entry.recordedAt.isAfter(latestGrowth.recordedAt)) {
        latestGrowth = entry;
      }
    }

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
                      const _SectionLabel('REMINDERS'),
                      const SizedBox(height: 8),
                      _RemindersCard(
                        upcoming: upcomingReminders,
                        overdue: overdueReminders,
                      ),
                      const SizedBox(height: 18),
                      const _SectionLabel('GROWTH'),
                      const SizedBox(height: 8),
                      _GrowthCard(entry: latestGrowth),
                      const SizedBox(height: 18),
                      const _SectionLabel('RECENT ACTIVITY'),
                      const SizedBox(height: 8),
                      _RecentActivityCard(activities: recentActivity),
                      const SizedBox(height: 18),
                      const _SectionLabel('QUICK SUMMARY'),
                      const SizedBox(height: 8),
                      _QuickSummaryGrid(
                        upcomingVaccines: upcomingVaccines.length,
                        overdueVaccines: overdueVaccines.length,
                        upcomingReminders: upcomingReminders.length,
                        overdueReminders: overdueReminders.length,
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

// ─── Reminders ────────────────────────────────────────────────────────────

class _RemindersCard extends StatelessWidget {
  final List<ReminderItem> upcoming;
  final List<ReminderItem> overdue;

  const _RemindersCard({required this.upcoming, required this.overdue});

  @override
  Widget build(BuildContext context) {
    final combined = [...overdue, ...upcoming].take(4).toList();

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatChip(
                label: 'Upcoming',
                value: upcoming.length,
                color: const Color(0xFF4682B4),
              ),
              const SizedBox(width: 8),
              _StatChip(
                label: 'Overdue',
                value: overdue.length,
                color: overdue.isNotEmpty
                    ? Colors.redAccent
                    : const Color(0xFFAAAAAA),
              ),
            ],
          ),
          if (combined.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final r in combined) ...[
              _NextItemRow(
                icon: Icons.alarm,
                iconColor:
                    r.isOverdue ? Colors.redAccent : const Color(0xFF7B68EE),
                title: r.title,
                subtitle: r.isOverdue
                    ? 'Overdue since ${DateFormat('MMM d, yyyy').format(r.scheduledAt)}'
                    : 'Due ${DateFormat('MMM d, yyyy').format(r.scheduledAt)}',
              ),
              if (r != combined.last) const SizedBox(height: 8),
            ],
          ] else ...[
            const SizedBox(height: 12),
            const _EmptyRow(text: 'No upcoming or overdue reminders.'),
          ],
        ],
      ),
    );
  }
}

// ─── Growth ───────────────────────────────────────────────────────────────

class _GrowthCard extends StatelessWidget {
  final GrowthEntry? entry;

  const _GrowthCard({required this.entry});

  @override
  Widget build(BuildContext context) {
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
                    ],
                  ),
                ),
              ],
            ),
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
                    itemBuilder: (_, index) {
                      final a = activities[index];

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
                                  DateFormat(
                                    'MMM d, h:mm a',
                                  ).format(a.timestamp),
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
                    },
                  ),
                ),
              ],
            ),
    );
  }
}  

// ─── Quick summary ────────────────────────────────────────────────────────

class _QuickSummaryGrid extends StatelessWidget {
  final int upcomingVaccines;
  final int overdueVaccines;
  final int upcomingReminders;
  final int overdueReminders;

  const _QuickSummaryGrid({
    required this.upcomingVaccines,
    required this.overdueVaccines,
    required this.upcomingReminders,
    required this.overdueReminders,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.4,
      children: [
        _SummaryTile(
          emoji: '💉',
          label: 'Upcoming vaccinations',
          value: upcomingVaccines,
          color: const Color(0xFF4682B4),
        ),
        _SummaryTile(
          emoji: '⚠️',
          label: 'Overdue vaccinations',
          value: overdueVaccines,
          color:
              overdueVaccines > 0 ? Colors.redAccent : const Color(0xFFAAAAAA),
        ),
        _SummaryTile(
          emoji: '🔔',
          label: 'Upcoming reminders',
          value: upcomingReminders,
          color: const Color(0xFF7B68EE),
        ),
        _SummaryTile(
          emoji: '⏰',
          label: 'Overdue reminders',
          value: overdueReminders,
          color:
              overdueReminders > 0 ? Colors.redAccent : const Color(0xFFAAAAAA),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String emoji;
  final String label;
  final int value;
  final Color color;

  const _SummaryTile({
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
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
