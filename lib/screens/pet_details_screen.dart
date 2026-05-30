// screens/pet_profiles/pet_details_screen.dart
//
// Shows ALL cat details. Inline editing. Saves to Hive + Firestore.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../providers/pet_profile_provider.dart';
import '../../models/pet_extended_models.dart';

const _kAvatarColors = [
  Color(0xFFFFB3BA),
  Color(0xFFFFDFBA),
  Color(0xFFFFFFBA),
  Color(0xFFBAFFBA),
  Color(0xFFBAE1FF),
  Color(0xFFD4BAFF),
  Color(0xFFFFCCE5),
  Color(0xFFCCFFEE),
  Color(0xFFFFEBCC),
  Color(0xFFCCE5FF),
];

class PetDetailsScreen extends StatefulWidget {
  final String petId;
  const PetDetailsScreen({super.key, required this.petId});

  @override
  State<PetDetailsScreen> createState() => _PetDetailsScreenState();
}

class _PetDetailsScreenState extends State<PetDetailsScreen> {
  final _provider = PetProfileProvider.instance;
  bool _editing = false;
  bool _saving = false;

  // Edit controllers
  late TextEditingController _name,
      _breed,
      _age,
      _weight,
      _furColor,
      _birthday,
      _adoptionDate,
      _notes;
  late String _gender;
  late int _avatarColorValue;

  @override
  void initState() {
    super.initState();
    _provider.addListener(_refresh);
    _initControllers();
  }

  @override
  void dispose() {
    _provider.removeListener(_refresh);
    for (final c in [
      _name,
      _breed,
      _age,
      _weight,
      _furColor,
      _birthday,
      _adoptionDate,
      _notes
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() => _initControllers());
  }

  void _initControllers() {
    final p = _pet;
    if (p == null) return;
    _name = TextEditingController(text: p.name);
    _breed = TextEditingController(text: p.breed);
    _age = TextEditingController(text: p.age);
    _weight = TextEditingController(text: p.weightKg);
    _furColor = TextEditingController(text: p.furColor);
    _birthday = TextEditingController(text: p.birthday);
    _adoptionDate = TextEditingController(text: p.adoptionDate);
    _notes = TextEditingController(text: p.notes);
    _gender = p.gender;
    _avatarColorValue = p.avatarColorValue;
  }

  FullPetProfile? get _pet => _provider.getById(widget.petId);

  Future<void> _save() async {
    final pet = _pet;
    if (pet == null) return;
    setState(() => _saving = true);
    await _provider.updateDetails(pet.copyWith(
      name: _name.text.trim(),
      breed: _breed.text.trim(),
      age: _age.text.trim(),
      weightKg: _weight.text.trim(),
      furColor: _furColor.text.trim(),
      birthday: _birthday.text.trim(),
      adoptionDate: _adoptionDate.text.trim(),
      notes: _notes.text.trim(),
      gender: _gender,
      avatarColorValue: _avatarColorValue,
    ));
    setState(() {
      _saving = false;
      _editing = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text('Profile saved!'),
        ]),
        backgroundColor: const Color(0xFF32CD32),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFFFF5EE),
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 8),
          Text('Delete Profile?',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ]),
        content: Text(
            'Delete ${_pet?.name ?? "this cat"}\'s profile permanently?',
            style: const TextStyle(fontSize: 13)),
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
            onPressed: () async {
              Navigator.pop(ctx);
              await _provider.deleteProfile(widget.petId);
              if (mounted) {
                Navigator.pop(context); // back to hub
                Navigator.pop(context); // back to list
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (c, child) => Theme(
        data: Theme.of(c).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFFFF8C69))),
        child: child!,
      ),
    );
    if (picked != null) {
      ctrl.text = DateFormat('MMMM d, yyyy').format(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pet = _pet;
    if (pet == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFFFE6CC),
        body: Center(child: Text('Profile not found.')),
      );
    }

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
              const Expanded(
                  child: Text('Pet Details',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold))),
              if (!_editing) ...[
                IconButton(
                  icon:
                      const Icon(Icons.edit_outlined, color: Color(0xFF4682B4)),
                  onPressed: () => setState(() => _editing = true),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: _confirmDelete,
                ),
              ] else ...[
                TextButton(
                  onPressed: () => setState(() {
                    _editing = false;
                    _initControllers();
                  }),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8C69),
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ]),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: [
                // Avatar + name hero
                Center(
                  child: Column(children: [
                    // Colour picker in edit mode
                    if (_editing) ...[
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: _kAvatarColors.map((c) {
                          final sel = c.value == _avatarColorValue;
                          return GestureDetector(
                            onTap: () =>
                                setState(() => _avatarColorValue = c.value),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: sel
                                        ? Colors.black87
                                        : Colors.transparent,
                                    width: 2),
                              ),
                              child: sel
                                  ? const Icon(Icons.check,
                                      size: 14, color: Colors.black54)
                                  : null,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Color(_avatarColorValue),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Color(_avatarColorValue).withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 5))
                        ],
                      ),
                      child: const Center(
                          child: Text('🐱', style: TextStyle(fontSize: 48))),
                    ),
                    const SizedBox(height: 12),
                    if (!_editing)
                      Text(pet.name,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold)),
                  ]),
                ),
                const SizedBox(height: 16),

                // Form fields
                _section('Basic Info', [
                  _editRow('Name', _name, Icons.edit, editing: _editing),
                  _editRow('Breed', _breed, Icons.pets, editing: _editing),
                  _editRow('Age', _age, Icons.cake,
                      hint: 'e.g. 2 years', editing: _editing),
                ]),
                const SizedBox(height: 12),
                _section('Physical Info', [
                  _editRow('Weight (kg)', _weight, Icons.monitor_weight,
                      hint: 'e.g. 3.5 kg', editing: _editing),
                  _editRow('Fur Color', _furColor, Icons.palette,
                      editing: _editing),
                ]),
                const SizedBox(height: 12),
                _section('Gender', [
                  if (_editing)
                    Row(
                        children: ['Female', 'Male'].map((g) {
                      final sel = _gender == g;
                      return Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: GestureDetector(
                          onTap: () => setState(() => _gender = g),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color:
                                  sel ? const Color(0xFFFF8C69) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color:
                                      const Color(0xFFFF8C69).withOpacity(0.5)),
                            ),
                            child:
                                Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(g == 'Female' ? Icons.female : Icons.male,
                                  size: 16,
                                  color: sel
                                      ? Colors.white
                                      : const Color(0xFFFF8C69)),
                              const SizedBox(width: 4),
                              Text(g,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: sel
                                          ? Colors.white
                                          : const Color(0xFFAA7755))),
                            ]),
                          ),
                        ),
                      );
                    }).toList())
                  else
                    _readRow('Gender', pet.gender,
                        pet.gender == 'Female' ? Icons.female : Icons.male),
                ]),
                const SizedBox(height: 12),
                _section('Dates', [
                  _dateRow('Birthday', _birthday, editing: _editing),
                  _dateRow('Adoption Date', _adoptionDate, editing: _editing),
                ]),
                const SizedBox(height: 12),
                _section('Notes', [
                  _editing
                      ? TextField(
                          controller: _notes,
                          maxLines: 4,
                          decoration: _fieldDeco('Notes', Icons.notes),
                          style: const TextStyle(fontSize: 13),
                        )
                      : _readRow('Notes', pet.notes.isEmpty ? '—' : pet.notes,
                          Icons.notes),
                ]),
              ],
            ),
          ),
        ])),
      ]),
    );
  }

  Widget _section(String title, List<Widget> children) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.82),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title.toUpperCase(),
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: Color(0xFFAA7755))),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      );

  Widget _editRow(String label, TextEditingController ctrl, IconData icon,
      {String? hint, required bool editing}) {
    if (!editing) {
      return _readRow(label, ctrl.text.isEmpty ? '—' : ctrl.text, icon);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        decoration: _fieldDeco(label, icon, hint: hint),
        style: const TextStyle(fontSize: 13),
      ),
    );
  }

  Widget _dateRow(String label, TextEditingController ctrl,
      {required bool editing}) {
    if (!editing) {
      return _readRow(
          label, ctrl.text.isEmpty ? '—' : ctrl.text, Icons.calendar_today);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _pickDate(ctrl),
        child: AbsorbPointer(
          child: TextField(
            controller: ctrl,
            decoration: _fieldDeco(label, Icons.calendar_today),
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ),
    );
  }

  Widget _readRow(String label, String value, IconData icon) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: [
          Icon(icon, size: 16, color: const Color(0xFFAA7755)),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFAA7755))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontSize: 13),
                  overflow: TextOverflow.ellipsis)),
        ]),
      );

  InputDecoration _fieldDeco(String label, IconData icon, {String? hint}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFFAA7755)),
        prefixIcon: Icon(icon, size: 16, color: const Color(0xFFFF8C69)),
        filled: true,
        fillColor: const Color(0xFFFFF5EE),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              BorderSide(color: const Color(0xFFFF8C69).withOpacity(0.2)),
        ),
      );
}
