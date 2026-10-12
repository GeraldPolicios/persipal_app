import 'package:flutter_test/flutter_test.dart';
import 'package:persipal_app/models/models.dart';
import 'package:persipal_app/services/firebase_sync_service.dart';

void main() {
  group('AppSettings defaults', () {
    test('a never-saved default can be serialized (used by first-login sync)',
        () {
      expect(() => const AppSettings().toMap(), returnsNormally);
    });

    test('a cloud copy is newer than a never-saved default (merge order)', () {
      final cloud = const AppSettings().copyWith(notificationsEnabled: false);
      expect(cloud.updatedAt.isAfter(const AppSettings().updatedAt), isTrue);
    });

    test('round-trips through toMap/fromMap', () {
      final saved = const AppSettings().copyWith(soundEnabled: false);
      final loaded = AppSettings.fromMap(saved.toMap());
      expect(loaded.soundEnabled, isFalse);
      expect(loaded.notificationsEnabled, isTrue);
    });

    test('cloud data containing only settings is not treated as empty', () {
      final cloud = CloudData(
        pets: const [],
        logs: const [],
        reminders: const [],
        quizzes: const [],
        settings: const AppSettings().copyWith(notificationsEnabled: false),
      );

      expect(cloud.isEmpty, isFalse);
    });
  });
}
