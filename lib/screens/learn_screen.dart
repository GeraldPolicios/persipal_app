// screens/learn_screen.dart
import 'package:flutter/material.dart';
import '../services/activity_service.dart';
import '../widgets/tap_effects.dart';
import 'lesson_detail_screen.dart';
import 'quiz_screen.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  static const _modules = [
    {
      'title': 'Feeding',
      'emoji': '🍗',
      'type': 'feeding',
      'color': Color(0xFFFF8C69),
      'desc': 'Diet & nutrition',
    },
    {
      'title': 'Grooming',
      'emoji': '✂️',
      'type': 'grooming',
      'color': Color(0xFFE91E8C),
      'desc': 'Coat & hygiene',
    },
    {
      'title': 'Behavior',
      'emoji': '🐾',
      'type': 'behavior',
      'color': Color(0xFF4682B4),
      'desc': 'Personality & play',
    },
    {
      'title': 'Vitamins',
      'emoji': '💊',
      'type': 'vitamins',
      'color': Color(0xFF32CD32),
      'desc': 'Supplements',
    },
    {
      'title': 'Health',
      'emoji': '🏥',
      'type': 'health',
      'color': Color(0xFFDC143C),
      'desc': 'Common issues',
    },
    {
      'title': 'Environment',
      'emoji': '🌿',
      'type': 'environment',
      'color': Color(0xFF20B2AA),
      'desc': 'Home setup',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE6CC),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.12,
              child:
                  Image.asset('assets/images/paws_bg.png', fit: BoxFit.cover),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Expanded(
                        child: Text(
                          '📚  Learn Cat Care',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Tap a topic below to learn how to care for Persian cats.',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFAA7755),
                          fontStyle: FontStyle.italic),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Module grid
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.1,
                      children: _modules
                          .map((m) => _ModuleTile(
                                title: m['title'] as String,
                                emoji: m['emoji'] as String,
                                type: m['type'] as String,
                                color: m['color'] as Color,
                                desc: m['desc'] as String,
                              ))
                          .toList(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Quiz button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7B68EE),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(15),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const QuizScreen()),
                      ),
                      icon: const Icon(Icons.quiz, size: 20),
                      label: const Text(
                        'Test Your Knowledge — Take the Quiz!',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModuleTile extends StatelessWidget {
  final String title;
  final String emoji;
  final String type;
  final Color color;
  final String desc;

  const _ModuleTile({
    required this.title,
    required this.emoji,
    required this.type,
    required this.color,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return BounceButton(
      onTap: () {
        ActivityService.instance.logActivity(
          icon: Icons.menu_book,
          iconColor: const Color(0xFF4682B4),
          title: 'Opened lesson — $title',
        );
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LessonDetailScreen(type: type)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.82),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 26))),
            ),
            const SizedBox(height: 8),
            Text(title,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(desc,
                style: TextStyle(fontSize: 10, color: color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }
}
