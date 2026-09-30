import 'package:flutter_test/flutter_test.dart';
import 'package:persipal_app/models/pet_extended_models.dart';

void main() {
  final recordedAt = DateTime(2026, 1, 1, 12);

  test('growth history is the current weight when legacy weight is stale', () {
    final profile = FullPetProfile(
      id: 'cat-1',
      name: 'Miso',
      weightKg: '',
      growthEntries: [
        GrowthEntry(
          id: 'growth-1',
          weightKg: 4.2,
          recordedAt: recordedAt,
        ),
      ],
      createdAt: recordedAt,
      updatedAt: recordedAt,
    );

    final map = profile.toMap()..['weightKg'] = '2.8';
    final restored = FullPetProfile.fromMap(map);

    expect(restored.currentWeightKg, 4.2);
    expect(restored.weightKg, '4.2');
  });

  test('equal timestamps keep the existing first-entry tie breaker', () {
    final profile = FullPetProfile(
      id: 'cat-2',
      name: 'Nala',
      growthEntries: [
        GrowthEntry(id: 'first', weightKg: 3.1, recordedAt: recordedAt),
        GrowthEntry(id: 'second', weightKg: 4.9, recordedAt: recordedAt),
      ],
      createdAt: recordedAt,
      updatedAt: recordedAt,
    );

    expect(profile.latestGrowthEntry?.id, 'first');
    expect(profile.currentWeightKg, 3.1);
  });
}
