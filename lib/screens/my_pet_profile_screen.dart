// screens/pet_profiles/my_pet_profile_screen.dart
//
// Hub screen after selecting a cat.
// Shows 4 module cards: Pet Details, Growth Tracker, Vaccinations, Achievements.

import 'package:flutter/material.dart';
import '../../providers/pet_profile_provider.dart';
import '../../models/pet_extended_models.dart';
import 'pet_details_screen.dart';
import 'growth_tracker_screen.dart';
import 'vaccination_screen.dart';
import 'achievements_screen.dart';
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
                      Text(pet.breed,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFAA7755),
                              fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),

                // ── Hero cat card ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Container(
                    padding: const EdgeInsets.all(18),
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
                    child: Row(
                      children: [
                        // Big avatar
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.35),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text('🐱', style: TextStyle(fontSize: 42)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                pet.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pet.breed,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 13),
                              ),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

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

  Widget _miniStat(String count, String emoji, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        Text(count,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.white70)),
      ],
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
