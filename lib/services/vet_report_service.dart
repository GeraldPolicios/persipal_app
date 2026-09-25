// lib/services/vet_report_service.dart
//
// Builds a plain-text, veterinary-friendly summary for ONE real pet, derived
// entirely from that pet's own Activity History entries (petId match — see
// buildVetReport's filter). No new storage, no new data source — this only
// formats existing ActivityLogService records for reading/sharing.
//
// Pure/testable: takes the pet + its already-loaded logs, returns a String.

import 'package:intl/intl.dart';

import '../models/models.dart';
import '../models/pet_extended_models.dart';

final DateFormat _dateFmt = DateFormat('MMM d, yyyy');
final DateFormat _dateTimeFmt = DateFormat('MMM d, yyyy \'at\' h:mm a');

/// [logs] should already be filtered to this [pet] (by petId). [periodStart]
/// / [periodEnd] (exclusive) narrow the report to a date range — both null
/// means "all recorded history". [generatedAt] defaults to now (overridable
/// for tests).
String buildVetReport({
  required FullPetProfile pet,
  required List<ActivityLogModel> logs,
  DateTime? periodStart,
  DateTime? periodEnd,
  DateTime? generatedAt,
}) {
  final now = generatedAt ?? DateTime.now();

  bool inPeriod(ActivityLogModel l) {
    if (periodStart == null || periodEnd == null) return true;
    return !l.timestamp.isBefore(periodStart) && l.timestamp.isBefore(periodEnd);
  }

  final scoped = logs.where(inPeriod).toList()
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

  List<ActivityLogModel> byType(ActionType t) =>
      scoped.where((l) => l.actionType == t).toList();

  final completedReminders = byType(ActionType.reminder)
      .where((l) => l.description.startsWith('Completed reminder'))
      .toList();
  final vaccinationRecords = byType(ActionType.vaccination);
  final growthRecords = byType(ActionType.growth);
  final healthRecords = byType(ActionType.health);

  final buf = StringBuffer();
  void line([String text = '']) => buf.writeln(text);
  void rule() => line('-' * 44);
  void section(String title, List<ActivityLogModel> entries, String emptyText) {
    line(title);
    rule();
    if (entries.isEmpty) {
      line(emptyText);
    } else {
      for (final e in entries) {
        line('${_dateFmt.format(e.timestamp)} — ${e.description}');
      }
    }
    line();
  }

  line('PERSIPAL CARE REPORT');
  line('=' * 44);
  line('Pet: ${pet.name}');
  if (pet.ageLabel.isNotEmpty) line('Age: ${pet.ageLabel}');
  if (pet.gender.isNotEmpty) line('Gender: ${pet.gender}');
  line('Generated: ${_dateTimeFmt.format(now)}');
  line('Period: ${periodStart == null || periodEnd == null ? 'All recorded history' : '${_dateFmt.format(periodStart)} - ${_dateFmt.format(periodEnd.subtract(const Duration(days: 1)))}'}');
  line();

  section('GROWTH / WEIGHT RECORDS', growthRecords,
      'No weight entries recorded in this period.');
  section('VACCINATION / VETERINARY-CARE RECORDS', vaccinationRecords,
      'No vaccination/veterinary-care records in this period.');
  section('COMPLETED CARE REMINDERS', completedReminders,
      'No completed care reminders in this period.');
  section('HEALTH / CHECKUP NOTES', healthRecords,
      'No health/checkup notes recorded in this period.');

  rule();
  line(
      'This report is generated from care records logged in the PersiPal '
      'app. It is not a medical diagnosis. Please consult a licensed '
      'veterinarian for professional advice.');

  return buf.toString();
}
