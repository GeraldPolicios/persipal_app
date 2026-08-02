// lib/models/reminder_item_model.dart
//
// Persisted reminder for REAL pets (feeding, grooming, vet visits,
// vaccinations, litter, etc.). This is the same shape that was previously
// defined inside services/activity_service.dart (in-memory only) — moved
// here and given toMap()/fromMap() so it can be persisted through
// LocalStorageService instead.
//
// NOT used by the Virtual Pet — the virtual pet has no reminders.

const Object _unset = Object();

class ReminderItem {
  final String id;
  final String title;
  final String type;
  final DateTime scheduledAt;
  final bool isDone;
  final String? petId; // which real pet this reminder belongs to (or null)
  final String? linkedVaccinationId; // set if auto-created from a vaccine dose
  final String recurrence; // 'none' | 'daily' | 'weekly' | 'monthly'

  const ReminderItem({
    required this.id,
    required this.title,
    required this.type,
    required this.scheduledAt,
    this.isDone = false,
    this.petId,
    this.linkedVaccinationId,
    this.recurrence = 'none',
  });

  bool get isOverdue => !isDone && scheduledAt.isBefore(DateTime.now());

  /// Returns a new ReminderItem with the given fields replaced.
  /// Pass `petId: null` / `linkedVaccinationId: null` explicitly to CLEAR
  /// those fields (they use a sentinel default so "not passed" != "null").
  ReminderItem copyWith({
    String? title,
    String? type,
    DateTime? scheduledAt,
    bool? isDone,
    Object? petId = _unset,
    Object? linkedVaccinationId = _unset,
    String? recurrence,
  }) =>
      ReminderItem(
        id: id,
        title: title ?? this.title,
        type: type ?? this.type,
        scheduledAt: scheduledAt ?? this.scheduledAt,
        isDone: isDone ?? this.isDone,
        petId: identical(petId, _unset) ? this.petId : petId as String?,
        linkedVaccinationId: identical(linkedVaccinationId, _unset)
            ? this.linkedVaccinationId
            : linkedVaccinationId as String?,
        recurrence: recurrence ?? this.recurrence,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'type': type,
        'scheduledAt': scheduledAt.toIso8601String(),
        'isDone': isDone,
        'petId': petId,
        'linkedVaccinationId': linkedVaccinationId,
        'recurrence': recurrence,
      };

  factory ReminderItem.fromMap(Map<String, dynamic> m) => ReminderItem(
        id: m['id'] as String,
        title: m['title'] as String? ?? '',
        type: m['type'] as String? ?? 'Other',
        scheduledAt: DateTime.tryParse(m['scheduledAt'] as String? ?? '') ??
            DateTime.now(),
        isDone: m['isDone'] as bool? ?? false,
        petId: m['petId'] as String?,
        linkedVaccinationId: m['linkedVaccinationId'] as String?,
        recurrence: m['recurrence'] as String? ?? 'none',
      );
}
