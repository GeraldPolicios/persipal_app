// screens/pet_profiles/pet_profile_screen.dart
//
// Pet Profiles — main selection screen.
// Shows ONLY: avatar emoji, name, breed.  Max 10 profiles.

import 'package:flutter/material.dart';
import '../../providers/pet_profile_provider.dart';
import '../../models/pet_extended_models.dart';
import 'my_pet_profile_screen.dart';
import '../../widgets/tap_effects.dart';

const _kColors = [
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

class PetProfileScreen extends StatefulWidget {
  const PetProfileScreen({super.key});
  @override
  State<PetProfileScreen> createState() => _PetProfileScreenState();
}

class _PetProfileScreenState extends State<PetProfileScreen> {
  late PetProfileProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = PetProfileProvider.instance;
    _provider.addListener(_refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) => _provider.init());
  }

  @override
  void dispose() {
    _provider.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() => setState(() {});

  void _showAddDialog() {
    if (!_provider.canAdd) {
      _showMaxReached();
      return;
    }
    final nameCtrl = TextEditingController();
    final breedCtrl = TextEditingController(text: 'Persian');
    int colorVal = _kColors[_provider.count % _kColors.length].value;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: const Color(0xFFFFF8F2),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF8C69).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.pets,
                          color: Color(0xFFFF8C69), size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Text('Add New Cat',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 20),
                  const Text('Avatar Color',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFAA7755))),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _kColors.map((c) {
                      final sel = c.value == colorVal;
                      return GestureDetector(
                        onTap: () => setD(() => colorVal = c.value),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color:
                                    sel ? Colors.black87 : Colors.transparent,
                                width: 2.5),
                            boxShadow: sel
                                ? [
                                    BoxShadow(
                                        color: c.withOpacity(0.5),
                                        blurRadius: 6)
                                  ]
                                : null,
                          ),
                          child: sel
                              ? const Icon(Icons.check,
                                  size: 16, color: Colors.black54)
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  _field(nameCtrl, 'Cat Name *', Icons.edit),
                  const SizedBox(height: 12),
                  _field(breedCtrl, 'Breed', Icons.pets),
                  const SizedBox(height: 22),
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
                          backgroundColor: const Color(0xFFFF8C69),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Cat'),
                        onPressed: () async {
                          if (nameCtrl.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Cat name is required.')));
                            return;
                          }
                          Navigator.pop(ctx);
                          await _provider.createProfile(
                            name: nameCtrl.text.trim(),
                            breed: breedCtrl.text.trim(),
                            avatarColorValue: colorVal,
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

  void _showMaxReached() {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Maximum of 10 cat profiles reached.'),
      backgroundColor: const Color(0xFFAA7755),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Widget _field(TextEditingController c, String label, IconData icon) =>
      TextField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13, color: Color(0xFFAA7755)),
          prefixIcon: Icon(icon, size: 18, color: const Color(0xFFFF8C69)),
          filled: true,
          fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: const Color(0xFFFF8C69).withOpacity(0.2)),
          ),
        ),
        style: const TextStyle(fontSize: 14),
      );

  @override
  Widget build(BuildContext context) {
    final profiles = _provider.profiles;
    return Scaffold(
      backgroundColor: const Color(0xFFFFE6CC),
      body: Stack(children: [
        Positioned.fill(
            child: Opacity(
          opacity: 0.10,
          child: Image.asset('assets/images/paws_bg.png', fit: BoxFit.cover),
        )),
        SafeArea(
            child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
                const Text('🐾 ', style: TextStyle(fontSize: 20)),
                const Expanded(
                    child: Text('Pet Profiles',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold))),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8C69).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text('${profiles.length}/10',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFAA7755))),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Text(
                profiles.isEmpty
                    ? 'Add your first Persian cat!'
                    : 'Tap a cat to manage their profile.',
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFAA7755),
                    fontStyle: FontStyle.italic),
              ),
            ),

            // Grid
            Expanded(
              child: _provider.loading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFFFF8C69)))
                  : profiles.isEmpty
                      ? _emptyState()
                      : GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 0.82,
                          ),
                          itemCount: profiles.length,
                          itemBuilder: (_, i) => _PetCard(profile: profiles[i]),
                        ),
            ),
          ],
        )),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _provider.canAdd ? _showAddDialog : _showMaxReached,
        backgroundColor:
            _provider.canAdd ? const Color(0xFFFF8C69) : Colors.grey.shade400,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Cat',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Opacity(
              opacity: 0.35, child: Text('🐱', style: TextStyle(fontSize: 80))),
          const SizedBox(height: 16),
          const Text('No cat profiles yet!',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFAA7755))),
          const SizedBox(height: 8),
          const Text('Tap + Add Cat to create your\nfirst Persian cat profile.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey)),
        ]),
      );
}

// ─── Pet Card ─────────────────────────────────────────────────────────────────

class _PetCard extends StatelessWidget {
  final FullPetProfile profile;
  const _PetCard({required this.profile});

  @override
  Widget build(BuildContext context) {
    return BounceButton(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => MyPetProfileScreen(petId: profile.id))),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.90),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.07),
                blurRadius: 12,
                offset: const Offset(0, 4))
          ],
        ),
        child: Stack(children: [
          // Watermark paw
          Positioned(
              right: -8,
              bottom: -8,
              child: Opacity(
                opacity: 0.06,
                child:
                    const Icon(Icons.pets, size: 68, color: Color(0xFFFF8C69)),
              )),

          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            // Avatar
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: profile.avatarColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: profile.avatarColor.withOpacity(0.5),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ],
              ),
              child: const Center(
                  child: Text('🐱', style: TextStyle(fontSize: 36))),
            ),
            const SizedBox(height: 12),

            // Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                profile.name,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4A2C1A)),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 5),

            // Breed pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFF8C69).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                profile.breed,
                style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFFF8C69),
                    fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),

          Positioned(
              top: 10,
              right: 10,
              child: Icon(Icons.chevron_right,
                  size: 18, color: Colors.grey.withOpacity(0.35))),
        ]),
      ),
    );
  }
}
