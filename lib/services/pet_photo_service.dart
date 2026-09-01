// lib/services/pet_photo_service.dart
//
// Local-only pet profile photos.
//
// A picked photo is copied into this device's app-documents directory and
// its path is stored keyed by petId. This is DELIBERATELY never uploaded to
// Firestore alongside FullPetProfile: a raw local file path is meaningless
// on another device, and the existing sync model has no support for binary
// blobs. Mirrors VirtualAchievementService's device-local-only pattern —
// safest option given the current architecture, per the Pet Profile Visual
// Redesign phase's explicit instruction not to invent a cloud-image system.

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'local_storage_service.dart';

class PetPhotoService extends ChangeNotifier {
  PetPhotoService._();
  static final PetPhotoService instance = PetPhotoService._();

  final LocalStorageService _local = LocalStorageService.instance;

  Map<String, String> _paths = {}; // petId -> absolute local file path
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _paths = await _local.fetchPetPhotoPaths();
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

  /// Deletes this pet's photo file + record. Called when a real pet profile
  /// itself is deleted — never for virtual-cat state, which has no photo.
  Future<void> deletePhotoForPet(String petId) async {
    final path = _paths[petId];
    if (path == null) return;

    if (File(path).existsSync()) {
      try {
        await File(path).delete();
      } catch (_) {
        // Best-effort — the record is removed either way below.
      }
    }

    _paths = {..._paths}..remove(petId);
    await _local.savePetPhotoPaths(_paths);
    notifyListeners();
  }

  /// Clears every pet's photo on this device. Used on sign-out/account
  /// deletion so the next guest/account on this device never sees a
  /// departed account's pet photos — mirrors PetProfileProvider's own
  /// clearAllLocalData().
  Future<void> clearAll() async {
    for (final path in _paths.values) {
      if (File(path).existsSync()) {
        try {
          await File(path).delete();
        } catch (_) {
          // Best-effort.
        }
      }
    }
    _paths = {};
    await _local.savePetPhotoPaths(_paths);
    notifyListeners();
  }
}
