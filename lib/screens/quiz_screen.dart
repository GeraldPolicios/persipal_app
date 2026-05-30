// screens/quiz_screen.dart
import 'package:flutter/material.dart';
import '../services/activity_service.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _score = 0;
  int _current = 0;
  int? _selected;
  bool _answered = false;

  static const _questions = [
    {
      'q': 'What is the best food for Persian cats?',
      'a': ['Milk', 'High-quality cat food', 'Chocolate'],
      'correct': 1,
      'explanation':
          'High-quality cat food (wet or dry) provides the balanced nutrition Persians need. Milk and chocolate are harmful.',
    },
    {
      'q': 'How often should you brush a Persian\'s coat?',
      'a': ['Once a week', 'Never', 'Daily'],
      'correct': 2,
      'explanation':
          'Persians have long, thick coats that tangle easily. Daily brushing for 10–20 minutes prevents mats and hairballs.',
    },
    {
      'q': 'Which sign best shows that a cat is happy?',
      'a': ['Hissing loudly', 'Purring softly', 'Hiding under the bed'],
      'correct': 1,
      'explanation':
          'Purring is the clearest sign of contentment. Hissing signals fear or aggression; hiding may indicate stress.',
    },
    {
      'q': 'How often should you bathe a Persian cat?',
      'a': ['Every day', 'Every 3–4 weeks', 'Once a year'],
      'correct': 1,
      'explanation':
          'Every 3–4 weeks is the recommended frequency. Too frequent bathing dries out their skin; too rare leads to matting.',
    },
    {
      'q': 'Which vitamin is important for a Persian\'s coat health?',
      'a': ['Vitamin C', 'Omega-3 fatty acids', 'Calcium'],
      'correct': 1,
      'explanation':
          'Omega-3 fatty acids support a shiny, healthy coat and reduce shedding. Always use vet-approved supplements.',
    },
  ];

  void _answer(int idx) {
    if (_answered) return;
    setState(() {
      _selected = idx;
      _answered = true;
      if (idx == _questions[_current]['correct']) _score++;
    });
  }

  void _next() {
    if (_current < _questions.length - 1) {
      setState(() {
        _current++;
        _selected = null;
        _answered = false;
      });
    } else {
      // Log quiz result
      ActivityService.instance.logActivity(
        icon: Icons.quiz,
        iconColor: const Color(0xFF7B68EE),
        title: 'Completed quiz — Score: $_score/${_questions.length}',
      );
      setState(() => _current = _questions.length); // trigger results view
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDone = _current >= _questions.length;

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
            child: isDone ? _buildResults() : _buildQuestion(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion() {
    final q = _questions[_current];
    final answers = q['a'] as List<String>;
    final correct = q['correct'] as int;
    final progress = (_current + 1) / _questions.length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back + title
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              const Text('🧠  Quiz',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              Text(
                '${_current + 1} / ${_questions.length}',
                style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFAA7755),
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: const Color(0xFF7B68EE).withOpacity(0.15),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF7B68EE)),
            ),
          ),
          const SizedBox(height: 20),

          // Score chip
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF32CD32).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '⭐ Score: $_score',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF32CD32)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Question card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.88),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2)),
              ],
            ),
            child: Text(
              q['q'] as String,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold, height: 1.4),
            ),
          ),
          const SizedBox(height: 16),

          // Answers
          ...answers.asMap().entries.map((e) {
            final i = e.key;
            final text = e.value;
            Color? bg;
            Color? border;
            Widget? trailing;

            if (_answered) {
              if (i == correct) {
                bg = const Color(0xFF32CD32).withOpacity(0.15);
                border = const Color(0xFF32CD32);
                trailing = const Icon(Icons.check_circle,
                    color: Color(0xFF32CD32), size: 20);
              } else if (i == _selected) {
                bg = Colors.redAccent.withOpacity(0.12);
                border = Colors.redAccent;
                trailing =
                    const Icon(Icons.cancel, color: Colors.redAccent, size: 20);
              }
            }

            return GestureDetector(
              onTap: () => _answer(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: bg ?? Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color:
                          border ?? const Color(0xFFFF8C69).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(text,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500)),
                    ),
                    if (trailing != null) trailing,
                  ],
                ),
              ),
            );
          }),

          // Explanation
          if (_answered)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: const Color(0xFFFF8C69).withOpacity(0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡 ', style: TextStyle(fontSize: 16)),
                  Expanded(
                    child: Text(
                      q['explanation'] as String,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF7A3B1E), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),

          const Spacer(),

          // Next button
          if (_answered)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8C69),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.all(15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                onPressed: _next,
                child: Text(
                  _current < _questions.length - 1
                      ? 'Next Question →'
                      : 'See Results!',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    final pct = (_score / _questions.length * 100).round();
    final emoji = pct >= 80
        ? '🏆'
        : pct >= 60
            ? '😺'
            : '😿';
    final msg = pct >= 80
        ? 'Excellent! You\'re a Persian cat expert!'
        : pct >= 60
            ? 'Good job! Keep learning!'
            : 'Keep practicing — you\'ll get there!';

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 72)),
          const SizedBox(height: 16),
          Text(
            '$_score out of ${_questions.length} correct',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            msg,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 14,
                color: Color(0xFFAA7755),
                fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 24),

          // Score ring
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: _score / _questions.length,
                  strokeWidth: 10,
                  backgroundColor: const Color(0xFF7B68EE).withOpacity(0.15),
                  valueColor: const AlwaysStoppedAnimation(Color(0xFF7B68EE)),
                ),
                Text(
                  '$pct%',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8C69),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.all(15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.menu_book, size: 18),
              label: const Text('Back to Learn Cat Care',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            ),
          ),

          const SizedBox(height: 12),

          TextButton(
            onPressed: () {
              setState(() {
                _score = 0;
                _current = 0;
                _selected = null;
                _answered = false;
              });
            },
            child: const Text('Try Again',
                style: TextStyle(
                    color: Color(0xFF7B68EE), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
