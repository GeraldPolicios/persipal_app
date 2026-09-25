// lib/services/daily_advice_service.dart
//
// "Daily Cat Care Advice" for Home. The advice text is NOT in the app: it is
// downloaded from a small public JSON file (see [adviceUrl]) — no login, no
// API key, no Firebase. The last successful download is cached in Hive, so:
//   • online + new day  → fetch, cache, show today's item
//   • online + same day → show the cached item (no re-download)
//   • offline           → show the most recently cached download
//   • offline + no cache→ no advice (the card hides itself)

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'connectivity_service.dart';
import 'local_storage_service.dart';

class DailyAdvice {
  final String id;
  final String text;

  /// 'paraphrase' (our wording of the source) or 'quote' (verbatim).
  final String textType;
  final String attribution;
  final String sourceName;
  final String sourceUrl;

  const DailyAdvice({
    required this.id,
    required this.text,
    required this.textType,
    required this.attribution,
    required this.sourceName,
    required this.sourceUrl,
  });

  bool get isQuote => textType == 'quote';

  Map<String, dynamic> toMap() => {
        'id': id,
        'text': text,
        'textType': textType,
        'attribution': attribution,
        'sourceName': sourceName,
        'sourceUrl': sourceUrl,
      };

  /// Null unless the entry is complete: non-empty text (bounded so the card
  /// never has to truncate), a named source, and an https source link.
  static DailyAdvice? tryParse(Object? raw) {
    if (raw is! Map) return null;
    String? str(String key) {
      final v = raw[key];
      return v is String && v.trim().isNotEmpty ? v.trim() : null;
    }

    final id = str('id');
    final text = str('text');
    final attribution = str('attribution');
    final sourceName = str('sourceName');
    final sourceUrl = str('sourceUrl');
    if (id == null ||
        text == null ||
        attribution == null ||
        sourceName == null ||
        sourceUrl == null) {
      return null;
    }
    if (text.length > 600) return null;
    final uri = Uri.tryParse(sourceUrl);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
    final type = raw['textType'] == 'quote' ? 'quote' : 'paraphrase';
    return DailyAdvice(
      id: id,
      text: text,
      textType: type,
      attribution: attribution,
      sourceName: sourceName,
      sourceUrl: sourceUrl,
    );
  }
}

/// What the Home card shows: today's item plus, when it isn't from a fetch
/// made today, the date of the download it came from.
class DailyAdviceResult {
  final DailyAdvice advice;
  final DateTime? lastUpdated;
  const DailyAdviceResult(this.advice, {this.lastUpdated});
}

class DailyAdviceService {
  DailyAdviceService._();
  static final DailyAdviceService instance = DailyAdviceService._();

  /// Public, no-auth JSON hosted in the project's own GitHub repository.
  static const adviceUrl =
      'https://raw.githubusercontent.com/GeraldPolicios/persipal_app/main/data/daily_advice.json';

  static const _timeout = Duration(seconds: 8);
  static const _maxBytes = 256 * 1024;

  final _local = LocalStorageService.instance;

  // ── Pure helpers (unit-tested) ────────────────────────────────────────────

  /// Same index for the whole calendar day (local date), rotating daily.
  static int indexForDate(DateTime date, int length) {
    final days = DateTime.utc(date.year, date.month, date.day)
        .difference(DateTime.utc(1970))
        .inDays;
    return days % length;
  }

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Parses the feed, skipping malformed entries and duplicates. Empty list
  /// if the body isn't a valid feed.
  static List<DailyAdvice> parseFeed(String body) {
    try {
      final decoded = jsonDecode(body);
      final rawItems = decoded is Map ? decoded['items'] : null;
      if (rawItems is! List) return const [];
      final seenIds = <String>{};
      final seenText = <String>{};
      final items = <DailyAdvice>[];
      for (final raw in rawItems) {
        final item = DailyAdvice.tryParse(raw);
        if (item == null) continue;
        if (!seenIds.add(item.id) || !seenText.add(item.text)) continue;
        items.add(item);
      }
      return items;
    } catch (_) {
      return const [];
    }
  }

  // ── Loading ───────────────────────────────────────────────────────────────

  /// Today's advice, or null when there is nothing to show (never throws).
  Future<DailyAdviceResult?> load({DateTime? now}) async {
    final today = now ?? DateTime.now();
    final todayKey = dayKey(today);

    List<DailyAdvice> items = const [];
    String? fetchedOn;
    final cached = _readCache();
    if (cached != null) {
      items = cached.$2;
      fetchedOn = cached.$1;
    }

    if (fetchedOn != todayKey || items.isEmpty) {
      final fresh = await _download();
      if (fresh != null && fresh.isNotEmpty) {
        items = fresh;
        fetchedOn = todayKey;
        await _writeCache(todayKey, fresh);
      }
    }

    if (items.isEmpty) return null;
    final advice = items[indexForDate(today, items.length)];
    DateTime? lastUpdated;
    if (fetchedOn != todayKey && fetchedOn != null) {
      lastUpdated = DateTime.tryParse(fetchedOn);
    }
    return DailyAdviceResult(advice, lastUpdated: lastUpdated);
  }

  Future<List<DailyAdvice>?> _download() async {
    if (!ConnectivityService.instance.isOnline) return null;
    final client = HttpClient()..connectionTimeout = _timeout;
    try {
      final request = await client.getUrl(Uri.parse(adviceUrl)).timeout(_timeout);
      request.headers.set(HttpHeaders.userAgentHeader, 'PersiPal/1.0');
      final response = await request.close().timeout(_timeout);
      if (response.statusCode != 200) return null;
      final bytes = <int>[];
      await for (final chunk in response.timeout(_timeout)) {
        bytes.addAll(chunk);
        if (bytes.length > _maxBytes) return null;
      }
      return parseFeed(utf8.decode(bytes));
    } catch (e) {
      debugPrint('DailyAdviceService: download failed: $e');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  // ── Cache ─────────────────────────────────────────────────────────────────

  (String, List<DailyAdvice>)? _readCache() {
    try {
      final raw = _local.fetchDailyAdviceCache();
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final date = map['fetchedOn'];
      final items = (map['items'] as List)
          .map(DailyAdvice.tryParse)
          .whereType<DailyAdvice>()
          .toList();
      if (date is! String || items.isEmpty) return null;
      return (date, items);
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeCache(String date, List<DailyAdvice> items) async {
    try {
      await _local.saveDailyAdviceCache(jsonEncode({
        'fetchedOn': date,
        'items': items.map((i) => i.toMap()).toList(),
      }));
    } catch (e) {
      debugPrint('DailyAdviceService: cache write failed: $e');
    }
  }
}
