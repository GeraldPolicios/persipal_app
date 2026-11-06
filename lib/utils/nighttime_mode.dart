/// Centralized rules for the Virtual Pet nighttime mode.
///
/// Daytime and nighttime are intentionally separate experiences. This file
/// contains only the time-of-day rules; the existing Virtual Pet provider,
/// status priority, and cat animations remain responsible for the pet's
/// actual condition and behavior.
class NighttimeMode {
  NighttimeMode._();

  // Use the actual local time to determine whether nighttime mode is active.
  static const bool forceDaytimeForTesting = false;

  // Nighttime rules remain enabled when the testing override is turned off.
  static const bool enabled = true;

  static const int nightStartHour = 18; // 6:00 PM
  static const int morningHour = 6; // 6:00 AM
  static const int bedtimeHour = 22; // 10:00 PM

  /// True from 6:00 PM until 6:00 AM.
  static bool isNighttime([DateTime? now]) {
    if (forceDaytimeForTesting || !enabled) return false;
    final hour = (now ?? DateTime.now()).hour;
    return hour >= nightStartHour || hour < morningHour;
  }

  /// True from 10:00 PM until 6:00 AM.
  static bool isBedtime([DateTime? now]) {
    if (forceDaytimeForTesting || !enabled) return false;
    final hour = (now ?? DateTime.now()).hour;
    return hour >= bedtimeHour || hour < morningHour;
  }

  /// The cat may still receive necessary care during the evening.
  /// General interactions are locked only once bedtime begins.
  /// Feed/Groom screens apply their own care-need checks during 6 PM–10 PM.
  static bool get interactionsLocked => isBedtime();
}
