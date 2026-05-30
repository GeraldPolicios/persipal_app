// screens/activity_log_screen.dart
import 'package:flutter/material.dart';
import '../services/activity_service.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  final _service = ActivityService.instance;

  @override
  void initState() {
    super.initState();
    _service.addListener(_refresh);
  }

  @override
  void dispose() {
    _service.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  List<ActivityEntry> get _activities => _service.log;

  // ─── Helpers ─────────────────────────────────────────────────────────────

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return _fullDate(dt);
  }

  String _fullDate(DateTime dt) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${months[dt.month]} ${dt.day}, ${dt.year}  $h:$m';
  }

  bool _isDifferentDay(DateTime a, DateTime b) =>
      a.year != b.year || a.month != b.month || a.day != b.day;

  String _dayLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[dt.month]} ${dt.day}, ${dt.year}';
  }

  void _confirmClearAll() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFFFF5EE),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Clear History?',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'All activity logs will be permanently cleared. This cannot be undone.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              _service.clearLog();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Activity history cleared.'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            },
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 22),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Icon(Icons.history, size: 26),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Activity Log',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (_activities.isNotEmpty)
                        TextButton.icon(
                          onPressed: _confirmClearAll,
                          icon: const Icon(Icons.delete_outline,
                              size: 18, color: Colors.redAccent),
                          label: const Text('Clear',
                              style: TextStyle(
                                  color: Colors.redAccent, fontSize: 13)),
                        ),
                    ],
                  ),
                ),

                // ── Count ───────────────────────────────────────────────────
                if (_activities.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    child: Text(
                      '${_activities.length} ${_activities.length == 1 ? 'activity' : 'activities'} recorded',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFAA7755),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                // ── List ────────────────────────────────────────────────────
                Expanded(
                  child: _activities.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _activities.length,
                          itemBuilder: (_, i) {
                            final entry = _activities[i];
                            final showDivider = i == 0 ||
                                _isDifferentDay(_activities[i - 1].timestamp,
                                    entry.timestamp);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (showDivider)
                                  _buildDayDivider(entry.timestamp),
                                _buildTile(entry),
                                const SizedBox(height: 8),
                              ],
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayDivider(DateTime dt) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFF8C69).withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _dayLabel(dt),
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFAA5533)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
                color: const Color(0xFFFF8C69).withOpacity(0.3), thickness: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(ActivityEntry entry) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: entry.iconColor.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(entry.icon, size: 22, color: entry.iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.title,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(_fullDate(entry.timestamp),
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE6CC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _timeAgo(entry.timestamp),
              style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFFAA7755),
                  fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: 0.35,
            child:
                const Icon(Icons.history, size: 80, color: Color(0xFFFF8C69)),
          ),
          const SizedBox(height: 16),
          const Text(
            'No activities yet!',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFAA7755)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your cat care activities will\nappear here as you use the app.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
