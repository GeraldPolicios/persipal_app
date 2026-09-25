// Tests splitForHighlight — the pure function HighlightedText renders from
// (see lib/widgets/highlighted_text.dart). Covers Part 5's exact,
// individually-required behaviors: case-insensitive matching, original
// capitalization preserved, multiple occurrences, and that the underlying
// text is never modified (every chunk is an exact substring).

import 'package:flutter_test/flutter_test.dart';
import 'package:persipal_app/widgets/highlighted_text.dart';

void main() {
  group('splitForHighlight', () {
    test('a single match produces [before, match, after] chunks', () {
      final chunks = splitForHighlight('Regular grooming helps a lot',
          'grooming');
      expect(chunks, [
        const TextChunk('Regular ', false),
        const TextChunk('grooming', true),
        const TextChunk(' helps a lot', false),
      ]);
    });

    test('is case-insensitive: "brush" matches inside "Brushing"', () {
      final chunks = splitForHighlight('Brushing helps distribute oils',
          'brush');
      expect(chunks.first, const TextChunk('Brush', true));
      // Original capitalization is preserved on the matched chunk itself —
      // the query was lowercase "brush" but the highlighted text keeps
      // the source's capital B.
      expect(chunks.first.text, 'Brush');
    });

    test('preserves original capitalization even for an all-caps query',
        () {
      final chunks = splitForHighlight('a Persian cat needs care', 'PERSIAN');
      final match = chunks.firstWhere((c) => c.isMatch);
      expect(match.text, 'Persian');
    });

    test('highlights every occurrence, not just the first', () {
      final chunks =
          splitForHighlight('cat cat cat', 'cat');
      final matches = chunks.where((c) => c.isMatch).toList();
      expect(matches.length, 3);
      expect(matches.every((c) => c.text == 'cat'), isTrue);
    });

    test('adjacent/overlapping-looking occurrences are each counted once, '
        'non-overlapping', () {
      // "aa" in "aaaa" — should find 2 non-overlapping matches, not 3
      // overlapping ones.
      final chunks = splitForHighlight('aaaa', 'aa');
      final matches = chunks.where((c) => c.isMatch).toList();
      expect(matches.length, 2);
    });

    test('never modifies the underlying text — concatenating every chunk '
        'reconstructs the original string exactly', () {
      const original = 'Persian cats need regular Persian-specific brushing.';
      final chunks = splitForHighlight(original, 'persian');
      final rebuilt = chunks.map((c) => c.text).join();
      expect(rebuilt, original);
    });

    test('a blank query returns the whole text as a single unmatched '
        'chunk', () {
      expect(splitForHighlight('some text', ''), [
        const TextChunk('some text', false),
      ]);
      expect(splitForHighlight('some text', '   '), [
        const TextChunk('some text', false),
      ]);
    });

    test('a query that never occurs returns the whole text unmatched', () {
      expect(splitForHighlight('some text', 'zzz'), [
        const TextChunk('some text', false),
      ]);
    });

    test('empty source text returns a single empty, unmatched chunk', () {
      expect(splitForHighlight('', 'anything'), [
        const TextChunk('', false),
      ]);
    });

    test('a match at the very start has no leading unmatched chunk', () {
      final chunks = splitForHighlight('grooming matters', 'grooming');
      expect(chunks.first, const TextChunk('grooming', true));
    });

    test('a match at the very end has no trailing unmatched chunk', () {
      final chunks = splitForHighlight('this is about grooming', 'grooming');
      expect(chunks.last, const TextChunk('grooming', true));
    });
  });
}
