import 'package:flutter_test/flutter_test.dart';
import 'package:persipal_app/models/models.dart';
import 'package:persipal_app/models/pet_extended_models.dart';
import 'package:persipal_app/services/vet_report_service.dart';

void main() {
  final pet = FullPetProfile.create(
    id: 'p1',
    name: 'Meow Meow',
    birthday: 'June 15, 2024',
  );

  ActivityLogModel entry(ActionType type, String desc, DateTime ts,
          {String petId = 'p1', String petName = 'Meow Meow'}) =>
      ActivityLogModel(
        id: '${type.name}-${ts.millisecondsSinceEpoch}',
        petId: petId,
        petName: petName,
        actionType: type,
        description: desc,
        timestamp: ts,
      );

  group('buildVetReport', () {
    test('includes pet name, generated time, and every relevant section',
        () {
      final logs = [
        entry(ActionType.growth, 'Recorded weight — Meow Meow: 4.2kg',
            DateTime(2026, 9, 1)),
        entry(ActionType.vaccination, 'Completed vaccination — Rabies',
            DateTime(2026, 9, 2)),
        entry(ActionType.reminder, 'Completed reminder — Morning feeding',
            DateTime(2026, 9, 3)),
        entry(ActionType.health, 'Health/checkup note — Meow Meow: ear check',
            DateTime(2026, 9, 4)),
      ];
      final report = buildVetReport(
        pet: pet,
        logs: logs,
        generatedAt: DateTime(2026, 9, 22, 10, 30),
      );

      expect(report, contains('Meow Meow'));
      expect(report, contains('Sep 22, 2026'));
      expect(report, contains('All recorded history'));
      expect(report, contains('4.2kg'));
      expect(report, contains('Rabies'));
      expect(report, contains('Morning feeding'));
      expect(report, contains('ear check'));
      expect(report, contains('not a medical diagnosis'));
    });

    test('excludes irrelevant entries (login/sync/virtual actions)', () {
      final logs = [
        entry(ActionType.login, 'Signed in — a@b.com', DateTime(2026, 9, 1)),
        entry(ActionType.sync, 'Cloud sync completed', DateTime(2026, 9, 1)),
        entry(ActionType.feed, '🎮 Virtual play — fed Whiskers',
            DateTime(2026, 9, 1)),
      ];
      final report = buildVetReport(pet: pet, logs: logs);
      expect(report, isNot(contains('Signed in')));
      expect(report, isNot(contains('Cloud sync')));
      expect(report, isNot(contains('Virtual play')));
    });

    test('respects the selected date period', () {
      final inRange = entry(
          ActionType.growth, 'Recorded weight — Meow Meow: 4.0kg',
          DateTime(2026, 9, 10));
      final outOfRange = entry(
          ActionType.growth, 'Recorded weight — Meow Meow: 3.0kg',
          DateTime(2026, 1, 1));
      final report = buildVetReport(
        pet: pet,
        logs: [inRange, outOfRange],
        periodStart: DateTime(2026, 9, 1),
        periodEnd: DateTime(2026, 10, 1),
      );
      expect(report, contains('4.0kg'));
      expect(report, isNot(contains('3.0kg')));
    });

    test('shows a graceful empty message for a section with no entries', () {
      final report = buildVetReport(pet: pet, logs: const []);
      expect(report, contains('No weight entries recorded'));
      expect(report, contains('No vaccination/veterinary-care records'));
    });
  });
}
