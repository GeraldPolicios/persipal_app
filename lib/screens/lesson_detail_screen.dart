// screens/lesson_detail_screen.dart
import 'package:flutter/material.dart';
import '../services/activity_service.dart';

class LessonDetailScreen extends StatefulWidget {
  final String type;

  const LessonDetailScreen({super.key, required this.type});

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  bool _completed = false;

  void _markComplete() {
    if (_completed) return;
    setState(() => _completed = true);
    ActivityService.instance.logActivity(
      icon: Icons.menu_book,
      iconColor: const Color(0xFF4682B4),
      title: 'Completed lesson — ${_title()}',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('${_title()} marked as complete!'),
          ],
        ),
        backgroundColor: const Color(0xFF32CD32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

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
            child: Column(
              children: [
                // Header
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
                          _title(),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (_completed)
                        const Icon(Icons.check_circle,
                            color: Color(0xFF32CD32), size: 22),
                    ],
                  ),
                ),

                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                    children: [
                      // Description card
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.8),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          _description(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF7A3B1E),
                            height: 1.5,
                          ),
                        ),
                      ),

                      // Content cards
                      ..._content(),

                      const SizedBox(height: 16),

                      // Mark complete button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _completed
                                ? const Color(0xFF32CD32)
                                : const Color(0xFFFF8C69),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: _markComplete,
                          icon: Icon(
                            _completed
                                ? Icons.check_circle
                                : Icons.check_circle_outline,
                            size: 18,
                          ),
                          label: Text(
                            _completed
                                ? 'Lesson Completed!'
                                : 'Mark as Complete',
                            style: const TextStyle(
                                fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
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

  // ── Content routers ───────────────────────────────────────────────────────

  List<Widget> _content() {
    switch (widget.type) {
      case 'feeding':
        return _feeding();
      case 'grooming':
        return _grooming();
      case 'behavior':
        return _behavior();
      case 'vitamins':
        return _vitamins();
      case 'health':
        return _health();
      case 'environment':
        return _environment();
      default:
        return [const Text('No data available')];
    }
  }

  List<Widget> _feeding() => const [
        DetailBox(
          title: '🥩 What They Should Eat',
          description:
              'Proper nutrition is important for growth, energy, and maintaining a healthy Persian cat.',
          content:
              '• Chicken, turkey, fish, lamb\n• High-quality dry kibble\n• Wet food for hydration\n• Cooked plain meat only',
        ),
        DetailBox(
          title: '🕒 Feeding Schedule',
          description:
              'Feeding schedule helps maintain healthy weight and proper digestion.',
          content:
              '• Kittens: 3–4 meals/day\n• Adults: 2 meals/day\n• Seniors: 2–3 small meals',
        ),
        DetailBox(
          title: '🚫 Foods to Avoid',
          description:
              'Some human foods are toxic and dangerous for Persian cats.',
          content:
              '• Chocolate\n• Onion & garlic\n• Milk\n• Spicy or oily food',
        ),
        DetailBox(
          title: '⚠️ Important Note',
          description:
              'Overfeeding can lead to obesity and health complications.',
          content:
              '• Control portions\n• Prevent obesity\n• Support heart and joint health',
        ),
      ];

  List<Widget> _grooming() => const [
        DetailBox(
          title: '🪮 Daily Brushing',
          description:
              'Daily brushing keeps your Persian cat\'s long fur clean and tangle-free.',
          content:
              '• Brush 10–20 minutes daily\n• Prevents tangles and hairballs\n• Use slicker brush + comb',
        ),
        DetailBox(
          title: '🛁 Bathing Care',
          description:
              'Regular bathing helps maintain coat hygiene and skin health.',
          content:
              '• Every 3–4 weeks\n• Use cat-safe shampoo\n• Dry completely after bath',
        ),
        DetailBox(
          title: '👁 Eye & Ear Care',
          description: 'Proper cleaning prevents infections and irritation.',
          content:
              '• Clean eyes daily\n• Weekly ear cleaning\n• Use soft cotton and warm water',
        ),
        DetailBox(
          title: '✂️ Nail Care',
          description:
              'Trimming nails prevents injuries and keeps paws healthy.',
          content: '• Trim every 2–3 weeks\n• Prevent scratching injuries',
        ),
      ];

  List<Widget> _behavior() => const [
        DetailBox(
          title: '😺 Personality',
          description:
              'Persian cats are calm, gentle, and love peaceful environments.',
          content:
              '• Calm and gentle\n• Prefers quiet environments\n• Affectionate but independent\n• Loves routine',
        ),
        DetailBox(
          title: '🏠 Social Behavior',
          description:
              'They interact differently depending on people and surroundings.',
          content:
              '• Friendly with family\n• Shy with strangers\n• Prefers calm interaction',
        ),
        DetailBox(
          title: '🎮 Activity Level',
          description:
              'They are low-energy cats and prefer light play activities.',
          content:
              '• Low energy breed\n• Enjoys soft toys\n• Short play sessions',
        ),
        DetailBox(
          title: '⚠️ Emotional Sensitivity',
          description: 'They are sensitive to stress and loud environments.',
          content: '• Stressed in loud spaces\n• May hide when overwhelmed',
        ),
      ];

  List<Widget> _vitamins() => const [
        DetailBox(
          title: '🧴 Supplements',
          description:
              'Vitamins help improve coat health, immunity, and overall wellness.',
          content:
              '• Omega-3 for coat health\n• Biotin for fur strength\n• Taurine for heart & eyes\n• Multivitamins (vet approved)',
        ),
        DetailBox(
          title: '⚠️ Safety Warning',
          description: 'Improper vitamin use can harm your cat\'s health.',
          content: '• Never use human vitamins\n• Always consult a vet first',
        ),
      ];

  List<Widget> _health() => const [
        DetailBox(
          title: '🩺 Common Issues',
          description:
              'Persian cats may develop certain health problems due to genetics.',
          content:
              '• Breathing problems\n• Eye infections\n• Dental disease\n• Kidney issues\n• Hairball buildup',
        ),
        DetailBox(
          title: '🏥 Vet Care',
          description:
              'Regular veterinary visits help prevent serious health issues.',
          content:
              '• Annual check-ups\n• Vaccinations\n• Dental cleaning if needed',
        ),
        DetailBox(
          title: '🪥 Prevention',
          description: 'Good daily care helps prevent most health problems.',
          content: '• Regular grooming\n• Healthy diet\n• Dental care routine',
        ),
      ];

  List<Widget> _environment() => const [
        DetailBox(
          title: '🏠 Home Setup',
          description:
              'A safe indoor environment keeps Persian cats comfortable and protected.',
          content: '• Indoor living recommended\n• Safe and quiet environment',
        ),
        DetailBox(
          title: '🌡 Temperature',
          description:
              'Temperature control is important for their comfort and health.',
          content: '• Cool and comfortable space\n• Avoid heat and humidity',
        ),
        DetailBox(
          title: '🧸 Enrichment',
          description:
              'Mental stimulation helps keep your cat active and happy.',
          content: '• Soft toys\n• Scratching posts\n• Window viewing spots',
        ),
        DetailBox(
          title: '🚽 Litter Box',
          description:
              'Clean litter boxes help maintain hygiene and prevent stress.',
          content: '• Clean daily\n• Place in quiet area',
        ),
      ];

  String _title() {
    switch (widget.type) {
      case 'feeding':
        return 'Feeding Guide 🍽️';
      case 'grooming':
        return 'Grooming Guide 🧼';
      case 'behavior':
        return 'Behavior Guide 🧠';
      case 'vitamins':
        return 'Vitamins Guide 💊';
      case 'health':
        return 'Health Guide 🏥';
      case 'environment':
        return 'Environment Guide 🌿';
      default:
        return 'Lesson';
    }
  }

  String _description() {
    switch (widget.type) {
      case 'feeding':
        return 'Learn how to properly feed Persian cats with a balanced diet for healthy growth and strong immunity.';
      case 'grooming':
        return 'Learn proper grooming routines to maintain a clean, healthy, and beautiful Persian cat coat.';
      case 'behavior':
        return 'Understand Persian cat personality, behavior patterns, and how they interact with humans and environment.';
      case 'vitamins':
        return 'Learn about safe vitamins and supplements that support immunity, fur health, and overall wellness.';
      case 'health':
        return 'Discover common health issues in Persian cats and how to prevent them through proper care and monitoring.';
      case 'environment':
        return 'Learn how to create a safe, comfortable, and stress-free home environment for your Persian cat.';
      default:
        return '';
    }
  }
}

// ── Expandable card ───────────────────────────────────────────────────────────

class DetailBox extends StatelessWidget {
  final String title;
  final String description;
  final String content;

  const DetailBox({
    super.key,
    required this.title,
    required this.description,
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white.withOpacity(0.88),
      elevation: 0,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        childrenPadding: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero, side: BorderSide.none),
        collapsedShape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero, side: BorderSide.none),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  description,
                  style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                      color: Color(0xFFAA7755)),
                ),
                const SizedBox(height: 8),
                Text(content,
                    style: const TextStyle(fontSize: 13, height: 1.6)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
