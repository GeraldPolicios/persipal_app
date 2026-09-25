// lib/models/lesson_reference_model.dart
//
// External source/reference links for the Learn Cat Care lessons
// (lesson_detail_screen.dart). Kept as structured data — never hardcoded
// directly into the lesson UI — so the References/Sources section can be
// driven by simple lookups instead of another switch statement.
//
// Every URL below was fetched and read directly (via live web research)
// before being added/kept here, and the lesson content in
// lesson_detail_screen.dart was written FROM what these sources actually
// say — not the reverse. Sources used across the six lessons:
//   • Cornell Feline Health Center (veterinary school — feeding, obesity,
//     dental disease, polycystic kidney disease, feline health topics index)
//   • ASPCA (animal welfare organization — toxic foods, general cat care,
//     common behavior issues)
//   • International Cat Care / icatcare.org (UK feline-welfare charity
//     affiliated with the International Society of Feline Medicine —
//     grooming, Persian-specific brachycephaly, stress in cats)
//   • Ohio State University Indoor Pet Initiative (veterinary school
//     program — indoor cat environment/enrichment)
//   • Humane World for Animals, formerly The Humane Society of the United
//     States (animal welfare organization — brachycephalic/Persian-specific
//     practical care)

class LessonReference {
  final String title;
  final String url;
  final String? description;
  final String? publisher;
  final String? type;

  const LessonReference({
    required this.title,
    required this.url,
    this.description,
    this.publisher,
    this.type,
  });
}

/// Keyed by the same lesson `type` string LearnScreen/LessonDetailScreen
/// already use ('feeding' | 'grooming' | 'behavior' | 'vitamins' | 'health'
/// | 'environment'). A missing key or empty list means "no references for
/// this lesson yet" — LessonDetailScreen treats that as normal and simply
/// omits the section.
const kLessonReferences = <String, List<LessonReference>>{
  'feeding': [
    LessonReference(
      title: 'Feeding Your Cat',
      url:
          'https://www.vet.cornell.edu/departments-centers-and-institutes/cornell-feline-health-center/health-information/feline-health-topics/feeding-your-cat',
      description:
          'Feline nutrition basics, hydration, feeding practices, life-stage needs, and supplement safety.',
      publisher: 'Cornell Feline Health Center',
      type: 'Veterinary school',
    ),
    LessonReference(
      title: 'People Foods to Avoid Feeding Your Pets',
      url:
          'https://www.aspca.org/pet-care/animal-poison-control/people-foods-avoid-feeding-your-pets',
      description: 'Human foods that are toxic or unsafe for cats and dogs.',
      publisher: 'ASPCA',
      type: 'Animal welfare organization',
    ),
    LessonReference(
      title: 'Obesity',
      url:
          'https://www.vet.cornell.edu/departments-centers-and-institutes/cornell-feline-health-center/health-information/feline-health-topics/obesity',
      description:
          'Causes, health risks, and management of feline obesity, including free-feeding and portion guidance.',
      publisher: 'Cornell Feline Health Center',
      type: 'Veterinary school',
    ),
  ],
  'grooming': [
    LessonReference(
      title: 'General Cat Care',
      url: 'https://www.aspca.org/pet-care/cat-care/general-cat-care',
      description:
          'Includes brushing, coat care, and nail-trimming guidance for cats.',
      publisher: 'ASPCA',
      type: 'Animal welfare organization',
    ),
    LessonReference(
      title: 'Grooming Your Cat',
      url: 'https://icatcare.org/articles/grooming-your-cat',
      description:
          'Brushing frequency for long- vs short-haired cats, mat handling, and signs your cat is uncomfortable during grooming.',
      publisher: 'International Cat Care',
      type: 'Feline welfare organization',
    ),
    LessonReference(
      title: 'Persian Cats and Brachycephaly',
      url: 'https://icatcare.org/articles/persian-cats-and-brachycephaly',
      description:
          'Persian-specific facial structure issues affecting the eyes, skin folds, and dental alignment, with care implications.',
      publisher: 'International Cat Care',
      type: 'Feline welfare organization',
    ),
  ],
  'behavior': [
    LessonReference(
      title: 'Common Cat Behavior Issues',
      url: 'https://www.aspca.org/pet-care/cat-care/common-cat-behavior-issues',
      description:
          'Overview of common feline behavior patterns, including scratching, litter box issues, and aging-related changes.',
      publisher: 'ASPCA',
      type: 'Animal welfare organization',
    ),
    LessonReference(
      title: 'Stress in Cats',
      url: 'https://icatcare.org/articles/stress-in-cats',
      description:
          'Signs of acute and chronic stress in cats and practical ways owners can reduce it, including resource placement.',
      publisher: 'International Cat Care',
      type: 'Feline welfare organization',
    ),
  ],
  'vitamins': [
    LessonReference(
      title: 'Feeding Your Cat',
      url:
          'https://www.vet.cornell.edu/departments-centers-and-institutes/cornell-feline-health-center/health-information/feline-health-topics/feeding-your-cat',
      description:
          'States plainly that supplements can be harmful and should never be given without veterinary approval.',
      publisher: 'Cornell Feline Health Center',
      type: 'Veterinary school',
    ),
  ],
  'health': [
    LessonReference(
      title: 'Feline Health Topics',
      url:
          'https://www.vet.cornell.edu/departments-centers-and-institutes/cornell-feline-health-center/health-information/feline-health-topics',
      description: 'Index of common feline health conditions and topics.',
      publisher: 'Cornell Feline Health Center',
      type: 'Veterinary school',
    ),
    LessonReference(
      title: 'Polycystic Kidney Disease',
      url:
          'https://www.vet.cornell.edu/departments-centers-and-institutes/cornell-feline-health-center/health-information/feline-health-topics/polycystic-kidney-disease',
      description:
          'PKD occurs most frequently in Persian cats — inheritance, signs, diagnosis, and management.',
      publisher: 'Cornell Feline Health Center',
      type: 'Veterinary school',
    ),
    LessonReference(
      title: 'Feline Dental Disease',
      url:
          'https://www.vet.cornell.edu/departments-centers-and-institutes/cornell-feline-health-center/health-information/feline-health-topics/feline-dental-disease',
      description:
          'Prevalence, signs, and prevention of dental disease in cats, including at-home brushing guidance.',
      publisher: 'Cornell Feline Health Center',
      type: 'Veterinary school',
    ),
    LessonReference(
      title: 'Persian Cats and Brachycephaly',
      url: 'https://icatcare.org/articles/persian-cats-and-brachycephaly',
      description:
          'Persian-specific breathing (BOAS), eye, skin-fold, and dental crowding health considerations.',
      publisher: 'International Cat Care',
      type: 'Feline welfare organization',
    ),
    LessonReference(
      title: 'Brachycephalic Cat Care',
      url: 'https://www.humaneworld.org/en/resources/brachycephalic-cat-care',
      description:
          'Practical care guidance for flat-faced cats: heat sensitivity, activity tolerance, and warning signs like noisy breathing.',
      publisher: 'Humane World for Animals',
      type: 'Animal welfare organization',
    ),
  ],
  'environment': [
    LessonReference(
      title: 'Indoor Pet Initiative — Cats',
      url: 'https://indoorpet.osu.edu/cats',
      description:
          'Guidance on enriching and safely setting up an indoor environment for cats.',
      publisher: 'Ohio State University Indoor Pet Initiative',
      type: 'Veterinary school program',
    ),
    LessonReference(
      title: 'Basic Indoor Cat Needs',
      url: 'https://indoorpet.osu.edu/cats/basicneeds',
      description:
          'Litter box, resting area, scratching, and perching recommendations for indoor cats.',
      publisher: 'Ohio State University Indoor Pet Initiative',
      type: 'Veterinary school program',
    ),
    LessonReference(
      title: 'Stress in Cats',
      url: 'https://icatcare.org/articles/stress-in-cats',
      description:
          'Resource placement (litter boxes, food/water, resting spots) to reduce stress in the home.',
      publisher: 'International Cat Care',
      type: 'Feline welfare organization',
    ),
    LessonReference(
      title: 'Brachycephalic Cat Care',
      url: 'https://www.humaneworld.org/en/resources/brachycephalic-cat-care',
      description:
          'Temperature and activity considerations relevant to a Persian cat\'s home environment.',
      publisher: 'Humane World for Animals',
      type: 'Animal welfare organization',
    ),
  ],
};
