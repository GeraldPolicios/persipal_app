// lib/models/lesson_reference_model.dart
//
// External source/reference links for the Learn Cat Care lessons
// (lesson_detail_screen.dart). Kept as structured data — never hardcoded
// directly into the lesson UI — so the References/Sources section can be
// driven by simple lookups instead of another switch statement.
//
// Every URL below was verified live before being added here (see the
// Lesson & Quiz Enhancement phase report) — no invented sources.

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
      title: 'People Foods to Avoid Feeding Your Pets',
      url:
          'https://www.aspca.org/pet-care/animal-poison-control/people-foods-avoid-feeding-your-pets',
      description: 'Human foods that are toxic or unsafe for cats and dogs.',
      publisher: 'ASPCA',
      type: 'Animal welfare organization',
    ),
    LessonReference(
      title: 'Feeding Your Cat',
      url:
          'https://www.vet.cornell.edu/departments-centers-and-institutes/cornell-feline-health-center/health-information/feline-health-topics/feeding-your-cat',
      description: 'Feline nutrition basics, food types, and diet guidance.',
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
  ],
  'behavior': [
    LessonReference(
      title: 'Common Cat Behavior Issues',
      url: 'https://www.aspca.org/pet-care/cat-care/common-cat-behavior-issues',
      description: 'Overview of common feline behavior patterns and issues.',
      publisher: 'ASPCA',
      type: 'Animal welfare organization',
    ),
  ],
  'vitamins': [
    LessonReference(
      title: 'Feeding Your Cat',
      url:
          'https://www.vet.cornell.edu/departments-centers-and-institutes/cornell-feline-health-center/health-information/feline-health-topics/feeding-your-cat',
      description:
          'Covers dietary considerations, including supplements, for cats.',
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
  ],
};
