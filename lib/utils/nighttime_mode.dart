/// Centralized rules for the Virtual Pet nighttime mode.
///
/// Daytime and nighttime are intentionally separate experiences. This file
/// contains only the time-of-day rules; the existing Virtual Pet provider,
/// status priority, and cat animations remain responsible for the pet's
/// actual condition and behavior.
class NighttimeMode {
  NighttimeMode._();

  // Nighttime rules are enabled for the nighttime care flow.
  static const bool enabled = true;

  static const int nightStartHour = 18; // 6:00 PM
  static const int morningHour = 6; // 6:00 AM
  static const int bedtimeHour = 22; // 10:00 PM

  /// True from 6:00 PM until 6:00 AM.
  static bool isNighttime([DateTime? now]) {
    if (!enabled) return false;
    final hour = (now ?? DateTime.now()).hour;
    return hour >= nightStartHour || hour < morningHour;
  }

  /// True from 10:00 PM until 6:00 AM.
  static bool isBedtime([DateTime? now]) {
    if (!enabled) return false;
    final hour = (now ?? DateTime.now()).hour;
    return hour >= bedtimeHour || hour < morningHour;
  }

  /// During nighttime the player cannot interact with the cat or use care
  /// actions. Thought bubbles remain available.
  static bool get interactionsLocked => isNighttime();
}
