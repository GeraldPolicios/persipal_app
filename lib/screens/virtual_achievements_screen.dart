// lib/screens/virtual_achievements_screen.dart
//
// Virtual Cat Achievements screen — shows the simulation-wide achievement
// progress (scope: virtual, never associated with any real pet's petId).
// Mirrors achievements_screen.dart's layout but reads from
// VirtualAchievementService instead of a FullPetProfile.

import 'package:flutter/material.dart';
import '../services/virtual_achievement_service.dart';
import '../models/virtual_achievement_model.dart';
import '../widgets/achievement_card.dart';

class VirtualAchievementsScreen extends StatefulWidget {
  const VirtualAchievementsScreen({super.key});

  @override
  State<VirtualAchievementsScreen> createState() =>
      _VirtualAchievementsScreenState();
}

class _VirtualAchievementsScreenState extends State<VirtualAchievementsScreen>
    with TickerProviderStateMixin, AchievementConfettiMixin {
  final _service = VirtualAchievementService.instance;

  @override
  void initState() {
    super.initState();
    _service.addListener(_refresh);
  }

  @override
  void dispose() {
    disposeConfetti();
    _service.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  AchievementCardData _toCardData(VirtualAchievement a) => AchievementCardData(
        title: a.title,
        description: a.description,
        emoji: a.emoji,
        unlocked: a.unlocked,
        unlockedAt: a.unlockedAt,
        progressCurrent: a.progressCurrent,
        progressTarget: a.progressTarget,
      );

  void _showDetail(VirtualAchievement achievement) {
    if (achievement.unlocked && !showingConfetti) celebrate();
    showAchievementDetail(context, _toCardData(achievement));
  }

  @override
  Widget build(BuildContext context) {
    final achievements = _service.achievements;
    final unlocked = _service.unlockedCount;
    final total = _service.totalCount;

    return Scaffold(
      backgroundColor: const Color(0xFFFFE6CC),
      body: Stack(children: [
        Positioned.fill(
            child: Opacity(
          opacity: 0.10,
          child: Image.asset('assets/images/paws_bg.png', fit: BoxFit.cover),
        )),

        SafeArea(
            child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              const Text('🐱 ', style: TextStyle(fontSize: 18)),
              const Expanded(
                child: Text('Virtual Cat Achievements',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB347).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$unlocked/$total',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFAA7755)),
                ),
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Overall Progress',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFAA7755))),
                    Text(
                      total > 0 ? '${(unlocked / total * 100).round()}%' : '0%',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFFFB347)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: total > 0 ? unlocked / total : 0,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFFFB347).withValues(alpha: 0.18),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFFFB347)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.0,
              ),
              itemCount: achievements.length,
              itemBuilder: (_, i) => AchievementGridCard(
                achievement: _toCardData(achievements[i]),
                onTap: () => _showDetail(achievements[i]),
              ),
            ),
          ),
        ])),

        buildConfettiOverlay(),
      ]),
    );
  }
}
