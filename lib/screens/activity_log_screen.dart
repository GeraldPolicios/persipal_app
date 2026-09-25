// screens/activity_log_screen.dart
import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/activity_log_service.dart';
import '../widgets/date_filter_control.dart';

class ActivityLogScreen extends StatefulWidget {
  const ActivityLogScreen({super.key});

  @override
  State<ActivityLogScreen> createState() => _ActivityLogScreenState();
}

class _ActivityLogScreenState extends State<ActivityLogScreen> {
  final _service = ActivityLogService.instance;

  static const _accentColor = Color(0xFFFF8C69);

  DateFilterSelection _filter = const DateFilterSelection.allDates();

  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _showTrends = false;

  @override
  void initState() {
    super.initState();
    _service.addListener(_refresh);
  }

  @override
  void dispose() {
    _service.removeListener(_refresh);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  /// The full, unfiltered, permanently-retained history.
  List<ActivityLogModel> get _activities => _service.logs;

  /// Only the entries whose timestamp falls in the active period —
  /// display-only, never mutates `_activities`/persisted history. The end
  /// boundary from [dateRangeForSelection] is already end-of-day inclusive
  /// for a custom range, so a record any time on the selected end date is
  /// included.
  List<ActivityLogModel> get _filteredActivities {
    final range = dateRangeForSelection(_filter);
    if (range == null) return _activities;
    final (start, end) = range;
    return _activities
        .where((a) => !a.timestamp.isBefore(start) && a.timestamp.isBefore(end))
        .toList();
  }

  static const _typeLabels = {
    ActionType.feed: 'Feeding',
    ActionType.groom: 'Grooming',
    ActionType.play: 'Playing',
    ActionType.lesson: 'Lessons',
    ActionType.quiz: 'Quizzes',
    ActionType.reminder: 'Reminders',
    ActionType.profile: 'Profiles',
    ActionType.vaccination: 'Vaccinations',
    ActionType.login: 'Account',
    ActionType.sync: 'Sync',
    ActionType.other: 'Other',
  };

  /// Case-insensitive text search over the fields an entry shows or carries:
  /// description, pet name, action type, and any stat changes. Display-only
  /// — like the date filter it never touches stored history.
  bool _matchesQuery(ActivityLogModel a, String q) {
    if (q.isEmpty) return true;
    final stats =
        a.statChanges.entries.map((e) => '${e.key} ${e.value}').join(' ');
    final haystack = [
      a.description,
      a.petName,
      a.actionType.name,
      _typeLabels[a.actionType] ?? '',
      stats,
    ].join(' ').toLowerCase();
    return haystack.contains(q);
  }

  /// Date filter first, then text search — the two combine.
  List<ActivityLogModel> get _visibleActivities {
    final q = _query.trim().toLowerCase();
    final dated = _filteredActivities;
    if (q.isEmpty) return dated;
    return dated.where((a) => _matchesQuery(a, q)).toList();
  }

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
                    ],
                  ),
                ),

                // ── Filter by Date ───────────────────────────────────────────
                // Display-only: never deletes, modifies, or archives any
                // record — see _filteredActivities/dateRangeForSelection.
                if (_activities.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DateFilterButton(
                      selection: _filter,
                      accentColor: _accentColor,
                      onTap: () async {
                        final picked = await showDateFilterSheet(
                          context,
                          current: _filter,
                          accentColor: _accentColor,
                        );
                        if (picked != null && mounted) {
                          setState(() => _filter = picked);
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Search + trends toggle ───────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            onChanged: (v) => setState(() => _query = v),
                            textInputAction: TextInputAction.search,
                            style: const TextStyle(fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search activity',
                              hintStyle: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: _query.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear search',
                                      icon: const Icon(Icons.close, size: 18),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() => _query = '');
                                      },
                                    ),
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white.withValues(alpha: 0.82),
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: _showTrends ? 'Hide trends' : 'Show trends',
                          isSelected: _showTrends,
                          icon: const Icon(Icons.insights, size: 20),
                          onPressed: () =>
                              setState(() => _showTrends = !_showTrends),
                        ),
                      ],
                    ),
                  ),
                  if (_showTrends)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: _buildTrends(),
                    ),
                  const SizedBox(height: 4),
                ],

                // ── Count ───────────────────────────────────────────────────
                if (_activities.isNotEmpty)
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    child: Text(
                      _filter.kind == DateFilterKind.allDates &&
                              _query.trim().isEmpty
                          ? '${_activities.length} ${_activities.length == 1 ? 'activity' : 'activities'} recorded'
                          : '${_visibleActivities.length} of ${_activities.length} activities'
                              '${_filter.kind == DateFilterKind.allDates ? '' : ' • ${dateFilterLabel(_filter)}'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFAA7755),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                // ── List ────────────────────────────────────────────────────
                Expanded(
                  child: Builder(builder: (_) {
                    final shown = _visibleActivities;

                    if (_activities.isEmpty) return _buildEmptyState();

                    if (shown.isEmpty) {
                      return _buildEmptyState(
                          filtered: true, searching: _query.trim().isNotEmpty);
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: shown.length,
                      itemBuilder: (_, i) {
                        final entry = shown[i];
                        final showDivider = i == 0 ||
                            _isDifferentDay(
                                shown[i - 1].timestamp, entry.timestamp);
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showDivider) _buildDayDivider(entry.timestamp),
                            _buildTile(entry),
                            const SizedBox(height: 8),
                          ],
                        );
                      },
                    );
                  }),
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
              color: const Color(0xFFFF8C69).withValues(alpha: 0.18),
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
                color: const Color(0xFFFF8C69).withValues(alpha: 0.3),
                thickness: 1),
          ),
        ],
      ),
    );
  }

  Widget _buildTile(ActivityLogModel entry) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
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
              color: entry.iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(entry.icon, size: 22, color: entry.iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.description,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 3),
                Text(_fullDate(entry.timestamp),
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Flexible (not a bare fixed-size Container): _timeAgo() falls
          // back to a full date+time string for entries older than a week,
          // which combined with a long description could otherwise force
          // a RenderFlex overflow on narrow screens — this lets the chip
          // shrink and ellipsize instead.
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE6CC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _timeAgo(entry.timestamp),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFFAA7755),
                    fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Simple, honest summary derived from the existing history (already
  /// date-filtered) — counts only, no stored trend data, no health claims.
  Widget _buildTrends() {
    final data = _filteredActivities; // newest first
    const minEntries = 3;

    Widget shell(Widget child) => Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(16),
          ),
          child: child,
        );

    if (data.length < minEntries) {
      return shell(const Text(
        'Not enough activity in this period to show trends yet. '
        'They will appear as you use PersiPal.',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      ));
    }

    // Count by type.
    final byType = <ActionType, int>{};
    for (final a in data) {
      byType[a.actionType] = (byType[a.actionType] ?? 0) + 1;
    }
    final types = byType.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxType = types.first.value;

    // Last 7 days, ending at the most recent activity in this period.
    final end = DateTime(data.first.timestamp.year, data.first.timestamp.month,
        data.first.timestamp.day);
    final days = [for (var i = 6; i >= 0; i--) end.subtract(Duration(days: i))];
    final perDay = {for (final d in days) d: 0};
    for (final a in data) {
      final d = DateTime(a.timestamp.year, a.timestamp.month, a.timestamp.day);
      if (perDay.containsKey(d)) perDay[d] = perDay[d]! + 1;
    }
    final maxDay = perDay.values.fold(1, (m, v) => v > m ? v : m);
    const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return shell(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${data.length} activities • ${dateFilterLabel(_filter)}',
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF4A2C1A))),
        const SizedBox(height: 10),
        const Text('BY TYPE',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: Color(0xFFAA7755))),
        const SizedBox(height: 6),
        for (final t in types.take(6))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 86,
                  child: Text(_typeLabels[t.key] ?? 'Other',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11)),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: t.value / maxType,
                      minHeight: 8,
                      backgroundColor: _accentColor.withValues(alpha: 0.15),
                      valueColor: const AlwaysStoppedAnimation(_accentColor),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${t.value}',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        const SizedBox(height: 10),
        Text(
            'LAST 7 DAYS (UP TO ${_fullDate(end).split('  ').first.toUpperCase()})',
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: Color(0xFFAA7755))),
        const SizedBox(height: 8),
        SizedBox(
          height: 70,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final d in days)
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text('${perDay[d]}',
                          style: const TextStyle(
                              fontSize: 9, color: Color(0xFFAA7755))),
                      const SizedBox(height: 2),
                      Container(
                        height: 4 + 36.0 * (perDay[d]! / maxDay),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: perDay[d] == 0
                              ? _accentColor.withValues(alpha: 0.2)
                              : _accentColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(weekdays[d.weekday - 1],
                          style:
                              const TextStyle(fontSize: 9, color: Colors.grey)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    ));
  }

  Widget _buildEmptyState({bool filtered = false, bool searching = false}) {
    // `filtered` distinguishes "no history has ever been recorded" from
    // "history exists, but nothing falls in the selected date range" — the
    // underlying records are never affected either way.
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: 0.35,
            child: Icon(
              filtered ? Icons.filter_alt_off : Icons.history,
              size: 80,
              color: const Color(0xFFFF8C69),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            searching
                ? 'No activities match your search.'
                : filtered
                    ? 'No activity found for this date range.'
                    : 'No activities yet!',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFAA7755)),
          ),
          const SizedBox(height: 8),
          Text(
            filtered
                ? 'Your full history is still saved — try a different search or filter.'
                : 'Your cat care activities will\nappear here as you use the app.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
