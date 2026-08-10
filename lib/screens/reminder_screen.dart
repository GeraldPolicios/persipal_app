// lib/screens/reminder_screen.dart
//
// Reminder system for real Persian cat profiles.
//
// Features:
//  • Reminders can belong to a specific cat (petId)
//  • Multi-cat filter: All Pets / individual cat
//  • Recurring reminders: daily / weekly / monthly
//  • Snooze: +1 hour / +1 day / +1 week
//  • Vaccine-linked reminders use the shared vaccination completion flow
//  • Vaccine-linked reminders cannot have their linked data edited here

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:persipal_app/providers/reminder_provider.dart';
import 'package:persipal_app/models/reminder_item_model.dart';

import '../providers/pet_profile_provider.dart';
import '../models/pet_extended_models.dart';
import '../widgets/vaccination_complete_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Type configuration
// ─────────────────────────────────────────────────────────────────────────────

const _kTypes = [
  {
    'label': 'Feeding',
    'emoji': '🍗',
    'color': Color(0xFFFF8C69),
  },
  {
    'label': 'Grooming',
    'emoji': '✂️',
    'color': Color(0xFF7B68EE),
  },
  {
    'label': 'Vitamins',
    'emoji': '💊',
    'color': Color(0xFF32CD32),
  },
  {
    'label': 'Exercise',
    'emoji': '🎾',
    'color': Color(0xFF20B2AA),
  },
  {
    'label': 'Vet Visit',
    'emoji': '🏥',
    'color': Color(0xFFDC143C),
  },
  {
    'label': 'Litter Box',
    'emoji': '🧹',
    'color': Color(0xFF9370DB),
  },
  {
    'label': 'Other',
    'emoji': '📌',
    'color': Color(0xFF4682B4),
  },
];

const _kRecurrences = [
  {
    'label': 'None',
    'value': 'none',
  },
  {
    'label': 'Daily',
    'value': 'daily',
  },
  {
    'label': 'Weekly',
    'value': 'weekly',
  },
  {
    'label': 'Monthly',
    'value': 'monthly',
  },
];

Map<String, dynamic> _typeConfig(String label) {
  return _kTypes.firstWhere(
    (type) => type['label'] == label,
    orElse: () => _kTypes.last,
  );
}

String _recurrenceLabel(String value) {
  return _kRecurrences.firstWhere(
    (recurrence) => recurrence['value'] == value,
    orElse: () => _kRecurrences.first,
  )['label'] as String;
}

// ─────────────────────────────────────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────────────────────────────────────

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen>
    with SingleTickerProviderStateMixin {
  final _petProvider = PetProfileProvider.instance;

  late TabController _tab;

  // null = All Pets
  String? _filterPetId;

  @override
  void initState() {
    super.initState();

    _tab = TabController(
      length: 2,
      vsync: this,
    );

    _petProvider.addListener(_refresh);
  }

  @override
  void dispose() {
    _tab.dispose();
    _petProvider.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {});
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Pet helpers
  // ───────────────────────────────────────────────────────────────────────────

  List<FullPetProfile> get _pets {
    return _petProvider.profiles;
  }

  List<ReminderItem> _filtered(List<ReminderItem> all) {
    if (_filterPetId == null) {
      return List<ReminderItem>.from(all);
    }

    return all.where((reminder) {
      return reminder.petId == _filterPetId;
    }).toList();
  }

  List<ReminderItem> _pendingFrom(List<ReminderItem> all) {
    final result =
        _filtered(all).where((reminder) => !reminder.isDone).toList();

    result.sort(
      (a, b) => a.scheduledAt.compareTo(b.scheduledAt),
    );

    return result;
  }

  List<ReminderItem> _doneFrom(List<ReminderItem> all) {
    final result = _filtered(all).where((reminder) => reminder.isDone).toList();

    result.sort(
      (a, b) => b.scheduledAt.compareTo(a.scheduledAt),
    );

    return result;
  }

  FullPetProfile? _petFor(String? petId) {
    if (petId == null) {
      return null;
    }

    return _petProvider.getById(petId);
  }

  VaccinationRecord? _vaccinationFor(ReminderItem item) {
    if (item.petId == null) {
      return null;
    }

    if (item.linkedVaccinationId == null) {
      return null;
    }

    final pet = _petProvider.getById(item.petId!);

    if (pet == null) {
      return null;
    }

    for (final vaccination in pet.vaccinations) {
      if (vaccination.id == item.linkedVaccinationId) {
        return vaccination;
      }
    }

    return null;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Mark reminder done
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _handleMarkDone(ReminderItem item) async {
    final vaccination = _vaccinationFor(item);

    // Vaccine-linked reminder.
    if (vaccination != null && item.petId != null) {
      await showVaccinationCompleteDialog(
        context,
        petId: item.petId!,
        record: vaccination,
      );

      return;
    }

    final reminders = context.read<ReminderProvider>();

    await reminders.markReminderDone(item.id);

    // Recurring reminders automatically create the next occurrence.
    if (item.recurrence != 'none') {
      await reminders.scheduleNextOccurrence(item);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Nice! Next ${item.title} reminder scheduled automatically.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF32CD32),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Snooze
  // ───────────────────────────────────────────────────────────────────────────

  void _snooze(
    ReminderItem item,
    Duration by,
  ) {
    final reminders = context.read<ReminderProvider>();

    reminders.updateReminder(
      item.copyWith(
        scheduledAt: item.scheduledAt.add(by),
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Snoozed "${item.title}".',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Add / Edit reminder dialog
  // ───────────────────────────────────────────────────────────────────────────

  void _showDialog({
    ReminderItem? editing,
  }) {
    final titleCtrl = TextEditingController(
      text: editing?.title ?? '',
    );

    String selectedType = editing?.type ?? 'Feeding';

    DateTime? pickedDt = editing?.scheduledAt;

    String recurrence = editing?.recurrence ?? 'none';

    String? selectedPetId = editing?.petId ??
        (_filterPetId ?? (_pets.length == 1 ? _pets.first.id : null));

    final bool isVaccineLinked = editing?.linkedVaccinationId != null;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setD) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              backgroundColor: const Color(0xFFFFF8F2),
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 30,
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ────────────────────────────────────────────────
                      // Title bar
                      // ────────────────────────────────────────────────

                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF8C69)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.alarm_add,
                              color: Color(0xFFFF8C69),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              editing == null
                                  ? 'New Reminder'
                                  : 'Edit Reminder',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 18),

                      // ────────────────────────────────────────────────
                      // Title
                      // ────────────────────────────────────────────────

                      _dialogField(
                        titleCtrl,
                        'What to remind?',
                        Icons.notes,
                        enabled: !isVaccineLinked,
                      ),

                      const SizedBox(height: 14),

                      // ────────────────────────────────────────────────
                      // Pet picker
                      // ────────────────────────────────────────────────

                      if (_pets.isNotEmpty) ...[
                        const Text(
                          'For which cat?',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFAA7755),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final pet in _pets)
                              GestureDetector(
                                onTap: isVaccineLinked
                                    ? null
                                    : () {
                                        setD(() {
                                          selectedPetId = pet.id;
                                        });
                                      },
                                child: AnimatedContainer(
                                  duration: const Duration(
                                    milliseconds: 150,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selectedPetId == pet.id
                                        ? pet.avatarColor
                                        : pet.avatarColor
                                            .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    pet.name,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: selectedPetId == pet.id
                                          ? Colors.white
                                          : Colors.black87,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],

                      // ────────────────────────────────────────────────
                      // Type
                      // ────────────────────────────────────────────────

                      const Text(
                        'Type',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFAA7755),
                        ),
                      ),

                      const SizedBox(height: 8),

                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _kTypes.map((type) {
                          final label = type['label'] as String;
                          final emoji = type['emoji'] as String;
                          final color = type['color'] as Color;

                          final isSelected = selectedType == label;

                          return GestureDetector(
                            onTap: isVaccineLinked
                                ? null
                                : () {
                                    setD(() {
                                      selectedType = label;
                                    });
                                  },
                            child: AnimatedContainer(
                              duration: const Duration(
                                milliseconds: 150,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? color
                                    : color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color:
                                      isSelected ? color : Colors.transparent,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    emoji,
                                    style: const TextStyle(
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    label,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected ? Colors.white : color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),

                      const SizedBox(height: 14),

                      // ────────────────────────────────────────────────
                      // Date & Time
                      // ────────────────────────────────────────────────

                      const Text(
                        'Date & Time',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFAA7755),
                        ),
                      ),

                      const SizedBox(height: 8),

                      GestureDetector(
                        onTap: isVaccineLinked
                            ? null
                            : () async {
                                final date = await showDatePicker(
                                  context: ctx,
                                  initialDate: pickedDt ?? DateTime.now(),
                                  firstDate: DateTime.now().subtract(
                                    const Duration(days: 1),
                                  ),
                                  lastDate: DateTime(2100),
                                  builder: (c, child) {
                                    return Theme(
                                      data: Theme.of(c).copyWith(
                                        colorScheme: const ColorScheme.light(
                                          primary: Color(0xFFFF8C69),
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );

                                if (date == null) return;

                                final time = await showTimePicker(
                                  context: ctx,
                                  initialTime: pickedDt != null
                                      ? TimeOfDay.fromDateTime(
                                          pickedDt!,
                                        )
                                      : TimeOfDay.now(),
                                  builder: (c, child) {
                                    return Theme(
                                      data: Theme.of(c).copyWith(
                                        colorScheme: const ColorScheme.light(
                                          primary: Color(0xFFFF8C69),
                                        ),
                                      ),
                                      child: child!,
                                    );
                                  },
                                );

                                if (time == null) return;

                                setD(() {
                                  pickedDt = DateTime(
                                    date.year,
                                    date.month,
                                    date.day,
                                    time.hour,
                                    time.minute,
                                  );
                                });
                              },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFFF8C69)
                                  .withValues(alpha: 0.4),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 18,
                                color: Color(0xFFFF8C69),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  pickedDt == null
                                      ? 'Pick date & time'
                                      : DateFormat(
                                          'MMM d, yyyy  •  hh:mm a',
                                        ).format(pickedDt!),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: pickedDt == null
                                        ? Colors.grey
                                        : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ────────────────────────────────────────────────
                      // Recurrence
                      // ────────────────────────────────────────────────

                      if (!isVaccineLinked) ...[
                        const Text(
                          'Repeat',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFAA7755),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _kRecurrences.map((item) {
                            final value = item['value'] as String;
                            final label = item['label'] as String;

                            final isSelected = recurrence == value;

                            const recurrenceColor = Color(0xFF20B2AA);

                            return GestureDetector(
                              onTap: () {
                                setD(() {
                                  recurrence = value;
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? recurrenceColor
                                      : recurrenceColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? Colors.white
                                        : recurrenceColor,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                      ] else ...[
                        // Vaccine-linked information.
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFFDC143C).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.link,
                                size: 15,
                                color: Color(0xFFDC143C),
                              ),
                              SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  'This reminder is linked to a vaccination record. '
                                  'Edit the date from the Vaccinations screen.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFFDC143C),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 8),
                      ],

                      // ────────────────────────────────────────────────
                      // Actions
                      // ────────────────────────────────────────────────

                      const SizedBox(height: 8),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                            },
                            child: const Text(
                              'Cancel',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF8C69),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              final title = titleCtrl.text.trim();

                              if (title.isEmpty || pickedDt == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Please fill in title & date/time.',
                                    ),
                                  ),
                                );
                                return;
                              }

                              final reminders =
                                  context.read<ReminderProvider>();

                              if (editing == null) {
                                // New reminder.
                                reminders.addReminder(
                                  ReminderItem(
                                    id: DateTime.now()
                                        .microsecondsSinceEpoch
                                        .toString(),
                                    title: title,
                                    type: selectedType,
                                    scheduledAt: pickedDt!,
                                    petId: selectedPetId,
                                    recurrence: recurrence,
                                  ),
                                );
                              } else {
                                // Edit existing reminder.
                                //
                                // Vaccine-linked reminders are normally
                                // not editable because their date/data
                                // should be controlled by Vaccinations.
                                reminders.updateReminder(
                                  editing.copyWith(
                                    title: title,
                                    type: selectedType,
                                    scheduledAt: pickedDt!,
                                    petId: selectedPetId,
                                    recurrence: recurrence,
                                  ),
                                );
                              }

                              Navigator.pop(ctx);
                            },
                            child: Text(
                              editing == null ? 'Add' : 'Save',
                            ),
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
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Dialog text field
  // ───────────────────────────────────────────────────────────────────────────

  Widget _dialogField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    bool enabled = true,
  }) {
    return TextField(
      controller: ctrl,
      enabled: enabled,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(
          icon,
          size: 18,
          color: const Color(0xFFFF8C69),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: const Color(0xFFFF8C69).withValues(alpha: 0.3),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: const Color(0xFFFF8C69).withValues(alpha: 0.25),
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: Colors.grey.withValues(alpha: 0.2),
          ),
        ),
      ),
      style: const TextStyle(fontSize: 14),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Build
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final allReminders = context.watch<ReminderProvider>().reminders;

    final pending = _pendingFrom(allReminders);
    final done = _doneFrom(allReminders);

    return Scaffold(
      backgroundColor: const Color(0xFFFFE6CC),
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Opacity(
              opacity: 0.12,
              child: Image.asset(
                'assets/images/paws_bg.png',
                fit: BoxFit.cover,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ────────────────────────────────────────────────
                // Header
                // ────────────────────────────────────────────────

                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    8,
                    4,
                    16,
                    0,
                  ),
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
                      const Icon(
                        Icons.alarm,
                        size: 26,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Care Reminders',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Add reminder',
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF8C69),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.add,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        onPressed: () {
                          _showDialog();
                        },
                      ),
                    ],
                  ),
                ),

                // ────────────────────────────────────────────────
                // Pet filter
                // ────────────────────────────────────────────────

                if (_pets.length > 1)
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      children: [
                        _petFilterChip(
                          'All Pets',
                          null,
                          const Color(0xFFAA7755),
                        ),
                        const SizedBox(width: 6),
                        for (final pet in _pets) ...[
                          _petFilterChip(
                            pet.name,
                            pet.id,
                            pet.avatarColor,
                          ),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ),

                const SizedBox(height: 8),

                // ────────────────────────────────────────────────
                // Stats
                // ────────────────────────────────────────────────

                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Row(
                    children: [
                      _statChip(
                        '${pending.length}',
                        'Pending',
                        const Color(0xFFFF8C69),
                      ),
                      const SizedBox(width: 10),
                      _statChip(
                        '${done.length}',
                        'Done',
                        const Color(0xFF32CD32),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ────────────────────────────────────────────────
                // Tabs
                // ────────────────────────────────────────────────

                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: TabBar(
                    controller: _tab,
                    indicator: BoxDecoration(
                      color: const Color(0xFFFF8C69),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: Colors.white,
                    unselectedLabelColor: const Color(0xFFAA7755),
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(
                        text: '⏰  Upcoming',
                      ),
                      Tab(
                        text: '✅  Done',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                // ────────────────────────────────────────────────
                // Lists
                // ────────────────────────────────────────────────

                Expanded(
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _buildList(
                        pending,
                        done: false,
                      ),
                      _buildList(
                        done,
                        done: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Pet filter chip
  // ───────────────────────────────────────────────────────────────────────────

  Widget _petFilterChip(
    String label,
    String? petId,
    Color color,
  ) {
    final isSelected = _filterPetId == petId;

    return GestureDetector(
      onTap: () {
        setState(() {
          _filterPetId = petId;
        });
      },
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Stat chip
  // ───────────────────────────────────────────────────────────────────────────

  Widget _statChip(
    String count,
    String label,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Text(
            count,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: 15,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Reminder list
  // ───────────────────────────────────────────────────────────────────────────

  Widget _buildList(
    List<ReminderItem> items, {
    required bool done,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: 0.35,
              child: Icon(
                done ? Icons.check_circle_outline : Icons.alarm_off,
                size: 70,
                color: const Color(0xFFFF8C69),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              done ? 'No completed reminders yet.' : 'No upcoming reminders!',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFFAA7755),
              ),
            ),
            if (!done) ...[
              const SizedBox(height: 6),
              const Text(
                'Tap + to add your first reminder.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        16,
        4,
        16,
        24,
      ),
      itemCount: items.length,
      itemBuilder: (_, index) {
        return _reminderCard(items[index]);
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Reminder card
  // ───────────────────────────────────────────────────────────────────────────

  Widget _reminderCard(ReminderItem item) {
    final cfg = _typeConfig(item.type);

    final color = cfg['color'] as Color;

    final isOverdue = !item.isDone && item.scheduledAt.isBefore(DateTime.now());

    final pet = _petFor(item.petId);

    final isVaccineLinked = item.linkedVaccinationId != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: item.isDone
            ? Colors.white.withValues(alpha: 0.55)
            : Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: isOverdue
            ? Border.all(
                color: Colors.redAccent.withValues(alpha: 0.5),
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
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ────────────────────────────────────────────────
            // Emoji badge
            // ────────────────────────────────────────────────

            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  cfg['emoji'] as String,
                  style: const TextStyle(fontSize: 22),
                ),
              ),
            ),

            const SizedBox(width: 12),

            // ────────────────────────────────────────────────
            // Reminder information
            // ────────────────────────────────────────────────

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      decoration:
                          item.isDone ? TextDecoration.lineThrough : null,
                      color: item.isDone ? Colors.grey : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      // Type
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.type,
                          style: TextStyle(
                            fontSize: 10,
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),

                      // Pet
                      if (pet != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: pet.avatarColor.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '🐱 ${pet.name}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF4A2C1A),
                            ),
                          ),
                        ),

                      // Recurrence
                      if (item.recurrence != 'none')
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF20B2AA).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.repeat,
                                size: 10,
                                color: Color(0xFF20B2AA),
                              ),
                              const SizedBox(
                                width: 2,
                              ),
                              Text(
                                _recurrenceLabel(
                                  item.recurrence,
                                ),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF20B2AA),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),

                      // Overdue
                      if (isOverdue)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
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
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat(
                      'MMM d, yyyy  •  hh:mm a',
                    ).format(item.scheduledAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 6),

            // ────────────────────────────────────────────────
            // Actions
            // ────────────────────────────────────────────────

            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!item.isDone) ...[
                  // Mark done
                  _iconAction(
                    isVaccineLinked
                        ? Icons.vaccines
                        : Icons.check_circle_outline,
                    const Color(0xFF32CD32),
                    'Done',
                    () => _handleMarkDone(item),
                  ),

                  const SizedBox(height: 4),

                  // Snooze
                  PopupMenuButton<Duration>(
                    tooltip: 'Snooze',
                    padding: EdgeInsets.zero,
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.snooze,
                        size: 18,
                        color: Colors.orange,
                      ),
                    ),
                    onSelected: (duration) {
                      _snooze(item, duration);
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: Duration(hours: 1),
                        child: Text('Snooze 1 hour'),
                      ),
                      PopupMenuItem(
                        value: Duration(days: 1),
                        child: Text('Snooze 1 day'),
                      ),
                      PopupMenuItem(
                        value: Duration(days: 7),
                        child: Text('Snooze 1 week'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  // Edit
                  if (!isVaccineLinked)
                    _iconAction(
                      Icons.edit_outlined,
                      const Color(0xFF4682B4),
                      'Edit',
                      () => _showDialog(
                        editing: item,
                      ),
                    ),

                  if (!isVaccineLinked) const SizedBox(height: 4),
                ],

                // Delete
                if (!isVaccineLinked)
                  _iconAction(
                    Icons.delete_outline,
                    Colors.redAccent,
                    'Del',
                    () => _confirmDelete(item),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Small action button
  // ───────────────────────────────────────────────────────────────────────────

  Widget _iconAction(
    IconData icon,
    Color color,
    String label,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          size: 18,
          color: color,
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Delete confirmation
  // ───────────────────────────────────────────────────────────────────────────

  void _confirmDelete(ReminderItem item) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: const Color(0xFFFFF5EE),
          title: const Text(
            'Delete Reminder?',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Remove "${item.title}"?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
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
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                context.read<ReminderProvider>().deleteReminder(item.id);

                Navigator.pop(ctx);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}
