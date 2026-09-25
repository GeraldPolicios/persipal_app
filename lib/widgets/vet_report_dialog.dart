// lib/widgets/vet_report_dialog.dart
//
// "Vet-Friendly Report" — pick a real pet + a date range (reusing the
// existing date-filter control), then show a plain-text report (built by
// vet_report_service.dart from that pet's OWN Activity History entries) in
// a scrollable dialog with a Copy button. Complements, and does not
// replace, Settings' existing raw-JSON "Export Local Data".

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/pet_extended_models.dart';
import '../providers/pet_profile_provider.dart';
import '../services/activity_log_service.dart';
import '../services/vet_report_service.dart';
import 'date_filter_control.dart';

Future<void> showVetReportDialog(BuildContext context) async {
  final pets = PetProfileProvider.instance.profiles;
  if (pets.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Add a real cat profile first to generate a report.'),
      behavior: SnackBarBehavior.floating,
    ));
    return;
  }

  await showDialog(
    context: context,
    builder: (_) => _VetReportDialog(pets: pets),
  );
}

class _VetReportDialog extends StatefulWidget {
  final List<FullPetProfile> pets;
  const _VetReportDialog({required this.pets});

  @override
  State<_VetReportDialog> createState() => _VetReportDialogState();
}

class _VetReportDialogState extends State<_VetReportDialog> {
  late FullPetProfile _pet = widget.pets.first;
  DateFilterSelection _filter = const DateFilterSelection.allDates();
  String? _reportText;

  static const _accent = Color(0xFFDC143C);

  void _generate() {
    // petName fallback covers vaccination/profile log entries that were
    // never given a petId — same matching rule used elsewhere in the app.
    final logs = ActivityLogService.instance.logs.where((l) =>
        (l.petId.isNotEmpty && l.petId == _pet.id) ||
        (l.petId.isEmpty && l.petName == _pet.name));
    final range = dateRangeForSelection(_filter);
    setState(() {
      _reportText = buildVetReport(
        pet: _pet,
        logs: logs.toList(),
        periodStart: range?.$1,
        periodEnd: range?.$2,
      );
    });
  }

  Future<void> _copy() async {
    final text = _reportText;
    if (text == null) return;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Report copied to clipboard.'),
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: const Color(0xFFFFF8F2),
      title: const Row(children: [
        Icon(Icons.description_outlined, color: _accent),
        SizedBox(width: 8),
        Expanded(
          child: Text('Vet-Friendly Report',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ]),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.pets.length > 1) ...[
                const Text('Pet',
                    style: TextStyle(fontSize: 12, color: Color(0xFFAA7755))),
                const SizedBox(height: 4),
                DropdownButton<FullPetProfile>(
                  isExpanded: true,
                  value: _pet,
                  items: widget.pets
                      .map((p) =>
                          DropdownMenuItem(value: p, child: Text(p.name)))
                      .toList(),
                  onChanged: (p) => setState(() {
                    _pet = p!;
                    _reportText = null;
                  }),
                ),
                const SizedBox(height: 12),
              ],
              const Text('Period',
                  style: TextStyle(fontSize: 12, color: Color(0xFFAA7755))),
              const SizedBox(height: 4),
              DateFilterButton(
                selection: _filter,
                accentColor: _accent,
                onTap: () async {
                  final picked = await showDateFilterSheet(context,
                      current: _filter, accentColor: _accent);
                  if (picked != null && mounted) {
                    setState(() {
                      _filter = picked;
                      _reportText = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 14),
              if (_reportText == null)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _accent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _generate,
                    child: const Text('Generate Report'),
                  ),
                )
              else ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _accent.withValues(alpha: 0.25)),
                  ),
                  child: SelectableText(
                    _reportText!,
                    style: const TextStyle(
                        fontSize: 11.5, fontFamily: 'monospace', height: 1.4),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: _accent,
                            side: const BorderSide(color: _accent)),
                        onPressed: _generate,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Regenerate'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _accent,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _copy,
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }
}
