// screens/groom_screen.dart
import 'dart:math';
import 'package:flutter/material.dart';
import '../services/activity_service.dart';

class GroomScreen extends StatefulWidget {
  final int cleanliness;
  final Function(String) onAction;

  const GroomScreen({
    super.key,
    required this.cleanliness,
    required this.onAction,
  });

  @override
  State<GroomScreen> createState() => _GroomScreenState();
}

class _GroomScreenState extends State<GroomScreen> {
  final _service = ActivityService.instance;
  final _random = Random();

  late int cleanliness;
  int _groomProgress = 0;
  bool _hovering = false;
  String _feedbackText = '';
  int _sparkleCount = 0;

  final List<Map<String, dynamic>> _tools = const [
    {'emoji': '🧼', 'name': 'Soap', 'color': Color(0xFFE1F5FE)},
    {'emoji': '🚿', 'name': 'Shower', 'color': Color(0xFFB3E5FC)},
    {'emoji': '✂️', 'name': 'Trim', 'color': Color(0xFFFFCDD2)},
    {'emoji': '🪮', 'name': 'Brush', 'color': Color(0xFFFFE0B2)},
  ];

  @override
  void initState() {
    super.initState();
    cleanliness = widget.cleanliness;
  }

  String _getHair() {
    if (cleanliness >= 70) return 'clean';
    if (cleanliness >= 40) return 'messy';
    return 'very_messy';
  }

  void _groom(String tool) {
    setState(() {
      _groomProgress += 1;
      if (tool == 'Shower' || tool == 'Soap') _groomProgress += 1;
      if (tool == 'Brush') _groomProgress += 1;

      if (_groomProgress >= 10) {
        cleanliness = 90;
        _feedbackText = 'Squeaky clean ✨';
      } else if (_groomProgress >= 5) {
        cleanliness = 60;
        _feedbackText = 'Getting better 🧼';
      } else {
        cleanliness = (cleanliness + 10).clamp(0, 100);
        _feedbackText = 'Grooming… 😽';
      }
      cleanliness = cleanliness.clamp(0, 100);
      _sparkleCount = 8;
    });

    widget.onAction('groom');

    // Log to activity service
    _service.logActivity(
      icon: Icons.content_cut,
      iconColor: const Color(0xFF7B68EE),
      title: 'Groomed cat — $tool',
    );

    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _sparkleCount = 0;
        _feedbackText = '';
      });
    });
  }

  Widget _toolCard(Map<String, dynamic> item) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: item['color'] as Color,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(2, 4)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(item['emoji'] as String, style: const TextStyle(fontSize: 28)),
          const SizedBox(height: 5),
          Text(item['name'] as String,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _draggable(Map<String, dynamic> item) {
    return Draggable<String>(
      data: item['name'] as String,
      feedback: Material(
        color: Colors.transparent,
        child:
            Text(item['emoji'] as String, style: const TextStyle(fontSize: 46)),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: _toolCard(item)),
      child: _toolCard(item),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hair = _getHair();

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
                        onPressed: () => Navigator.pop(
                            context, {'cleanliness': cleanliness}),
                      ),
                      const Expanded(
                        child: Text(
                          '✂️  Groom Your Cat',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 4),
                const Text(
                  'Drag grooming tools to your cat!',
                  style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFAA7755),
                      fontStyle: FontStyle.italic),
                ),
                const SizedBox(height: 8),

                // Progress bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Grooming Progress',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFAA7755))),
                          Text(
                              '${(_groomProgress / 10 * 100).clamp(0, 100).round()}%',
                              style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF7B68EE))),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: (_groomProgress / 10).clamp(0, 1),
                          minHeight: 8,
                          backgroundColor:
                              const Color(0xFF7B68EE).withOpacity(0.15),
                          valueColor:
                              const AlwaysStoppedAnimation(Color(0xFF7B68EE)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Drop zone
                Stack(
                  children: [
                    DragTarget<String>(
                      onWillAccept: (_) {
                        setState(() => _hovering = true);
                        return true;
                      },
                      onLeave: (_) => setState(() => _hovering = false),
                      onAccept: (data) {
                        setState(() => _hovering = false);
                        _groom(data);
                      },
                      builder: (_, __, ___) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 200,
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: _hovering
                                ? const Color(0xFF7B68EE)
                                : Colors.transparent,
                            width: _hovering ? 3 : 0,
                          ),
                          boxShadow: _hovering
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFF7B68EE)
                                        .withOpacity(0.3),
                                    blurRadius: 16,
                                  ),
                                ]
                              : null,
                          image: const DecorationImage(
                            image: AssetImage('assets/images/cat_bg_room.png'),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Image.asset(
                                'assets/images/cat_normal_$hair.png',
                                key: ValueKey(hair),
                                height: 95,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Sparkles
                    ...List.generate(
                        _sparkleCount,
                        (i) => Positioned(
                              left: 30 + _random.nextDouble() * 200,
                              bottom: 60 + _random.nextDouble() * 100,
                              child: const Text('✨',
                                  style: TextStyle(fontSize: 18)),
                            )),

                    // Feedback
                    Positioned(
                      top: 12,
                      left: 0,
                      right: 0,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: _feedbackText.isEmpty ? 0 : 1,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              _feedbackText,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF7A3B1E),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Tool grid
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _tools.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                    ),
                    itemBuilder: (_, i) => _draggable(_tools[i]),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
