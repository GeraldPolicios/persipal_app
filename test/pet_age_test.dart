import 'package:flutter_test/flutter_test.dart';
import 'package:persipal_app/utils/pet_age.dart';

void main() {
  final now = DateTime(2026, 9, 21);

  group('petAgeLabel (age is computed from the birthday)', () {
    test('years and months', () {
      expect(petAgeLabel('June 15, 2024', now: now), '2 years, 3 months old');
    });

    test('whole years', () {
      expect(petAgeLabel('September 21, 2024', now: now), '2 years old');
    });

    test('months only under a year', () {
      expect(petAgeLabel('January 5, 2026', now: now), '8 months old');
    });

    test('days for a newborn', () {
      expect(petAgeLabel('September 11, 2026', now: now), '10 days old');
    });

    test('month rolls over on the day of the month', () {
      // 21 Sep is one day short of 3 full months after 22 Jun.
      expect(petAgeLabel('June 22, 2026', now: now), '2 months old');
    });

    test('missing, invalid and future birthdays give an empty label', () {
      expect(petAgeLabel('', now: now), '');
      expect(petAgeLabel('not a date', now: now), '');
      expect(petAgeLabel('December 25, 2030', now: now), '');
    });
  });
}
