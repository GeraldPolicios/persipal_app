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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:persipal_app/providers/reminder_provider.dart';
import 'package:persipal_app/models/reminder_item_model.dart';
import '../../providers/pet_profile_provider.dart';
import '../../models/pet_extended_models.dart';
import '../../services/pet_photo_service.dart';
import '../../widgets/pet_photo_avatar.dart';
import 'pet_details_screen.dart';
import 'growth_tracker_screen.dart';
import 'vaccination_screen.dart';
import 'achievements_screen.dart';
import 'reminder_screen.dart';
import 'pet_health_dashboard_screen.dart';
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
    PetPhotoService.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    _provider.removeListener(_refresh);
    PetPhotoService.instance.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _changePhoto() async {
    final file = await pickPetPhotoFromGallery(context);
    if (file != null) {
      await PetPhotoService.instance.setPhoto(widget.petId, file);
    }
  }

  Future<void> _changeCoverPhoto() async {
    final file = await pickPetPhotoFromGallery(context);
    if (file != null) {
      await PetPhotoService.instance.setCoverPhoto(widget.petId, file);
    }
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

                // ── Scrollable content ──────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Column(
                      children: [
                        // ── Hero cat card ───────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: _ProfileHero(
                            pet: pet,
                            photoPath:
                                PetPhotoService.instance.pathFor(pet.id),
                            coverPhotoPath: PetPhotoService.instance
                                .coverPathFor(pet.id),
                            onTapPhoto: _changePhoto,
                            onTapCover: _changeCoverPhoto,
                          ),
                        ),

                        const SizedBox(height: 14),

                        // ── Pet info chips ──────────────────────────────
                        if (_infoChips(pet).isNotEmpty)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            child: _InfoChipsCard(chips: _infoChips(pet)),
                          ),

                        if (_infoChips(pet).isNotEmpty)
                          const SizedBox(height: 14),

                        // ── What's Next card ────────────────────────────
                        if (nextReminder != null || nextVaccine != null)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
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
                                    builder: (_) => VaccinationScreen(
                                        petId: widget.petId)),
                              ),
                            ),
                          ),

                        const SizedBox(height: 14),

                        // ── Section label ────────────────────────────────
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

                        // ── 5 Module cards ──────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
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
                                emoji: '🩺',
                                title: 'Health & Care',
                                subtitle: 'Full overview',
                                color: const Color(0xFF32CD32),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PetHealthDashboardScreen(
                                      petId: widget.petId,
                                    ),
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
                                    builder: (_) => GrowthTrackerScreen(
                                        petId: widget.petId),
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
                                badgeText:
                                    vaccineDue > 0 ? '$vaccineDue' : null,
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

// ─── Info chips ─────────────────────────────────────────────────────────────

class _ChipData {
  final String emoji;
  final String label;
  final String value;
  const _ChipData(this.emoji, this.label, this.value);
}

List<_ChipData> _infoChips(FullPetProfile pet) {
  final chips = <_ChipData>[];
  if (pet.birthday.trim().isNotEmpty) {
    chips.add(_ChipData('🎂', 'Birthday', pet.birthday));
  }
  if (pet.ageLabel.isNotEmpty) {
    chips.add(_ChipData('🐾', 'Age', pet.ageLabel));
  }
  if (pet.furColor.trim().isNotEmpty) {
    chips.add(_ChipData('🎨', 'Fur Color', pet.furColor));
  }
  if (pet.adoptionDate.trim().isNotEmpty) {
    chips.add(_ChipData('🏠', 'Adopted', pet.adoptionDate));
  }
  final latestWeight = pet.growthEntries.isNotEmpty
      ? pet.growthEntries.last.weightKg
      : double.tryParse(pet.weightKg.trim());
  if (latestWeight != null && latestWeight > 0) {
    chips.add(
        _ChipData('⚖️', 'Weight', '${latestWeight.toStringAsFixed(1)} kg'));
  }
  return chips;
}

class _InfoChipsCard extends StatelessWidget {
  final List<_ChipData> chips;
  const _InfoChipsCard({required this.chips});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: chips.map(_chip).toList(),
      ),
    );
  }

  Widget _chip(_ChipData c) => Semantics(
        label: '${c.label}: ${c.value}',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFF8C69).withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(c.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                c.value,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF7A5C45),
                ),
              ),
            ],
          ),
        ),
      );
}

// ─── Profile hero ───────────────────────────────────────────────────────────

class _ProfileHero extends StatelessWidget {
  final FullPetProfile pet;
  final String? photoPath;
  final String? coverPhotoPath;
  final VoidCallback onTapPhoto;
  final VoidCallback onTapCover;

  const _ProfileHero({
    required this.pet,
    required this.photoPath,
    required this.coverPhotoPath,
    required this.onTapPhoto,
    required this.onTapCover,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoPath != null;
    final hasCover = coverPhotoPath != null;
    final subtitle = [pet.breed, pet.gender]
        .where((s) => s.trim().isNotEmpty)
        .join(' • ');

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        // Falls back to the existing solid gradient exactly as before when
        // no cover photo has been set — zero visual change for a profile
        // that only has an avatar photo (or no photo at all).
        image: hasCover
            ? DecorationImage(
                image: FileImage(File(coverPhotoPath!)),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.32),
                  BlendMode.darken,
                ),
              )
            : null,
        gradient: hasCover
            ? null
            : LinearGradient(
                colors: [
                  pet.avatarColor,
                  pet.avatarColor.withValues(alpha: 0.55)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        color: hasCover ? pet.avatarColor.withValues(alpha: 0.3) : null,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: pet.avatarColor.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Subtle cozy pattern — kept low-opacity so it stays secondary
          // to the pet's photo and name. Skipped once a real cover photo
          // is set, so it doesn't compete with the user's own image.
          if (!hasCover)
            Positioned.fill(
              child: Opacity(
                opacity: 0.08,
                child: Image.asset('assets/images/paws_bg.png',
                    fit: BoxFit.cover),
              ),
            ),
          // Soft decorative accent shapes — same reasoning as above.
          if (!hasCover) ...[
            Positioned(
              top: -30,
              right: -30,
              child: _softCircle(90, Colors.white.withValues(alpha: 0.18)),
            ),
            Positioned(
              bottom: -40,
              left: -20,
              child: _softCircle(110, Colors.white.withValues(alpha: 0.12)),
            ),
          ],
          // Change-cover control — a small pill in the corner rather than
          // covering the avatar's own edit badge.
          Positioned(
            top: 10,
            right: 10,
            child: Material(
              color: Colors.black.withValues(alpha: 0.32),
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onTapCover,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.image_outlined,
                          size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        hasCover ? 'Change Cover' : 'Add Cover',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PetPhotoAvatar(
                  photoPath: photoPath,
                  color: pet.avatarColor,
                  size: 96,
                  showEditBadge: true,
                  onTap: onTapPhoto,
                ),
                const SizedBox(height: 12),
                // A cover photo can be ANY color a user happens to upload —
                // unlike the fixed pastel avatarColor gradient below, it
                // isn't guaranteed to contrast with dark text. Rather than
                // guessing at the photo's actual colors, the name/subtitle/
                // hint get their own small opaque scrim (the same technique
                // the "Change Cover" pill above already uses) plus white
                // text, so they stay legible against literally any photo —
                // the no-cover pastel-gradient case is untouched.
                Container(
                  padding: hasCover
                      ? const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8)
                      : EdgeInsets.zero,
                  decoration: hasCover
                      ? BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.38),
                          borderRadius: BorderRadius.circular(14),
                        )
                      : null,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!hasPhoto)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'Tap to add a photo',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: hasCover
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : Colors.black.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                      Text(
                        pet.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: hasCover
                              ? Colors.white
                              : const Color(0xFF3A2A1E),
                          shadows: hasCover
                              ? [
                                  Shadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.5),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: hasCover
                                ? Colors.white.withValues(alpha: 0.9)
                                : Colors.black.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
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

  Widget _softCircle(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      );
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
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
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
                      color: color.withValues(alpha: 0.15),
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
                              fontSize: 10,
                              color: color.withValues(alpha: 0.8))),
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
