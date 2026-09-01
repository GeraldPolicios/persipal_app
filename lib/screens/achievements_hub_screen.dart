// lib/screens/achievements_hub_screen.dart
//
// Top-level Achievements entry point. Makes the two achievement scopes
// unmistakable: a single "Virtual Cat" card (global to the simulation, not
// tied to any real pet), and a list of the user's real cat profiles, each
// with its own independent achievement progress. Tapping either navigates
// into the existing, unmodified per-scope screens.

import 'dart:async';
import 'package:flutter/material.dart';
import '../providers/pet_profile_provider.dart';
import '../services/virtual_achievement_service.dart';
import '../themes/app_theme.dart';
import '../widgets/shared_widgets.dart';
import 'achievements_screen.dart';
import 'virtual_achievements_screen.dart';

class AchievementsHubScreen extends StatefulWidget {
  const AchievementsHubScreen({super.key});

  @override
  State<AchievementsHubScreen> createState() => _AchievementsHubScreenState();
}

class _AchievementsHubScreenState extends State<AchievementsHubScreen> {
  final _pets = PetProfileProvider.instance;
  final _virtual = VirtualAchievementService.instance;

  @override
  void initState() {
    super.initState();
    unawaited(_pets.init());
    _pets.addListener(_refresh);
    _virtual.addListener(_refresh);
  }

  @override
  void dispose() {
    _pets.removeListener(_refresh);
    _virtual.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final profiles = _pets.profiles;

    return Scaffold(
      backgroundColor: AppTheme.cream,
      body: Stack(
        children: [
          const PawBackground(),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Text('🏆 ', style: TextStyle(fontSize: 18)),
                        const Expanded(
                          child: Text('Achievements',
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Text('VIRTUAL CAT',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                            color: AppTheme.softBrown)),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _AchievementSummaryTile(
                      icon: '🐱',
                      title: 'Virtual Cat',
                      subtitle: 'Feeding, playing & grooming milestones',
                      unlocked: _virtual.unlockedCount,
                      total: _virtual.totalCount,
                      color: const Color(0xFFFFB347),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const VirtualAchievementsScreen()),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Text(
                      profiles.isEmpty ? 'REAL CATS' : 'REAL CATS',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                          color: AppTheme.softBrown),
                    ),
                  ),
                ),
                if (profiles.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'Add a real cat profile to start unlocking care achievements for them.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final pet = profiles[i];
                          final unlocked =
                              pet.achievements.where((a) => a.unlocked).length;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _AchievementSummaryTile(
                              icon: '🐾',
                              title: pet.name,
                              subtitle: 'Real-pet care achievements',
                              unlocked: unlocked,
                              total: pet.achievements.length,
                              color: AppTheme.teal,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      AchievementsScreen(petId: pet.id),
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: profiles.length,
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

class _AchievementSummaryTile extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final int unlocked;
  final int total;
  final Color color;
  final VoidCallback onTap;

  const _AchievementSummaryTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.unlocked,
    required this.total,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BounceButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14)),
              child: Center(
                  child: Text(icon, style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(12)),
              child: Text('$unlocked/$total',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 6),
            Icon(Icons.arrow_forward_ios,
                size: 15, color: Colors.grey.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}
