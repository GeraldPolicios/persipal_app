// lib/widgets/daily_advice_card.dart
//
// Compact "Daily Cat Care Advice" card for Home. Content comes from
// DailyAdviceService (online JSON + local cache); nothing is hardcoded here.
// While loading it shows a small placeholder; with nothing to show (offline
// and never cached, or a bad/empty feed) it hides itself entirely.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/daily_advice_service.dart';
import '../themes/app_theme.dart';

class DailyAdviceCard extends StatefulWidget {
  const DailyAdviceCard({super.key});

  @override
  State<DailyAdviceCard> createState() => _DailyAdviceCardState();
}

class _DailyAdviceCardState extends State<DailyAdviceCard> {
  // Loaded once per screen instance so Home rebuilds never re-select or
  // re-download.
  late final Future<DailyAdviceResult?> _future =
      DailyAdviceService.instance.load();

  Future<void> _openSource(String url) async {
    final uri = Uri.tryParse(url);
    var opened = false;
    if (uri != null) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {}
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Couldn't open the source link."),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DailyAdviceResult?>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _shell(
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daily Advice',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.softBrown)),
                SizedBox(height: 4),
                Text('Loading today\'s advice...',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          );
        }
        final result = snap.data;
        if (result == null) return const SizedBox.shrink();
        return _content(result);
      },
    );
  }

  Widget _content(DailyAdviceResult result) {
    final a = result.advice;
    final text = a.isQuote ? '“${a.text}”' : a.text;
    final sourceLabel = a.isQuote
        ? '${a.attribution} — ${a.sourceName}'
        : 'Summarized from ${a.sourceName} — ${a.attribution}';

    return _shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Daily Advice',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.softBrown)),
          const SizedBox(height: 5),
          Text(text,
              style: const TextStyle(
                  fontSize: 13, height: 1.35, color: AppTheme.darkText)),
          const SizedBox(height: 6),
          InkWell(
            onTap: () => _openSource(a.sourceUrl),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Text(sourceLabel,
                  style: TextStyle(
                      fontSize: 10.5,
                      height: 1.25,
                      color: AppTheme.softBrown.withValues(alpha: 0.8),
                      decoration: TextDecoration.underline,
                      decorationColor:
                          AppTheme.softBrown.withValues(alpha: 0.45))),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            result.lastUpdated != null
                ? 'General information, not veterinary advice. '
                    'Last updated ${DateFormat('MMM d').format(result.lastUpdated!)}.'
                : 'General information, not veterinary advice.',
            style: const TextStyle(
              fontSize: 9,
              height: 1.25,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _shell({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.salmon.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border:
              Border.all(color: AppTheme.salmon.withValues(alpha: 0.2)),
        ),
        child: child,
      );
}
