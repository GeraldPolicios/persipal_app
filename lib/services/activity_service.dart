// services/activity_service.dart
//
// Singleton service for the activity feed the virtual-cat screens (feed /
// groom / play / game) write to via logActivity(), persisted through
// LocalStorageService (Hive). Nothing reads this feed back today — the
// user-facing Activity History screen is driven by ActivityLogService.
//
// Real-pet reminders and profiles are NOT handled here: they live in
// ReminderProvider / models/reminder_item_model.dart and PetProfileProvider
// respectively (an older in-memory copy of both used to live in this file
// and was removed once nothing referenced it).

import 'package:flutter/material.dart';
import 'local_storage_service.dart';

// Every icon this service's logActivity() is ever called with (feed/groom/
// play/game_screen.dart's activity logging, plus icons persisted by older
// app versions that also logged reminder/profile events from this service —
// kept so those old Hive entries still decode) — each a literal `Icons.x`
// reference in source, which
// is what lets the release build's icon tree-shaker keep exactly the
// glyphs actually used. Keyed by codepoint (computed once, not a const
// map — the tree-shaker only cares that `Icons.x` appears literally in
// source, not whether the surrounding map/switch is itself const; see
// ActivityLogModel.icon in models.dart for the same already-working
// pattern). Add to this list (never remove an in-use entry) if a new icon
// is ever logged.
final Map<int, IconData> _knownActivityIcons = {
  for (final icon in const <IconData>[
    Icons.restaurant, // feed_screen.dart
    Icons.content_cut, // groom_screen.dart
    Icons.sports_esports, // play_screen.dart
    Icons.pets, // game_screen.dart (+ old persisted "Added profile" entries)
    Icons.alarm_add, // old persisted "Added reminder" entries
    Icons.alarm_on, // old persisted "Completed reminder" entries
    Icons.alarm_off, // old persisted "Deleted reminder" entries
    Icons.edit_notifications, // old persisted "Edited reminder" entries
    Icons.edit, // old persisted "Edited profile" entries
    Icons.delete_outline, // old persisted "Deleted profile" entries
  ])
    icon.codePoint: icon,
};

// ─── Activity Entry ──────────────────────────────────────────────────────────

class ActivityEntry {
  final String id;
  final IconData icon;
  final Color iconColor;
  final String title;
  final DateTime timestamp;

  ActivityEntry({
    required this.id,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'iconCodePoint': icon.codePoint,
        'iconFontFamily': icon.fontFamily,
        'iconFontPackage': icon.fontPackage,
        'colorValue': iconColor.value,
        'title': title,
        'timestamp': timestamp.toIso8601String(),
      };

  /// Reads the same 'iconCodePoint'/'iconFontFamily'/'iconFontPackage'
  /// fields [toMap] always wrote (old persisted Hive entries decode
  /// unchanged), but resolves them through [_knownActivityIcons] — a fixed
  /// set of literal `Icons.x` constants — instead of calling the `IconData`
  /// constructor at runtime, which is what broke release icon tree-shaking
  /// (a codepoint the release build can't statically prove is one of a
  /// known set of glyphs). An unrecognized codepoint (never expected, but
  /// possible from a corrupted/foreign record) falls back to a plain info
  /// icon rather than crashing.
  factory ActivityEntry.fromMap(Map<String, dynamic> m) => ActivityEntry(
        id: m['id'] as String,
        icon: _knownActivityIcons[m['iconCodePoint'] as int? ?? 0] ??
            Icons.info_outline,
        iconColor: Color(m['colorValue'] as int),
        title: m['title'] as String? ?? '',
        timestamp: DateTime.tryParse(m['timestamp'] as String? ?? '') ??
            DateTime.now(),
      );
}

// ─── Singleton Service ───────────────────────────────────────────────────────

class ActivityService extends ChangeNotifier {
  // Private constructor for singleton
  ActivityService._();
  static final ActivityService instance = ActivityService._();

  final _local = LocalStorageService.instance;

  // ── Data stores ──────────────────────────────────────────────────────────
  final List<ActivityEntry> _log = [];

  bool _loading = true;
  bool get loading => _loading;

  List<ActivityEntry> get log => List.unmodifiable(_log);

  /// Loads persisted activity entries from Hive. Call once at app startup,
  /// before the first screen that reads `.log` builds — same pattern as the
  /// app's other providers (VirtualPetProvider, ReminderProvider, etc.).
  Future<void> init() async {
    final loaded = await _local.fetchActivityEntries();
    _log
      ..clear()
      ..addAll(loaded);
    _loading = false;
    notifyListeners();
  }

  // ── Activity Log ─────────────────────────────────────────────────────────

  void logActivity({
    required IconData icon,
    required Color iconColor,
    required String title,
  }) {
    final entry = ActivityEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      icon: icon,
      iconColor: iconColor,
      title: title,
      timestamp: DateTime.now(),
    );
    _log.insert(0, entry);
    notifyListeners();
    _local.saveActivityEntry(entry);
  }

  void clearLog() {
    _log.clear();
    notifyListeners();
    _local.clearActivityEntries();
  }
}
