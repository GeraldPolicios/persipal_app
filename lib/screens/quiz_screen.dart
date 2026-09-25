// screens/quiz_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/lesson_content_model.dart';
import '../providers/app_provider.dart';
import '../services/reward_service.dart';

class QuizScreen extends StatefulWidget {
  /// The lesson topic this quiz belongs to (QZ-4), or null for the
  /// general/mixed quiz reachable from the Learn screen's own quiz button —
  /// that entry point is unchanged.
  final String? topic;

  const QuizScreen({super.key, this.topic});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _score = 0;
  int _current = 0;
  int? _selected;
  bool _answered = false;

  // Reward points earned by the just-finished attempt (null until known).
  int? _pointsEarned;

  // The original 5, each now tagged with the topic it belongs to — reused
  // as-is (not rewritten) for that topic's quiz, plus the general quiz.
  static const _legacyQuestions = [
    {
      'topic': 'feeding',
      'q': 'What is the best food for Persian cats?',
      'a': ['Milk', 'High-quality cat food', 'Chocolate'],
      'correct': 1,
      'explanation':
          'High-quality cat food (wet or dry) provides the balanced nutrition Persians need. Milk and chocolate are harmful.',
    },
    {
      'topic': 'grooming',
      'q': 'How often should you brush a Persian\'s coat?',
      'a': ['Once a week', 'Never', 'Daily'],
      'correct': 2,
      'explanation':
          'Persians have long, thick coats that tangle easily. Daily brushing for 10–20 minutes prevents mats and hairballs.',
    },
    {
      'topic': 'behavior',
      'q': 'Which sign best shows that a cat is happy?',
      'a': ['Hissing loudly', 'Purring softly', 'Hiding under the bed'],
      'correct': 1,
      'explanation':
          'Purring is the clearest sign of contentment. Hissing signals fear or aggression; hiding may indicate stress.',
    },
    {
      'topic': 'grooming',
      'q': 'How often should you bathe a Persian cat?',
      'a': ['Every day', 'Every 3–4 weeks', 'Once a year'],
      'correct': 1,
      'explanation':
          'Every 3–4 weeks is the recommended frequency. Too frequent bathing dries out their skin; too rare leads to matting.',
    },
    {
      'topic': 'vitamins',
      'q': 'Which vitamin is important for a Persian\'s coat health?',
      'a': ['Vitamin C', 'Omega-3 fatty acids', 'Calcium'],
      'correct': 1,
      'explanation':
          'Omega-3 fatty acids support a shiny, healthy coat and reduce shedding. Always use vet-approved supplements.',
    },
  ];

  static const _topicTitles = {
    'feeding': 'Feeding Quiz 🍽️',
    'grooming': 'Grooming Quiz 🧼',
    'behavior': 'Behavior Quiz 🧠',
    'vitamins': 'Vitamins Quiz 💊',
    'health': 'Health Quiz 🏥',
    'environment': 'Environment Quiz 🌿',
  };

  /// This topic's legacy question(s) plus the question grounded in that
  /// lesson's own content (quizScenarioQuestionsFor) — never fabricated.
  /// Null topic (the Learn screen's general quiz button) keeps the original
  /// 5-question mixed quiz unchanged.
  late final List<Map<String, Object>> _questions = _buildQuestions();

  List<Map<String, Object>> _buildQuestions() {
    final topic = widget.topic;
    if (topic == null) {
      return [for (final q in _legacyQuestions) Map<String, Object>.from(q)];
    }
    final list = <Map<String, Object>>[
      for (final q in _legacyQuestions)
        if (q['topic'] == topic) Map<String, Object>.from(q),
    ];
    for (final sq in quizScenarioQuestionsFor(topic)) {
      list.add({
        'q': sq.question,
        'a': sq.options,
        'correct': sq.correctIndex,
        'explanation': sq.explanation,
      });
    }
    return list;
  }

  // Records the user's chosen answer index for every question (null = not
  // yet answered), so the results screen can show a review of what was
  // missed. Reset alongside the other quiz state on retry.
  late final List<int?> _answersGiven =
      List.filled(_questions.length, null);

  void _answer(int idx) {
    if (_answered) return;
    setState(() {
      _selected = idx;
      _answered = true;
      _answersGiven[_current] = idx;
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
      // Persist the result (Hive + cloud sync; also writes the "Completed
      // quiz" Activity History entry) and award reward points.
      _finishQuiz();
      setState(() => _current = _questions.length); // trigger results view
    }
  }

  Future<void> _finishQuiz() async {
    final topic = widget.topic ?? 'general';
    final app = context.read<AppProvider>();
    await app.saveQuizResult(_score, _questions.length, topic: topic);
    final pts = await RewardService.instance.awardQuiz(_score, topic: topic);
    if (mounted) setState(() => _pointsEarned = pts);
  }

  @override
  Widget build(BuildContext context) {
    // Every lesson's quiz is immediately reachable — no completion-gating
    // guard here, matching the rest of the lesson system (see
    // LessonDetailScreen/LearnScreen).
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
              Flexible(
                child: Text(_topicTitles[widget.topic] ?? '🧠  Quiz',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
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
              backgroundColor: const Color(0xFF7B68EE).withValues(alpha: 0.15),
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
                  color: const Color(0xFF32CD32).withValues(alpha: 0.15),
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
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
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
                bg = const Color(0xFF32CD32).withValues(alpha: 0.15);
                border = const Color(0xFF32CD32);
                trailing = const Icon(Icons.check_circle,
                    color: Color(0xFF32CD32), size: 20);
              } else if (i == _selected) {
                bg = Colors.redAccent.withValues(alpha: 0.12);
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
                  color: bg ?? Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: border ??
                          const Color(0xFFFF8C69).withValues(alpha: 0.2)),
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

          // Explanation — an explicit text headline (not just the answer
          // tile's color/icon) states whether the pick was correct, so
          // feedback never relies on color alone.
          if (_answered) ...[
            Row(
              children: [
                Icon(
                  _selected == correct ? Icons.check_circle : Icons.info,
                  size: 16,
                  color: _selected == correct
                      ? const Color(0xFF32CD32)
                      : const Color(0xFFFF8C69),
                ),
                const SizedBox(width: 6),
                Text(
                  _selected == correct ? 'Correct!' : 'Not quite',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _selected == correct
                        ? const Color(0xFF32CD32)
                        : const Color(0xFF7A3B1E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFFF8C69).withValues(alpha: 0.3)),
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
          ],

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

    return SingleChildScrollView(
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
          if (_pointsEarned != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB347).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _pointsEarned! > 0
                    ? '⭐ +$_pointsEarned reward points earned!'
                    : '⭐ No new points — beat your best score to earn more.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFAA5533)),
              ),
            ),
          ],
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
                  backgroundColor:
                      const Color(0xFF7B68EE).withValues(alpha: 0.15),
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

          if (_score < _questions.length) ...[
            _buildIncorrectReview(),
            const SizedBox(height: 24),
          ],

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
                _pointsEarned = null;
                _current = 0;
                _selected = null;
                _answered = false;
                _answersGiven.fillRange(0, _answersGiven.length, null);
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

  // Compact list of the questions answered incorrectly — shows what the
  // user picked next to the correct answer, so they can learn from misses
  // without re-taking the whole quiz.
  Widget _buildIncorrectReview() {
    final missedIndexes = <int>[
      for (var i = 0; i < _questions.length; i++)
        if (_answersGiven[i] != _questions[i]['correct']) i,
    ];

    return Align(
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Review Incorrect Answers',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ...missedIndexes.map((i) {
            final q = _questions[i];
            final answers = q['a'] as List<String>;
            final correctIdx = q['correct'] as int;
            final givenIdx = _answersGiven[i];
            final givenText =
                givenIdx != null ? answers[givenIdx] : '(not answered)';

            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(q['q'] as String,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('Your answer: $givenText',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.redAccent)),
                  const SizedBox(height: 2),
                  Text('Correct answer: ${answers[correctIdx]}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF32CD32),
                          fontWeight: FontWeight.w600)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
