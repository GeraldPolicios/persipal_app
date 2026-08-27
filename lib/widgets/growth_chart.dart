// lib/widgets/growth_chart.dart
//
// Shared growth chart — a 12-month (January–December) bar chart for a
// single, user-navigable year. One bar per month showing that month's
// actual recorded weight; months with no recorded entry show no bar
// (never a fabricated 0 kg reading). Shared by growth_tracker_screen.dart
// and the Pet Health Dashboard so both reuse this exact implementation —
// there is no separate chart elsewhere.
//
// When the caller supplies a `statusForEntry` callback, bars are colored
// by that month's weight status (underweight / normal / overweight /
// obese) instead of a flat color — so the chart doubles as a mini
// growth/health-status view. Without that callback the chart falls back
// to a single flat color, so existing callers keep working unchanged.
// Exact values are read off the Y-axis gridlines rather than a per-bar
// label, keeping each bar clean.
//
// Reads only GrowthEntry.weightKg / recordedAt — never writes, never
// interpolates or estimates a missing month.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/pet_extended_models.dart';
import '../utils/cat_weight_status.dart';

const _kMonthLabels = [
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
  'Dec',
];

const Color _kDefaultBarColor = Color(0xFF20B2AA);

/// Same status → color mapping used by the weight-status card
/// (growth_tracker_screen.dart's `_statusColor`). Kept here too so the
/// chart can color its bars without depending on that screen's private
/// method. If cat_weight_status.dart later grows a canonical color
/// helper, both call sites should switch to it instead of duplicating
/// this mapping.
Color _statusColor(CatWeightStatus status) {
  switch (status) {
    case CatWeightStatus.underweight:
      return Colors.orange;
    case CatWeightStatus.normal:
      return _kDefaultBarColor;
    case CatWeightStatus.overweight:
      return Colors.deepOrange;
    case CatWeightStatus.obese:
      return Colors.redAccent;
    case CatWeightStatus.notClassified:
    case CatWeightStatus.unknownAgeNeeded:
    case CatWeightStatus.unrecognizedGender:
      return Colors.grey;
  }
}

class GrowthChart extends StatefulWidget {
  final List<GrowthEntry> entries;

  /// Optional per-entry status classifier, supplied by the caller (which
  /// holds the pet's birth date/gender needed by `classifyCatWeight`).
  /// When omitted, every bar uses the flat default color.
  final CatWeightStatus Function(GrowthEntry entry)? statusForEntry;

  const GrowthChart({super.key, required this.entries, this.statusForEntry});

  @override
  State<GrowthChart> createState() => _GrowthChartState();
}

class _GrowthChartState extends State<GrowthChart> {
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedYear = _defaultYear();
  }

  @override
  void didUpdateWidget(covariant GrowthChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-anchor the selected year only when the previous selection no
    // longer makes sense for the new data (e.g. first entry just added,
    // or the year range shrank) — otherwise leave the user's navigation
    // alone while they're browsing.
    if (oldWidget.entries.isEmpty && widget.entries.isNotEmpty) {
      _selectedYear = _defaultYear();
    } else if (_selectedYear < _minYear || _selectedYear > _maxYear) {
      _selectedYear = _defaultYear();
    }
  }

  int _defaultYear() {
    if (widget.entries.isEmpty) return DateTime.now().year;
    var latest = widget.entries.first;
    for (final e in widget.entries) {
      if (e.recordedAt.isAfter(latest.recordedAt)) latest = e;
    }
    return latest.recordedAt.year;
  }

  // Bounds intentionally reach a bit past the actual data range (rather
  // than stopping exactly at it) so a user can navigate to a genuinely
  // empty year and see the "No growth records for <year>" state — that's
  // an explicitly required, reachable state, not just a fallback.
  int get _minYear {
    final base = DateTime.now().year - 30;
    if (widget.entries.isEmpty) return base;
    final dataMin = widget.entries
        .map((e) => e.recordedAt.year)
        .reduce((a, b) => a < b ? a : b);
    return dataMin < base ? dataMin : base;
  }

  int get _maxYear {
    // Growth entries can't be dated in the future (the entry editor caps
    // the date picker at "today"), so there's never a real year to reach
    // past the current one.
    final now = DateTime.now().year;
    if (widget.entries.isEmpty) return now;
    final dataMax = widget.entries
        .map((e) => e.recordedAt.year)
        .reduce((a, b) => a > b ? a : b);
    return dataMax > now ? dataMax : now;
  }

  /// One slot per calendar month (index 0 = January). When a month has
  /// more than one recorded entry, the latest-recorded one is used —
  /// never averaged/invented — so exactly one bar represents that month.
  List<GrowthEntry?> _monthlyEntriesForSelectedYear() {
    final months = List<GrowthEntry?>.filled(12, null);
    for (final e in widget.entries) {
      if (e.recordedAt.year != _selectedYear) continue;
      final i = e.recordedAt.month - 1;
      final current = months[i];
      if (current == null || e.recordedAt.isAfter(current.recordedAt)) {
        months[i] = e;
      }
    }
    return months;
  }

  @override
  Widget build(BuildContext context) {
    final months = _monthlyEntriesForSelectedYear();
    final yearWeights =
        months.whereType<GrowthEntry>().map((e) => e.weightKg).toList();
    final hasDataThisYear = yearWeights.isNotEmpty;
    final maxW =
        hasDataThisYear ? yearWeights.reduce((a, b) => a > b ? a : b) : 0.0;

    // A real 0-based axis: ticks run 0..axisMax in whole-kg steps sized so
    // there are roughly 4-6 gridlines regardless of how big the weights
    // are. axisMax is always >= the year's actual max weight, so bar
    // height is a true fraction of a labeled scale, not an arbitrary pad.
    final ticks = _axisTicks(maxW);
    final axisMax = hasDataThisYear ? ticks.first.toDouble() : 0.0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('WEIGHT (KG)',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: Color(0xFF20B2AA))),
              _YearSelector(
                year: _selectedYear,
                canGoBack: _selectedYear > _minYear,
                canGoForward: _selectedYear < _maxYear,
                onBack: () => setState(() => _selectedYear--),
                onForward: () => setState(() => _selectedYear++),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!hasDataThisYear)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                'No growth records for $_selectedYear.',
                style: const TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ),
          if (widget.statusForEntry != null && hasDataThisYear) ...[
            const _StatusLegend(),
            const SizedBox(height: 8),
          ],
          SizedBox(
            height: _MonthBar._barAreaHeight + 30,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasDataThisYear) ...[
                  SizedBox(
                    width: 20,
                    height: _MonthBar._barAreaHeight,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final t in ticks)
                          Text(
                            '$t',
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Expanded(
                  child: Stack(
                    children: [
                      // Minimal gridlines — one per Y-axis tick, so bar
                      // heights can be read against the scale at a glance.
                      // The 0 line is drawn slightly stronger as the
                      // baseline; the rest stay faint on purpose.
                      if (hasDataThisYear)
                        for (final t in ticks)
                          Positioned(
                            left: 0,
                            right: 0,
                            top: _MonthBar._barAreaHeight *
                                (1 - t / axisMax),
                            child: Container(
                              height: 1,
                              color: Colors.grey
                                  .withValues(alpha: t == 0 ? 0.3 : 0.12),
                            ),
                          ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 0; i < 12; i++)
                            Expanded(
                              child: _MonthBar(
                                label: _kMonthLabels[i],
                                weightKg: months[i]?.weightKg,
                                axisMax: axisMax,
                                barColor: months[i] == null
                                    ? _kDefaultBarColor
                                    : (widget.statusForEntry != null
                                        ? _statusColor(
                                            widget.statusForEntry!(
                                                months[i]!))
                                        : _kDefaultBarColor),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Whole-kg tick values from 0 up to a "nice" number at or above [maxW],
  /// descending (so callers can lay them out top-to-bottom directly above
  /// a bottom-anchored 0). Targets ~5 labels (0 + 4 steps) via a classic
  /// 1/2/5-per-decade "nice number" step, regardless of how large or
  /// small the weights are — the fixed-height tick column only has room
  /// for a handful of labels. [maxW] <= 0 (no data) returns a minimal
  /// [1, 0].
  List<int> _axisTicks(double maxW) {
    if (maxW <= 0) return const [1, 0];

    const targetIntervals = 4;
    final step = _niceStep(maxW / targetIntervals);

    var top = step;
    while (top < maxW) {
      top += step;
    }

    return [for (var v = top; v >= 0; v -= step) v];
  }

  /// Rounds [raw] up to the nearest "nice" whole number of the form
  /// 1/2/5 × 10^n (e.g. 1, 2, 5, 10, 20, 50, 100...) — the standard
  /// chart-axis step heuristic. Never returns less than 1, since ticks
  /// here are always whole kg.
  int _niceStep(double raw) {
    if (raw <= 1) return 1;
    final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor());
    final normalized = raw / magnitude;
    final niceNormalized =
        normalized <= 1 ? 1 : (normalized <= 2 ? 2 : (normalized <= 5 ? 5 : 10));
    final step = (niceNormalized * magnitude).round();
    return step < 1 ? 1 : step;
  }
}

class _StatusLegend extends StatelessWidget {
  const _StatusLegend();

  @override
  Widget build(BuildContext context) {
    final items = <MapEntry<CatWeightStatus, String>>[
      const MapEntry(CatWeightStatus.underweight, 'Underweight'),
      const MapEntry(CatWeightStatus.normal, 'Normal'),
      const MapEntry(CatWeightStatus.overweight, 'Overweight'),
      const MapEntry(CatWeightStatus.obese, 'Obese'),
    ];
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        for (final item in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _statusColor(item.key),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                item.value,
                style: const TextStyle(fontSize: 9, color: Colors.grey),
              ),
            ],
          ),
      ],
    );
  }
}

class _YearSelector extends StatelessWidget {
  final int year;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;

  const _YearSelector({
    required this.year,
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _arrow(Icons.chevron_left, canGoBack ? onBack : null),
        SizedBox(
          width: 40,
          child: Text(
            '$year',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
        _arrow(Icons.chevron_right, canGoForward ? onForward : null),
      ],
    );
  }

  Widget _arrow(IconData icon, VoidCallback? onTap) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Icon(
          icon,
          size: 18,
          color: enabled
              ? const Color(0xFF20B2AA)
              : Colors.grey.withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class _MonthBar extends StatelessWidget {
  final String label;
  final double? weightKg;

  /// The Y-axis's top tick value (see `_axisTicks`) — bar height is a
  /// direct fraction of this real, labeled 0-based scale, not an
  /// arbitrary padding factor.
  final double axisMax;
  final Color barColor;

  const _MonthBar({
    required this.label,
    required this.weightKg,
    required this.axisMax,
    required this.barColor,
  });

  static const double _barAreaHeight = 82;

  @override
  Widget build(BuildContext context) {
    final w = weightKg;
    final fraction = (w == null || axisMax <= 0)
        ? 0.0
        : (w / axisMax).clamp(0.0, 1.0);
    final barHeight = w == null
        ? 0.0
        : (fraction * _barAreaHeight).clamp(4.0, _barAreaHeight);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: _barAreaHeight,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: w == null
                ? Container(
                    width: 10,
                    height: 2,
                    color: Colors.grey.withValues(alpha: 0.35),
                  )
                // Fills most of this month's column width instead of a
                // small fixed pixel width, so the 12 bars use the card's
                // full horizontal space regardless of screen size.
                : FractionallySizedBox(
                    widthFactor: 0.7,
                    child: Container(
                      height: barHeight,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4)),
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 9, color: Colors.grey),
        ),
      ],
    );
  }
}
