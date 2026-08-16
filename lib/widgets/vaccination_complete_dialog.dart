// widgets/vaccination_complete_dialog.dart
//
// Shared "mark this dose as given" flow. Used from BOTH the Vaccination
// screen (tapping "Mark Given" on a card) and the Reminder screen (marking
// a vaccine-linked reminder done), so the two stay perfectly in sync.
//
// Follow-up doses are no longer scheduled manually from here — a recurring
// dose series (set up when the vaccination was first added) is the only way
// to schedule follow-up doses now, and every generated dose already has its
// own linked Care Reminder. This dialog only confirms the given date.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/pet_profile_provider.dart';
import '../providers/reminder_provider.dart';
import '../models/pet_extended_models.dart';

Future<void> showVaccinationCompleteDialog(
  BuildContext context, {
  required String petId,
  required VaccinationRecord record,
}) async {
  DateTime givenDate = DateTime.now();

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
                  "Nice work! Confirm the date this dose was actually given.",
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
                if (record.isPlanned) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF20B2AA).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline,
                          size: 16, color: Color(0xFF20B2AA)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "This dose is part of a series — the next "
                          "scheduled dose (if any) already exists with its "
                          "own reminder.",
                          style:
                              TextStyle(fontSize: 12, color: Color(0xFF20B2AA)),
                        ),
                      ),
                    ]),
                  ),
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
                        final reminderProvider = Provider.of<ReminderProvider>(
                            context,
                            listen: false);
                        Navigator.pop(ctx);
                        await PetProfileProvider.instance
                            .completeVaccinationDose(
                          petId,
                          record.id,
                          givenDate: givenDate,
                          reminderProvider: reminderProvider,
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
