// lib/screens/pet_profiles/vaccination_screen.dart
//
// Vaccination Records — full CRUD + Care Reminder synchronization.
//
// Features:
// • Add / edit / delete vaccination records
// • Quick-add common cat vaccines/treatments
// • Optional next-schedule date
// • Automatic Care Reminder synchronization
// • Turning reminder OFF removes the linked reminder
// • Clearing next date removes the linked reminder
// • Deleting a record removes its linked reminder
// • Editing a record updates its existing reminder
// • Recurring dose series
// • Dose X of Y display
// • Mark Given flow
// • Due / overdue labels
//
// IMPORTANT:
// This file assumes the existing project APIs:
//
// PetProfileProvider.instance
// ReminderProvider
// VaccinationRecord
// ReminderItem
// showVaccinationCompleteDialog()

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:persipal_app/models/reminder_item_model.dart';
import 'package:persipal_app/providers/reminder_provider.dart';

import '../../models/pet_extended_models.dart';
import '../../providers/pet_profile_provider.dart';
import '../../widgets/vaccination_complete_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QUICK VACCINE TEMPLATES
// ─────────────────────────────────────────────────────────────────────────────

const List<Map<String, dynamic>> _kVaccineTemplates = [
  {
    'label': 'FVRCP',
    'days': 365,
  },
  {
    'label': 'Rabies',
    'days': 365,
  },
  {
    'label': 'FeLV',
    'days': 365,
  },
  {
    'label': 'Deworming',
    'days': 90,
  },
];

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class VaccinationScreen extends StatefulWidget {
  final String petId;

  const VaccinationScreen({
    super.key,
    required this.petId,
  });

  @override
  State<VaccinationScreen> createState() => _VaccinationScreenState();
}

class _VaccinationScreenState extends State<VaccinationScreen> {
  final PetProfileProvider _provider = PetProfileProvider.instance;
  final Uuid _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _provider.addListener(_refresh);
  }

  @override
  void dispose() {
    _provider.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
  }

  FullPetProfile? get _pet {
    return _provider.getById(widget.petId);
  }

  VaccinationRecord? _findRecord(String id) {
    final vaccinations = _pet?.vaccinations;

    if (vaccinations == null) {
      return null;
    }

    for (final record in vaccinations) {
      if (record.id == id) {
        return record;
      }
    }

    return null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REMINDER SYNCHRONIZATION
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _syncReminder({
    required String recordId,
    required String vaccineName,
    required DateTime? nextSchedule,
    required bool reminderEnabled,
    required String? existingLinkedReminderId,
  }) async {
    final pet = _pet;

    if (pet == null) {
      return;
    }

    final reminderProvider = context.read<ReminderProvider>();

    // ───────────────────────────────────────────────────────────────────────
    // CASE 1:
    // No date OR reminder disabled.
    //
    // Remove the linked reminder if one exists.
    // ───────────────────────────────────────────────────────────────────────

    if (nextSchedule == null || !reminderEnabled) {
      if (existingLinkedReminderId != null &&
          existingLinkedReminderId.isNotEmpty) {
        await reminderProvider.deleteReminder(existingLinkedReminderId);
      }

      final record = _findRecord(recordId);

      if (record != null && record.linkedReminderId != null) {
        await _provider.updateVaccination(
          widget.petId,
          record.copyWith(
            linkedReminderId: null,
          ),
        );
      }

      return;
    }

    // ───────────────────────────────────────────────────────────────────────
    // CASE 2:
    // We have a date and reminder is enabled.
    // ───────────────────────────────────────────────────────────────────────

    final reminderTitle = "💉 $vaccineName — ${pet.name}'s next dose";

    String? validExistingReminderId;

    if (existingLinkedReminderId != null &&
        existingLinkedReminderId.isNotEmpty) {
      final exists = reminderProvider.reminders.any(
        (reminder) => reminder.id == existingLinkedReminderId,
      );

      if (exists) {
        validExistingReminderId = existingLinkedReminderId;
      }
    }

    // ───────────────────────────────────────────────────────────────────────
    // CASE 2A:
    // Existing reminder found -> UPDATE it.
    //
    // This prevents duplicate reminders when editing a vaccination.
    // ───────────────────────────────────────────────────────────────────────

    if (validExistingReminderId != null) {
      final oldReminder = reminderProvider.reminders.firstWhere(
        (reminder) => reminder.id == validExistingReminderId,
      );

      await reminderProvider.updateReminder(
        oldReminder.copyWith(
          title: reminderTitle,
          type: 'Vet Visit',
          scheduledAt: nextSchedule,
          petId: widget.petId,
          linkedVaccinationId: recordId,
          isDone: false,
        ),
      );

      // Make sure the vaccination still points to this reminder.
      final record = _findRecord(recordId);

      if (record != null &&
          record.linkedReminderId != validExistingReminderId) {
        await _provider.updateVaccination(
          widget.petId,
          record.copyWith(
            linkedReminderId: validExistingReminderId,
          ),
        );
      }

      return;
    }

    // ───────────────────────────────────────────────────────────────────────
    // CASE 2B:
    // No existing reminder -> CREATE a new one.
    // ───────────────────────────────────────────────────────────────────────

    final reminderId = _uuid.v4();

    await reminderProvider.addReminder(
      ReminderItem(
        id: reminderId,
        title: reminderTitle,
        type: 'Vet Visit',
        scheduledAt: nextSchedule,
        petId: widget.petId,
        linkedVaccinationId: recordId,
      ),
    );

    final record = _findRecord(recordId);

    if (record != null) {
      await _provider.updateVaccination(
        widget.petId,
        record.copyWith(
          linkedReminderId: reminderId,
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ADD / EDIT VACCINATION DIALOG
  // ─────────────────────────────────────────────────────────────────────────

  void _showDialog({
    VaccinationRecord? existing,
  }) {
    final nameController = TextEditingController(
      text: existing?.vaccineName ?? '',
    );

    final notesController = TextEditingController(
      text: existing?.vetNotes ?? '',
    );

    DateTime completedDate = existing?.completedDate ?? DateTime.now();

    DateTime? nextSchedule = existing?.nextSchedule;

    bool reminderEnabled = existing?.reminderEnabled ?? false;

    final existingLinkedReminderId = existing?.linkedReminderId;

    // ───────────────────────────────────────────────────────────────────────
    // RECURRING SERIES SETTINGS
    // ───────────────────────────────────────────────────────────────────────

    bool useRecurringSchedule = false;

    String recurrenceType = 'everyXDays';

    final intervalController = TextEditingController(text: '7');

    final totalDosesController = TextEditingController(text: '3');

    bool seriesReminderEnabled = true;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              backgroundColor: const Color(0xFFFFF8F2),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 40,
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ─────────────────────────────────────────────────────
                      // HEADER
                      // ─────────────────────────────────────────────────────

                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7B68EE)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.vaccines,
                              color: Color(0xFF7B68EE),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            existing == null
                                ? 'Add Vaccination'
                                : 'Edit Vaccination',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // ─────────────────────────────────────────────────────
                      // QUICK ADD
                      // ─────────────────────────────────────────────────────

                      if (existing == null) ...[
                        const _SLabel(
                          'Quick Add (core vaccines & care)',
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _kVaccineTemplates.map((template) {
                            final label = template['label'] as String;

                            final days = template['days'] as int;

                            return GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  nameController.text = label;

                                  if (nextSchedule == null) {
                                    nextSchedule = completedDate.add(
                                      Duration(days: days),
                                    );

                                    reminderEnabled = true;
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF7B68EE)
                                      .withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFF7B68EE)
                                        .withValues(alpha: 0.30),
                                  ),
                                ),
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF7B68EE),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ─────────────────────────────────────────────────────
                      // VACCINE NAME
                      // ─────────────────────────────────────────────────────

                      _field(
                        nameController,
                        'Vaccine Name *',
                        Icons.medical_services,
                        const Color(0xFF7B68EE),
                      ),

                      const SizedBox(height: 12),

                      // ─────────────────────────────────────────────────────
                      // COMPLETION DATE
                      // ─────────────────────────────────────────────────────

                      const _SLabel('Completion Date'),

                      const SizedBox(height: 6),

                      _dateTile(
                        label: DateFormat(
                          'MMM d, yyyy',
                        ).format(completedDate),
                        icon: Icons.check_circle_outline,
                        color: const Color(0xFF32CD32),
                        onTap: () async {
                          final selected = await _pickDate(
                            dialogContext,
                            initial: completedDate,
                            first: DateTime(2000),
                            last: DateTime.now(),
                          );

                          if (selected != null) {
                            setDialogState(() {
                              completedDate = selected;
                            });
                          }
                        },
                      ),

                      const SizedBox(height: 12),

                      // ─────────────────────────────────────────────────────
                      // SINGLE NEXT SCHEDULE
                      // ─────────────────────────────────────────────────────

                      if (!useRecurringSchedule) ...[
                        const _SLabel(
                          'Next Schedule (optional)',
                        ),
                        const SizedBox(height: 6),
                        _dateTile(
                          label: nextSchedule != null
                              ? DateFormat(
                                  'MMM d, yyyy',
                                ).format(nextSchedule!)
                              : 'Tap to set next date',
                          icon: Icons.calendar_month,
                          color: const Color(0xFF7B68EE),
                          dimmed: nextSchedule == null,
                          onTap: () async {
                            final selected = await _pickDate(
                              dialogContext,
                              initial: nextSchedule ?? DateTime.now(),
                              first: DateTime.now(),
                              last: DateTime(2100),
                            );

                            if (selected != null) {
                              setDialogState(() {
                                nextSchedule = selected;
                                reminderEnabled = true;
                              });
                            }
                          },
                          trailing: nextSchedule != null
                              ? GestureDetector(
                                  onTap: () {
                                    setDialogState(() {
                                      nextSchedule = null;
                                      reminderEnabled = false;
                                    });
                                  },
                                  child: const Icon(
                                    Icons.close,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 12),
                      ],

                      // ─────────────────────────────────────────────────────
                      // RECURRING SERIES
                      // ─────────────────────────────────────────────────────

                      if (existing == null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF20B2AA)
                                  .withValues(alpha: 0.30),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.repeat,
                                    size: 18,
                                    color: Color(0xFF20B2AA),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Text(
                                      'Set up a recurring dose series',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  Switch(
                                    value: useRecurringSchedule,
                                    onChanged: (value) {
                                      setDialogState(() {
                                        useRecurringSchedule = value;

                                        // If switching to recurring,
                                        // don't leave a misleading
                                        // single-dose reminder active.
                                        if (value) {
                                          nextSchedule = null;
                                          reminderEnabled = false;
                                        }
                                      });
                                    },
                                    activeColor: const Color(0xFF20B2AA),
                                  ),
                                ],
                              ),
                              if (useRecurringSchedule) ...[
                                const SizedBox(height: 10),
                                DropdownButtonFormField<String>(
                                  value: recurrenceType,
                                  decoration: _fieldDeco(
                                    'Repeats',
                                    Icons.event_repeat,
                                    const Color(0xFF20B2AA),
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                      value: 'everyXDays',
                                      child: Text('Every X days'),
                                    ),
                                    DropdownMenuItem(
                                      value: 'annual',
                                      child: Text('Annual'),
                                    ),
                                  ],
                                  onChanged: (value) {
                                    setDialogState(() {
                                      recurrenceType = value ?? 'everyXDays';
                                    });
                                  },
                                ),
                                const SizedBox(height: 10),
                                if (recurrenceType == 'everyXDays')
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: intervalController,
                                          keyboardType: TextInputType.number,
                                          decoration: _fieldDeco(
                                            'Interval (days)',
                                            Icons.timer,
                                            const Color(0xFF20B2AA),
                                          ),
                                          style: const TextStyle(
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextField(
                                          controller: totalDosesController,
                                          keyboardType: TextInputType.number,
                                          decoration: _fieldDeco(
                                            'Total doses',
                                            Icons.numbers,
                                            const Color(0xFF20B2AA),
                                          ),
                                          style: const TextStyle(
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                else
                                  TextField(
                                    controller: totalDosesController,
                                    keyboardType: TextInputType.number,
                                    decoration: _fieldDeco(
                                      'Repeat for how many years',
                                      Icons.numbers,
                                      const Color(0xFF20B2AA),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 13,
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                const Text(
                                  'This automatically creates the '
                                  'follow-up doses and their reminders.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // ─────────────────────────────────────────────────────
                      // VET NOTES
                      // ─────────────────────────────────────────────────────

                      TextField(
                        controller: notesController,
                        maxLines: 3,
                        decoration: _fieldDeco(
                          'Vet Notes',
                          Icons.notes,
                          const Color(0xFF7B68EE),
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // ─────────────────────────────────────────────────────
                      // REMINDER TOGGLE
                      // ─────────────────────────────────────────────────────

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color:
                                const Color(0xFF7B68EE).withValues(alpha: 0.20),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.notifications_active,
                              size: 18,
                              color: Color(0xFF7B68EE),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Sync to Care Reminders',
                                style: TextStyle(
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Switch(
                              value: useRecurringSchedule
                                  ? seriesReminderEnabled
                                  : (reminderEnabled && nextSchedule != null),
                              onChanged: useRecurringSchedule
                                  ? (value) {
                                      setDialogState(() {
                                        seriesReminderEnabled = value;
                                      });
                                    }
                                  : nextSchedule == null
                                      ? null
                                      : (value) {
                                          setDialogState(() {
                                            reminderEnabled = value;
                                          });
                                        },
                              activeColor: const Color(0xFF7B68EE),
                            ),
                          ],
                        ),
                      ),

                      if (!useRecurringSchedule && nextSchedule == null) ...[
                        const SizedBox(height: 6),
                        const Text(
                          'Set a next schedule date to enable a reminder.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),

                      // ─────────────────────────────────────────────────────
                      // ACTIONS
                      // ─────────────────────────────────────────────────────

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                            },
                            child: const Text(
                              'Cancel',
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7B68EE),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: Icon(
                              existing == null ? Icons.add : Icons.save,
                              size: 16,
                            ),
                            label: Text(
                              existing == null ? 'Add' : 'Save',
                            ),
                            onPressed: () async {
                              // ───────────────────────────────────────────
                              // VALIDATION
                              // ───────────────────────────────────────────

                              final vaccineName = nameController.text.trim();

                              if (vaccineName.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Vaccine name is required.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              // ───────────────────────────────────────────
                              // RECURRING SERIES
                              // ───────────────────────────────────────────

                              if (existing == null && useRecurringSchedule) {
                                final parsedInterval = int.tryParse(
                                      intervalController.text.trim(),
                                    ) ??
                                    7;

                                final parsedTotal = int.tryParse(
                                      totalDosesController.text.trim(),
                                    ) ??
                                    1;

                                final interval = parsedInterval.clamp(
                                  1,
                                  3650,
                                );

                                final totalDoses = parsedTotal.clamp(
                                  1,
                                  60,
                                );

                                Navigator.pop(dialogContext);

                                await _provider.addVaccinationSeries(
                                  petId: widget.petId,
                                  vaccineName: vaccineName,
                                  firstGivenDate: completedDate,
                                  vetNotes: notesController.text.trim(),
                                  recurrenceType: recurrenceType,
                                  intervalDays: recurrenceType == 'everyXDays'
                                      ? interval
                                      : null,
                                  totalDoses: totalDoses,
                                  reminderEnabled: seriesReminderEnabled,
                                  reminderProvider:
                                      context.read<ReminderProvider>(),
                                );

                                return;
                              }

                              // ───────────────────────────────────────────
                              // SINGLE VACCINATION
                              // ───────────────────────────────────────────

                              final recordId = existing?.id ?? _uuid.v4();

                              final effectiveReminderEnabled =
                                  nextSchedule != null && reminderEnabled;

                              // Close dialog first.
                              Navigator.pop(dialogContext);

                              // ───────────────────────────────────────────
                              // CREATE
                              // ───────────────────────────────────────────

                              if (existing == null) {
                                await _provider.addVaccination(
                                  widget.petId,
                                  VaccinationRecord(
                                    id: recordId,
                                    vaccineName: vaccineName,
                                    completedDate: completedDate,
                                    nextSchedule: nextSchedule,
                                    vetNotes: notesController.text.trim(),
                                    reminderEnabled: effectiveReminderEnabled,
                                  ),
                                );
                              }

                              // ───────────────────────────────────────────
                              // UPDATE
                              // ───────────────────────────────────────────

                              else {
                                await _provider.updateVaccination(
                                  widget.petId,
                                  existing.copyWith(
                                    vaccineName: vaccineName,
                                    completedDate: completedDate,
                                    nextSchedule: nextSchedule,
                                    vetNotes: notesController.text.trim(),
                                    reminderEnabled: effectiveReminderEnabled,
                                  ),
                                );
                              }

                              // ───────────────────────────────────────────
                              // SYNC REMINDER
                              // ───────────────────────────────────────────

                              await _syncReminder(
                                recordId: recordId,
                                vaccineName: vaccineName,
                                nextSchedule: nextSchedule,
                                reminderEnabled: effectiveReminderEnabled,
                                existingLinkedReminderId:
                                    existingLinkedReminderId,
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      nameController.dispose();
      notesController.dispose();
      intervalController.dispose();
      totalDosesController.dispose();
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DATE PICKER
  // ─────────────────────────────────────────────────────────────────────────

  Future<DateTime?> _pickDate(
    BuildContext ctx, {
    required DateTime initial,
    required DateTime first,
    required DateTime last,
  }) {
    final safeInitial = initial.isBefore(first)
        ? first
        : initial.isAfter(last)
            ? last
            : initial;

    return showDatePicker(
      context: ctx,
      initialDate: safeInitial,
      firstDate: first,
      lastDate: last,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF7B68EE),
            ),
          ),
          child: child!,
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DELETE
  // ─────────────────────────────────────────────────────────────────────────

  void _confirmDelete(VaccinationRecord record) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          backgroundColor: const Color(0xFFFFF5EE),
          title: const Text(
            'Delete Record?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Remove "${record.vaccineName}" vaccination record?'
            '${record.linkedReminderId != null ? ' Its linked reminder will also be removed.' : ''}',
            style: const TextStyle(
              fontSize: 13,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                Navigator.pop(dialogContext);

                try {
                  // Delete linked reminder first.
                  if (record.linkedReminderId != null &&
                      record.linkedReminderId!.isNotEmpty) {
                    await context.read<ReminderProvider>().deleteReminder(
                          record.linkedReminderId!,
                        );
                  }

                  // Then delete vaccination.
                  await _provider.deleteVaccination(
                    widget.petId,
                    record.id,
                  );
                } catch (e) {
                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Could not delete vaccination: $e',
                      ),
                    ),
                  );
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pet = _pet;

    if (pet == null) {
      return const Scaffold(
        body: Center(
          child: Text('Profile not found.'),
        ),
      );
    }

    // ───────────────────────────────────────────────────────────────────────
    // SORT RECORDS
    //
    // 0 = overdue
    // 1 = planned/upcoming
    // 2 = has next schedule
    // 3 = completed/history
    // ───────────────────────────────────────────────────────────────────────

    final records = List<VaccinationRecord>.from(pet.vaccinations);

    records.sort((a, b) {
      int rank(VaccinationRecord record) {
        if (record.isOverdue) {
          return 0;
        }

        if (record.isPlanned) {
          return 1;
        }

        if (record.nextSchedule != null) {
          return 2;
        }

        return 3;
      }

      final rankA = rank(a);
      final rankB = rank(b);

      if (rankA != rankB) {
        return rankA.compareTo(rankB);
      }

      if (rankA == 0 || rankA == 1 || rankA == 2) {
        final dateA = a.nextSchedule;
        final dateB = b.nextSchedule;

        if (dateA != null && dateB != null) {
          return dateA.compareTo(dateB);
        }

        return 0;
      }

      return b.completedDate.compareTo(
        a.completedDate,
      );
    });

    final overdueCount = records.where((record) => record.isOverdue).length;

    final upcomingCount = records.where((record) {
      return record.isPlanned ||
          (!record.isOverdue && record.nextSchedule != null);
    }).length;

    return Scaffold(
      backgroundColor: const Color(0xFFFFE6CC),
      body: Stack(
        children: [
          // ─────────────────────────────────────────────────────────────────
          // BACKGROUND
          // ─────────────────────────────────────────────────────────────────

          Positioned.fill(
            child: Opacity(
              opacity: 0.10,
              child: Image.asset(
                'assets/images/paws_bg.png',
                fit: BoxFit.cover,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ───────────────────────────────────────────────────────────
                // HEADER
                // ───────────────────────────────────────────────────────────

                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new,
                          size: 20,
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                      const Text(
                        '💉 ',
                        style: TextStyle(
                          fontSize: 18,
                        ),
                      ),
                      const Expanded(
                        child: Text(
                          'Vaccinations',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (overdueCount > 0)
                        _headerBadge(
                          '$overdueCount overdue',
                          Colors.redAccent,
                        ),
                    ],
                  ),
                ),

                // ───────────────────────────────────────────────────────────
                // STATS
                // ───────────────────────────────────────────────────────────

                if (records.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        _statChip(
                          '${records.length}',
                          'Total',
                          const Color(0xFF7B68EE),
                        ),
                        const SizedBox(width: 8),
                        _statChip(
                          '$upcomingCount',
                          'Upcoming',
                          const Color(0xFF20B2AA),
                        ),
                        const SizedBox(width: 8),
                        _statChip(
                          '$overdueCount',
                          'Overdue',
                          Colors.redAccent,
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 4),

                // ───────────────────────────────────────────────────────────
                // LIST
                // ───────────────────────────────────────────────────────────

                Expanded(
                  child: records.isEmpty
                      ? _emptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(
                            16,
                            8,
                            16,
                            100,
                          ),
                          itemCount: records.length,
                          itemBuilder: (_, index) {
                            final record = records[index];

                            return _VaccineCard(
                              record: record,
                              onEdit: () {
                                _showDialog(
                                  existing: record,
                                );
                              },
                              onDelete: () {
                                _confirmDelete(record);
                              },
                              onMarkGiven: () {
                                showVaccinationCompleteDialog(
                                  context,
                                  petId: widget.petId,
                                  record: record,
                                );
                              },
                              onReminderToggle: () async {
                                await _toggleReminder(record);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),

      // ─────────────────────────────────────────────────────────────────────
      // ADD BUTTON
      // ─────────────────────────────────────────────────────────────────────

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _showDialog();
        },
        backgroundColor: const Color(0xFF7B68EE),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text(
          'Add Record',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REMINDER TOGGLE FROM CARD
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _toggleReminder(
    VaccinationRecord record,
  ) async {
    // A reminder cannot exist without a date.
    if (record.nextSchedule == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Set a next schedule date before enabling the reminder.',
          ),
        ),
      );

      return;
    }

    final newValue = !record.reminderEnabled;

    try {
      // Update record state first.
      await _provider.updateVaccination(
        widget.petId,
        record.copyWith(
          reminderEnabled: newValue,
        ),
      );

      // Synchronize Care Reminders.
      await _syncReminder(
        recordId: record.id,
        vaccineName: record.vaccineName,
        nextSchedule: record.nextSchedule,
        reminderEnabled: newValue,
        existingLinkedReminderId: record.linkedReminderId,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not update reminder: $e',
          ),
        ),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HEADER BADGE
  // ─────────────────────────────────────────────────────────────────────────

  Widget _headerBadge(
    String text,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STAT CHIP
  // ─────────────────────────────────────────────────────────────────────────

  Widget _statChip(
    String count,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EMPTY STATE
  // ─────────────────────────────────────────────────────────────────────────

  Widget _emptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: 0.35,
            child: Icon(
              Icons.vaccines,
              size: 80,
              color: Color(0xFF7B68EE),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'No vaccination records yet.',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFFAA7755),
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Tap + to add your first vaccine record.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TEXT FIELD
  // ─────────────────────────────────────────────────────────────────────────

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon,
    Color color,
  ) {
    return TextField(
      controller: controller,
      decoration: _fieldDeco(
        label,
        icon,
        color,
      ),
      style: const TextStyle(
        fontSize: 13,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // INPUT DECORATION
  // ─────────────────────────────────────────────────────────────────────────

  InputDecoration _fieldDeco(
    String label,
    IconData icon,
    Color color,
  ) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        fontSize: 12,
        color: color.withValues(alpha: 0.8),
      ),
      prefixIcon: Icon(
        icon,
        size: 16,
        color: color,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(
          color: color.withValues(alpha: 0.65),
          width: 1.2,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DATE TILE
  // ─────────────────────────────────────────────────────────────────────────

  Widget _dateTile({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool dimmed = false,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: dimmed ? Colors.grey : Colors.black87,
                ),
              ),
            ),
            trailing ?? const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DUE DATE LABEL
// ─────────────────────────────────────────────────────────────────────────────

String _dueLabel(DateTime next) {
  final now = DateTime.now();

  final today = DateTime(
    now.year,
    now.month,
    now.day,
  );

  final target = DateTime(
    next.year,
    next.month,
    next.day,
  );

  final days = target.difference(today).inDays;

  if (days < 0) {
    final amount = -days;

    return 'Overdue by $amount '
        'day${amount == 1 ? '' : 's'}';
  }

  if (days == 0) {
    return 'Due today';
  }

  if (days == 1) {
    return 'Due tomorrow';
  }

  return 'Due in $days days';
}

// ─────────────────────────────────────────────────────────────────────────────
// VACCINATION CARD
// ─────────────────────────────────────────────────────────────────────────────

class _VaccineCard extends StatelessWidget {
  final VaccinationRecord record;

  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onReminderToggle;
  final VoidCallback onMarkGiven;

  const _VaccineCard({
    required this.record,
    required this.onEdit,
    required this.onDelete,
    required this.onReminderToggle,
    required this.onMarkGiven,
  });

  @override
  Widget build(BuildContext context) {
    final isOverdue = record.isOverdue;

    final hasNext = record.nextSchedule != null;

    final isPlanned = record.isPlanned;

    final hasDoseInfo =
        record.doseNumber != null && record.totalDosesInSeries != null;

    Color? borderColor;

    if (isOverdue) {
      borderColor = Colors.redAccent.withValues(alpha: 0.5);
    } else if (isPlanned) {
      borderColor = const Color(0xFF20B2AA).withValues(alpha: 0.4);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(16),
        border: borderColor != null
            ? Border.all(
                color: borderColor,
                width: 1.5,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ───────────────────────────────────────────────────────────────
            // TOP ROW
            // ───────────────────────────────────────────────────────────────

            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B68EE).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: Text(
                      '💉',
                      style: TextStyle(fontSize: 22),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.vaccineName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isPlanned
                            ? 'Planned: ${DateFormat('MMM d, yyyy').format(record.completedDate)}'
                            : 'Given: ${DateFormat('MMM d, yyyy').format(record.completedDate)}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      if (hasDoseInfo) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Dose ${record.doseNumber} '
                          'of ${record.totalDosesInSeries}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF20B2AA),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // ─────────────────────────────────────────────────────────
                // STATUS
                // ─────────────────────────────────────────────────────────

                if (isPlanned)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF20B2AA).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Planned',
                      style: TextStyle(
                        fontSize: 10,
                        color: Color(0xFF20B2AA),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else if (isOverdue)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Overdue',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),

            // ───────────────────────────────────────────────────────────────
            // NEXT SCHEDULE
            // ───────────────────────────────────────────────────────────────

            if (hasNext) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isOverdue
                      ? Colors.redAccent.withValues(alpha: 0.08)
                      : const Color(0xFF7B68EE).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_month,
                      size: 13,
                      color: isOverdue
                          ? Colors.redAccent
                          : const Color(
                              0xFF7B68EE,
                            ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${DateFormat('MMM d, yyyy').format(record.nextSchedule!)}'
                        ' · '
                        '${_dueLabel(record.nextSchedule!)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isOverdue
                              ? Colors.redAccent
                              : const Color(
                                  0xFF7B68EE,
                                ),
                        ),
                      ),
                    ),
                    if (record.linkedReminderId != null)
                      Icon(
                        Icons.notifications_active,
                        size: 13,
                        color: isOverdue
                            ? Colors.redAccent
                            : const Color(
                                0xFF7B68EE,
                              ),
                      ),
                  ],
                ),
              ),
            ],

            // ───────────────────────────────────────────────────────────────
            // NOTES
            // ───────────────────────────────────────────────────────────────

            if (record.vetNotes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                record.vetNotes,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF7A5C3A),
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 8),

            const Divider(height: 1),

            const SizedBox(height: 6),

            // ───────────────────────────────────────────────────────────────
            // BOTTOM ACTIONS
            // ───────────────────────────────────────────────────────────────

            Row(
              children: [
                // Reminder control.
                if (!isPlanned) ...[
                  const Icon(
                    Icons.notifications_outlined,
                    size: 14,
                    color: Color(0xFF7B68EE),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Reminder',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF7B68EE),
                    ),
                  ),
                  Transform.scale(
                    scale: 0.75,
                    child: Switch(
                      value: record.reminderEnabled && hasNext,
                      onChanged: hasNext ? (_) => onReminderToggle() : null,
                      activeColor: const Color(0xFF7B68EE),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ] else ...[
                  Icon(
                    Icons.notifications_active,
                    size: 14,
                    color: record.linkedReminderId != null
                        ? const Color(0xFF20B2AA)
                        : Colors.grey,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    record.linkedReminderId != null
                        ? 'Reminder set'
                        : 'No reminder',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ],

                const Spacer(),

                // Mark Given.
                if (hasNext || isPlanned) ...[
                  _pillBtn(
                    'Mark Given',
                    Icons.check,
                    const Color(0xFF32CD32),
                    onMarkGiven,
                  ),
                  const SizedBox(width: 6),
                ],

                // Edit.
                _actionBtn(
                  Icons.edit_outlined,
                  const Color(0xFF4682B4),
                  onEdit,
                ),

                const SizedBox(width: 6),

                // Delete.
                _actionBtn(
                  Icons.delete_outline,
                  Colors.redAccent,
                  onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PILL BUTTON
  // ─────────────────────────────────────────────────────────────────────────

  Widget _pillBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: color.withValues(
            alpha: 0.12,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTION BUTTON
  // ─────────────────────────────────────────────────────────────────────────

  Widget _actionBtn(
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(
            alpha: 0.10,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 16,
          color: color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL SECTION LABEL
// ─────────────────────────────────────────────────────────────────────────────

class _SLabel extends StatelessWidget {
  final String text;

  const _SLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFFAA7755),
      ),
    );
  }
}
