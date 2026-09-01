// lib/widgets/achievement_card.dart
//
// Presentational-only achievement grid card + detail sheet + unlock
// confetti, shared by the real-pet Achievements screen and the Virtual Cat
// achievements screen. Deliberately takes only primitive fields (not
// PetAchievement or VirtualAchievement directly) so this stays scope-
// agnostic — it has no idea whether it's rendering a real-pet or virtual
// achievement, which keeps the two data models fully separate while still
// sharing the UI.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AchievementCardData {
  final String title;
  final String description;
  final String emoji;
  final bool unlocked;
  final DateTime? unlockedAt;
  final int progressCurrent;
  final int progressTarget;

  const AchievementCardData({
    required this.title,
    required this.description,
    required this.emoji,
    required this.unlocked,
    required this.unlockedAt,
    required this.progressCurrent,
    required this.progressTarget,
  });

  double get progressPercent =>
      progressTarget > 0 ? (progressCurrent / progressTarget).clamp(0.0, 1.0) : 0;
}

void showAchievementDetail(BuildContext context, AchievementCardData a) {
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
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          AnimatedScale(
            scale: a.unlocked ? 1.0 : 0.7,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            child: Text(a.emoji,
                style: TextStyle(
                    fontSize: 64,
                    color: a.unlocked ? null : Colors.grey.withValues(alpha: 0.4))),
          ),
          const SizedBox(height: 12),
          Text(
            a.unlocked ? a.title : '???',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: a.unlocked ? const Color(0xFF4A2C1A) : Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            a.unlocked ? a.description : 'Keep going to unlock this badge!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: a.unlocked ? const Color(0xFFAA7755) : Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
          if (a.unlocked && a.unlockedAt != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB347).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '🏆 Unlocked on ${DateFormat('MMMM d, yyyy').format(a.unlockedAt!)}',
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFAA7755),
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
          if (!a.unlocked) ...[
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
                  '${a.progressCurrent} / ${a.progressTarget}',
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
                value: a.progressPercent,
                minHeight: 10,
                backgroundColor: const Color(0xFFFF8C69).withValues(alpha: 0.15),
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

class AchievementGridCard extends StatelessWidget {
  final AchievementCardData achievement;
  final VoidCallback onTap;

  const AchievementGridCard({
    super.key,
    required this.achievement,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final unlocked = a.unlocked;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: unlocked
              ? Colors.white.withValues(alpha: 0.92)
              : Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(18),
          border: unlocked
              ? Border.all(
                  color: const Color(0xFFFFB347).withValues(alpha: 0.5),
                  width: 1.5)
              : null,
          boxShadow: unlocked
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFB347).withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.topRight,
                children: [
                  Text(
                    unlocked ? a.emoji : '🔒',
                    style: TextStyle(
                        fontSize: 38,
                        color: unlocked ? null : Colors.grey.withValues(alpha: 0.5)),
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
              Text(
                unlocked ? a.title : '???',
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
              if (!unlocked) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: a.progressPercent,
                    minHeight: 5,
                    backgroundColor: Colors.grey.withValues(alpha: 0.2),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFFFF8C69)),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${a.progressCurrent}/${a.progressTarget}',
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Particle {
  final double x;
  final Color color;
  final double size;
  final double speed;

  _Particle(
      {required this.x, required this.color, required this.size, required this.speed});
}

class _ConfettiPainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()..color = p.color.withValues(alpha: 1 - progress);
      final y = progress * p.speed * size.height;
      final x = p.x * size.width + sin(progress * 3 * pi + p.x * 10) * 30;
      canvas.drawCircle(Offset(x, y), p.size / 2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => true;
}

/// Mixin providing the confetti celebration overlay used by both
/// achievement screens. The host must call [buildConfettiOverlay] inside a
/// Stack and dispose [confettiController] in its own dispose().
mixin AchievementConfettiMixin<T extends StatefulWidget>
    on State<T>, TickerProviderStateMixin<T> {
  final List<_Particle> _particles = [];
  AnimationController? confettiController;
  bool showingConfetti = false;

  void celebrate() {
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

    confettiController?.dispose();
    confettiController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    setState(() => showingConfetti = true);
    confettiController!.forward().then((_) {
      if (mounted) setState(() => showingConfetti = false);
    });
  }

  Widget buildConfettiOverlay() {
    if (!showingConfetti || confettiController == null) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: confettiController!,
      builder: (_, __) {
        final t = confettiController!.value;
        return IgnorePointer(
          child: CustomPaint(
            painter: _ConfettiPainter(particles: _particles, progress: t),
            child: const SizedBox.expand(),
          ),
        );
      },
    );
  }

  void disposeConfetti() => confettiController?.dispose();
}
