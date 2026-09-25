// screens/pet_profiles/growth_tracker_screen.dart
//
// Monthly weight / growth tracking with a simple bar chart. Recording a
// new weight is the only mutation offered — once added, a GrowthEntry is a
// permanent historical record (no edit/delete from this screen).

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../providers/pet_profile_provider.dart';
import '../../models/pet_extended_models.dart';
import '../../utils/cat_weight_status.dart';
import '../../widgets/growth_chart.dart';
import '../../widgets/date_filter_control.dart';

class GrowthTrackerScreen extends StatefulWidget {
  final String petId;
  const GrowthTrackerScreen({super.key, required this.petId});

  @override
  State<GrowthTrackerScreen> createState() => _GrowthTrackerScreenState();
}

class _GrowthTrackerScreenState extends State<GrowthTrackerScreen> {
  final _provider = PetProfileProvider.instance;
  final _uuid = const Uuid();

  static const _accentColor = Color(0xFF20B2AA);

  DateFilterSelection _filter = const DateFilterSelection.allDates();

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

  // ── Date filter (display-only — never mutates growthEntries) ─────────────

  /// Filters [all] (the pet's full, untouched growthEntries) down to the
  /// active period, then returns newest-first by `recordedAt` — display
  /// order only. Never sorts by weight, never mutates the source list, and
  /// never touches storage. The end boundary from [dateRangeForSelection]
  /// is already end-of-day inclusive for a custom range, so a record any
  /// time on the selected end date is included.
  List<GrowthEntry> _filteredNewestFirst(List<GrowthEntry> all) {
    final range = dateRangeForSelection(_filter);
    final filtered = range == null
        ? all
        : all
            .where((e) =>
                !e.recordedAt.isBefore(range.$1) &&
                e.recordedAt.isBefore(range.$2))
            .toList();
    return filtered.reversed.toList();
  }

  Widget _noRecordsForPeriod() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Icon(Icons.filter_alt_off,
              size: 36, color: _accentColor.withValues(alpha: 0.4)),
          const SizedBox(height: 8),
          const Text(
            'No weight records found for this date range.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFFAA7755)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Your full history is still saved — try a different filter.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // ── Add dialog ─────────────────────────────────────────────────────────────
  // A recorded GrowthEntry is a historical record once added — there is no
  // edit mode. To correct a mistaken measurement, record a new entry rather
  // than editing an old one (matches how a real growth chart works: a new
  // weigh-in is a new data point, not a correction to the last one).

  void _showEntryDialog() {
    final weightCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          backgroundColor: const Color(0xFFFFF8F2),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
          child: Padding(
            padding: const EdgeInsets.all(20),
            // Scrollable so the dialog never overflows when the keyboard is
            // open, on short/landscape screens, or with large text.
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF20B2AA).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.show_chart,
                          color: Color(0xFF20B2AA), size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Add Growth Entry',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ]),
                  const SizedBox(height: 18),

                  // Date picker
                  GestureDetector(
                    onTap: () async {
                      final d = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        builder: (c, child) => Theme(
                          data: Theme.of(c).copyWith(
                              colorScheme: const ColorScheme.light(
                                  primary: Color(0xFF20B2AA))),
                          child: child!,
                        ),
                      );
                      if (d != null) setD(() => selectedDate = d);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color:
                                const Color(0xFF20B2AA).withValues(alpha: 0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.calendar_today,
                            size: 16, color: Color(0xFF20B2AA)),
                        const SizedBox(width: 10),
                        Text(DateFormat('MMMM d, yyyy').format(selectedDate),
                            style: const TextStyle(fontSize: 13)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Weight
                  TextField(
                    controller: weightCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: _deco('Weight (kg) *', Icons.monitor_weight,
                        const Color(0xFF20B2AA)),
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 10),

                  // Notes
                  TextField(
                    controller: notesCtrl,
                    maxLines: 3,
                    decoration:
                        _deco('Notes', Icons.notes, const Color(0xFF20B2AA)),
                    style: const TextStyle(fontSize: 13),
                  ),
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
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF20B2AA),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        onPressed: () async {
                          final w = double.tryParse(weightCtrl.text.trim());
                          if (w == null || !w.isFinite || w <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Enter a valid weight.')));
                            return;
                          }
                          Navigator.pop(ctx);
                          await _provider.addGrowthEntry(
                            widget.petId,
                            GrowthEntry(
                              id: _uuid.v4(),
                              weightKg: w,
                              notes: notesCtrl.text.trim(),
                              recordedAt: selectedDate,
                            ),
                          );
                        },
                        child: const Text('Add'),
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

  InputDecoration _deco(String label, IconData icon, Color color) =>
      InputDecoration(
        labelText: label,
        labelStyle:
            TextStyle(fontSize: 12, color: color.withValues(alpha: 0.8)),
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
          borderSide: BorderSide(color: color.withValues(alpha: 0.25)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final pet = _pet;
    if (pet == null) {
      return const Scaffold(body: Center(child: Text('Not found.')));
    }

    final entries = pet.growthEntries;

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
              const Text('📈 ', style: TextStyle(fontSize: 18)),
              Expanded(
                  child: Text("${pet.name}'s Growth Tracker",
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold))),
            ]),
          ),
          const SizedBox(height: 4),

          Expanded(
            child: entries.isEmpty
                ? _emptyState()
                : Builder(builder: (_) {
                    // The status card and chart always reflect the pet's
                    // FULL history (see requirement: filtering must never
                    // change the derived "current/latest weight"). Only the
                    // "WEIGHT HISTORY" list below is affected by the date
                    // filter.
                    final filteredNewestFirst = _filteredNewestFirst(entries);

                    return ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                      children: [
                        // Estimated weight status (latest entry)
                        _buildWeightStatusCard(pet, entries),
                        const SizedBox(height: 16),

                        // Mini chart — bars colored by each month's weight
                        // status, using the same classifier as the status
                        // card above so the two stay consistent. Always
                        // shows the full history, independent of the list
                        // filter below.
                        GrowthChart(
                          entries: entries,
                          statusForEntry: (e) => classifyCatWeight(
                            weightKg: e.weightKg,
                            birthDate: pet.birthDate,
                            gender: pet.gender,
                            asOf: e.recordedAt,
                          ).status,
                        ),
                        const SizedBox(height: 16),

                        // Entries — historical, view-only. Each recorded
                        // weigh-in is its own permanent record; to correct
                        // a mistake, record a new entry rather than editing
                        // an old one.
                        const _Label('WEIGHT HISTORY'),
                        const SizedBox(height: 8),
                        DateFilterButton(
                          selection: _filter,
                          accentColor: _accentColor,
                          onTap: () async {
                            final picked = await showDateFilterSheet(
                              context,
                              current: _filter,
                              accentColor: _accentColor,
                            );
                            if (picked != null && mounted) {
                              setState(() => _filter = picked);
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        if (filteredNewestFirst.isEmpty)
                          _noRecordsForPeriod()
                        else
                          ...filteredNewestFirst
                              .map((e) => _EntryCard(entry: e)),
                      ],
                    );
                  }),
          ),
        ])),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEntryDialog(),
        backgroundColor: const Color(0xFF20B2AA),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Entry',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildWeightStatusCard(
    FullPetProfile pet,
    List<GrowthEntry> entries,
  ) {
    // Determine the latest entry by recordedAt explicitly — entries is
    // usually sorted ascending, but editing an entry's date doesn't
    // re-sort the list, so we don't rely on entries.last.
    var latest = entries.first;
    for (final e in entries) {
      if (e.recordedAt.isAfter(latest.recordedAt)) {
        latest = e;
      }
    }

    final result = classifyCatWeight(
      weightKg: latest.weightKg,
      birthDate: pet.birthDate,
      gender: pet.gender,
      asOf: latest.recordedAt,
    );

    final color = _statusColor(result.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('ESTIMATED WEIGHT STATUS'),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${latest.weightKg} kg',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    result.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'As of ${DateFormat('MMMM d, yyyy').format(latest.recordedAt)}',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Text(
            result.detail,
            style: const TextStyle(fontSize: 12, color: Color(0xFFAA7755)),
          ),
          const SizedBox(height: 8),
          const Text(
            kCatWeightStatusDisclaimer,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(CatWeightStatus status) {
    switch (status) {
      case CatWeightStatus.underweight:
        return Colors.orange;
      case CatWeightStatus.normal:
        return const Color(0xFF20B2AA);
      case CatWeightStatus.overweight:
        return Colors.deepOrange;
      case CatWeightStatus.obese:
        return Colors.redAccent;
      case CatWeightStatus.notClassified:
      case CatWeightStatus.unknownAgeNeeded:
      case CatWeightStatus.unrecognizedGender:
        return Colors.grey;
    }
  }

  Widget _emptyState() => const Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Opacity(
              opacity: 0.35,
              child:
                  Icon(Icons.show_chart, size: 80, color: Color(0xFF20B2AA))),
          SizedBox(height: 16),
          Text('No growth records yet.',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFAA7755))),
          SizedBox(height: 8),
          Text('Tap + to record your cat\'s weight.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      );
}

// Historical, view-only — a recorded weight measurement is never editable
// or deletable from this screen (see requirement: record a new
// measurement instead of correcting an old one).
class _EntryCard extends StatelessWidget {
  final GrowthEntry entry;

  const _EntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF20B2AA).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child:
              const Center(child: Text('⚖️', style: TextStyle(fontSize: 22))),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${entry.weightKg} kg',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(DateFormat('MMMM d, yyyy').format(entry.recordedAt),
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
            if (entry.notes.isNotEmpty)
              Text(entry.notes,
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFFAA7755)),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
          ],
        )),
      ]),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: Color(0xFFAA7755)));
}
