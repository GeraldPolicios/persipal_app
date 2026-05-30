// screens/pet_profiles/achievements_screen.dart
//
// Achievements & Badges screen.
// Shows locked/unlocked state, progress bars, animated unlock celebration.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../providers/pet_profile_provider.dart';
import '../../models/pet_extended_models.dart';

class AchievementsScreen extends StatefulWidget {
  final String petId;
  const AchievementsScreen({super.key, required this.petId});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with TickerProviderStateMixin {
  final _provider = PetProfileProvider.instance;

  // Confetti particles
  final List<_Particle> _particles = [];
  AnimationController? _confettiCtrl;
  bool _showConfetti = false;

  @override
  void initState() {
    super.initState();
    _provider.addListener(_refresh);
  }

  @override
  void dispose() {
    _confettiCtrl?.dispose();
    _provider.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  FullPetProfile? get _pet => _provider.getById(widget.petId);

  void _celebrate() {
    final rnd = Random();
    _particles.clear();
    for (int i = 0; i < 40; i++) {
      _particles.add(_Particle(
        x: rnd.nextDouble(),
        color: [
          const Color(0xFFFF8C69),
          const Color(0xFF7B68EE),
          const Color(0xFF20B2AA),
          const Color(0xFFFFB347),
          const Color(0xFF32CD32),
        ][rnd.nextInt(5)],
        size: 6 + rnd.nextDouble() * 6,
        speed: 0.3 + rnd.nextDouble() * 0.7,
      ));
    }

    _confettiCtrl?.dispose();
    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    setState(() => _showConfetti = true);
    _confettiCtrl!.forward().then((_) {
      if (mounted) setState(() => _showConfetti = false);
    });
  }

  void _showDetail(PetAchievement achievement) {
    if (achievement.unlocked && !_showConfetti) _celebrate();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFFF8F2),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // Emoji
            AnimatedScale(
              scale: achievement.unlocked ? 1.0 : 0.7,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              child: Text(achievement.emoji,
                  style: TextStyle(
                      fontSize: 64,
                      color: achievement.unlocked
                          ? null
                          : Colors.grey.withOpacity(0.4))),
            ),
            const SizedBox(height: 12),

            // Title
            Text(
              achievement.unlocked ? achievement.title : '???',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: achievement.unlocked
                    ? const Color(0xFF4A2C1A)
                    : Colors.grey,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              achievement.unlocked
                  ? achievement.description
                  : 'Keep using the app to unlock this badge!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: achievement.unlocked
                    ? const Color(0xFFAA7755)
                    : Colors.grey,
                fontStyle: FontStyle.italic,
              ),
            ),

            // Unlocked date
            if (achievement.unlocked && achievement.unlockedAt != null) ...[
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB347).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '🏆 Unlocked on ${DateFormat('MMMM d, yyyy').format(achievement.unlockedAt!)}',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFAA7755),
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],

            // Progress bar (if locked)
            if (!achievement.unlocked) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Progress',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFAA7755))),
                  Text(
                    '${achievement.progressCurrent} / ${achievement.progressTarget}',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF8C69)),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: achievement.progressPercent,
                  minHeight: 10,
                  backgroundColor: const Color(0xFFFF8C69).withOpacity(0.15),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFFFF8C69)),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pet = _pet;
    if (pet == null) {
      return const Scaffold(body: Center(child: Text('Profile not found.')));
    }

    final achievements = pet.achievements;
    final unlocked = achievements.where((a) => a.unlocked).length;
    final total = achievements.length;

    return Scaffold(
      backgroundColor: const Color(0xFFFFE6CC),
      body: Stack(children: [
        // Paw background
        Positioned.fill(
            child: Opacity(
          opacity: 0.10,
          child: Image.asset('assets/images/paws_bg.png', fit: BoxFit.cover),
        )),

        SafeArea(
            child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              const Text('🏆 ', style: TextStyle(fontSize: 18)),
              const Expanded(
                child: Text('Achievements',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB347).withOpacity(0.18),
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

          // Overall progress bar
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
                      '${(unlocked / total * 100).round()}%',
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
                    backgroundColor: const Color(0xFFFFB347).withOpacity(0.18),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFFFB347)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Grid
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
              itemBuilder: (_, i) => _AchievementCard(
                achievement: achievements[i],
                onTap: () => _showDetail(achievements[i]),
              ),
            ),
          ),
        ])),

        // Confetti overlay
        if (_showConfetti && _confettiCtrl != null)
          AnimatedBuilder(
            animation: _confettiCtrl!,
            builder: (_, __) {
              final t = _confettiCtrl!.value;
              return IgnorePointer(
                child: CustomPaint(
                  painter: _ConfettiPainter(particles: _particles, progress: t),
                  child: const SizedBox.expand(),
                ),
              );
            },
          ),
      ]),
    );
  }
}

// ─── Achievement Card ─────────────────────────────────────────────────────────

class _AchievementCard extends StatelessWidget {
  final PetAchievement achievement;
  final VoidCallback onTap;

  const _AchievementCard({required this.achievement, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final unlocked = achievement.unlocked;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: unlocked
              ? Colors.white.withOpacity(0.92)
              : Colors.white.withOpacity(0.55),
          borderRadius: BorderRadius.circular(18),
          border: unlocked
              ? Border.all(
                  color: const Color(0xFFFFB347).withOpacity(0.5), width: 1.5)
              : null,
          boxShadow: unlocked
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFB347).withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Stack(children: [
          // Locked overlay shimmer
          if (!unlocked)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Emoji
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Text(
                      unlocked ? achievement.emoji : '🔒',
                      style: TextStyle(
                          fontSize: 38,
                          color:
                              unlocked ? null : Colors.grey.withOpacity(0.5)),
                    ),
                    if (unlocked)
                      const Positioned(
                        right: 0,
                        top: 0,
                        child: Text('✨', style: TextStyle(fontSize: 12)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Title
                Text(
                  unlocked ? achievement.title : '???',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: unlocked ? const Color(0xFF4A2C1A) : Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),

                // Mini progress bar (locked only)
                if (!unlocked) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: achievement.progressPercent,
                      minHeight: 5,
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      valueColor:
                          const AlwaysStoppedAnimation(Color(0xFFFF8C69)),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${achievement.progressCurrent}/${achievement.progressTarget}',
                    style: const TextStyle(fontSize: 9, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ─── Confetti ─────────────────────────────────────────────────────────────────

class _Particle {
  final double x;
  final Color color;
  final double size;
  final double speed;

  _Particle(
      {required this.x,
      required this.color,
      required this.size,
      required this.speed});
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()..color = p.color.withOpacity(1 - progress);
      final y = progress * p.speed * size.height;
      final x = p.x * size.width + sin(progress * 3 * pi + p.x * 10) * 30;
      canvas.drawCircle(Offset(x, y), p.size / 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => true;
}
