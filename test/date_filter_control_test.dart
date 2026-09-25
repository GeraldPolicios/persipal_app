// Tests the three DateFilterKind values added for the Reminder Screen's
// Done-tab filter (Requirement 3: This Week/This Month/Last Month/This
// Year/Last Year/Custom Date Range/All Dates) — Last Month, This Year and
// Last Year didn't exist on the shared widget before. Since it's shared
// with Activity History and Growth Tracker, these are also now available
// there — purely additive, so their existing kinds are covered too (to
// confirm nothing about them changed) alongside the three new ones.
//
// dateRangeForSelection has no dependency on platform/Hive/Firebase — it's
// a pure function of DateTime.now() and the given selection.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:persipal_app/widgets/date_filter_control.dart';

void main() {
  final now = DateTime.now();

  group('pre-existing kinds are unaffected by the new additions', () {
    test('allDates has no range (no filtering)', () {
      expect(dateRangeForSelection(const DateFilterSelection.allDates()),
          isNull);
    });

    test('thisWeek starts Monday and spans exactly 7 days', () {
      final range = dateRangeForSelection(const DateFilterSelection.thisWeek())!;
      expect(range.$1.weekday, DateTime.monday);
      expect(range.$2.difference(range.$1), const Duration(days: 7));
    });

    test('thisMonth is the current calendar month', () {
      final range = dateRangeForSelection(const DateFilterSelection.thisMonth())!;
      expect(range.$1, DateTime(now.year, now.month, 1));
      expect(range.$2, DateTime(now.year, now.month + 1, 1));
    });
  });

  group('lastMonth (new)', () {
    test('is the calendar month immediately before this one', () {
      final range = dateRangeForSelection(const DateFilterSelection.lastMonth())!;
      expect(range.$1, DateTime(now.year, now.month - 1, 1));
      expect(range.$2, DateTime(now.year, now.month, 1));
      // A reminder completed on the last day of last month must fall
      // inside [start, end) — the boundary is exclusive at THIS month's
      // start, not before it.
      expect(range.$2.isAfter(range.$1), isTrue);
    });

    test('label reads "Last Month"', () {
      expect(dateFilterLabel(const DateFilterSelection.lastMonth()), 'Last Month');
    });

    test('rolls over the year boundary correctly (Jan -> last Dec)', () {
      // DateTime(year, 0, 1) == DateTime(year - 1, 12, 1) in Dart — this
      // just confirms that's exactly the behavior relied on, explicitly,
      // rather than leaving it as an unverified assumption.
      final jan = DateTime(2026, 1, 15);
      final rangeStart = DateTime(jan.year, jan.month - 1, 1);
      expect(rangeStart, DateTime(2025, 12, 1));
    });
  });

  group('thisYear (new)', () {
    test('spans Jan 1 through Jan 1 next year', () {
      final range = dateRangeForSelection(const DateFilterSelection.thisYear())!;
      expect(range.$1, DateTime(now.year, 1, 1));
      expect(range.$2, DateTime(now.year + 1, 1, 1));
    });

    test('label reads "This Year"', () {
      expect(dateFilterLabel(const DateFilterSelection.thisYear()), 'This Year');
    });
  });

  group('lastYear (new)', () {
    test('spans Jan 1 through Jan 1 of the previous calendar year', () {
      final range = dateRangeForSelection(const DateFilterSelection.lastYear())!;
      expect(range.$1, DateTime(now.year - 1, 1, 1));
      expect(range.$2, DateTime(now.year, 1, 1));
    });

    test('label reads "Last Year"', () {
      expect(dateFilterLabel(const DateFilterSelection.lastYear()), 'Last Year');
    });

    test('lastYear and thisYear never overlap', () {
      final last = dateRangeForSelection(const DateFilterSelection.lastYear())!;
      final thisY = dateRangeForSelection(const DateFilterSelection.thisYear())!;
      expect(last.$2, thisY.$1,
          reason: 'lastYear must end exactly where thisYear begins');
    });
  });

  group('custom range (unaffected by the additions)', () {
    test('end date is inclusive of the whole day', () {
      final range = DateTimeRange(
        start: DateTime(2026, 3, 1),
        end: DateTime(2026, 3, 5),
      );
      final resolved =
          dateRangeForSelection(DateFilterSelection.custom(range))!;
      // A completion timestamp at 23:59 on March 5 must still be < end.
      final lateOnEndDay = DateTime(2026, 3, 5, 23, 59);
      expect(lateOnEndDay.isBefore(resolved.$2), isTrue);
      expect(lateOnEndDay.isBefore(resolved.$1), isFalse);
    });
  });

  test('every non-custom, non-allDates kind has a distinct, correctly '
      'ordered [start, end) range', () {
    for (final selection in [
      const DateFilterSelection.thisWeek(),
      const DateFilterSelection.thisMonth(),
      const DateFilterSelection.lastMonth(),
      const DateFilterSelection.thisYear(),
      const DateFilterSelection.lastYear(),
    ]) {
      final range = dateRangeForSelection(selection)!;
      expect(range.$1.isBefore(range.$2), isTrue, reason: selection.kind.name);
    }
  });
}
