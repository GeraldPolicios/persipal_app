// lib/services/pet_photo_service.dart
//
// Local-only pet profile photos: the avatar photo and the cover/background
// photo, each keyed by petId in its own map/Hive key.
//
// A picked photo is copied into this device's app-documents directory (not
// referenced by its original image-picker temp path, which isn't guaranteed
// to stay valid) and its path is stored keyed by petId. This is
// DELIBERATELY never uploaded to Firestore alongside FullPetProfile: a raw
// local file path is meaningless on another device, and the existing sync
// model has no support for binary blobs. Mirrors VirtualAchievementService's
// device-local-only pattern — safest option given the current architecture,
// per the Pet Profile Visual Redesign phase's explicit instruction not to
// invent a cloud-image system.
//
// Account deletion uses [clearAll] to wipe every file, but a plain sign-out
// deliberately does NOT call it — see
// AppProvider's sign-out flow — so a photo set by an account is still there
// when that same account signs back in on this device, while never being
// reachable by a different account (whose own pets never share these IDs).
// True cross-device restoration is NOT supported — there is no cloud copy.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'local_storage_service.dart';

class PetPhotoService extends ChangeNotifier {
  PetPhotoService._();
  static final PetPhotoService instance = PetPhotoService._();

  final LocalStorageService _local = LocalStorageService.instance;

  Map<String, String> _paths = {}; // petId -> absolute local file path
  // petId -> absolute local file path for the profile's cover/background
  // photo — same device-local pattern as the avatar photo above, kept as a
  // second map/Hive key rather than a new service.
  Map<String, String> _coverPaths = {};
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _paths = await _local.fetchPetPhotoPaths();
    _coverPaths = await _local.fetchPetCoverPhotoPaths();
  }

  /// Returns the pet's photo path only if the file still actually exists on
  /// disk — protects every caller from a missing/deleted file automatically.
  String? pathFor(String petId) {
    final path = _paths[petId];
    if (path == null) return null;
    return File(path).existsSync() ? path : null;
  }

  Future<void> setPhoto(String petId, File source) async {
    final dir = await getApplicationDocumentsDirectory();
    final rawExt = source.path.contains('.') ? source.path.split('.').last : 'jpg';
    final ext = rawExt.length <= 5 ? rawExt.toLowerCase() : 'jpg';
    final dest = File('${dir.path}/pet_photo_$petId.$ext');

    final old = _paths[petId];
    if (old != null && old != dest.path && File(old).existsSync()) {
      try {
        await File(old).delete();
      } catch (_) {
        // Best-effort cleanup — a stray old file isn't worth failing over.
      }
    }

    await source.copy(dest.path);

    _paths = {..._paths, petId: dest.path};
    await _local.savePetPhotoPaths(_paths);
    notifyListeners();
  }

  /// Returns the pet's cover/background photo path only if the file still
  /// actually exists on disk — same missing-file safety as [pathFor].
  String? coverPathFor(String petId) {
    final path = _coverPaths[petId];
    if (path == null) return null;
    return File(path).existsSync() ? path : null;
  }

  Future<void> setCoverPhoto(String petId, File source) async {
    final dir = await getApplicationDocumentsDirectory();
    final rawExt = source.path.contains('.') ? source.path.split('.').last : 'jpg';
    final ext = rawExt.length <= 5 ? rawExt.toLowerCase() : 'jpg';
    final dest = File('${dir.path}/pet_cover_$petId.$ext');

    final old = _coverPaths[petId];
    if (old != null && old != dest.path && File(old).existsSync()) {
      try {
        await File(old).delete();
      } catch (_) {
        // Best-effort cleanup — a stray old file isn't worth failing over.
      }
    }

    await source.copy(dest.path);

    _coverPaths = {..._coverPaths, petId: dest.path};
    await _local.savePetCoverPhotoPaths(_coverPaths);
    notifyListeners();
  }

  /// Deletes this pet's photo file(s) + record(s) (profile photo and cover
  /// photo). Called when a real pet profile itself is deleted — never for
  /// virtual-cat state, which has no photo.
  Future<void> deletePhotoForPet(String petId) async {
    final path = _paths[petId];
    if (path != null && File(path).existsSync()) {
      try {
        await File(path).delete();
      } catch (_) {
        // Best-effort — the record is removed either way below.
      }
    }
    _paths = {..._paths}..remove(petId);
    await _local.savePetPhotoPaths(_paths);

    final coverPath = _coverPaths[petId];
    if (coverPath != null && File(coverPath).existsSync()) {
      try {
        await File(coverPath).delete();
      } catch (_) {
        // Best-effort.
      }
    }
    _coverPaths = {..._coverPaths}..remove(petId);
    await _local.savePetCoverPhotoPaths(_coverPaths);

    notifyListeners();
  }

  /// Clears every pet's photo (profile + cover) on this device. Used for
  /// account deletion, but not for a plain sign-out, which must leave these
  /// files in place so signing back into
  /// the SAME account on this device still finds them (there is currently
  /// no cloud copy to restore from — see this file's header comment).
  /// Another account never sees them either way, since its own pet
  /// profiles never contain this account's pet IDs.
  Future<void> clearAll() async {
    for (final path in [..._paths.values, ..._coverPaths.values]) {
      if (File(path).existsSync()) {
        try {
          await File(path).delete();
        } catch (_) {
          // Best-effort.
        }
      }
    }
    _paths = {};
    _coverPaths = {};
    await _local.savePetPhotoPaths(_paths);
    await _local.savePetCoverPhotoPaths(_coverPaths);
    notifyListeners();
  }
}
