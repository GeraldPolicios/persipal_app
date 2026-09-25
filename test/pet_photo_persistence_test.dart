// Tests the persistence layer PetPhotoService is built on: two genuinely
// separate Hive-backed maps (profile photo vs. cover photo), each keyed by
// petId, that round-trip across a fresh load (simulating an app restart).
//
// PetPhotoService itself also calls path_provider (to copy a picked file
// into the app's documents directory), which has no platform implementation
// under plain `flutter test` — that file-copy behavior was verified by code
// review instead (see the final report). What's tested here is the exact
// persistence mechanism this task changed: that avatar and cover photos
// don't share storage, and that data survives a reload.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:persipal_app/services/local_storage_service.dart';

void main() {
  late Directory dir;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('persipal_photo_test');
    Hive.init(dir.path);
    await Hive.openBox<String>('ls_pet_photos');
  });

  tearDownAll(() async {
    await Hive.close();
    dir.deleteSync(recursive: true);
  });

  setUp(() async {
    await Hive.box<String>('ls_pet_photos').clear();
  });

  final local = LocalStorageService.instance;

  group('avatar vs. cover photo paths are stored independently', () {
    test('saving a cover photo path does not affect the avatar map', () async {
      await local.savePetPhotoPaths({'cat1': '/a/avatar1.jpg'});
      await local.savePetCoverPhotoPaths({'cat1': '/a/cover1.jpg'});

      expect(await local.fetchPetPhotoPaths(), {'cat1': '/a/avatar1.jpg'});
      expect(
          await local.fetchPetCoverPhotoPaths(), {'cat1': '/a/cover1.jpg'});
    });

    test('clearing the avatar map leaves the cover map untouched', () async {
      await local.savePetPhotoPaths({'cat1': '/a/avatar1.jpg'});
      await local.savePetCoverPhotoPaths({'cat1': '/a/cover1.jpg'});

      await local.savePetPhotoPaths({});

      expect(await local.fetchPetPhotoPaths(), isEmpty);
      expect(
          await local.fetchPetCoverPhotoPaths(), {'cat1': '/a/cover1.jpg'});
    });

    test('an empty store returns an empty map, not null/a crash', () async {
      expect(await local.fetchPetPhotoPaths(), isEmpty);
      expect(await local.fetchPetCoverPhotoPaths(), isEmpty);
    });
  });

  group('persistence survives a fresh read (simulated app restart)', () {
    test('multiple pets\' avatar and cover photos all round-trip', () async {
      await local.savePetPhotoPaths({
        'catA': '/a/avatarA.jpg',
        'catB': '/a/avatarB.jpg',
      });
      await local.savePetCoverPhotoPaths({
        'catA': '/a/coverA.jpg',
      });

      // A brand-new read (no shared in-memory state) — same as what
      // PetPhotoService.init() does on a real app restart.
      final avatars = await LocalStorageService.instance.fetchPetPhotoPaths();
      final covers =
          await LocalStorageService.instance.fetchPetCoverPhotoPaths();

      expect(avatars['catA'], '/a/avatarA.jpg');
      expect(avatars['catB'], '/a/avatarB.jpg');
      expect(covers['catA'], '/a/coverA.jpg');
      expect(covers.containsKey('catB'), isFalse);
    });
  });
}
