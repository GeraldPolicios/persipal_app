// screens/pet_profiles/vaccination_screen.dart
//
// Vaccination Records — full CRUD, now wired into Care Reminders.
//
// WHAT'S NEW:
//  • Setting a "Next Schedule" + enabling the reminder toggle auto-creates
//    (and keeps in sync) a matching entry in Care Reminders.
//  • Turning the reminder off, clearing the date, or deleting the record
//    removes the linked reminder automatically.
//  • "Mark Given" button on any card with a pending dose runs the shared
//    completion flow (see widgets/vaccination_complete_dialog.dart) — it
//    marks the linked reminder done (kept in the Done tab) and adds a new
//    completed record, so full dose history is never overwritten.
//  • Quick-add chips for the 4 core cat vaccines/treatments.
//  • Due-in-X-days / overdue-by-X-days labels instead of just a raw date.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:provider/provider.dart';
import 'package:persipal_app/providers/reminder_provider.dart';
import 'package:persipal_app/models/reminder_item_model.dart';
import '../../providers/pet_profile_provider.dart';
import '../../models/pet_extended_models.dart';
import '../../widgets/vaccination_complete_dialog.dart';

// ─── Quick vaccine templates ────────────────────────────────────────────────
// Tapping one fills the name field and, if no next-schedule is set yet,
// suggests a sensible follow-up interval so parents don't have to remember it.
const _kVaccineTemplates = [
  {'label': 'FVRCP', 'days': 365},
  {'label': 'Rabies', 'days': 365},
  {'label': 'FeLV', 'days': 365},
  {'label': 'Deworming', 'days': 90},
];

class VaccinationScreen extends StatefulWidget {
  final String petId;
  const VaccinationScreen({super.key, required this.petId});

  @override
  State<VaccinationScreen> createState() => _VaccinationScreenState();
}

class _VaccinationScreenState extends State<VaccinationScreen> {
  final _provider = PetProfileProvider.instance;
  final _uuid = const Uuid();

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

  void _refresh() => setState(() {});

  FullPetProfile? get _pet => _provider.getById(widget.petId);

  VaccinationRecord? _findRecord(String id) {
    for (final r in _pet?.vaccinations ?? const <VaccinationRecord>[]) {
      if (r.id == id) return r;
    }
    return null;
  }

  // ── Reminder sync ────────────────────────────────────────────────────────

  Future<void> _syncReminder({
    required String recordId,
    required String vaccineName,
    required DateTime? nextSchedule,
    required bool reminderEnabled,
    required String? existingLinkedReminderId,
  }) async {
    final pet = _pet;
    if (pet == null) return;
    final reminders = context.read<ReminderProvider>();

    // No date, or reminders off -> tear down any existing linked reminder.
    if (nextSchedule == null || !reminderEnabled) {
      if (existingLinkedReminderId != null) {
        await reminders.deleteReminder(existingLinkedReminderId);
        final rec = _findRecord(recordId);
        if (rec != null) {
          await _provider.updateVaccination(
              widget.petId, rec.copyWith(linkedReminderId: null));
        }
      }
      return;
    }

    final title = "💉 $vaccineName — ${pet.name}'s next dose";
    final stillExists = existingLinkedReminderId != null &&
        reminders.reminders.any((r) => r.id == existingLinkedReminderId);

    if (stillExists) {
      final old = reminders.reminders
          .firstWhere((r) => r.id == existingLinkedReminderId);
      await reminders.updateReminder(old.copyWith(
        title: title,
        scheduledAt: nextSchedule,
        isDone: false,
      ));
    } else {
      final reminderId = _uuid.v4();
      await reminders.addReminder(ReminderItem(
        id: reminderId,
        title: title,
        type: 'Vet Visit',
        scheduledAt: nextSchedule,
        petId: widget.petId,
        linkedVaccinationId: recordId,
      ));
      final rec = _findRecord(recordId);
      if (rec != null) {
        await _provider.updateVaccination(
            widget.petId, rec.copyWith(linkedReminderId: reminderId));
      }
    }
  }

  // ── Add / Edit dialog ─────────────────────────────────────────────────────

  void _showDialog({VaccinationRecord? existing}) {
    final nameCtrl = TextEditingController(text: existing?.vaccineName ?? '');
    final notesCtrl = TextEditingController(text: existing?.vetNotes ?? '');
    DateTime completedDate = existing?.completedDate ?? DateTime.now();
    DateTime? nextSchedule = existing?.nextSchedule;
    bool reminderEnabled = existing?.reminderEnabled ?? false;
    final existingLinkedReminderId = existing?.linkedReminderId;

    // Recurring series (only offered when adding a brand-new record — never
    // shown/used when editing, which is what prevents the same series from
    // being generated twice).
    bool useRecurringSchedule = false;
    String recurrenceType = 'everyXDays'; // 'everyXDays' | 'annual'
    final intervalCtrl = TextEditingController(text: '7');
    final totalDosesCtrl = TextEditingController(text: '3');
    // Independent of `reminderEnabled`/`nextSchedule` above — those only
    // apply to the single-dose flow. The recurring series has its own
    // reminder toggle since it has no single "next schedule" date at all.
    bool seriesReminderEnabled = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          backgroundColor: const Color(0xFFFFF8F2),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7B68EE).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.vaccines,
                          color: Color(0xFF7B68EE), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      existing == null ? 'Add Vaccination' : 'Edit Vaccination',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ]),
                  const SizedBox(height: 14),

                  // Quick templates
                  if (existing == null) ...[
                    const _SLabel('Quick Add (core vaccines & care)'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _kVaccineTemplates.map((t) {
                        final label = t['label'] as String;
                        final days = t['days'] as int;
                        return GestureDetector(
                          onTap: () {
                            setD(() {
                              nameCtrl.text = label;
                              if (nextSchedule == null) {
                                nextSchedule =
                                    completedDate.add(Duration(days: days));
                                reminderEnabled = true;
                              }
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF7B68EE).withOpacity(0.10),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color:
                                      const Color(0xFF7B68EE).withOpacity(0.3)),
                            ),
                            child: Text(label,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF7B68EE))),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Vaccine name
                  _field(nameCtrl, 'Vaccine Name *', Icons.medical_services,
                      const Color(0xFF7B68EE)),
                  const SizedBox(height: 12),

                  // Completed date
                  const _SLabel('Completion Date'),
                  const SizedBox(height: 6),
                  _dateTile(
                    label: DateFormat('MMM d, yyyy').format(completedDate),
                    icon: Icons.check_circle_outline,
                    color: const Color(0xFF32CD32),
                    onTap: () async {
                      final d = await _pickDate(ctx,
                          initial: completedDate,
                          first: DateTime(2000),
                          last: DateTime.now());
                      if (d != null) setD(() => completedDate = d);
                    },
                  ),
                  const SizedBox(height: 12),

                  // Next schedule (single-dose flow only — a recurring
                  // series determines all future dates itself)
                  if (!useRecurringSchedule) ...[
                    const _SLabel('Next Schedule (optional)'),
                    const SizedBox(height: 6),
                    _dateTile(
                      label: nextSchedule != null
                          ? DateFormat('MMM d, yyyy').format(nextSchedule!)
                          : 'Tap to set next date',
                      icon: Icons.calendar_month,
                      color: const Color(0xFF7B68EE),
                      dimmed: nextSchedule == null,
                      onTap: () async {
                        final d = await _pickDate(ctx,
                            initial: nextSchedule ?? DateTime.now(),
                            first: DateTime.now(),
                            last: DateTime(2100));
                        if (d != null) {
                          setD(() {
                            nextSchedule = d;
                            reminderEnabled = true;
                          });
                        }
                      },
                      trailing: nextSchedule != null
                          ? GestureDetector(
                              onTap: () => setD(() {
                                nextSchedule = null;
                                reminderEnabled = false;
                              }),
                              child: const Icon(Icons.close,
                                  size: 16, color: Colors.grey),
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Recurring series (add-only — never shown on Edit)
                  if (existing == null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: const Color(0xFF20B2AA).withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.repeat,
                                size: 18, color: Color(0xFF20B2AA)),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text('Set up a recurring dose series',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ),
                            Switch(
                              value: useRecurringSchedule,
                              onChanged: (v) =>
                                  setD(() => useRecurringSchedule = v),
                              activeColor: const Color(0xFF20B2AA),
                            ),
                          ]),
                          if (useRecurringSchedule) ...[
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              value: recurrenceType,
                              decoration: _fieldDeco('Repeats',
                                  Icons.event_repeat, const Color(0xFF20B2AA)),
                              items: const [
                                DropdownMenuItem(
                                    value: 'everyXDays',
                                    child: Text('Every X days')),
                                DropdownMenuItem(
                                    value: 'annual', child: Text('Annual')),
                              ],
                              onChanged: (v) => setD(
                                  () => recurrenceType = v ?? 'everyXDays'),
                            ),
                            const SizedBox(height: 10),
                            if (recurrenceType == 'everyXDays')
                              Row(children: [
                                Expanded(
                                  child: TextField(
                                    controller: intervalCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: _fieldDeco('Interval (days)',
                                        Icons.timer, const Color(0xFF20B2AA)),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: TextField(
                                    controller: totalDosesCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: _fieldDeco('Total doses',
                                        Icons.numbers, const Color(0xFF20B2AA)),
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ])
                            else
                              TextField(
                                controller: totalDosesCtrl,
                                keyboardType: TextInputType.number,
                                decoration: _fieldDeco(
                                    'Repeat for how many years',
                                    Icons.numbers,
                                    const Color(0xFF20B2AA)),
                                style: const TextStyle(fontSize: 13),
                              ),
                            const SizedBox(height: 6),
                            const Text(
                              'This automatically creates the follow-up '
                              'doses and their reminders now.',
                              style:
                                  TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Vet notes
                  TextField(
                    controller: notesCtrl,
                    maxLines: 3,
                    decoration: _fieldDeco(
                        'Vet Notes', Icons.notes, const Color(0xFF7B68EE)),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),

                  // Reminder toggle
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF7B68EE).withOpacity(0.2)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.notifications_active,
                          size: 18, color: Color(0xFF7B68EE)),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text('Sync to Care Reminders',
                            style: TextStyle(fontSize: 13)),
                      ),
                      Switch(
                        value: useRecurringSchedule
                            ? seriesReminderEnabled
                            : (reminderEnabled && nextSchedule != null),
                        onChanged: useRecurringSchedule
                            ? (v) => setD(() => seriesReminderEnabled = v)
                            : (nextSchedule == null
                                ? null
                                : (v) => setD(() => reminderEnabled = v)),
                        activeColor: const Color(0xFF7B68EE),
                      ),
                    ]),
                  ),
                  if (!useRecurringSchedule && nextSchedule == null) ...[
                    const SizedBox(height: 6),
                    const Text(
                      'Set a next schedule date to enable a reminder.',
                      style: TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                  const SizedBox(height: 18),

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
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF7B68EE),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: Icon(existing == null ? Icons.add : Icons.save,
                            size: 16),
                        label: Text(existing == null ? 'Add' : 'Save'),
                        onPressed: () async {
                          if (nameCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Vaccine name is required.')));
                            return;
                          }
                          final vaccineName = nameCtrl.text.trim();

                          // ── Recurring series (add-only) ───────────────────
                          if (existing == null && useRecurringSchedule) {
                            final interval =
                                int.tryParse(intervalCtrl.text.trim()) ?? 7;
                            final rawTotal =
                                int.tryParse(totalDosesCtrl.text.trim()) ?? 1;
                            // Bounded, sane range — never an open-ended/huge
                            // recurrence even if the user types something wild.
                            final totalDoses = rawTotal.clamp(1, 60);

                            Navigator.pop(ctx);
                            await _provider.addVaccinationSeries(
                              petId: widget.petId,
                              vaccineName: vaccineName,
                              firstGivenDate: completedDate,
                              vetNotes: notesCtrl.text.trim(),
                              recurrenceType: recurrenceType,
                              intervalDays: recurrenceType == 'everyXDays'
                                  ? interval.clamp(1, 3650)
                                  : null,
                              totalDoses: totalDoses,
                              reminderEnabled: seriesReminderEnabled,
                              reminderProvider:
                                  context.read<ReminderProvider>(),
                            );
                            return;
                          }

                          final recordId = existing?.id ?? _uuid.v4();
                          final effectiveReminderEnabled =
                              reminderEnabled && nextSchedule != null;
                          Navigator.pop(ctx);

                          if (existing == null) {
                            await _provider.addVaccination(
                              widget.petId,
                              VaccinationRecord(
                                id: recordId,
                                vaccineName: vaccineName,
                                completedDate: completedDate,
                                nextSchedule: nextSchedule,
                                vetNotes: notesCtrl.text.trim(),
                                reminderEnabled: effectiveReminderEnabled,
                              ),
                            );
                          } else {
                            await _provider.updateVaccination(
                              widget.petId,
                              existing.copyWith(
                                vaccineName: vaccineName,
                                completedDate: completedDate,
                                nextSchedule: nextSchedule,
                                vetNotes: notesCtrl.text.trim(),
                                reminderEnabled: effectiveReminderEnabled,
                              ),
                            );
                          }

                          await _syncReminder(
                            recordId: recordId,
                            vaccineName: vaccineName,
                            nextSchedule: nextSchedule,
                            reminderEnabled: effectiveReminderEnabled,
                            existingLinkedReminderId: existingLinkedReminderId,
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

  Future<DateTime?> _pickDate(
    BuildContext ctx, {
    required DateTime initial,
    required DateTime first,
    required DateTime last,
  }) =>
      showDatePicker(
        context: ctx,
        initialDate: initial,
        firstDate: first,
        lastDate: last,
        builder: (c, child) => Theme(
          data: Theme.of(c).copyWith(
              colorScheme: const ColorScheme.light(primary: Color(0xFF7B68EE))),
          child: child!,
        ),
      );

  void _confirmDelete(VaccinationRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: const Color(0xFFFFF5EE),
        title: const Text('Delete Record?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
            'Remove "${record.vaccineName}" vaccination record?'
            '${record.linkedReminderId != null ? ' Its linked reminder will be removed too.' : ''}',
            style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child:
                  const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(ctx);
              if (record.linkedReminderId != null) {
                await context
                    .read<ReminderProvider>()
                    .deleteReminder(record.linkedReminderId!);
              }
              await _provider.deleteVaccination(widget.petId, record.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pet = _pet;
    if (pet == null) {
      return const Scaffold(body: Center(child: Text('Profile not found.')));
    }

    // Sort: overdue first, then by next schedule
    // Sort: overdue first, then planned/upcoming (soonest first), then
    // records with a next schedule, then everything else by most recent.
    final records = List.of(pet.vaccinations)
      ..sort((a, b) {
        int rank(VaccinationRecord r) {
          if (r.isOverdue) return 0;
          if (r.isPlanned) return 1;
          if (r.nextSchedule != null) return 2;
          return 3;
        }

        final ra = rank(a), rb = rank(b);
        if (ra != rb) return ra.compareTo(rb);
        if (ra == 0 || ra == 2)
          return a.nextSchedule!.compareTo(b.nextSchedule!);
        if (ra == 1) return a.completedDate.compareTo(b.completedDate);
        return b.completedDate.compareTo(a.completedDate);
      });

    final overdueCount = records.where((r) => r.isOverdue).length;
    final upcomingCount = records
        .where((r) => r.isPlanned || (!r.isOverdue && r.nextSchedule != null))
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFFFE6CC),
      body: Stack(children: [
        Positioned.fill(
            child: Opacity(
          opacity: 0.10,
          child: Image.asset('assets/images/paws_bg.png', fit: BoxFit.cover),
        )),
        SafeArea(
            child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
            child: Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
              const Text('💉 ', style: TextStyle(fontSize: 18)),
              const Expanded(
                child: Text('Vaccinations',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              if (overdueCount > 0)
                _headerBadge('$overdueCount overdue', Colors.redAccent),
            ]),
          ),

          // Stats row
          if (records.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(children: [
                _statChip(
                    '${records.length}', 'Total', const Color(0xFF7B68EE)),
                const SizedBox(width: 8),
                _statChip(
                    '$upcomingCount', 'Upcoming', const Color(0xFF20B2AA)),
                const SizedBox(width: 8),
                _statChip('$overdueCount', 'Overdue', Colors.redAccent),
              ]),
            ),
          const SizedBox(height: 4),

          Expanded(
            child: records.isEmpty
                ? _emptyState()
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: records.length,
                    itemBuilder: (_, i) => _VaccineCard(
                      record: records[i],
                      onEdit: () => _showDialog(existing: records[i]),
                      onDelete: () => _confirmDelete(records[i]),
                      onMarkGiven: () => showVaccinationCompleteDialog(
                        context,
                        petId: widget.petId,
                        record: records[i],
                      ),
                      onReminderToggle: () async {
                        final rec = records[i];
                        final newVal = !rec.reminderEnabled;
                        await _provider.updateVaccination(widget.petId,
                            rec.copyWith(reminderEnabled: newVal));
                        await _syncReminder(
                          recordId: rec.id,
                          vaccineName: rec.vaccineName,
                          nextSchedule: rec.nextSchedule,
                          reminderEnabled: newVal,
                          existingLinkedReminderId: rec.linkedReminderId,
                        );
                      },
                    ),
                  ),
          ),
        ])),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDialog(),
        backgroundColor: const Color(0xFF7B68EE),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Record',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _headerBadge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.bold, color: color)),
      );

  Widget _statChip(String count, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(count,
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: color, fontSize: 13)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color.withOpacity(0.85),
                  fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _emptyState() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Opacity(
            opacity: 0.35,
            child:
                const Icon(Icons.vaccines, size: 80, color: Color(0xFF7B68EE)),
          ),
          const SizedBox(height: 16),
          const Text('No vaccination records yet.',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFAA7755))),
          const SizedBox(height: 8),
          const Text('Tap + to add your first vaccine record.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      );

  Widget _field(TextEditingController ctrl, String label, IconData icon,
          Color color) =>
      TextField(
        controller: ctrl,
        decoration: _fieldDeco(label, icon, color),
        style: const TextStyle(fontSize: 13),
      );

  InputDecoration _fieldDeco(String label, IconData icon, Color color) =>
      InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 12, color: color.withOpacity(0.8)),
        prefixIcon: Icon(icon, size: 16, color: color),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: color.withOpacity(0.25)),
        ),
      );

  Widget _dateTile({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool dimmed = false,
    Widget? trailing,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          child: Row(children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      color: dimmed ? Colors.grey : Colors.black87)),
            ),
            trailing ?? const SizedBox.shrink(),
          ]),
        ),
      );
}

// ─── Due-date label helper ─────────────────────────────────────────────────

String _dueLabel(DateTime next) {
  final now = DateTime.now();
  final days = DateTime(next.year, next.month, next.day)
      .difference(DateTime(now.year, now.month, now.day))
      .inDays;
  if (days < 0) return 'Overdue by ${-days} day${-days == 1 ? '' : 's'}';
  if (days == 0) return 'Due today';
  if (days == 1) return 'Due tomorrow';
  return 'Due in $days days';
}

// ─── Vaccine Card ─────────────────────────────────────────────────────────────

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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.90),
        borderRadius: BorderRadius.circular(16),
        border: isOverdue
            ? Border.all(color: Colors.redAccent.withOpacity(0.5), width: 1.5)
            : isPlanned
                ? Border.all(
                    color: const Color(0xFF20B2AA).withOpacity(0.4), width: 1.5)
                : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row
            Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF7B68EE).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                    child: Text('💉', style: TextStyle(fontSize: 22))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(record.vaccineName,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        isPlanned
                            ? 'Planned: ${DateFormat('MMM d, yyyy').format(record.completedDate)}'
                            : 'Given: ${DateFormat('MMM d, yyyy').format(record.completedDate)}',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      if (hasDoseInfo) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Dose ${record.doseNumber} of ${record.totalDosesInSeries}',
                          style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF20B2AA),
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ]),
              ),
              // Status badge
              if (isPlanned)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF20B2AA).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Planned',
                      style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF20B2AA),
                          fontWeight: FontWeight.bold)),
                )
              else if (isOverdue)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Overdue',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold)),
                ),
            ]),

            // Next schedule + due countdown
            if (hasNext) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isOverdue
                      ? Colors.redAccent.withOpacity(0.08)
                      : const Color(0xFF7B68EE).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(children: [
                  Icon(
                    Icons.calendar_month,
                    size: 13,
                    color:
                        isOverdue ? Colors.redAccent : const Color(0xFF7B68EE),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${DateFormat('MMM d, yyyy').format(record.nextSchedule!)} · ${_dueLabel(record.nextSchedule!)}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isOverdue
                              ? Colors.redAccent
                              : const Color(0xFF7B68EE)),
                    ),
                  ),
                  if (record.linkedReminderId != null)
                    Icon(Icons.notifications_active,
                        size: 13,
                        color: isOverdue
                            ? Colors.redAccent
                            : const Color(0xFF7B68EE)),
                ]),
              ),
            ],

            // Vet notes
            if (record.vetNotes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(record.vetNotes,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7A5C3A),
                      fontStyle: FontStyle.italic),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],

            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 6),

            // Bottom actions row
            Row(children: [
              if (!isPlanned) ...[
                const Icon(Icons.notifications_outlined,
                    size: 14, color: Color(0xFF7B68EE)),
                const SizedBox(width: 4),
                const Text('Reminder',
                    style: TextStyle(fontSize: 11, color: Color(0xFF7B68EE))),
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
                Icon(Icons.notifications_active,
                    size: 14,
                    color: record.linkedReminderId != null
                        ? const Color(0xFF20B2AA)
                        : Colors.grey),
                const SizedBox(width: 4),
                Text(
                  record.linkedReminderId != null
                      ? 'Reminder set'
                      : 'No reminder',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
              const Spacer(),
              if (hasNext || isPlanned) ...[
                _pillBtn('Mark Given', Icons.check, const Color(0xFF32CD32),
                    onMarkGiven),
                const SizedBox(width: 6),
              ],
              _actionBtn(Icons.edit_outlined, const Color(0xFF4682B4), onEdit),
              const SizedBox(width: 6),
              _actionBtn(Icons.delete_outline, Colors.redAccent, onDelete),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _pillBtn(
          String label, IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          ]),
        ),
      );

  Widget _actionBtn(IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 16, color: color),
        ),
      );
}

// ── Small label ───────────────────────────────────────────────────────────────

class _SLabel extends StatelessWidget {
  final String text;
  const _SLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFFAA7755)),
      );
}
