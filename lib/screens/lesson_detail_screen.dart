// screens/lesson_detail_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/lesson_content_model.dart';
import '../models/lesson_reference_model.dart';
import '../services/activity_log_service.dart';
import '../services/connectivity_service.dart';
import '../services/lesson_progress_service.dart';
import '../services/reward_service.dart';
import '../widgets/highlighted_text.dart';
import 'quiz_screen.dart';

class LessonDetailScreen extends StatefulWidget {
  final String type;

  /// Set when opened from a search result (see LearnScreen): which section
  /// — an index into `lessonSectionsFor(type)` — to scroll to and
  /// highlight on open, or null for a normal open (e.g. from the Learn
  /// screen's lesson grid, or a title/description-only search match with
  /// no specific section to point at).
  final int? openSectionIndex;

  /// The search term that led here, if any — used to highlight matching
  /// text within the opened lesson's own content (not just in the search
  /// results list), so the match is visible in place once the lesson
  /// opens. Purely cosmetic: never filters or hides any section.
  final String? searchQuery;

  const LessonDetailScreen({
    super.key,
    required this.type,
    this.openSectionIndex,
    this.searchQuery,
  });

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  // Seeded from persisted progress, not hardcoded — reopening an already
  // completed lesson shows it as completed/review-only from the start.
  late bool _completed = LessonProgressService.instance.isCompleted(widget.type);

  // Search-result navigation (see [LessonDetailScreen.openSectionIndex]).
  final Map<int, GlobalKey> _sectionKeys = {};
  int? _highlightSectionIndex;
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    final target = widget.openSectionIndex;
    if (target != null) {
      _highlightSectionIndex = target;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToSection(target));
      _highlightTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _highlightSectionIndex = null);
      });
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    super.dispose();
  }

  /// Best-effort scroll-into-view for the section a search result pointed
  /// at, bringing it near the top of the viewport — the section's
  /// GlobalKey only gets a BuildContext once the ListView actually lays it
  /// out, which may not have happened on the very first frame yet.
  void _scrollToSection(int index) {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      final ctx = _sectionKeys[index]?.currentContext;
      if (ctx != null && ctx.mounted) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 300),
          alignment: 0.08,
        );
      }
    });
  }

  List<LessonReference> _references() => kLessonReferences[widget.type] ?? const [];

  Future<void> _openReference(LessonReference ref) async {
    if (!ConnectivityService.instance.isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'This source requires an internet connection. Please reconnect and try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final uri = Uri.parse(ref.url);
    final launched =
        await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Couldn\'t open ${ref.title}.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// The single, explicit completion point for this lesson — unchanged in
  /// spirit from before (an explicit user action, not "opened the screen"
  /// or "scrolled to the bottom"). Guarded so reviewing an already-
  /// completed lesson never re-persists or re-logs a duplicate "completed
  /// lesson" Activity History entry.
  void _markComplete() {
    if (_completed) return;
    setState(() => _completed = true);
    LessonProgressService.instance.markCompleted(widget.type);
    RewardService.instance
        .awardOnce('lesson:${widget.type}', RewardService.lessonCompletePoints);
    ActivityLogService.instance.logLessonComplete(lessonTitle(widget.type));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  '${lessonTitle(widget.type)} marked as complete! +${RewardService.lessonCompletePoints} points',
                  overflow: TextOverflow.ellipsis),
            ),
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
    // Every lesson is immediately accessible — PersiPal's lessons are
    // reference information a user may need right away, so there is no
    // locking guard here (or anywhere else in the lesson system) to check.
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
                          lessonTitle(widget.type),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (_completed) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.check_circle,
                            color: Color(0xFF32CD32), size: 22),
                      ],
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
                          color: Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          lessonDescription(widget.type),
                          style: const TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: Color(0xFF7A3B1E),
                            height: 1.5,
                          ),
                        ),
                      ),

                      // Interactive content sections — each wrapped with a
                      // GlobalKey so a search result can scroll straight to
                      // the exact section it matched (see initState /
                      // _scrollToSection), and passed the active search
                      // query (if any) so the matching text is highlighted
                      // in place, not just in the search results list.
                      for (final entry
                          in lessonSectionsFor(widget.type).indexed)
                        _renderSection(entry.$2, entry.$1),

                      // References / Sources
                      if (_references().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'REFERENCES / SOURCES',
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: Color(0xFFAA7755)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        ..._references().map((ref) => _ReferenceTile(
                              reference: ref,
                              onTap: () => _openReference(ref),
                            )),
                      ],

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

                      const SizedBox(height: 10),

                      // This lesson's own quiz (QZ-4) — same shared
                      // QuizScreen, now scoped to this topic.
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF7B68EE),
                            side: const BorderSide(color: Color(0xFF7B68EE)),
                            padding: const EdgeInsets.all(14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => QuizScreen(topic: widget.type)),
                          ),
                          icon: const Icon(Icons.quiz, size: 18),
                          label: const Text(
                            'Test Your Knowledge',
                            style: TextStyle(
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

  // ── Section rendering ─────────────────────────────────────────────────────

  Widget _renderSection(LessonSection section, int index) {
    final key = _sectionKeys.putIfAbsent(index, () => GlobalKey());
    final query = widget.searchQuery ?? '';
    final highlighted = index == _highlightSectionIndex;
    return Container(
      key: key,
      decoration: highlighted
          ? BoxDecoration(
              border: Border.all(color: const Color(0xFFFFC107), width: 2.5),
              borderRadius: BorderRadius.circular(16),
            )
          : null,
      margin: highlighted ? const EdgeInsets.only(bottom: 4) : null,
      child: switch (section) {
        InfoSection s => _InfoCard(section: s, query: query),
        TapRevealSection s => _TapRevealCard(section: s, query: query),
        TipSection s => _TipCard(section: s, query: query),
        ScenarioSection s => _ScenarioCard(section: s, query: query),
      },
    );
  }
}

// ── Reference / source tile ────────────────────────────────────────────────

class _ReferenceTile extends StatelessWidget {
  final LessonReference reference;
  final VoidCallback onTap;

  const _ReferenceTile({required this.reference, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Colors.white.withValues(alpha: 0.85),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.open_in_new, size: 16, color: Color(0xFF7B68EE)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reference.title,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A2C1A)),
                    ),
                    if (reference.publisher != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        reference.publisher!,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFFAA7755)),
                      ),
                    ],
                    if (reference.description != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        reference.description!,
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Info card — essential content, always visible (never hidden behind a
// tap) ───────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final InfoSection section;
  final String query;
  const _InfoCard({required this.section, this.query = ''});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HighlightedText(
            text: section.title,
            query: query,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          HighlightedText(
            text: section.body,
            query: query,
            style: const TextStyle(fontSize: 13, height: 1.6),
          ),
        ],
      ),
    );
  }
}

// ── Tap-to-reveal card ──────────────────────────────────────────────────────

class _TapRevealCard extends StatefulWidget {
  final TapRevealSection section;
  final String query;
  const _TapRevealCard({required this.section, this.query = ''});

  @override
  State<_TapRevealCard> createState() => _TapRevealCardState();
}

class _TapRevealCardState extends State<_TapRevealCard> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF20B2AA);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => setState(() => _revealed = !_revealed),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.touch_app, size: 16, color: accent),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'TAP TO LEARN',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.0,
                          color: accent),
                    ),
                  ),
                  Icon(
                    _revealed
                        ? Icons.expand_less
                        : Icons.expand_more,
                    size: 20,
                    color: accent,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              HighlightedText(
                text: widget.section.prompt,
                query: widget.query,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4A2C1A)),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState: _revealed
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox(width: double.infinity),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: HighlightedText(
                    text: widget.section.reveal,
                    query: widget.query,
                    style: const TextStyle(fontSize: 13, height: 1.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Practical care tip ──────────────────────────────────────────────────────

class _TipCard extends StatelessWidget {
  final TipSection section;
  final String query;
  const _TipCard({required this.section, this.query = ''});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFF8C69).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFFFF8C69).withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CARE TIP',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                      color: Color(0xFFAA5533)),
                ),
                const SizedBox(height: 4),
                HighlightedText(
                  text: section.tip,
                  query: query,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      color: Color(0xFF7A3B1E)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Scenario question ───────────────────────────────────────────────────────

class _ScenarioCard extends StatefulWidget {
  final ScenarioSection section;
  final String query;
  const _ScenarioCard({required this.section, this.query = ''});

  @override
  State<_ScenarioCard> createState() => _ScenarioCardState();
}

class _ScenarioCardState extends State<_ScenarioCard> {
  int? _selected;
  bool _answered = false;

  void _select(int index) {
    // Once answered, prevent accidental repeated changes — matches the
    // existing QuizScreen's own guard.
    if (_answered) return;
    setState(() {
      _selected = index;
      _answered = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.section;
    final isCorrect = _selected == s.correctIndex;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SCENARIO',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                color: Color(0xFF7B68EE)),
          ),
          const SizedBox(height: 6),
          HighlightedText(
            text: s.scenario,
            query: widget.query,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, height: 1.4),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < s.options.length; i++)
            _OptionTile(
              text: s.options[i],
              query: widget.query,
              index: i,
              selected: _selected,
              answered: _answered,
              correctIndex: s.correctIndex,
              onTap: () => _select(i),
            ),
          if (_answered) ...[
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCorrect
                    ? const Color(0xFF32CD32).withValues(alpha: 0.12)
                    : const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isCorrect
                      ? const Color(0xFF32CD32).withValues(alpha: 0.4)
                      : const Color(0xFFFF8C69).withValues(alpha: 0.35),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isCorrect ? Icons.check_circle : Icons.info_outline,
                        size: 16,
                        color: isCorrect
                            ? const Color(0xFF32CD32)
                            : const Color(0xFFFF8C69),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isCorrect ? 'Correct!' : 'Not quite',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isCorrect
                              ? const Color(0xFF32CD32)
                              : const Color(0xFF7A3B1E),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isCorrect ? s.correctExplanation : s.incorrectExplanation,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF7A3B1E), height: 1.4),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final String text;
  final String query;
  final int index;
  final int? selected;
  final bool answered;
  final int correctIndex;
  final VoidCallback onTap;

  const _OptionTile({
    required this.text,
    this.query = '',
    required this.index,
    required this.selected,
    required this.answered,
    required this.correctIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = Colors.white.withValues(alpha: 0.7);
    Color border = const Color(0xFFFF8C69).withValues(alpha: 0.2);
    Widget? trailing;

    if (answered) {
      if (index == correctIndex) {
        bg = const Color(0xFF32CD32).withValues(alpha: 0.15);
        border = const Color(0xFF32CD32);
        trailing = const Icon(Icons.check_circle,
            color: Color(0xFF32CD32), size: 20);
      } else if (index == selected) {
        bg = Colors.redAccent.withValues(alpha: 0.12);
        border = Colors.redAccent;
        trailing =
            const Icon(Icons.cancel, color: Colors.redAccent, size: 20);
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Expanded(
                child: HighlightedText(
                  text: text,
                  query: query,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
