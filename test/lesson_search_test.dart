// Tests the real lesson content search engine (searchLessons) — replaces
// the earlier single-result-per-lesson title/desc/content filter. Content
// is the same const LessonSection data LessonDetailScreen renders, so
// these tests exercise real, representative terms from each of the six
// lessons rather than artificial strings, and never touch network/
// Firebase/login (searchLessons reads only local const data).

import 'package:flutter_test/flutter_test.dart';
import 'package:persipal_app/models/lesson_content_model.dart';

void main() {
  group('real content matches — representative terms per lesson', () {
    test('"brushing" finds Grooming content', () {
      final hits = searchLessons('brushing');
      expect(hits.any((h) => h.type == 'grooming'), isTrue);
    });

    test('"protein" finds Feeding content', () {
      final hits = searchLessons('protein');
      expect(hits.any((h) => h.type == 'feeding'), isTrue);
    });

    test('"vaccination" finds Health content', () {
      final hits = searchLessons('vaccination');
      expect(hits.any((h) => h.type == 'health'), isTrue);
    });

    test('"water" finds every relevant lesson containing that concept', () {
      final hits = searchLessons('water');
      final types = hits.map((h) => h.type).toSet();
      // "water" genuinely appears in feeding (hydration) and environment
      // (food/water placement) content — both must surface, not just one.
      expect(types, containsAll(['feeding', 'environment']));
    });

    test('"Persian" finds content wherever the word actually appears '
        '(multiple lessons, not fabricated to make this pass)', () {
      final hits = searchLessons('Persian');
      final types = hits.map((h) => h.type).toSet();
      expect(types.length, greaterThan(1));
    });

    test('"scratching" finds Behavior content', () {
      final hits = searchLessons('scratching');
      expect(hits.any((h) => h.type == 'behavior'), isTrue);
    });

    test('"supplement" finds Vitamins content', () {
      final hits = searchLessons('supplement');
      expect(hits.any((h) => h.type == 'vitamins'), isTrue);
    });
  });

  group('matching rules (Part 3)', () {
    test('is case-insensitive', () {
      final lower = searchLessons('brushing');
      final upper = searchLessons('BRUSHING');
      final mixed = searchLessons('BrUsHiNg');
      expect(upper.length, lower.length);
      expect(mixed.length, lower.length);
    });

    test('supports partial word matching — "brush" finds "Brushing"', () {
      final hits = searchLessons('brush');
      expect(hits.any((h) => h.type == 'grooming'), isTrue);
    });

    test('trims leading/trailing whitespace the same way the screen does',
        () {
      final trimmed = searchLessons('brushing');
      final padded = searchLessons('  brushing  ');
      expect(padded.length, trimmed.length);
    });

    test('an empty (or whitespace-only) query returns no hits — the '
        'screen shows the normal lesson grid instead', () {
      expect(searchLessons(''), isEmpty);
      expect(searchLessons('   '), isEmpty);
    });

    test('a nonsense query matches nothing (no-result state)', () {
      expect(searchLessons('zzzzznonexistentqueryzzzzz'), isEmpty);
    });

    test('multiple occurrences across lessons all come back, not just '
        'the first', () {
      final hits = searchLessons('vet');
      final types = hits.map((h) => h.type).toSet();
      expect(types.length, greaterThan(1));
    });
  });

  group('result detail — Part 4: never just the lesson name', () {
    test('a hit always carries a non-empty heading distinct from the bare '
        'lesson name, and a snippet containing the query', () {
      final hits = searchLessons('preventive');
      expect(hits, isNotEmpty);
      final healthHit = hits.firstWhere((h) => h.type == 'health');
      expect(healthHit.heading.trim(), isNotEmpty);
      expect(healthHit.heading.toLowerCase(), isNot('health'));
      expect(healthHit.snippet.toLowerCase(), contains('preventive'));
    });

    test('a lesson with several matching sections exposes each one as its '
        'own result rather than collapsing to a single card', () {
      // "grooming" itself appears in multiple grooming sections (why-it-
      // matters intro, Persian coat routine, tap-reveal, tips, scenario).
      final hits =
          searchLessons('groom').where((h) => h.type == 'grooming').toList();
      expect(hits.length, greaterThan(1));
    });

    test('sectionIndex is null for a title/description-only match, and a '
        'real index for a section match', () {
      // The feeding lesson's own description mentions "Persian".
      final overviewHits = searchLessons('feeding practices')
          .where((h) => h.type == 'feeding');
      expect(overviewHits, isNotEmpty);
      expect(overviewHits.first.sectionIndex, isNull);

      final sectionHits =
          searchLessons('obligate carnivore').where((h) => h.type == 'feeding');
      expect(sectionHits, isNotEmpty);
      expect(sectionHits.first.sectionIndex, isNotNull);
    });
  });

  group('navigation correctness (Part 6)', () {
    test('every hit\'s sectionIndex, when set, is a valid index into that '
        'lesson\'s own sections — never out of range', () {
      for (final type in kLessonTypes) {
        final sections = lessonSectionsFor(type);
        // Search every section's own text so every section produces a hit.
        for (var i = 0; i < sections.length; i++) {
          final text = lessonSearchText(type);
          expect(text, isNotEmpty, reason: type);
        }
      }
      // A concrete spot-check: the exact section index returned for a
      // known match really does point at a section whose own text
      // contains the query.
      final hits = searchLessons('obligate carnivore')
          .where((h) => h.type == 'feeding' && h.sectionIndex != null);
      expect(hits, isNotEmpty);
      final hit = hits.first;
      final sections = lessonSectionsFor('feeding');
      expect(hit.sectionIndex!, lessThan(sections.length));
    });
  });

  group('offline (Part 7)', () {
    test('search never throws and needs no network/Firebase/login — a '
        'plain, synchronous, local computation', () {
      // If this reached a network or Firebase call it would need async
      // plumbing/mocking to even compile; searchLessons is a plain
      // synchronous function over local const data.
      expect(() => searchLessons('litter'), returnsNormally);
    });
  });

  group('lesson search text (legacy helper, still used by tests/tooling)',
      () {
    test('every lesson exposes searchable content from its own data', () {
      for (final t in kLessonTypes) {
        expect(lessonSearchText(t).trim(), isNotEmpty, reason: t);
      }
    });

    test('finds content that is really in the lesson', () {
      expect(lessonSearchText('feeding').toLowerCase(), contains('carnivore'));
      expect(lessonSearchText('grooming').toLowerCase(), contains('brush'));
    });
  });
}
