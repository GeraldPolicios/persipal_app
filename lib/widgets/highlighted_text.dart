// lib/widgets/highlighted_text.dart
//
// Reusable "highlight the search term" rendering for lesson search results
// and the lesson detail screen. Built on plain TextSpans/Text.rich (no
// literal markup ever inserted into displayed text) so every matching
// occurrence — case-insensitive — is visually distinguished while the
// underlying text is never modified or re-cased.

import 'package:flutter/material.dart';
import '../themes/app_theme.dart';

/// One piece of text for [HighlightedText] — either plain or a matched
/// occurrence of the active search query.
class TextChunk {
  final String text;
  final bool isMatch;
  const TextChunk(this.text, this.isMatch);

  @override
  bool operator ==(Object other) =>
      other is TextChunk && other.text == text && other.isMatch == isMatch;
  @override
  int get hashCode => Object.hash(text, isMatch);
  @override
  String toString() => 'TextChunk($text, isMatch: $isMatch)';
}

/// Splits [text] into a sequence of chunks marking every case-insensitive,
/// non-overlapping occurrence of [query]. Pure and independent of any
/// widget, so it's directly unit-testable — see
/// test/highlighted_text_test.dart. Never alters [text]: every chunk's
/// [TextChunk.text] is an exact substring of the original, so original
/// capitalization is always preserved even when [query] doesn't match it
/// (e.g. query "brush" against text "Brushing" highlights "Brush", not
/// "brush"). A blank query, or a query that never occurs, returns the
/// whole text as one unmatched chunk.
List<TextChunk> splitForHighlight(String text, String query) {
  final q = query.trim();
  if (q.isEmpty || text.isEmpty) return [TextChunk(text, false)];

  final lowerText = text.toLowerCase();
  final lowerQuery = q.toLowerCase();
  final chunks = <TextChunk>[];
  var pos = 0;
  while (true) {
    final idx = lowerText.indexOf(lowerQuery, pos);
    if (idx == -1) {
      if (pos < text.length) chunks.add(TextChunk(text.substring(pos), false));
      break;
    }
    if (idx > pos) chunks.add(TextChunk(text.substring(pos, idx), false));
    chunks.add(TextChunk(text.substring(idx, idx + q.length), true));
    pos = idx + q.length;
  }
  if (chunks.isEmpty) chunks.add(TextChunk(text, false));
  return chunks;
}

/// Renders [text] as rich text, visually highlighting every
/// case-insensitive occurrence of [query] (see [splitForHighlight]).
/// Falls back to an ordinary-looking [Text] when [query] is blank or
/// doesn't occur, so this is always safe to use in place of a plain [Text]
/// — including outside of an active search (an empty query renders
/// identically to a plain Text.rich of the whole string).
///
/// The default highlight style pulls from [AppTheme] (gold background,
/// dark brown bold text) rather than a hard-coded color, matching the
/// app's existing palette instead of introducing a new one.
class HighlightedText extends StatelessWidget {
  final String text;
  final String query;
  final TextStyle? style;
  final TextStyle? highlightStyle;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;

  const HighlightedText({
    super.key,
    required this.text,
    required this.query,
    this.style,
    this.highlightStyle,
    this.maxLines,
    this.overflow,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = DefaultTextStyle.of(context).style.merge(style);
    final matchStyle = highlightStyle ??
        baseStyle.copyWith(
          fontWeight: FontWeight.w800,
          color: AppTheme.darkBrown,
          backgroundColor: AppTheme.gold.withValues(alpha: 0.42),
        );

    final chunks = splitForHighlight(text, query);
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          for (final c in chunks)
            TextSpan(text: c.text, style: c.isMatch ? matchStyle : null),
        ],
      ),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      textAlign: textAlign,
    );
  }
}
