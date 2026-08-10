// screens/pet_profiles/my_pet_profile_screen.dart
//
// Hub screen after selecting a cat.
// Shows 4 module cards: Pet Details, Growth Tracker, Vaccinations, Achievements.
//
// WHAT'S NEW:
//  • Hero card content is now centered (avatar, name, breed stacked and
//    centered) instead of left-aligned in a row.
//  • A "What's Next" card surfaces the nearest upcoming reminder and the
//    nearest vaccine due for THIS cat, pulled live from Care Reminders —
//    so parents don't have to hop between screens to know what's coming up.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:persipal_app/providers/reminder_provider.dart';
import 'package:persipal_app/models/reminder_item_model.dart';
import '../../providers/pet_profile_provider.dart';
import '../../models/pet_extended_models.dart';
import 'pet_details_screen.dart';
import 'growth_tracker_screen.dart';
import 'vaccination_screen.dart';
import 'achievements_screen.dart';
import 'reminder_screen.dart';
import '../../widgets/tap_effects.dart';

class MyPetProfileScreen extends StatefulWidget {
  final String petId;
  const MyPetProfileScreen({super.key, required this.petId});

  @override
  State<MyPetProfileScreen> createState() => _MyPetProfileScreenState();
}

class _MyPetProfileScreenState extends State<MyPetProfileScreen> {
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

  ReminderItem? _nextReminderFrom(List<ReminderItem> allReminders) {
    final upcoming = allReminders
        .where((r) => r.petId == widget.petId && !r.isDone)
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return upcoming.isEmpty ? null : upcoming.first;
  }

  VaccinationRecord? _nextVaccine(FullPetProfile pet) {
    final withSchedule = pet.vaccinations
        .where((v) => v.nextSchedule != null)
        .toList()
      ..sort((a, b) => a.nextSchedule!.compareTo(b.nextSchedule!));
    return withSchedule.isEmpty ? null : withSchedule.first;
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

    final unlockedCount = pet.achievements.where((a) => a.unlocked).length;
    final vaccineDue = pet.vaccinations.where((v) => v.isOverdue).length;
    final allReminders = context.watch<ReminderProvider>().reminders;
    final nextReminder = _nextReminderFrom(allReminders);
    final nextVaccine = _nextVaccine(pet);

    return Scaffold(
      backgroundColor: const Color(0xFFFFE6CC),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.10,
              child:
                  Image.asset('assets/images/paws_bg.png', fit: BoxFit.cover),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // ── Header ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          pet.name,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Care Reminders',
                        icon: const Icon(Icons.alarm, size: 22),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ReminderScreen()),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Hero cat card (now centered) ───────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 22, horizontal: 18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          pet.avatarColor,
                          pet.avatarColor.withOpacity(0.6),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: pet.avatarColor.withOpacity(0.4),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Centered avatar
                        Container(
                          width: 84,
                          height: 84,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.35),
                            shape: BoxShape.circle,
                          ),
                          child:
                              const Text('🐱', style: TextStyle(fontSize: 44)),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          pet.name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          pet.breed,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // ── What's Next card ────────────────────────────────────
                if (nextReminder != null || nextVaccine != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _WhatsNextCard(
                      reminder: nextReminder,
                      vaccine: nextVaccine,
                      onTapReminders: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ReminderScreen()),
                      ),
                      onTapVaccines: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                VaccinationScreen(petId: widget.petId)),
                      ),
                    ),
                  ),

                const SizedBox(height: 14),

                // ── Section label ─────────────────────────────────────
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'MANAGE PROFILE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: Color(0xFFAA7755),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // ── 4 Module cards ────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.1,
                      children: [
                        _ModuleCard(
                          emoji: '📋',
                          title: 'Pet Details',
                          subtitle: 'Full info & edit',
                          color: const Color(0xFFFF8C69),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  PetDetailsScreen(petId: widget.petId),
                            ),
                          ),
                        ),
                        _ModuleCard(
                          emoji: '📈',
                          title: 'Growth Tracker',
                          subtitle: '${pet.growthEntries.length} entries',
                          color: const Color(0xFF20B2AA),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  GrowthTrackerScreen(petId: widget.petId),
                            ),
                          ),
                        ),
                        _ModuleCard(
                          emoji: '💉',
                          title: 'Vaccinations',
                          subtitle: vaccineDue > 0
                              ? '$vaccineDue overdue!'
                              : '${pet.vaccinations.length} records',
                          color: const Color(0xFF7B68EE),
                          badgeText: vaccineDue > 0 ? '$vaccineDue' : null,
                          badgeColor: Colors.redAccent,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  VaccinationScreen(petId: widget.petId),
                            ),
                          ),
                        ),
                        _ModuleCard(
                          emoji: '🏆',
                          title: 'Achievements',
                          subtitle:
                              '$unlockedCount / ${pet.achievements.length} unlocked',
                          color: const Color(0xFFFFB347),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  AchievementsScreen(petId: widget.petId),
                            ),
                          ),
                        ),
                      ],
                    ),
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

// ─── What's Next Card ───────────────────────────────────────────────────────

class _WhatsNextCard extends StatelessWidget {
  final ReminderItem? reminder;
  final VaccinationRecord? vaccine;
  final VoidCallback onTapReminders;
  final VoidCallback onTapVaccines;

  const _WhatsNextCard({
    required this.reminder,
    required this.vaccine,
    required this.onTapReminders,
    required this.onTapVaccines,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.90),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('WHAT\'S NEXT',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Color(0xFFAA7755))),
          const SizedBox(height: 8),
          if (reminder != null)
            _row(
              onTap: onTapReminders,
              emoji: '⏰',
              text: reminder!.title,
              sub:
                  DateFormat('MMM d  •  hh:mm a').format(reminder!.scheduledAt),
              overdue: reminder!.scheduledAt.isBefore(DateTime.now()),
            ),
          if (reminder != null && vaccine != null) const SizedBox(height: 8),
          if (vaccine != null)
            _row(
              onTap: onTapVaccines,
              emoji: '💉',
              text: '${vaccine!.vaccineName} due',
              sub: DateFormat('MMM d, yyyy').format(vaccine!.nextSchedule!),
              overdue: vaccine!.isOverdue,
            ),
        ],
      ),
    );
  }

  Widget _row({
    required VoidCallback onTap,
    required String emoji,
    required String text,
    required String sub,
    required bool overdue,
  }) {
    final color = overdue ? Colors.redAccent : const Color(0xFF7B68EE);
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                  overdue ? 'Overdue · $sub' : sub,
                  style: TextStyle(
                      fontSize: 11, color: color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 18, color: color),
        ],
      ),
    );
  }
}

// ─── Module Card ──────────────────────────────────────────────────────────────

class _ModuleCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final String? badgeText;
  final Color? badgeColor;

  const _ModuleCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.badgeText,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return BounceButton(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.88),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 22)),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: TextStyle(
                              fontSize: 10, color: color.withOpacity(0.8))),
                    ],
                  ),
                ],
              ),
            ),
            if (badgeText != null)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor ?? color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badgeText!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
