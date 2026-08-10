// screens/reminder_screen.dart
//
// WHAT'S NEW:
//  • Reminders can belong to a specific cat (petId) — a filter row lets
//    multi-cat households view "All Pets" or just one. Cards show a small
//    pet chip so it's obvious whose reminder it is.
//  • Recurring reminders (daily / weekly / monthly) — feeding, grooming,
//    litter changes, etc. auto-reschedule themselves when marked done.
//  • Snooze (+1 hour / +1 day / +1 week) on any pending reminder — no need
//    to delete and recreate one just because today got busy.
//  • Vaccine-linked reminders (created from the Vaccinations screen) open
//    the shared "mark dose given" flow instead of a plain checkbox, so the
//    health record and the reminder never drift out of sync.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:persipal_app/providers/reminder_provider.dart';
import 'package:persipal_app/models/reminder_item_model.dart';
import '../providers/pet_profile_provider.dart';
import '../models/pet_extended_models.dart';
import '../widgets/vaccination_complete_dialog.dart';

// ─── Type Config ─────────────────────────────────────────────────────────────

const _kTypes = [
  {'label': 'Feeding', 'emoji': '🍗', 'color': Color(0xFFFF8C69)},
  {'label': 'Grooming', 'emoji': '✂️', 'color': Color(0xFF7B68EE)},
  {'label': 'Vitamins', 'emoji': '💊', 'color': Color(0xFF32CD32)},
  {'label': 'Exercise', 'emoji': '🎾', 'color': Color(0xFF20B2AA)},
  {'label': 'Vet Visit', 'emoji': '🏥', 'color': Color(0xFFDC143C)},
  {'label': 'Litter Box', 'emoji': '🧹', 'color': Color(0xFF9370DB)},
  {'label': 'Other', 'emoji': '📌', 'color': Color(0xFF4682B4)},
];

const _kRecurrences = [
  {'label': 'None', 'value': 'none'},
  {'label': 'Daily', 'value': 'daily'},
  {'label': 'Weekly', 'value': 'weekly'},
  {'label': 'Monthly', 'value': 'monthly'},
];

Map<String, dynamic> _typeConfig(String label) =>
    _kTypes.firstWhere((t) => t['label'] == label, orElse: () => _kTypes.last);

String _recurrenceLabel(String value) =>
    _kRecurrences.firstWhere((r) => r['value'] == value,
        orElse: () => _kRecurrences.first)['label'] as String;

// ─── Screen ───────────────────────────────────────────────────────────────────

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen>
    with SingleTickerProviderStateMixin {
  final _petProvider = PetProfileProvider.instance;
  late TabController _tab;
  String? _filterPetId; // null = All Pets

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _petProvider.addListener(_refresh);
  }

  @override
  void dispose() {
    _tab.dispose();
    _petProvider.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  // ── Helpers ─────────────────────────────────────────────────────────────

  List<FullPetProfile> get _pets => _petProvider.profiles;

  List<ReminderItem> _filtered(List<ReminderItem> all) => _filterPetId == null
      ? all
      : all.where((r) => r.petId == _filterPetId).toList();

  List<ReminderItem> _pendingFrom(List<ReminderItem> all) =>
      _filtered(all).where((r) => !r.isDone).toList()
        ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

  List<ReminderItem> _doneFrom(List<ReminderItem> all) =>
      _filtered(all).where((r) => r.isDone).toList()
        ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

  FullPetProfile? _petFor(String? petId) =>
      petId == null ? null : _petProvider.getById(petId);

  VaccinationRecord? _vaccinationFor(ReminderItem item) {
    if (item.petId == null || item.linkedVaccinationId == null) return null;
    final pet = _petProvider.getById(item.petId!);
    if (pet == null) return null;
    for (final v in pet.vaccinations) {
      if (v.id == item.linkedVaccinationId) return v;
    }
    return null;
  }

  // ── Mark done ─────────────────────────────────────────────────────────────

  Future<void> _handleMarkDone(ReminderItem item) async {
    final vaccination = _vaccinationFor(item);
    if (vaccination != null && item.petId != null) {
      // Vaccine-linked: hand off to the shared completion flow, which marks
      // this reminder done AND keeps the vaccination record in sync.
      await showVaccinationCompleteDialog(
        context,
        petId: item.petId!,
        record: vaccination,
      );
      return;
    }

    final reminders = context.read<ReminderProvider>();
    await reminders.markReminderDone(item.id);

    if (item.recurrence != 'none') {
      await reminders.scheduleNextOccurrence(item);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('Nice! Next ${item.title} reminder scheduled automatically.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF32CD32),
        duration: const Duration(seconds: 2),
      ));
    }
  }

  void _snooze(ReminderItem item, Duration by) {
    context
        .read<ReminderProvider>()
        .updateReminder(item.copyWith(scheduledAt: item.scheduledAt.add(by)));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Snoozed "${item.title}".'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  // ── Add / Edit Dialog ────────────────────────────────────────────────────

  void _showDialog({ReminderItem? editing}) {
    final titleCtrl = TextEditingController(text: editing?.title ?? '');
    String selectedType = editing?.type ?? 'Feeding';
    DateTime? pickedDt = editing?.scheduledAt;
    String recurrence = editing?.recurrence ?? 'none';
    String? selectedPetId = editing?.petId ??
        (_filterPetId ?? (_pets.length == 1 ? _pets.first.id : null));
    final isVaccineLinked = editing?.linkedVaccinationId != null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: const Color(0xFFFFF8F2),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title bar
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF8C69).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.alarm_add,
                            color: Color(0xFFFF8C69), size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          editing == null ? 'New Reminder' : 'Edit Reminder',
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Title field
                  _dialogField(titleCtrl, 'What to remind?', Icons.notes,
                      enabled: !isVaccineLinked),
                  const SizedBox(height: 14),

                  // Pet picker (only if there are profiles)
                  if (_pets.isNotEmpty) ...[
                    const Text('For which cat?',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFAA7755))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _pets.map((p) {
                        final isSelected = selectedPetId == p.id;
                        return GestureDetector(
                          onTap: isVaccineLinked
                              ? null
                              : () => setD(() => selectedPetId = p.id),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? p.avatarColor
                                  : p.avatarColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              p.name,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color:
                                    isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Type chips
                  const Text('Type',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFAA7755))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _kTypes.map((t) {
                      final isSelected = selectedType == t['label'];
                      final color = t['color'] as Color;
                      return GestureDetector(
                        onTap: isVaccineLinked
                            ? null
                            : () =>
                                setD(() => selectedType = t['label'] as String),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? color : color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: isSelected ? color : Colors.transparent),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(t['emoji'] as String,
                                  style: const TextStyle(fontSize: 13)),
                              const SizedBox(width: 4),
                              Text(
                                t['label'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : color.withOpacity(0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // Date-time picker
                  const Text('Date & Time',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFAA7755))),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: isVaccineLinked
                        ? null
                        : () async {
                            final date = await showDatePicker(
                              context: ctx,
                              initialDate: pickedDt ?? DateTime.now(),
                              firstDate: DateTime.now()
                                  .subtract(const Duration(days: 1)),
                              lastDate: DateTime(2100),
                              builder: (c, child) => Theme(
                                data: Theme.of(c).copyWith(
                                  colorScheme: const ColorScheme.light(
                                      primary: Color(0xFFFF8C69)),
                                ),
                                child: child!,
                              ),
                            );
                            if (date == null) return;
                            final time = await showTimePicker(
                              context: ctx,
                              initialTime: pickedDt != null
                                  ? TimeOfDay.fromDateTime(pickedDt!)
                                  : TimeOfDay.now(),
                              builder: (c, child) => Theme(
                                data: Theme.of(c).copyWith(
                                  colorScheme: const ColorScheme.light(
                                      primary: Color(0xFFFF8C69)),
                                ),
                                child: child!,
                              ),
                            );
                            if (time == null) return;
                            setD(() => pickedDt = DateTime(date.year,
                                date.month, date.day, time.hour, time.minute));
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFFFF8C69).withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 18, color: Color(0xFFFF8C69)),
                          const SizedBox(width: 10),
                          Text(
                            pickedDt == null
                                ? 'Pick date & time'
                                : DateFormat('MMM d, yyyy  •  hh:mm a')
                                    .format(pickedDt!),
                            style: TextStyle(
                              fontSize: 13,
                              color: pickedDt == null
                                  ? Colors.grey
                                  : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Recurrence
                  if (!isVaccineLinked) ...[
                    const Text('Repeat',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFAA7755))),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: _kRecurrences.map((r) {
                        final value = r['value'] as String;
                        final isSelected = recurrence == value;
                        return GestureDetector(
                          onTap: () => setD(() => recurrence = value),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF20B2AA)
                                  : const Color(0xFF20B2AA).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              r['label'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF20B2AA),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC143C).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(children: const [
                        Icon(Icons.link, size: 14, color: Color(0xFFDC143C)),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'This reminder is linked to a vaccination record. '
                            'Edit the date from the Vaccinations screen.',
                            style: TextStyle(
                                fontSize: 11, color: Color(0xFFDC143C)),
                          ),
                        ),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel',
                            style: TextStyle(color: Colors.grey)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF8C69),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 22, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () {
                          if (titleCtrl.text.trim().isEmpty ||
                              pickedDt == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Please fill in title & date/time.')),
                            );
                            return;
                          }
                          final reminders = context.read<ReminderProvider>();
                          if (editing == null) {
                            reminders.addReminder(ReminderItem(
                              id: DateTime.now()
                                  .microsecondsSinceEpoch
                                  .toString(),
                              title: titleCtrl.text.trim(),
                              type: selectedType,
                              scheduledAt: pickedDt!,
                              petId: selectedPetId,
                              recurrence: recurrence,
                            ));
                          } else {
                            reminders.updateReminder(editing.copyWith(
                              title: titleCtrl.text.trim(),
                              type: selectedType,
                              scheduledAt: pickedDt!,
                              petId: selectedPetId,
                              recurrence: recurrence,
                            ));
                          }
                          Navigator.pop(ctx);
                        },
                        child: Text(editing == null ? 'Add' : 'Save'),
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

  Widget _dialogField(TextEditingController ctrl, String hint, IconData icon,
      {bool enabled = true}) {
    return TextField(
      controller: ctrl,
      enabled: enabled,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: const Color(0xFFFF8C69)),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: const Color(0xFFFF8C69).withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: const Color(0xFFFF8C69).withOpacity(0.25)),
        ),
      ),
      style: const TextStyle(fontSize: 14),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final allReminders = context.watch<ReminderProvider>().reminders;
    final pending = _pendingFrom(allReminders);
    final done = _doneFrom(allReminders);
    return Scaffold(
      backgroundColor: const Color(0xFFFFE6CC),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.12,
              child:
                  Image.asset('assets/images/paws_bg.png', fit: BoxFit.cover),
            ),
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header ──────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Icon(Icons.alarm, size: 26),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Care Reminders',
                          style: TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
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
                          child: const Icon(Icons.add,
                              color: Colors.white, size: 20),
                        ),
                        onPressed: () => _showDialog(),
                      ),
                    ],
                  ),
                ),

                // ── Pet filter row (multi-cat households) ───────────────
                if (_pets.length > 1)
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _petFilterChip(
                            'All Pets', null, const Color(0xFFAA7755)),
                        const SizedBox(width: 6),
                        for (final p in _pets) ...[
                          _petFilterChip(p.name, p.id, p.avatarColor),
                          const SizedBox(width: 6),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 8),

                // ── Stats row ──────────────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      _statChip('${pending.length}', 'Pending',
                          const Color(0xFFFF8C69)),
                      const SizedBox(width: 10),
                      _statChip(
                          '${done.length}', 'Done', const Color(0xFF32CD32)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // ── Tabs ───────────────────────────────────────────────
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.45),
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
                        fontWeight: FontWeight.bold, fontSize: 13),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: '⏰  Upcoming'),
                      Tab(text: '✅  Done'),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                Expanded(
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _buildList(pending, done: false),
                      _buildList(done, done: true),
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

  Widget _petFilterChip(String label, String? petId, Color color) {
    final isSelected = _filterPetId == petId;
    return GestureDetector(
      onTap: () => setState(() => _filterPetId = petId),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : Colors.black87)),
      ),
    );
  }

  Widget _statChip(String count, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Text(count,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 15)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: color.withOpacity(0.8),
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildList(List<ReminderItem> items, {required bool done}) {
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
                  color: Color(0xFFAA7755)),
            ),
            if (!done) ...[
              const SizedBox(height: 6),
              const Text('Tap + to add your first reminder.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ]
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: items.length,
      itemBuilder: (_, i) => _reminderCard(items[i]),
    );
  }

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
            ? Colors.white.withOpacity(0.55)
            : Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(16),
        border: isOverdue
            ? Border.all(color: Colors.redAccent.withOpacity(0.5), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
            // Color badge
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(cfg['emoji'] as String,
                    style: const TextStyle(fontSize: 22)),
              ),
            ),
            const SizedBox(width: 12),

            // Info
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
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.type,
                          style: TextStyle(
                              fontSize: 10,
                              color: color,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (pet != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: pet.avatarColor.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('🐱 ${pet.name}',
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF4A2C1A))),
                        ),
                      if (item.recurrence != 'none')
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF20B2AA).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.repeat,
                                size: 10, color: Color(0xFF20B2AA)),
                            const SizedBox(width: 2),
                            Text(_recurrenceLabel(item.recurrence),
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF20B2AA),
                                    fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      if (isOverdue)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Overdue',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.w700)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('MMM d, yyyy  •  hh:mm a')
                        .format(item.scheduledAt),
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),

            // Actions
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
                        color: Colors.orange.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.snooze,
                          size: 18, color: Colors.orange),
                    ),
                    onSelected: (d) => _snooze(item, d),
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: Duration(hours: 1),
                          child: Text('Snooze 1 hour')),
                      PopupMenuItem(
                          value: Duration(days: 1),
                          child: Text('Snooze 1 day')),
                      PopupMenuItem(
                          value: Duration(days: 7),
                          child: Text('Snooze 1 week')),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Edit
                  if (!isVaccineLinked)
                    _iconAction(
                      Icons.edit_outlined,
                      const Color(0xFF4682B4),
                      'Edit',
                      () => _showDialog(editing: item),
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

  Widget _iconAction(
      IconData icon, Color color, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  void _confirmDelete(ReminderItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFFFF5EE),
        title: const Text('Delete Reminder?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Remove "${item.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              context.read<ReminderProvider>().deleteReminder(item.id);
              Navigator.pop(ctx);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
