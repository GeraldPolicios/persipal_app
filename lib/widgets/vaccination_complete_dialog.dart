// widgets/vaccination_complete_dialog.dart
//
// Shared "mark this dose as given" flow. Used from BOTH the Vaccination
// screen (tapping "Mark Given" on a card) and the Reminder screen (marking
// a vaccine-linked reminder done), so the two stay perfectly in sync.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../providers/pet_profile_provider.dart';
import '../models/pet_extended_models.dart';

Future<void> showVaccinationCompleteDialog(
  BuildContext context, {
  required String petId,
  required VaccinationRecord record,
}) async {
  DateTime givenDate = DateTime.now();
  DateTime? nextSchedule;
  bool reminderEnabled = false;

  await showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setD) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: const Color(0xFFFFF8F2),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF32CD32).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_circle,
                        color: Color(0xFF32CD32), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('${record.vaccineName} given? 🎉',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ]),
                const SizedBox(height: 6),
                const Text(
                  "Nice work! Confirm the date and we'll log it and "
                  "keep the record up to date.",
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                const Text('Date Given',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFAA7755))),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: givenDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      builder: (c, child) => Theme(
                        data: Theme.of(c).copyWith(
                            colorScheme: const ColorScheme.light(
                                primary: Color(0xFF32CD32))),
                        child: child!,
                      ),
                    );
                    if (d != null) setD(() => givenDate = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF32CD32).withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.event_available,
                          size: 16, color: Color(0xFF32CD32)),
                      const SizedBox(width: 10),
                      Text(DateFormat('MMM d, yyyy').format(givenDate),
                          style: const TextStyle(fontSize: 13)),
                    ]),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Schedule the following dose? (optional)',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFAA7755))),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate: nextSchedule ??
                          givenDate.add(const Duration(days: 365)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(2100),
                      builder: (c, child) => Theme(
                        data: Theme.of(c).copyWith(
                            colorScheme: const ColorScheme.light(
                                primary: Color(0xFF7B68EE))),
                        child: child!,
                      ),
                    );
                    if (d != null) {
                      setD(() {
                        nextSchedule = d;
                        reminderEnabled = true;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFF7B68EE).withOpacity(0.3)),
                    ),
                    child: Row(children: [
                      Icon(Icons.calendar_month,
                          size: 16,
                          color: nextSchedule == null
                              ? Colors.grey
                              : const Color(0xFF7B68EE)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          nextSchedule != null
                              ? DateFormat('MMM d, yyyy').format(nextSchedule!)
                              : 'Not scheduled',
                          style: TextStyle(
                              fontSize: 13,
                              color: nextSchedule == null
                                  ? Colors.grey
                                  : Colors.black87),
                        ),
                      ),
                      if (nextSchedule != null)
                        GestureDetector(
                          onTap: () => setD(() {
                            nextSchedule = null;
                            reminderEnabled = false;
                          }),
                          child: const Icon(Icons.close,
                              size: 16, color: Colors.grey),
                        ),
                    ]),
                  ),
                ),
                if (nextSchedule != null) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    const Icon(Icons.notifications_active,
                        size: 16, color: Color(0xFF7B68EE)),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Remind me for this dose',
                          style: TextStyle(fontSize: 12)),
                    ),
                    Switch(
                      value: reminderEnabled,
                      onChanged: (v) => setD(() => reminderEnabled = v),
                      activeColor: const Color(0xFF7B68EE),
                    ),
                  ]),
                ],
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel',
                          style: TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF32CD32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Confirm'),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await PetProfileProvider.instance
                            .completeVaccinationDose(
                          petId,
                          record.id,
                          givenDate: givenDate,
                          nextSchedule: nextSchedule,
                          reminderEnabled: reminderEnabled,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
