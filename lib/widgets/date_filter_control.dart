// lib/widgets/date_filter_control.dart
//
// Shared "Filter by Date" control for Activity History and Growth History.
// Display-only: everything here only ever computes a [start, end) window
// used to FILTER an already-loaded list for display — nothing in this file
// reads or writes Hive/Firestore, nothing mutates a record, and nothing
// here ever touches a record's stored timestamp/recordedAt.
//
// Shared between the two screens (rather than duplicated) specifically so
// their filter UI/behavior stays identical by construction, per the
// consistency requirement — the two screens differ only in accent color
// and the wording of their own empty-state message.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Which kind of date filter is active.
enum DateFilterKind {
  allDates,
  thisWeek,
  thisMonth,
  lastMonth,
  thisYear,
  lastYear,
  custom,
}

/// The user's current filter choice. Immutable value type — a screen holds
/// one of these in its State and recomputes its filtered list from it on
/// every build; nothing here is persisted (filter resets to "All Dates"
/// when the screen is reopened, per the app's existing UI-only-filter
/// pattern).
class DateFilterSelection {
  final DateFilterKind kind;

  /// Only set (and only meaningful) when [kind] is [DateFilterKind.custom].
  final DateTimeRange? customRange;

  const DateFilterSelection.allDates()
      : kind = DateFilterKind.allDates,
        customRange = null;

  const DateFilterSelection.thisWeek()
      : kind = DateFilterKind.thisWeek,
        customRange = null;

  const DateFilterSelection.thisMonth()
      : kind = DateFilterKind.thisMonth,
        customRange = null;

  const DateFilterSelection.lastMonth()
      : kind = DateFilterKind.lastMonth,
        customRange = null;

  const DateFilterSelection.thisYear()
      : kind = DateFilterKind.thisYear,
        customRange = null;

  const DateFilterSelection.lastYear()
      : kind = DateFilterKind.lastYear,
        customRange = null;

  const DateFilterSelection.custom(DateTimeRange range)
      : kind = DateFilterKind.custom,
        customRange = range;
}

/// The [start, end) boundary for [selection] in the device's local time, or
/// null for "All Dates" (no filtering). Weeks start Monday; "This Month" is
/// the current calendar month — never a rolling day-count window. For a
/// custom range, the END date is treated INCLUSIVELY of the whole day (the
/// boundary is midnight the day AFTER the selected end date), so a record
/// at any time on the selected end date is included.
///
/// [now] defaults to the current time; it exists only so callers (and tests)
/// can evaluate a filter against a fixed moment.
(DateTime, DateTime)? dateRangeForSelection(
  DateFilterSelection selection, {
  DateTime? now,
}) {
  now ??= DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  switch (selection.kind) {
    case DateFilterKind.allDates:
      return null;
    case DateFilterKind.thisWeek:
      final start = today.subtract(Duration(days: today.weekday - 1));
      return (start, start.add(const Duration(days: 7)));
    case DateFilterKind.thisMonth:
      return (
        DateTime(today.year, today.month, 1),
        DateTime(today.year, today.month + 1, 1),
      );
    case DateFilterKind.lastMonth:
      return (
        DateTime(today.year, today.month - 1, 1),
        DateTime(today.year, today.month, 1),
      );
    case DateFilterKind.thisYear:
      return (
        DateTime(today.year, 1, 1),
        DateTime(today.year + 1, 1, 1),
      );
    case DateFilterKind.lastYear:
      return (
        DateTime(today.year - 1, 1, 1),
        DateTime(today.year, 1, 1),
      );
    case DateFilterKind.custom:
      final range = selection.customRange;
      if (range == null) return null;
      final start = DateTime(range.start.year, range.start.month, range.start.day);
      final endInclusive =
          DateTime(range.end.year, range.end.month, range.end.day)
              .add(const Duration(days: 1));
      return (start, endInclusive);
  }
}

/// Compact, mobile-friendly label for the active filter — never a raw
/// DateTime string. Includes the year in a custom-range label only when
/// needed to stay unambiguous (the range spans two years, or isn't in the
/// current year).
String dateFilterLabel(DateFilterSelection selection) {
  switch (selection.kind) {
    case DateFilterKind.allDates:
      return 'All Dates';
    case DateFilterKind.thisWeek:
      return 'This Week';
    case DateFilterKind.thisMonth:
      return 'This Month';
    case DateFilterKind.lastMonth:
      return 'Last Month';
    case DateFilterKind.thisYear:
      return 'This Year';
    case DateFilterKind.lastYear:
      return 'Last Year';
    case DateFilterKind.custom:
      final range = selection.customRange;
      if (range == null) return 'Custom Range';
      final needsYear = range.start.year != range.end.year ||
          range.start.year != DateTime.now().year;
      final fmt = DateFormat(needsYear ? 'MMM d, yyyy' : 'MMM d');
      if (range.start.year == range.end.year &&
          range.start.month == range.end.month &&
          range.start.day == range.end.day) {
        return fmt.format(range.start);
      }
      return '${fmt.format(range.start)} – ${fmt.format(range.end)}';
  }
}

/// The compact "Filter by Date" button. A single tap target (opens
/// [showDateFilterSheet]) — deliberately not a Row of independent chips, so
/// there's nothing here that can horizontally overflow: the icon and
/// trailing chevron are fixed-size, and the label sits in an [Expanded]
/// column with `maxLines: 1` + ellipsis, so even a long custom-range label
/// truncates instead of overflowing on a narrow screen.
class DateFilterButton extends StatelessWidget {
  final DateFilterSelection selection;
  final Color accentColor;
  final VoidCallback onTap;

  const DateFilterButton({
    super.key,
    required this.selection,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = selection.kind != DateFilterKind.allDates;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isActive
              ? accentColor.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: accentColor.withValues(alpha: isActive ? 0.5 : 0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.filter_alt, size: 18, color: accentColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'FILTER BY DATE',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                        color: Color(0xFFAA7755)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isActive ? dateFilterLabel(selection) : 'All Dates',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isActive ? accentColor : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.keyboard_arrow_down,
                size: 18, color: accentColor.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}

/// Shows the Material 3 bottom-sheet filter panel and resolves once the
/// user picks an option (or dismisses without choosing, returning null).
/// Sized to its content (not full-screen) so it never exceeds the device's
/// available height; `showDateRangePicker` — the standard Material widget,
/// already responsive/adaptive by itself — handles the Custom Date Range
/// sub-flow and inherently prevents picking an invalid reversed range.
Future<DateFilterSelection?> showDateFilterSheet(
  BuildContext context, {
  required DateFilterSelection current,
  required Color accentColor,
}) {
  return showModalBottomSheet<DateFilterSelection>(
    context: context,
    backgroundColor: const Color(0xFFFFF8F2),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (sheetCtx) {
      // Capped to the device's actual available height (minus a small
      // margin) and wrapped in a scroll view — normally the content is far
      // shorter than this, but large/accessibility text sizes or a short
      // landscape screen could otherwise push it past the visible area.
      final maxHeight = MediaQuery.of(sheetCtx).size.height * 0.85;

      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.filter_alt, color: accentColor, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Filter by Date',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _SheetOption(
                icon: Icons.view_week,
                label: 'This Week',
                accentColor: accentColor,
                selected: current.kind == DateFilterKind.thisWeek,
                onTap: () =>
                    Navigator.pop(sheetCtx, const DateFilterSelection.thisWeek()),
              ),
              _SheetOption(
                icon: Icons.calendar_view_month,
                label: 'This Month',
                accentColor: accentColor,
                selected: current.kind == DateFilterKind.thisMonth,
                onTap: () => Navigator.pop(
                    sheetCtx, const DateFilterSelection.thisMonth()),
              ),
              _SheetOption(
                icon: Icons.calendar_view_month_outlined,
                label: 'Last Month',
                accentColor: accentColor,
                selected: current.kind == DateFilterKind.lastMonth,
                onTap: () => Navigator.pop(
                    sheetCtx, const DateFilterSelection.lastMonth()),
              ),
              _SheetOption(
                icon: Icons.event_note,
                label: 'This Year',
                accentColor: accentColor,
                selected: current.kind == DateFilterKind.thisYear,
                onTap: () => Navigator.pop(
                    sheetCtx, const DateFilterSelection.thisYear()),
              ),
              _SheetOption(
                icon: Icons.event_note_outlined,
                label: 'Last Year',
                accentColor: accentColor,
                selected: current.kind == DateFilterKind.lastYear,
                onTap: () => Navigator.pop(
                    sheetCtx, const DateFilterSelection.lastYear()),
              ),
              _SheetOption(
                icon: Icons.date_range,
                label: 'Custom Date Range',
                accentColor: accentColor,
                selected: current.kind == DateFilterKind.custom,
                onTap: () async {
                  final now = DateTime.now();
                  final fallbackInitial =
                      DateTimeRange(start: now, end: now);
                  final existing = current.customRange;
                  final initialRange = (existing != null &&
                          !existing.start.isAfter(now) &&
                          !existing.end.isAfter(now))
                      ? existing
                      : fallbackInitial;

                  final picked = await showDateRangePicker(
                    context: sheetCtx,
                    firstDate: DateTime(2000),
                    lastDate: now,
                    initialDateRange: initialRange,
                    builder: (dialogCtx, child) => Theme(
                      data: Theme.of(dialogCtx).copyWith(
                        colorScheme: Theme.of(dialogCtx)
                            .colorScheme
                            .copyWith(primary: accentColor),
                      ),
                      child: child!,
                    ),
                  );

                  if (picked == null) return;
                  if (!sheetCtx.mounted) return;
                  Navigator.pop(sheetCtx, DateFilterSelection.custom(picked));
                },
              ),
              const Divider(height: 24),
              _SheetOption(
                icon: Icons.all_inclusive,
                label: 'All Dates',
                accentColor: Colors.grey.shade700,
                selected: current.kind == DateFilterKind.allDates,
                onTap: () => Navigator.pop(
                    sheetCtx, const DateFilterSelection.allDates()),
              ),
            ],
          ),
          ),
        ),
      );
    },
  );
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accentColor;
  final bool selected;
  final VoidCallback onTap;

  const _SheetOption({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: accentColor),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected ? accentColor : Colors.black87,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, size: 18, color: accentColor),
          ],
        ),
      ),
    );
  }
}
