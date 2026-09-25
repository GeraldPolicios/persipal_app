// screens/completed_history_screen.dart
//
// Completed Care History for ONE real pet: completed veterinary visits /
// checkup notes, completed vaccination doses and completed care reminders,
// with the shared "Filter by Date" control.
//
// Read-only view over data that already exists (see
// services/completed_care_history.dart for the rules): it creates no storage,
// no provider and no second history system, and nothing here edits a record.
// Pending / overdue / upcoming items and deleted records never appear.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/pet_profile_provider.dart';
import '../../providers/reminder_provider.dart';
import '../../services/completed_care_history.dart';
import '../../widgets/date_filter_control.dart';

const Color _kAccent = Color(0xFF32CD32);

class CompletedHistoryScreen extends StatefulWidget {
  final String petId;

  const CompletedHistoryScreen({super.key, required this.petId});

  @override
  State<CompletedHistoryScreen> createState() => _CompletedHistoryScreenState();
}

class _CompletedHistoryScreenState extends State<CompletedHistoryScreen> {
  final _petProvider = PetProfileProvider.instance;

  // UI-only, per-screen filter — resets to All Dates when reopened, like the
  // Reminders Done tab / Activity History / Growth History filters.
  DateFilterSelection _filter = const DateFilterSelection.allDates();

  @override
  void initState() {
    super.initState();
    _petProvider.addListener(_refresh);
  }

  @override
  void dispose() {
    _petProvider.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _pickFilter() async {
    final picked = await showDateFilterSheet(
      context,
      current: _filter,
      accentColor: _kAccent,
    );
    if (picked != null && mounted) setState(() => _filter = picked);
  }

  @override
  Widget build(BuildContext context) {
    final pet = _petProvider.getById(widget.petId);
    final reminders = context.watch<ReminderProvider>().reminders;

    if (pet == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFE6CC),
        body: Center(child: Text('Profile not found.')),
      );
    }

    final history = buildCompletedCareHistory(
      pet: pet,
      reminders: reminders,
      filter: _filter,
    );
    final filtered = _filter.kind != DateFilterKind.allDates;

    return Scaffold(
      backgroundColor: const Color(0xFFFFE6CC),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.10,
              child: Image.asset('assets/images/paws_bg.png', fit: BoxFit.cover),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '✅  Completed History',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              pet.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, color: Color(0xFFAA7755)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: DateFilterButton(
                    selection: _filter,
                    accentColor: _kAccent,
                    onTap: _pickFilter,
                  ),
                ),
                Expanded(
                  child: history.isEmpty
                      ? _EmptyState(filtered: filtered, petName: pet.name)
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          children: [
                            if (history.vetVisits.isNotEmpty)
                              _Section(
                                title: 'Veterinary Visits',
                                icon: Icons.local_hospital,
                                color: const Color(0xFF20B2AA),
                                entries: history.vetVisits,
                              ),
                            if (history.vaccinations.isNotEmpty)
                              _Section(
                                title: 'Vaccinations',
                                icon: Icons.vaccines,
                                color: const Color(0xFF7B68EE),
                                entries: history.vaccinations,
                              ),
                            if (history.reminders.isNotEmpty)
                              _Section(
                                title: 'Completed Reminders',
                                icon: Icons.check_circle,
                                color: _kAccent,
                                entries: history.reminders,
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
}

class _EmptyState extends StatelessWidget {
  final bool filtered;
  final String petName;

  const _EmptyState({required this.filtered, required this.petName});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🐾', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 12),
            Text(
              filtered
                  ? 'No completed care in this date range'
                  : 'No completed care yet',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              filtered
                  ? 'Try another date filter or choose All Dates.'
                  : 'Completed vet visits, vaccinations and reminders for '
                      '$petName will appear here.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFFAA7755)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final List<CompletedCareEntry> entries;

  const _Section({
    required this.title,
    required this.icon,
    required this.color,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                    color: Color(0xFFAA7755),
                  ),
                ),
              ),
              Text(
                '${entries.length}',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                for (var i = 0; i < entries.length; i++) ...[
                  if (i > 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1),
                    ),
                  _EntryRow(entry: entries[i], icon: icon, color: color),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  final CompletedCareEntry entry;
  final IconData icon;
  final Color color;

  const _EntryRow({
    required this.entry,
    required this.icon,
    required this.color,
  });

  String get _dateLabel {
    switch (entry.kind) {
      case CompletedCareKind.reminder:
        return 'Completed: '
            '${DateFormat('MMM d, yyyy • h:mm a').format(entry.date)}';
      case CompletedCareKind.vaccination:
        return 'Given: ${DateFormat('MMM d, yyyy').format(entry.date)}';
      case CompletedCareKind.vetVisit:
        final verb = entry.sourceLabel == 'Vet visit' ? 'Completed' : 'Visit';
        return '$verb: ${DateFormat('MMM d, yyyy').format(entry.date)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.title,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                _dateLabel,
                style: const TextStyle(fontSize: 11, color: Color(0xFFAA7755)),
              ),
              if (entry.doseInfo != null) ...[
                const SizedBox(height: 2),
                Text(
                  entry.doseInfo!,
                  style:
                      const TextStyle(fontSize: 11, color: Color(0xFFAA7755)),
                ),
              ],
              if (entry.notes != null) ...[
                const SizedBox(height: 4),
                Text(
                  entry.notes!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Color(0xFF7A3B1E),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
