// screens/pet_profiles/growth_tracker_screen.dart
//
// Monthly weight / growth tracking with a simple line chart and full CRUD.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../providers/pet_profile_provider.dart';
import '../../models/pet_extended_models.dart';

class GrowthTrackerScreen extends StatefulWidget {
  final String petId;
  const GrowthTrackerScreen({super.key, required this.petId});

  @override
  State<GrowthTrackerScreen> createState() => _GrowthTrackerScreenState();
}

class _GrowthTrackerScreenState extends State<GrowthTrackerScreen> {
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

  // ── Add / Edit dialog ─────────────────────────────────────────────────────

  void _showEntryDialog({GrowthEntry? existing}) {
    final weightCtrl = TextEditingController(
        text: existing != null ? existing.weightKg.toString() : '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    DateTime selectedDate = existing?.recordedAt ?? DateTime.now();

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF20B2AA).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.show_chart,
                        color: Color(0xFF20B2AA), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(existing == null ? 'Add Growth Entry' : 'Edit Entry',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
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
                          color: const Color(0xFF20B2AA).withOpacity(0.3)),
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
                        if (w == null || w <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Enter a valid weight.')));
                          return;
                        }
                        Navigator.pop(ctx);
                        if (existing == null) {
                          await _provider.addGrowthEntry(
                            widget.petId,
                            GrowthEntry(
                              id: _uuid.v4(),
                              weightKg: w,
                              notes: notesCtrl.text.trim(),
                              recordedAt: selectedDate,
                            ),
                          );
                        } else {
                          await _provider.updateGrowthEntry(
                            widget.petId,
                            existing.copyWith(
                              weightKg: w,
                              notes: notesCtrl.text.trim(),
                              recordedAt: selectedDate,
                            ),
                          );
                        }
                      },
                      child: Text(existing == null ? 'Add' : 'Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(GrowthEntry entry) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: const Color(0xFFFFF5EE),
        title: const Text('Delete Entry?',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Remove this growth record?',
            style: TextStyle(fontSize: 13)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10))),
            onPressed: () async {
              Navigator.pop(ctx);
              await _provider.deleteGrowthEntry(widget.petId, entry.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  InputDecoration _deco(String label, IconData icon, Color color) =>
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

  @override
  Widget build(BuildContext context) {
    final pet = _pet;
    if (pet == null)
      return const Scaffold(body: Center(child: Text('Not found.')));

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
              const Expanded(
                  child: Text('Growth Tracker',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold))),
            ]),
          ),
          const SizedBox(height: 4),

          Expanded(
            child: entries.isEmpty
                ? _emptyState()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                    children: [
                      // Mini chart
                      if (entries.length >= 2) _buildChart(entries),
                      const SizedBox(height: 16),

                      // Entries
                      const _Label('WEIGHT HISTORY'),
                      const SizedBox(height: 8),
                      ...entries.reversed.map((e) => _EntryCard(
                            entry: e,
                            onEdit: () => _showEntryDialog(existing: e),
                            onDelete: () => _confirmDelete(e),
                          )),
                    ],
                  ),
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

  Widget _buildChart(List<GrowthEntry> entries) {
    final maxW = entries.map((e) => e.weightKg).reduce((a, b) => a > b ? a : b);
    final minW = entries.map((e) => e.weightKg).reduce((a, b) => a < b ? a : b);
    final range = (maxW - minW).clamp(0.1, double.infinity);

    return Container(
      height: 120,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('WEIGHT TREND',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: Color(0xFF20B2AA))),
          const SizedBox(height: 8),
          Expanded(
            child: CustomPaint(
              painter: _LinePainter(entries: entries, minW: minW, range: range),
              child: Container(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Opacity(
              opacity: 0.35,
              child: const Icon(Icons.show_chart,
                  size: 80, color: Color(0xFF20B2AA))),
          const SizedBox(height: 16),
          const Text('No growth records yet.',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFAA7755))),
          const SizedBox(height: 8),
          const Text('Tap + to record your cat\'s weight.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
      );
}

class _LinePainter extends CustomPainter {
  final List<GrowthEntry> entries;
  final double minW;
  final double range;

  _LinePainter(
      {required this.entries, required this.minW, required this.range});

  @override
  void paint(Canvas canvas, Size size) {
    if (entries.length < 2) return;
    final paint = Paint()
      ..color = const Color(0xFF20B2AA)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final dotPaint = Paint()
      ..color = const Color(0xFF20B2AA)
      ..style = PaintingStyle.fill;

    final pts = entries.asMap().entries.map((e) {
      final x = e.key / (entries.length - 1) * size.width;
      final y = size.height -
          ((e.value.weightKg - minW) / range) * size.height * 0.8 -
          size.height * 0.1;
      return Offset(x, y);
    }).toList();

    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(path, paint);
    for (final p in pts) {
      canvas.drawCircle(p, 4, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

class _EntryCard extends StatelessWidget {
  final GrowthEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EntryCard(
      {required this.entry, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.88),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF20B2AA).withOpacity(0.12),
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
        IconButton(
          icon: const Icon(Icons.edit_outlined,
              size: 18, color: Color(0xFF4682B4)),
          onPressed: onEdit,
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline,
              size: 18, color: Colors.redAccent),
          onPressed: onDelete,
        ),
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
