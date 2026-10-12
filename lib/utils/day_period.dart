import 'dart:async';

import 'package:flutter/widgets.dart';

enum DayPeriod {
  day,
  noon,
  night,
}

DayPeriod currentDayPeriod([DateTime? now]) {
  final hour = (now ?? DateTime.now()).hour;

  if (hour >= 6 && hour < 12) {
    return DayPeriod.day;
  }
  if (hour >= 12 && hour < 18) {
    return DayPeriod.noon;
  }
  return DayPeriod.night;
}

String roomAsset(
  DayPeriod period, {
  required String day,
  required String noon,
  required String night,
}) {
  switch (period) {
    case DayPeriod.day:
      return day;
    case DayPeriod.noon:
      return noon;
    case DayPeriod.night:
      return night;
  }
}

/// Shared time-of-day notifier. The next transition is scheduled for the
/// exact local clock boundary (06:00, 12:00, or 18:00), instead of polling
/// every 30 seconds. When the app resumes, the value is recalculated too.
final ValueNotifier<DayPeriod> dayPeriodNotifier = _createDayPeriodNotifier();

ValueNotifier<DayPeriod> _createDayPeriodNotifier() {
  final notifier = ValueNotifier<DayPeriod>(currentDayPeriod());
  WidgetsBinding.instance.addObserver(_dayPeriodLifecycleObserver);
  _scheduleNextDayPeriodBoundary();
  return notifier;
}

Timer? _dayPeriodTimer;

void _refreshDayPeriod() {
  final next = currentDayPeriod();
  if (next != dayPeriodNotifier.value) {
    dayPeriodNotifier.value = next;
  }
  _scheduleNextDayPeriodBoundary();
}

void _scheduleNextDayPeriodBoundary() {
  _dayPeriodTimer?.cancel();

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final boundaries = <DateTime>[
    today.add(const Duration(hours: 6)),
    today.add(const Duration(hours: 12)),
    today.add(const Duration(hours: 18)),
    today.add(const Duration(days: 1, hours: 6)),
  ];

  final next = boundaries.firstWhere((time) => time.isAfter(now));
  _dayPeriodTimer = Timer(next.difference(now), _refreshDayPeriod);
}

class _DayPeriodLifecycleObserver with WidgetsBindingObserver {
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshDayPeriod();
    }
  }
}

final _dayPeriodLifecycleObserver = _DayPeriodLifecycleObserver();
