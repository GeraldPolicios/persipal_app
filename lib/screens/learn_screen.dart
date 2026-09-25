// screens/learn_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/lesson_content_model.dart';
import '../services/activity_log_service.dart';
import '../services/lesson_progress_service.dart';
import '../services/reward_service.dart';
import '../widgets/highlighted_text.dart';
import '../widgets/tap_effects.dart';
import 'lesson_detail_screen.dart';
import 'quiz_screen.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});

  // Every lesson is immediately accessible — this list is display order
  // only (kept in step with LessonProgressService.order), never an unlock
  // sequence.
  static const _modules = [
    {
      'title': 'Feeding',
      'emoji': '🍗',
      'type': 'feeding',
      'color': Color(0xFFFF8C69),
      'desc': 'Balanced meals, safe foods, and feeding habits.',
    },
    {
      'title': 'Grooming',
      'emoji': '✂️',
      'type': 'grooming',
      'color': Color(0xFFE91E8C),
      'desc': 'Brushing, mat prevention, and coat care.',
    },
    {
      'title': 'Behavior',
      'emoji': '🐾',
      'type': 'behavior',
      'color': Color(0xFF4682B4),
      'desc': 'Body language, stress signs, and play.',
    },
    {
      'title': 'Vitamins',
      'emoji': '💊',
      'type': 'vitamins',
      'color': Color(0xFF32CD32),
      'desc': 'Nutrition basics and safe supplement use.',
    },
    {
      'title': 'Health',
      'emoji': '🏥',
      'type': 'health',
      'color': Color(0xFFDC143C),
      'desc': 'Preventive care and when to see a vet.',
    },
    {
      'title': 'Environment',
      'emoji': '🌿',
      'type': 'environment',
      'color': Color(0xFF20B2AA),
      'desc': 'A safe, enriching home setup.',
    },
  ];

  static Color colorFor(String type) =>
      _modules.firstWhere((m) => m['type'] == type)['color'] as Color;

  static String emojiFor(String type) =>
      _modules.firstWhere((m) => m['type'] == type)['emoji'] as String;

  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _titleOf(String type) => LearnScreen._modules
      .firstWhere((m) => m['type'] == type)['title'] as String;

  void _openLesson(String type, {int? sectionIndex, String? query}) {
    ActivityLogService.instance.logLesson(_titleOf(type));
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LessonDetailScreen(
          type: type,
          openSectionIndex: sectionIndex,
          searchQuery: query,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Real progress, computed from persisted completion state — never
    // hardcoded.
    final progress = context.watch<LessonProgressService>();
    final rewards = context.watch<RewardService>();
    final completedCount = LearnScreen._modules
        .where((m) => progress.isCompleted(m['type'] as String))
        .length;
    final totalCount = LearnScreen._modules.length;

    final q = _query.trim();
    // Real content search — actual lesson text (title, description,
    // section headings, body, tap-reveal, tips, scenarios), entirely
    // offline (see searchLessons's own doc comment). Empty query = no
    // hits, and the grid below is shown instead.
    final hits = searchLessons(q);

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
                          '📚  Your Learning',
                          overflow: TextOverflow.ellipsis,
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
                      'Learn practical care tips for your Persian cat.',
                      style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFAA7755),
                          fontStyle: FontStyle.italic),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Overall progress + reward points
                  _ProgressCard(
                    completed: completedCount,
                    total: totalCount,
                    points: rewards.points,
                  ),

                  const SizedBox(height: 12),

                  // Search lessons — real content search, not just a
                  // title/category filter (see searchLessons).
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    textInputAction: TextInputAction.search,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Search lessons and care information…',
                      hintStyle:
                          const TextStyle(fontSize: 12, color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, size: 20),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            ),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.82),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Module grid (no active search) / search results list.
                  Expanded(
                    child: q.isEmpty
                        ? _buildGrid(progress)
                        : _buildSearchResults(hits, q),
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
                        overflow: TextOverflow.ellipsis,
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

  // ── Normal lesson grid — every card immediately opens its lesson, no
  // locked state ────────────────────────────────────────────────────────

  Widget _buildGrid(LessonProgressService progress) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 0.88,
      children: LearnScreen._modules.map((m) {
        final type = m['type'] as String;
        return _ModuleTile(
          title: m['title'] as String,
          emoji: m['emoji'] as String,
          color: m['color'] as Color,
          desc: m['desc'] as String,
          completed: progress.isCompleted(type),
          onTap: () => _openLesson(type),
        );
      }).toList(),
    );
  }

  // ── Search results — grouped by lesson, each hit showing the section
  // it matched and a highlighted excerpt (Parts 3–6, 10) ─────────────────

  Widget _buildSearchResults(List<LessonSearchHit> hits, String query) {
    if (hits.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 48, color: Color(0xFFFF8C69)),
            const SizedBox(height: 8),
            Text(
              'No lesson information found for "$query".',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFAA7755)),
            ),
            const SizedBox(height: 4),
            const Text('Try a different word.',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: hits.length,
      itemBuilder: (context, i) {
        final hit = hits[i];
        final isFirstOfGroup = i == 0 || hits[i - 1].type != hit.type;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isFirstOfGroup) _lessonGroupHeader(hit.type),
            _SearchResultTile(
              key: ValueKey('search_result_$i'),
              hit: hit,
              query: query,
              accent: LearnScreen.colorFor(hit.type),
              onTap: () => _openLesson(
                hit.type,
                sectionIndex: hit.sectionIndex,
                query: query,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _lessonGroupHeader(String type) {
    final color = LearnScreen.colorFor(type);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 10, 2, 6),
      child: Row(
        children: [
          Text(LearnScreen.emojiFor(type), style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 6),
          Text(
            _titleOf(type),
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}

// ── Overall progress card ───────────────────────────────────────────────────

class _ProgressCard extends StatelessWidget {
  final int completed;
  final int total;
  final int points;
  const _ProgressCard({
    required this.completed,
    required this.total,
    required this.points,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total == 0 ? 0.0 : completed / total;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school, size: 16, color: Color(0xFFFF8C69)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$completed / $total Topics Completed',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4A2C1A)),
                ),
              ),
              const SizedBox(width: 8),
              Text('⭐ $points pts',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFAA5533))),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: const Color(0xFFFF8C69).withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation(Color(0xFFFF8C69)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Topic card ───────────────────────────────────────────────────────────────

class _ModuleTile extends StatelessWidget {
  final String title;
  final String emoji;
  final Color color;
  final String desc;
  final bool completed;
  final VoidCallback onTap;

  const _ModuleTile({
    required this.title,
    required this.emoji,
    required this.color,
    required this.desc,
    required this.completed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BounceButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(18),
          border: completed
              ? Border.all(color: const Color(0xFF32CD32).withValues(alpha: 0.4))
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(emoji, style: const TextStyle(fontSize: 20)),
                  ),
                ),
                const Spacer(),
                if (completed)
                  const Icon(Icons.check_circle,
                      color: Color(0xFF32CD32), size: 18)
                else
                  Icon(Icons.chevron_right,
                      color: color.withValues(alpha: 0.5), size: 18),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Expanded(
              child: Text(
                desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10.5, color: Colors.grey.shade700, height: 1.3),
              ),
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: completed
                    ? const Color(0xFF32CD32).withValues(alpha: 0.15)
                    : color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                completed ? 'REVIEW' : 'START',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: completed ? const Color(0xFF2E8B36) : color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Search result tile — shows the matching section's heading and a
// highlighted excerpt of the actual lesson content (Parts 4–5) ─────────────

class _SearchResultTile extends StatelessWidget {
  final LessonSearchHit hit;
  final String query;
  final Color accent;
  final VoidCallback onTap;

  const _SearchResultTile({
    super.key,
    required this.hit,
    required this.query,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HighlightedText(
                        text: hit.heading,
                        query: query,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: accent),
                      ),
                      const SizedBox(height: 4),
                      HighlightedText(
                        text: hit.snippet,
                        query: query,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF4A2C1A),
                            height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right,
                    size: 18, color: accent.withValues(alpha: 0.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
