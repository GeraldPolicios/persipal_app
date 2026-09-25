import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:persipal_app/services/daily_advice_service.dart';

void main() {
  group('DailyAdviceService.parseFeed', () {
    Map<String, dynamic> item(String id, String text, {String? url}) => {
          'id': id,
          'text': text,
          'textType': 'paraphrase',
          'attribution': 'Some Organization',
          'sourceName': 'Some Page',
          'sourceUrl': url ?? 'https://example.org/page',
        };

    test('the hosted data file parses and every item is valid', () {
      final body = File('data/daily_advice.json').readAsStringSync();
      final raw = (jsonDecode(body) as Map)['items'] as List;
      final parsed = DailyAdviceService.parseFeed(body);
      expect(parsed, isNotEmpty);
      expect(parsed.length, raw.length); // none skipped as malformed/duplicate
    });

    test('the hosted feed is Persian-cat-exclusive — every item mentions '
        'Persian(s), not just general cat care', () {
      final body = File('data/daily_advice.json').readAsStringSync();
      final parsed = DailyAdviceService.parseFeed(body);
      expect(parsed, isNotEmpty);
      for (final item in parsed) {
        expect(item.text.toLowerCase(), contains('persian'), reason: item.id);
      }
    });

    test('skips malformed entries, non-https links and duplicates', () {
      final body = jsonEncode({
        'items': [
          item('a', 'Good'),
          item('a', 'Same id'),
          item('b', 'Good'),
          item('c', 'Plain http link', url: 'http://example.org'),
          {'id': 'd', 'text': 'No source'},
          item('e', 'x' * 601),
          'not a map',
          item('f', 'Another good one'),
        ],
      });
      final ids = DailyAdviceService.parseFeed(body).map((a) => a.id).toList();
      expect(ids, ['a', 'f']);
    });

    test('empty, wrong-shaped or invalid bodies give an empty list', () {
      expect(DailyAdviceService.parseFeed('{"items": []}'), isEmpty);
      expect(DailyAdviceService.parseFeed('[]'), isEmpty);
      expect(DailyAdviceService.parseFeed('not json'), isEmpty);
    });
  });

  group('DailyAdviceService.indexForDate', () {
    test('is stable within a calendar day and advances the next day', () {
      final morning = DateTime(2026, 9, 20, 0, 5);
      final night = DateTime(2026, 9, 20, 23, 55);
      final next = DateTime(2026, 9, 21, 8);
      expect(DailyAdviceService.indexForDate(morning, 13),
          DailyAdviceService.indexForDate(night, 13));
      expect(DailyAdviceService.indexForDate(next, 13),
          (DailyAdviceService.indexForDate(morning, 13) + 1) % 13);
    });

    test('always within range', () {
      for (var d = 0; d < 400; d++) {
        final i = DailyAdviceService.indexForDate(
            DateTime(2026, 1, 1).add(Duration(days: d)), 7);
        expect(i, inInclusiveRange(0, 6));
      }
    });
  });
}
