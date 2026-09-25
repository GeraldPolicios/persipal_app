// lib/models/lesson_content_model.dart
//
// Structured, interactive lesson content for the Learn Cat Care module.
// Replaces the old pattern of building lesson widgets directly inside
// lesson_detail_screen.dart's per-topic methods — the content here is DATA
// (LessonSection subtypes), rendered polymorphically by the screen, so
// interaction state (tap-to-reveal, answered scenario) lives per-section
// instead of being hand-rolled per topic.
//
// The factual content itself is carried over from the existing,
// source-verified lesson material (Cornell Feline Health Center, ASPCA,
// International Cat Care, Ohio State Indoor Pet Initiative, Humane World
// for Animals — see lesson_reference_model.dart for the exact references),
// just restructured into interactive sections rather than rewritten.

/// One section of a lesson. Sealed so the renderer's switch is exhaustive
/// — adding a new section type is a compile error everywhere it isn't
/// handled yet, rather than a silently-ignored case.
sealed class LessonSection {
  const LessonSection();
}

/// A concise explanation shown directly (not hidden behind a tap) — used
/// for information essential enough that it shouldn't require interaction
/// to see.
class InfoSection extends LessonSection {
  final String title;
  final String body;
  const InfoSection({required this.title, required this.body});
}

/// "Tap to learn" — a prompt question the user taps to reveal the answer.
/// Used sparingly, for genuinely interesting supplementary facts, not for
/// essential information.
class TapRevealSection extends LessonSection {
  final String prompt;
  final String reveal;
  const TapRevealSection({required this.prompt, required this.reveal});
}

/// A short, memorable practical-care tip, shown in a visually distinct
/// "CARE TIP" card.
class TipSection extends LessonSection {
  final String tip;
  const TipSection(this.tip);
}

/// A practical scenario question with one correct multiple-choice answer.
/// Feedback always explains WHY, for both a correct and an incorrect pick.
class ScenarioSection extends LessonSection {
  final String scenario;
  final List<String> options;
  final int correctIndex;
  final String correctExplanation;
  final String incorrectExplanation;
  const ScenarioSection({
    required this.scenario,
    required this.options,
    required this.correctIndex,
    required this.correctExplanation,
    required this.incorrectExplanation,
  });
}

/// The six lesson types, in the app's canonical learning-topic order.
/// Mirrors LessonProgressService.order exactly (duplicated as a plain
/// const rather than imported, so this models file — data only — never
/// depends on a services file for something [lessonSectionsFor]'s own
/// switch already enumerates one-for-one).
const kLessonTypes = [
  'feeding',
  'grooming',
  'behavior',
  'vitamins',
  'health',
  'environment',
];

/// A lesson's own display title — the single source of truth
/// LessonDetailScreen's header AND lesson search both read from (previously
/// duplicated as a private method inside lesson_detail_screen.dart only,
/// invisible to search — see lesson_search_test.dart).
String lessonTitle(String type) => switch (type) {
      'feeding' => 'Feeding Guide 🍽️',
      'grooming' => 'Grooming Guide 🧼',
      'behavior' => 'Behavior Guide 🧠',
      'vitamins' => 'Vitamins Guide 💊',
      'health' => 'Health Guide 🏥',
      'environment' => 'Environment Guide 🌿',
      _ => 'Lesson',
    };

/// A lesson's intro/description paragraph — same single-source-of-truth
/// reasoning as [lessonTitle].
String lessonDescription(String type) => switch (type) {
      'feeding' =>
        'Evidence-based feeding practices for cats, plus feeding '
            'considerations specific to Persian cats, based on veterinary '
            'and animal-welfare guidance. This is educational information, '
            'not a substitute for advice from your veterinarian.',
      'grooming' =>
        'How to keep a Persian cat\'s long coat healthy and mat-free, '
            'based on feline-welfare grooming guidance.',
      'behavior' =>
        'Normal cat behavior, communication, and stress signals — with '
            'Persian-specific considerations noted only where there\'s real '
            'evidence behind them, not breed stereotypes.',
      'vitamins' =>
        'What cats actually need nutritionally, when supplements may be '
            'appropriate, and why giving vitamins without veterinary '
            'guidance can be risky.',
      'health' =>
        'Veterinary-recognized Persian cat health considerations, '
            'preventive care, and the warning signs that call for a vet '
            'visit. This is educational information only — it cannot '
            'diagnose your cat.',
      'environment' =>
        'How to set up a safe, enriching indoor home for a Persian cat, '
            'based on feline-welfare and indoor-cat guidance.',
      _ => '',
    };

/// Every readable string of one section, concatenated for search/matching.
/// The single place that knows how to flatten each [LessonSection]
/// subtype's fields — both [lessonSearchText] and [searchLessons] build on
/// this rather than re-deriving it, so there is exactly one definition of
/// "what text does this section contain."
String _sectionSearchText(LessonSection section) => switch (section) {
      InfoSection(:final title, :final body) => '$title $body',
      TapRevealSection(:final prompt, :final reveal) => '$prompt $reveal',
      TipSection(:final tip) => tip,
      ScenarioSection(
        :final scenario,
        :final options,
        :final correctExplanation,
        :final incorrectExplanation,
      ) =>
        '$scenario ${options.join(' ')} $correctExplanation '
            '$incorrectExplanation',
    };

/// A short, human label for one section — shown as a search result's
/// "which part of the lesson matched" heading (e.g. an InfoSection's own
/// title, or a fixed label for the other section kinds, which don't carry
/// one of their own).
String _headingFor(LessonSection section) => switch (section) {
      InfoSection(:final title) => title,
      TapRevealSection() => '💡 Did You Know?',
      TipSection() => '💡 Care Tip',
      ScenarioSection() => '🎯 Practice Scenario',
    };

/// All the readable text of a lesson, for the Learn screen's search. Built
/// from the same [lessonSectionsFor] data the lesson screen renders, so
/// search can never drift from what a lesson actually says.
String lessonSearchText(String type) {
  final b = StringBuffer();
  for (final section in lessonSectionsFor(type)) {
    b.writeln(_sectionSearchText(section));
  }
  return b.toString();
}

/// One lesson section that matched a search query — enough context for a
/// result to show WHY it matched (lesson + section heading + an excerpt
/// containing the match) and to navigate straight back to that exact spot.
class LessonSearchHit {
  final String type;

  /// Index into `lessonSectionsFor(type)` for the matching section, or
  /// null when the match was in the lesson's own title/description rather
  /// than any specific section (see [searchLessons]).
  final int? sectionIndex;
  final String heading;
  final String snippet;

  const LessonSearchHit({
    required this.type,
    required this.sectionIndex,
    required this.heading,
    required this.snippet,
  });
}

/// A short excerpt of [text] surrounding the first case-insensitive match
/// of [query], so a result shows real matching content instead of the
/// whole section. Never modifies casing/content — a straight substring of
/// the original, just windowed and possibly ellipsized at the edges.
String _excerptAround(String text, String query, {int radius = 60}) {
  final flat = text.replaceAll('\n', ' ').trim();
  final idx = flat.toLowerCase().indexOf(query.toLowerCase());
  if (idx == -1) {
    return flat.length > 140 ? '${flat.substring(0, 140).trim()}…' : flat;
  }
  final start = (idx - radius).clamp(0, flat.length);
  final end = (idx + query.length + radius).clamp(0, flat.length);
  final prefix = start > 0 ? '…' : '';
  final suffix = end < flat.length ? '…' : '';
  return '$prefix${flat.substring(start, end).trim()}$suffix';
}

/// Real content search across the six bundled lessons — the app's actual
/// lesson text (title, description, section headings, informational body
/// text, tap-reveal prompts/answers, tips, and scenario text/options/
/// explanations), never just a title/category filter. Entirely offline:
/// reads only the const [LessonSection] data already defined in this file
/// — no network call, no Firebase, no login required, so it works for a
/// guest exactly as it does for a signed-in user, online or off.
///
/// Case-insensitive, partial-word ("brush" matches "Brushing"), and
/// returns EVERY matching section (not just the first) so a lesson with
/// several relevant parts surfaces all of them rather than collapsing to
/// one generic "Health" result. A blank/whitespace-only query returns no
/// hits (the caller is expected to show the normal lesson list instead —
/// see LearnScreen).
List<LessonSearchHit> searchLessons(String query, {List<String>? types}) {
  final q = query.trim();
  if (q.isEmpty) return const [];
  final lowerQ = q.toLowerCase();
  final hits = <LessonSearchHit>[];

  for (final type in types ?? kLessonTypes) {
    final title = lessonTitle(type);
    final description = lessonDescription(type);
    if (title.toLowerCase().contains(lowerQ) ||
        description.toLowerCase().contains(lowerQ)) {
      hits.add(LessonSearchHit(
        type: type,
        sectionIndex: null,
        heading: '📖 Overview',
        snippet: description.isNotEmpty ? description : title,
      ));
    }

    final sections = lessonSectionsFor(type);
    for (var i = 0; i < sections.length; i++) {
      final text = _sectionSearchText(sections[i]);
      if (text.toLowerCase().contains(lowerQ)) {
        hits.add(LessonSearchHit(
          type: type,
          sectionIndex: i,
          heading: _headingFor(sections[i]),
          snippet: _excerptAround(text, q),
        ));
      }
    }
  }
  return hits;
}

/// One multiple-choice quiz question sourced directly from a lesson's own
/// content — never invented separately for the quiz.
class QuizQuestionData {
  final String question;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  const QuizQuestionData({
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.explanation,
  });
}

/// The quiz question(s) grounded in [type]'s own lesson content (QZ-4).
/// Each topic currently authors exactly one ScenarioSection, so this
/// returns exactly one question per known topic, or an empty list for an
/// unrecognized type — never fabricated content.
List<QuizQuestionData> quizScenarioQuestionsFor(String type) {
  final questions = <QuizQuestionData>[];
  for (final section in lessonSectionsFor(type)) {
    if (section is ScenarioSection) {
      questions.add(QuizQuestionData(
        question: section.scenario,
        options: section.options,
        correctIndex: section.correctIndex,
        explanation: section.correctExplanation,
      ));
    }
  }
  return questions;
}

List<LessonSection> lessonSectionsFor(String type) {
  switch (type) {
    case 'feeding':
      return _feeding;
    case 'grooming':
      return _grooming;
    case 'behavior':
      return _behavior;
    case 'vitamins':
      return _vitamins;
    case 'health':
      return _health;
    case 'environment':
      return _environment;
    default:
      return const [];
  }
}

// ─── Feeding ────────────────────────────────────────────────────────────────

const _feeding = <LessonSection>[
  InfoSection(
    title: '✅ What You Should Know',
    body: 'Cats are obligate carnivores — they need nutrients found mainly '
        'in animal-based protein. Choose a commercial food labeled '
        '"complete and balanced" (look for an AAFCO nutritional adequacy '
        'statement), and check that meat or seafood is listed among the '
        'first ingredients.',
  ),
  InfoSection(
    title: '🍼 Kitten, Adult & Senior Needs',
    body: 'Kittens, adults, and senior cats have different energy and '
        'nutrient needs, which is why foods are usually labeled for a '
        'specific life stage. A growing kitten generally needs a '
        'kitten-formulated food; adult cats do best on a maintenance '
        'formula; and older cats may benefit from a senior diet — ask your '
        'vet which stage fits your cat and when to switch.',
  ),
  InfoSection(
    title: '🥫 Wet vs. Dry Food',
    body: 'Both wet and dry commercial diets can be complete and balanced. '
        'Wet/canned food is roughly 75% water and can help increase overall '
        'water intake, which is useful for cats prone to urinary or kidney '
        'issues. Dry food is convenient and shelf-stable but contributes '
        'little moisture on its own — many owners feed a mix of both.',
  ),
  InfoSection(
    title: '💧 Hydration & Feeding Practices',
    body: 'Always provide clean, fresh water, changed daily. Place food '
        'and water away from litter boxes, loud appliances, and '
        'high-traffic areas — cats are more likely to eat and drink '
        'comfortably somewhere calm.',
  ),
  InfoSection(
    title: '🍽️ Routines, Portions & Treats',
    body: 'Follow the feeding guide on the food packaging as a starting '
        'point, and ask your vet to help set the right portion for your '
        'cat\'s age, weight, and activity level. Treats are fine in '
        'moderation but shouldn\'t make up more than a small share of daily '
        'calories — too many treats can unbalance an otherwise complete '
        'diet.',
  ),
  InfoSection(
    title: '⚠️ Foods & Substances to Avoid',
    body: 'Never feed chocolate, onions, garlic, grapes or raisins, raw '
        'bread dough, alcohol, or anything containing xylitol (a sweetener '
        'in some sugar-free products) — all can be toxic to cats. Cow\'s '
        'milk isn\'t toxic, but many adult cats are lactose intolerant and '
        'it can cause stomach upset.',
  ),
  InfoSection(
    title: '🔄 Changing Foods Safely',
    body: 'Switch foods gradually over about 7–10 days, mixing in a little '
        'more of the new food each day, rather than swapping all at once — '
        'this helps avoid digestive upset and gives a picky cat time to '
        'adjust.',
  ),
  InfoSection(
    title: '🚩 Warning Signs Worth a Vet Visit',
    body: 'Not eating for more than a day, sudden weight loss or gain, '
        'noticeably increased thirst, vomiting after most meals, or '
        'reluctance to eat while apparently hungry are all reasons to '
        'contact your veterinarian rather than wait it out.',
  ),
  InfoSection(
    title: '🐱 Persian Cat Tips',
    body: 'A Persian\'s flat face can make it harder to pick up food from a '
        'deep, narrow bowl. A wide, shallow dish is often easier and more '
        'comfortable, and keeping the face clean at mealtimes helps prevent '
        'staining and irritation around the mouth.',
  ),
  TapRevealSection(
    prompt: 'Why can\'t Persian cats thrive on a vegetarian or dog-food '
        'diet?',
    reveal: 'Cats are obligate carnivores — they need nutrients found '
        'mainly in animal-based protein that plant-based food or dog food '
        'can\'t reliably provide.',
  ),
  TipSection(
    'Free-feeding dry food all day is a major contributor to weight gain — '
    'scheduled meals instead of constant access help maintain a healthy '
    'weight.',
  ),
  TipSection(
    'Quick checklist: complete-and-balanced food for the right life stage, '
    'fresh water daily, a calm feeding spot, treats kept to a small share '
    'of calories, and any food change made gradually over about a week.',
  ),
  ScenarioSection(
    scenario: 'Your cat finishes dinner and starts meowing for more. You '
        'have leftover milk and some chocolate dessert on the counter. '
        'What should you do?',
    options: [
      'Give her the milk as a treat',
      'Give her a small amount of her regular cat food instead',
      'Give her a piece of the chocolate dessert',
      'Ignore her completely and never offer anything extra',
    ],
    correctIndex: 1,
    correctExplanation: 'Milk and chocolate can upset a cat\'s stomach or '
        'be toxic. If you want to offer something extra, a small amount '
        'of her regular, complete cat food is the safer choice.',
    incorrectExplanation: 'Milk and chocolate can cause digestive upset or '
        'be toxic to cats — a small amount of her regular, complete cat '
        'food is a safer way to offer something extra.',
  ),
  ScenarioSection(
    scenario: 'You want to switch your cat to a new food. What\'s the '
        'safest approach?',
    options: [
      'Swap all of the old food for the new food overnight',
      'Mix a little more new food in with the old food each day over about '
          'a week',
      'Feed the old and new food at completely separate meals with no '
          'mixing',
      'Skip a day of eating first to encourage her to accept the new food',
    ],
    correctIndex: 1,
    correctExplanation: 'A gradual transition over about 7–10 days, mixing '
        'in more of the new food each day, is the safest way to avoid '
        'digestive upset and help a cat accept a new diet.',
    incorrectExplanation: 'An abrupt switch can upset digestion, and '
        'withholding food isn\'t a safe way to encourage eating. A gradual '
        'week-or-so transition works best.',
  ),
];

// ─── Grooming ───────────────────────────────────────────────────────────────

const _grooming = <LessonSection>[
  InfoSection(
    title: '💡 Why Coat Care Matters',
    body: 'Removing loose/dead hair reduces hairballs and shedding, and '
        'brushing helps distribute the skin\'s natural oils for a '
        'healthier coat. Regular handling also gives you a chance to spot '
        'fleas, lumps, or skin changes early.',
  ),
  InfoSection(
    title: '🧶 Persian Coat & Brushing Routine',
    body: 'A Persian\'s very long, dense double coat needs far more '
        'grooming than a short-haired cat\'s. Long-haired cats generally '
        'need daily combing, for as long as your cat stays comfortable — '
        'a wide-toothed comb works best through the undercoat, followed by '
        'a softer brush to smooth the top coat.',
  ),
  InfoSection(
    title: '⚠️ Mat Prevention & What to Do When Mats Develop',
    body: 'Mats form fastest around the armpits, belly, and behind the '
        'ears, where fur rubs together. Small tangles are easiest to '
        'manage right away by gently working through them with a comb, '
        'starting at the tips and working toward the skin. A tight, '
        'established mat is often safest removed by a groomer or vet, '
        'since cutting close to the skin at home risks nicking it.',
  ),
  InfoSection(
    title: '🛁 Bathing Basics',
    body: 'Persians are bathed more often than most cats because of their '
        'coat length — many owners bathe every few weeks as part of the '
        'regular routine. Use a cat-specific shampoo (human shampoo can '
        'irritate skin), rinse thoroughly, and dry completely before '
        'letting your cat wander, since a damp double coat mats easily and '
        'holds moisture against the skin.',
  ),
  InfoSection(
    title: '👁️ Face & Tear-Area Hygiene',
    body: 'Persian cats\' flat facial structure can lead to more visible '
        'tear staining around the eyes. Gently wipe the area with a damp, '
        'soft cloth as needed to keep it clean, using a fresh area of the '
        'cloth for each eye. Ask your vet about the cause if staining is '
        'heavy, sudden, or the area looks red or irritated.',
  ),
  InfoSection(
    title: '👂 Ear Care',
    body: 'Healthy cat ears are usually clean with little odor. Check '
        'periodically and only clean the visible, outer part of the ear '
        'with a vet-approved cleaner on a soft cloth — never insert cotton '
        'swabs into the ear canal. Dark debris, strong odor, redness, or '
        'frequent head-shaking are reasons to see a vet.',
  ),
  InfoSection(
    title: '✂️ Nail Care',
    body: 'Regular nail trims help prevent snagging and overgrowth, '
        'especially for indoor cats. Trim only the sharp tip, avoiding the '
        'pink "quick" inside the nail, which contains blood vessels and '
        'nerves — if you\'re unsure where that is, ask your vet or groomer '
        'to show you the first time.',
  ),
  InfoSection(
    title: '🚩 Grooming Safety & When to Get Help',
    body: 'Never use scissors close to the skin to remove a mat — a '
        'groomer or vet has clippers designed to do this safely. Stop and '
        'try again later if your cat shows tail-swishing, ear-flicking, or '
        'tries to move away. Widespread matting, skin that looks red or '
        'sore, or a coat that seems painful to touch are reasons for '
        'professional or veterinary grooming help.',
  ),
  TapRevealSection(
    prompt: 'Why is regular grooming especially important for Persian '
        'cats?',
    reveal: 'Persian cats have long coats that can become tangled and '
        'matted without regular grooming. Daily combing is the most '
        'effective way to prevent painful mats from forming in the first '
        'place.',
  ),
  TipSection(
    'Introduce grooming gradually and reward calm behavior — short, '
    'positive sessions build tolerance far better than one long struggle.',
  ),
  TipSection(
    'Quick checklist: daily combing, an every-few-weeks bath, gentle daily '
    'face wipes, periodic ear checks, and regular nail trims — with a '
    'groomer or vet for anything matted, sore, or hard to manage at home.',
  ),
  ScenarioSection(
    scenario: 'Your Persian cat\'s coat has started developing small '
        'tangles. What should you do?',
    options: [
      'Ignore it until the next bath',
      'Gently work through the tangles with appropriate grooming tools',
      'Cut the entire coat immediately',
      'Stop grooming completely',
    ],
    correctIndex: 1,
    correctExplanation: 'Small tangles are easiest to manage right away — '
        'gently working through them with a wide-tooth comb prevents them '
        'from tightening into painful mats.',
    incorrectExplanation: 'Waiting, cutting, or stopping grooming '
        'altogether all make matting worse or risk injury. Gently combing '
        'out small tangles early is the safest approach.',
  ),
  ScenarioSection(
    scenario: 'You find a tight, established mat close to your cat\'s '
        'skin. What\'s the safest next step?',
    options: [
      'Cut it out yourself with scissors right against the skin',
      'Pull it out by hand as quickly as possible',
      'Have a groomer or vet remove it with proper clippers',
      'Shave the entire cat yourself',
    ],
    correctIndex: 2,
    correctExplanation: 'A tight mat close to the skin is easy to injure '
        'with scissors at home. A groomer or vet has clippers designed to '
        'remove it safely.',
    incorrectExplanation: 'Scissors or pulling near the skin risk cutting '
        'or hurting your cat — a professional groomer or vet can remove an '
        'established mat safely.',
  ),
];

// ─── Behavior ───────────────────────────────────────────────────────────────

const _behavior = <LessonSection>[
  InfoSection(
    title: '✅ Normal Persian-Cat Behavior',
    body: 'Cats rely heavily on body language, posture, and vocalization '
        'to communicate. A behavior that seems like a "problem" is very '
        'often a normal cat instinct — scratching, meowing, and hiding '
        'are all natural. Persians are generally known for a calm, quiet '
        'temperament, but every individual cat still has its own '
        'personality.',
  ),
  InfoSection(
    title: '🗣️ Body Language & Vocalizations',
    body: 'A relaxed cat usually has a loosely held tail, soft eyes, and '
        'forward-facing ears. A puffed-up tail, flattened ears, or a low '
        'crouch can signal fear or agitation. Cats meow mainly to '
        'communicate with people (not much with each other) — the meaning '
        'depends on context, tone, and what else is going on.',
  ),
  InfoSection(
    title: '😿 Stress & Fear Signals',
    body: 'Acute stress can look like freezing, crouching, dilated pupils, '
        'or flattened ears. Chronic stress can show up as hiding more, '
        'grooming less (or over-grooming), or appetite changes. Give your '
        'cat resources (food, water, litter, resting spots) in multiple '
        'locations, and let them choose when to approach you.',
  ),
  InfoSection(
    title: '🤝 Positive Interaction & Handling',
    body: 'Let a cat sniff a hand before petting, and watch for tail '
        'flicking or skin twitching that signal "that\'s enough." Short, '
        'gentle, predictable handling — especially around the face and '
        'paws — builds trust over time and makes routine care (brushing, '
        'nail trims, vet visits) far less stressful.',
  ),
  InfoSection(
    title: '🪵 Scratching',
    body: 'Scratching is natural — cats do it to stretch, mark territory, '
        'and remove the outer nail sheath, not out of spite. If a post '
        'isn\'t in a location or material your cat likes, they\'ll choose '
        'furniture instead — offer sturdy, tall posts in the spots your '
        'cat already prefers to scratch.',
  ),
  InfoSection(
    title: '🧶 Play & Enrichment',
    body: 'Regular play mimics natural hunting behavior and is an '
        'important outlet for indoor cats, especially a less active breed '
        'like the Persian. Short, frequent play sessions with wand toys or '
        'puzzle feeders help prevent boredom and support a healthy weight.',
  ),
  InfoSection(
    title: '🚽 Litter-Box Behavior',
    body: 'Most cats are naturally inclined to use a litter box if it\'s '
        'kept clean, accessible, and in a quiet location. Avoiding the '
        'box, straining, or eliminating just outside it are behavior '
        'changes worth investigating rather than punishing — the cause is '
        'often the box setup itself or an underlying health issue.',
  ),
  InfoSection(
    title: '🔄 Environmental Changes & Adjustment',
    body: 'Cats generally prefer routine and can take time to adjust to a '
        'new home, new pet, or rearranged furniture. Introduce changes '
        'gradually where possible, and keep familiar items (bedding, '
        'scratching posts) in place during a transition to help your cat '
        'settle.',
  ),
  InfoSection(
    title: '🚩 When Unusual Behavior Warrants a Vet Visit',
    body: 'A sudden, lasting change in behavior — new aggression, hiding, '
        'vocalizing more, or litter-box avoidance — is not automatically '
        '"just personality." Because cats often hide pain well, unexplained '
        'behavior changes are worth a veterinary check to rule out a '
        'medical cause.',
  ),
  TapRevealSection(
    prompt: 'Why does my cat scratch furniture instead of just the '
        'scratching post?',
    reveal: 'Scratching is natural — cats do it to stretch, mark '
        'territory, and remove the outer nail sheath. If a post isn\'t in '
        'a location or material your cat likes, they\'ll choose furniture '
        'instead.',
  ),
  TipSection(
    'Reward use of the scratching post rather than punishing scratching '
    'elsewhere — make off-limits surfaces less appealing instead.',
  ),
  TipSection(
    'Quick checklist: read body language before handling, offer daily play, '
    'keep the litter box clean and accessible, introduce changes gradually, '
    'and treat any sudden behavior change as worth mentioning to your vet.',
  ),
  ScenarioSection(
    scenario: 'Your cat suddenly starts hiding more than usual and '
        'grooming herself less. What\'s the best response?',
    options: [
      'Assume she\'s just being independent and ignore it',
      'Force her out of hiding so she socializes',
      'Note the change and consider whether her environment or health '
          'needs attention',
      'Punish her for hiding',
    ],
    correctIndex: 2,
    correctExplanation: 'Hiding more and grooming less can be signs of '
        'stress or illness. Noting the change and looking into possible '
        'causes — including a vet visit if it continues — is the '
        'responsible response.',
    incorrectExplanation: 'Ignoring, forcing, or punishing a stressed cat '
        'can make things worse. A sudden behavior change is worth paying '
        'attention to, and discussing with a veterinarian if it '
        'continues.',
  ),
  ScenarioSection(
    scenario: 'One of your two cats has started avoiding the single '
        'shared litter box. What\'s the most likely helpful first step?',
    options: [
      'Scold the cat for eliminating outside the box',
      'Check the box\'s cleanliness/location and consider adding a second '
          'box',
      'Remove the litter box entirely',
      'Assume it will resolve on its own with no changes',
    ],
    correctIndex: 1,
    correctExplanation: 'Box avoidance is often about cleanliness, '
        'location, or competition over a shared box — checking those '
        'basics and adding a second box in a different spot is the '
        'evidence-based first step.',
    incorrectExplanation: 'Punishment doesn\'t address the cause, and '
        'removing the box makes things worse. Reviewing the setup and '
        'adding a box is the more helpful approach.',
  ),
];

// ─── Vitamins ───────────────────────────────────────────────────────────────

const _vitamins = <LessonSection>[
  InfoSection(
    title: '✅ Nutrients Come From Diet First',
    body: 'A commercial cat food carrying an AAFCO "complete and balanced" '
        'nutritional adequacy statement is formulated to meet a cat\'s '
        'known nutrient needs. If your cat eats a complete and balanced '
        'diet appropriate for their life stage, additional vitamins are '
        'often unnecessary.',
  ),
  InfoSection(
    title: '📋 Complete-and-Balanced Food vs. Supplements',
    body: 'A "complete and balanced" label means the food alone is meant '
        'to supply everything a healthy cat needs — supplements are meant '
        'to add to a diet, not replace poor-quality food or fix a problem '
        'a vet hasn\'t identified. Stacking multiple supplements "just in '
        'case" can push some nutrients above safe levels.',
  ),
  InfoSection(
    title: '🚫 Why Not Human Vitamins',
    body: 'Never give human vitamins or supplements to a cat. They\'re '
        'dosed and formulated for a person\'s body weight and metabolism, '
        'not a cat\'s, and some common human supplement ingredients — like '
        'certain forms of vitamin D — can be toxic to cats even in small '
        'amounts.',
  ),
  InfoSection(
    title: '⚠️ Risks of Inappropriate Supplementation',
    body: 'More is not automatically better — oversupplementing certain '
        'vitamins and minerals (including some fat-soluble vitamins) can '
        'build up in the body and cause harm over time. Supplements can '
        'also interact with medications your cat is already taking.',
  ),
  InfoSection(
    title: '🩺 When a Vet May Recommend Supplementation',
    body: 'A veterinarian may recommend a specific supplement for a '
        'particular reason — for example, to support joints in an older '
        'cat, or as part of managing a diagnosed condition. In those '
        'cases, the product, dose, and duration are chosen for that cat\'s '
        'situation, which is different from adding something on a guess.',
  ),
  InfoSection(
    title: '☑️ Safe Supplement Decision-Making',
    body: 'Before giving anything beyond your cat\'s regular food, ask: '
        'is this cat-specific, has a vet reviewed it for my cat, and is '
        'there an actual reason for it? If the honest answer to any of '
        'those is no, it\'s worth checking with your vet before starting.',
  ),
  TapRevealSection(
    prompt: 'If my cat eats a complete and balanced diet, do they still '
        'need vitamin supplements?',
    reveal: 'Usually not. A food labeled "complete and balanced" is '
        'already formulated to meet a cat\'s known nutrient needs — extra '
        'supplements are often unnecessary and should only be added on a '
        'vet\'s advice.',
  ),
  TipSection(
    'Never give human vitamins to a cat — doses and formulations are made '
    'for people, and some ingredients can be toxic to cats.',
  ),
  TipSection(
    'This lesson covers nutrition education, not veterinary treatment — '
    'any decision to add or change a supplement for a specific health '
    'reason should go through your veterinarian.',
  ),
  ScenarioSection(
    scenario: 'You read online that omega-3 supplements are great for a '
        'shiny coat, and you have human fish-oil capsules at home. What '
        'should you do?',
    options: [
      'Give your cat one of your fish-oil capsules right away',
      'Ask your veterinarian before giving any supplement not already in '
          'your cat\'s diet',
      'Give your cat a double dose since more is better',
      'Mix it into all of your cat\'s meals every day without asking '
          'anyone',
    ],
    correctIndex: 1,
    correctExplanation: 'Even a supplement that sounds harmless should be '
        'checked with your vet first — human products aren\'t dosed for '
        'cats, and unnecessary supplementation can cause harm.',
    incorrectExplanation: 'Giving human supplements without guidance — '
        'especially at a guessed or doubled dose — can do more harm than '
        'good. Always check with your veterinarian first.',
  ),
  ScenarioSection(
    scenario: 'Your senior cat\'s vet suggests a joint supplement made for '
        'cats as part of her care plan. What\'s the appropriate next step?',
    options: [
      'Buy any joint supplement, cat or human, and start immediately',
      'Follow the vet\'s specific product and dosing guidance for your cat',
      'Give a larger dose than recommended so it works faster',
      'Add several other supplements at the same time on your own',
    ],
    correctIndex: 1,
    correctExplanation: 'When a vet recommends a supplement for a specific '
        'reason, following their specific product and dosing guidance is '
        'the safe, appropriate way to use it.',
    incorrectExplanation: 'Substituting products, increasing the dose, or '
        'stacking extra supplements on your own goes beyond what was '
        'actually recommended and can cause harm.',
  ),
];

// ─── Health ─────────────────────────────────────────────────────────────────

const _health = <LessonSection>[
  InfoSection(
    title: '🩺 Preventive Care Matters Most',
    body: 'Routine veterinary visits let your vet track subtle changes in '
        'weight, teeth, coat, and behavior over time. Many conditions '
        'common in Persians have no early outward signs, which is why '
        'regular check-ups matter even when your cat seems fine. This '
        'lesson is educational — it doesn\'t diagnose your specific cat.',
  ),
  InfoSection(
    title: '💉 Vaccination Concepts',
    body: 'Core vaccinations protect against common, serious feline '
        'diseases, and your vet will recommend a schedule based on your '
        'cat\'s age, lifestyle, and local risk. Kittens typically need a '
        'series of doses, followed by boosters — the exact timing and '
        'which vaccines are appropriate is a conversation for your '
        'veterinarian, not something to self-schedule.',
  ),
  InfoSection(
    title: '🐛 Parasite Prevention',
    body: 'Fleas, ticks, and intestinal worms can affect indoor and '
        'outdoor cats alike. Regular, vet-recommended parasite prevention '
        'is generally easier and safer than treating an established '
        'infestation — ask your vet which products are appropriate and how '
        'often to use them for your cat.',
  ),
  InfoSection(
    title: '🦷 Dental Care',
    body: 'Dental disease is very common in adult cats and can affect '
        'overall health, not just the mouth. Signs to watch for include '
        'bad breath, drooling, reduced interest in dry food, or pawing at '
        'the mouth. Vet-approved tooth brushing and regular dental checks '
        'are the main ways to help protect your cat\'s teeth.',
  ),
  InfoSection(
    title: '⚖️ Weight Monitoring',
    body: 'Gradual weight change can be easy to miss day-to-day. Weighing '
        'your cat periodically (PersiPal\'s Growth Tracker can help with '
        'this) and asking your vet to assess body condition at check-ups '
        'makes it easier to catch a trend early, whether it\'s weight gain '
        'or unexplained weight loss.',
  ),
  InfoSection(
    title: '👁️ Eye & Tear-Area Concerns',
    body: 'Because of their facial structure, Persians can show more '
        'visible tearing than other breeds. Gentle daily cleaning helps '
        'manage staining, but redness, squinting, cloudiness, or thick '
        'discharge are different from routine tearing and should be '
        'checked by a vet.',
  ),
  InfoSection(
    title: '🐱 Persian-Specific: Breathing Considerations',
    body: 'Persian cats\' flat facial structure can affect breathing — '
        'noisy breathing, snoring, or wheezing is not just "a Persian '
        'thing" and should be checked by a vet, especially if it\'s new, '
        'worsening, or paired with reduced activity or open-mouth '
        'breathing.',
  ),
  InfoSection(
    title: '🐱 Persian-Specific: Kidney Screening',
    body: 'Persians are the breed most frequently associated with '
        'polycystic kidney disease (PKD), an inherited condition. It\'s '
        'best detected early through routine veterinary screening — this '
        'is general breed information, not a diagnosis for any individual '
        'cat.',
  ),
  InfoSection(
    title: '🧴 Coat & Skin Monitoring',
    body: 'Because grooming sessions involve close handling, they\'re also '
        'a good time to check the skin underneath the coat for lumps, '
        'redness, flaking, or unusual odor — changes that can be hidden '
        'under a long coat until you look.',
  ),
  InfoSection(
    title: '🚩 General Warning Signs',
    body: 'Contact your vet for: not eating for more than a day, '
        'repeated vomiting or diarrhea, noticeable weight change, '
        'increased thirst or urination, lethargy, labored breathing, '
        'limping, or straining in the litter box. These are signals to '
        'seek assessment, not something to diagnose at home.',
  ),
  TapRevealSection(
    prompt: 'Why do vets recommend regular check-ups even when my cat '
        'seems perfectly fine?',
    reveal: 'Many conditions common in Persians — like polycystic kidney '
        'disease or dental disease — often have no obvious early signs. '
        'Routine visits let your vet catch changes in weight, teeth, or '
        'organ function long before you\'d notice a problem at home.',
  ),
  TipSection(
    'Noisy breathing, snoring, or wheezing in a Persian is not just '
    'normal "flat-face" behavior — mention it to your vet.',
  ),
  TipSection(
    'Quick checklist: keep vaccines and parasite prevention on your vet\'s '
    'schedule, brush teeth if your vet has shown you how, track weight '
    'over time, and don\'t wait out warning signs like breathing changes '
    'or a sudden drop in appetite.',
  ),
  ScenarioSection(
    scenario: 'Your Persian cat has been drinking noticeably more water '
        'and seems less interested in food this week. What should you '
        'do?',
    options: [
      'Wait a few months to see if it goes away on its own',
      'Assume it\'s normal for the breed and do nothing',
      'Contact your veterinarian to have it checked',
      'Try to diagnose the cause yourself online',
    ],
    correctIndex: 2,
    correctExplanation: 'Increased thirst and reduced appetite can be '
        'early signs of several conditions, including kidney issues that '
        'are more common in Persians. A veterinary visit — not waiting or '
        'self-diagnosing — is the safe next step.',
    incorrectExplanation: 'These symptoms can have several possible '
        'causes and shouldn\'t be diagnosed at home or ignored — a '
        'veterinary assessment is the appropriate response.',
  ),
  ScenarioSection(
    scenario: 'You notice your cat has bad breath and seems to chew '
        'carefully on one side of her mouth. What\'s the appropriate '
        'response?',
    options: [
      'Assume it\'s normal and ignore it',
      'Try to brush her teeth aggressively right away to fix it',
      'Mention it to your veterinarian so her teeth can be checked',
      'Switch her to only soft food permanently without asking anyone',
    ],
    correctIndex: 2,
    correctExplanation: 'Bad breath and careful chewing can be signs of '
        'dental disease or discomfort — having a vet check her teeth is '
        'the appropriate next step rather than guessing at a fix.',
    incorrectExplanation: 'Ignoring it, brushing aggressively, or changing '
        'her diet on your own doesn\'t address a possible dental problem — '
        'a veterinary dental check is the right response.',
  ),
];

// ─── Environment ────────────────────────────────────────────────────────────

const _environment = <LessonSection>[
  InfoSection(
    title: '🏠 Setting Up a Cat-Friendly Home',
    body: 'Indoor cats rely entirely on their home environment for '
        'exercise, mental stimulation, and safety. Giving cats choice and '
        'control over their space — where to rest, hide, eat, and '
        'eliminate — helps reduce stress.',
  ),
  InfoSection(
    title: '🍽️ Food & Water Placement',
    body: 'Keep food and water away from the litter box and away from '
        'loud appliances or high-traffic areas. In multi-cat homes, '
        'spacing bowls out (rather than one shared station) reduces '
        'competition and lets every cat eat and drink comfortably.',
  ),
  InfoSection(
    title: '🚽 Litter-Box Environment',
    body: 'Provide one litter box per cat, plus one extra, in different '
        'quiet locations — not clustered together. Scoop at least daily, '
        'and place boxes somewhere your cat can enter and exit without '
        'feeling cornered.',
  ),
  InfoSection(
    title: '🪵 Scratching Areas',
    body: 'Offer sturdy, tall scratching posts near resting areas and '
        'entry points, since cats often like to stretch and scratch after '
        'waking up. A mix of vertical and horizontal scratchers covers '
        'different preferences.',
  ),
  InfoSection(
    title: '🛏️ Resting & Hiding Spaces',
    body: 'Cats appreciate having both open resting spots and enclosed, '
        'hideaway spaces (a covered bed, box, or quiet corner) they can '
        'retreat to when they want privacy — this is especially helpful '
        'during stressful moments like visitors or loud noises.',
  ),
  InfoSection(
    title: '🧶 Play & Enrichment',
    body: 'Rotate toys to keep them interesting, and use interactive play '
        '(wand toys, puzzle feeders) to give your cat a regular outlet for '
        'natural hunting behavior — this matters even more for a less '
        'active, indoor-only breed like the Persian.',
  ),
  InfoSection(
    title: '🌡️ Temperature & Ventilation',
    body: 'Persian cats can struggle to regulate body temperature because '
        'of their dense coat and facial structure. Keep the home '
        'comfortably cool and well-ventilated, especially in hot, humid '
        'weather, and make sure your cat has access to shade and fresh '
        'water at all times.',
  ),
  InfoSection(
    title: '⚠️ Household Hazards',
    body: 'Keep small objects (string, rubber bands, hair ties), open '
        'flames, hot stovetops, and unattended chemicals or medications '
        'out of reach. Secure blind/curtain cords, and check that windows '
        'and balconies are safely screened.',
  ),
  InfoSection(
    title: '🌿 Plants & Household Substances',
    body: 'Lilies are highly toxic to cats and should be kept out of the '
        'home entirely, including bouquets. Other common household hazards '
        'include certain essential oils, some houseplants, insecticides, '
        'and cleaning products — check with your vet or a pet poison '
        'resource before bringing a new plant or product into a home with '
        'cats.',
  ),
  InfoSection(
    title: '🧳 Carrier & Travel Preparation',
    body: 'Leave the carrier out as a normal, comfortable part of the '
        'home (with soft bedding, maybe treats) so it isn\'t only '
        'associated with stressful trips. Familiarizing your cat with the '
        'carrier ahead of time makes vet visits and travel noticeably '
        'less stressful for everyone.',
  ),
  InfoSection(
    title: '🐱 Persian-Specific Environmental Tips',
    body: 'A Persian\'s long coat picks up dust and debris easily, so a '
        'clean home environment supports coat care between groomings. Because '
        'of temperature sensitivity, avoid leaving a Persian in a hot car, '
        'a sunny unventilated room, or in direct sun with no shaded '
        'option.',
  ),
  TapRevealSection(
    prompt: 'Why does my multi-cat household need more than one litter '
        'box?',
    reveal: 'The general guideline is one litter box per cat, plus one '
        'extra, in different locations — this reduces competition and '
        'stress around using the box.',
  ),
  TipSection(
    'Persian cats can struggle to regulate body temperature — keep them '
    'cool and dry, especially in hot, humid weather.',
  ),
  TipSection(
    'Quick checklist: spaced-out food/water/litter, scratching posts near '
    'resting spots, a quiet hideaway option, regular play, a comfortable '
    'temperature, and hazards like lilies and loose cords kept out of '
    'reach.',
  ),
  ScenarioSection(
    scenario: 'You have two cats but only one litter box, and one cat has '
        'started avoiding it. What\'s the most likely helpful change?',
    options: [
      'Punish the cat for avoiding the box',
      'Add at least one more litter box in a different location',
      'Remove litter boxes entirely',
      'Assume nothing can be done',
    ],
    correctIndex: 1,
    correctExplanation: 'With multiple cats, the recommended guideline is '
        'one litter box per cat plus one extra in different locations — '
        'adding a box often resolves avoidance caused by competition or '
        'guarding.',
    incorrectExplanation: 'Punishing, removing boxes, or assuming nothing '
        'can help won\'t address the underlying cause — adding an '
        'appropriately placed extra box is the evidence-based fix.',
  ),
  ScenarioSection(
    scenario: 'A friend gives you a lily bouquet as a housewarming gift '
        'and you have a Persian cat at home. What should you do?',
    options: [
      'Display it somewhere your cat can\'t reach, like a high shelf',
      'Keep the flowers out of the home entirely',
      'Let your cat sniff it once, then put it out of reach',
      'Only worry if your cat actually chews on the petals',
    ],
    correctIndex: 1,
    correctExplanation: 'Lilies are highly toxic to cats, and even pollen '
        'or vase water can pose a risk — the safest choice is keeping them '
        'out of the home entirely rather than trying to keep them "out of '
        'reach."',
    incorrectExplanation: 'Lilies are dangerous enough that "out of reach" '
        'or "just don\'t let her chew it" isn\'t a safe enough precaution — '
        'they shouldn\'t be brought into a home with cats at all.',
  ),
];
