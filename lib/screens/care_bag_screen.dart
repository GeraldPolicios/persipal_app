import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/reward_service.dart';
import '../providers/virtual_pet_provider.dart';

/// Inventory for consumables used by PersiPal's virtual Persian cat.
class CareBagScreen extends StatelessWidget {
  const CareBagScreen({super.key});

  static const _cream = Color(0xFFFFF8F0);
  static const _brown = Color(0xFF85552F);
  static const _muted = Color(0xFFAA7A51);

  @override
  Widget build(BuildContext context) {
    final rewards = context.watch<RewardService>();
    final virtualPet = context.watch<VirtualPetProvider>();
    return Scaffold(
      backgroundColor: const Color(0xFFFFE7D0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 560),
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
              decoration: BoxDecoration(
                color: _cream,
                borderRadius: BorderRadius.circular(32),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 18,
                      offset: Offset(0, 8))
                ],
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Text('👜', style: TextStyle(fontSize: 32)),
                      const SizedBox(width: 12),
                      const Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('Care Bag',
                                style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    color: _brown)),
                            Text('Your cat-care items',
                                style: TextStyle(fontSize: 15, color: _muted)),
                          ])),
                      IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close,
                              size: 30, color: Color(0xFF654D40))),
                    ]),
                    const SizedBox(height: 22),
                    const Text('YOUR ITEMS',
                        style: TextStyle(
                            fontSize: 13,
                            letterSpacing: 1.8,
                            fontWeight: FontWeight.w800,
                            color: _muted)),
                    const SizedBox(height: 12),
                    _itemCard(
                        emoji: '💊',
                        name: 'Cat Medicine',
                        description: 'For your sick virtual Persian cat.',
                        count: rewards.medicineCount,
                        detail: 'Shop price: 10 points'),
                    const SizedBox(height: 12),
                    _itemCard(
                        emoji: '💉',
                        name: 'Persian Cat Vaccine',
                        description:
                            'A separate vaccine item for the virtual Persian cat.',
                        count: rewards.vaccineCount,
                        detail: 'Shop price: 10 points'),
                    const SizedBox(height: 18),
                    Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFFE9D5),
                            borderRadius: BorderRadius.circular(18)),
                        child: Text(
                            'Use the quick Care Bag in the Virtual Pet room to drag Medicine onto a sick cat or Vaccine onto the cat. Vaccination records are saved separately from real-pet records.\n\nVaccinations recorded: ${virtualPet.vaccinationRecords.length}${virtualPet.lastVaccinatedAt == null ? '' : '\nLast vaccination: ${MaterialLocalizations.of(context).formatMediumDate(virtualPet.lastVaccinatedAt!)}'}',
                            style: const TextStyle(
                                color: _brown,
                                height: 1.4,
                                fontWeight: FontWeight.w600))),
                  ]),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _itemCard(
      {required String emoji,
      required String name,
      required String description,
      required int count,
      required String detail,
      bool subdued = false}) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFEBD5BE))),
      child: Row(children: [
        Container(
            width: 58,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color:
                    subdued ? const Color(0xFFF3E8D9) : const Color(0xFFFFE8D8),
                borderRadius: BorderRadius.circular(16)),
            child: Text(emoji, style: const TextStyle(fontSize: 30))),
        const SizedBox(width: 13),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: _brown)),
            const SizedBox(height: 4),
            Text(description,
                style:
                    const TextStyle(fontSize: 12, color: _muted, height: 1.3)),
            const SizedBox(height: 5),
            Text(detail,
                style: TextStyle(
                    fontSize: 11, color: subdued ? Colors.grey : _muted))
          ]),
        ),
        const SizedBox(width: 8),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
                color: const Color(0xFFFFE4D6),
                borderRadius: BorderRadius.circular(12)),
            child: Text('× $count',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: _brown, fontSize: 16))),
      ]),
    );
  }
}
