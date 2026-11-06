// Stores pet photos locally for offline display and in the signed-in user's
// Firestore data so they can be restored after reinstalling the app.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import 'auth_service.dart';
import 'connectivity_service.dart';
import 'local_storage_service.dart';

class PetPhotoService extends ChangeNotifier {
  PetPhotoService._();
  static final PetPhotoService instance = PetPhotoService._();

  static const String _collectionName = 'pet_photos';
  static const int _maxCloudImageBytes = 650 * 1024;

  final LocalStorageService _local = LocalStorageService.instance;
  final AuthService _auth = AuthService.instance;
  final ConnectivityService _connectivity = ConnectivityService.instance;

  Map<String, String> _paths = {};
  Map<String, String> _coverPaths = {};
  bool _initialized = false;
  bool _flushInProgress = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    _paths = await _local.fetchPetPhotoPaths();
    _coverPaths = await _local.fetchPetCoverPhotoPaths();
    _auth.addListener(_onSyncStateChanged);
    _connectivity.addListener(_onSyncStateChanged);
    _onSyncStateChanged();
  }

  @override
  void dispose() {
    _auth.removeListener(_onSyncStateChanged);
    _connectivity.removeListener(_onSyncStateChanged);
    super.dispose();
  }

  void _onSyncStateChanged() {
    if (_canSync) unawaited(flushPendingCloudPhotosIfPossible());
  }

  bool get _canSync =>
      _auth.isAuthenticated &&
      _auth.accountSyncAllowed &&
      _connectivity.isOnline;

  CollectionReference<Map<String, dynamic>>? get _photoCollection {
    if (!_auth.isAuthenticated || !_auth.accountSyncAllowed) return null;
    final uid = _auth.userId;
    if (uid.isEmpty || uid == 'guest') return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection(_collectionName);
  }

  String? pathFor(String petId) {
    final path = _paths[petId];
    if (path == null) return null;
    return File(path).existsSync() ? path : null;
  }

  String? coverPathFor(String petId) {
    final path = _coverPaths[petId];
    if (path == null) return null;
    return File(path).existsSync() ? path : null;
  }

  Future<void> setPhoto(String petId, File source) =>
      _savePhoto(petId, source, _PhotoKind.avatar);

  Future<void> setCoverPhoto(String petId, File source) =>
      _savePhoto(petId, source, _PhotoKind.cover);

  Future<void> _savePhoto(
    String petId,
    File source,
    _PhotoKind kind,
  ) async {
    await init();
    final dir = await getApplicationDocumentsDirectory();
    final destination = File(
      '${dir.path}/pet_${kind.filePrefix}_${Uri.encodeComponent(petId)}_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    final oldPath = _pathsFor(kind)[petId];

    // Normalize the picked image locally too, so the Hive path and cloud copy
    // always refer to a stable JPEG instead of the image-picker temp file.
    final bytes = await _encodeImage(source);
    await destination.writeAsBytes(bytes, flush: true);
    try {
      final nextPaths = {..._pathsFor(kind), petId: destination.path};
      await _savePaths(kind, nextPaths);
      _setPaths(kind, nextPaths);
    } catch (_) {
      if (await destination.exists()) await destination.delete();
      rethrow;
    }

    if (oldPath != null && oldPath != destination.path) {
      try {
        final oldFile = File(oldPath);
        if (await oldFile.exists()) await oldFile.delete();
      } catch (_) {
        // A stale local copy must not fail a successful photo change.
      }
    }
    notifyListeners();

    // Keep the local change successful even if the network is unavailable;
    // a UID-scoped queue token retries the cloud copy later.
    await _queueOrUpload(petId, kind);
  }

  Map<String, String> _pathsFor(_PhotoKind kind) =>
      kind == _PhotoKind.avatar ? _paths : _coverPaths;

  void _setPaths(_PhotoKind kind, Map<String, String> paths) {
    if (kind == _PhotoKind.avatar) {
      _paths = paths;
    } else {
      _coverPaths = paths;
    }
  }

  Future<void> _savePaths(
    _PhotoKind kind,
    Map<String, String> paths,
  ) =>
      kind == _PhotoKind.avatar
          ? _local.savePetPhotoPaths(paths)
          : _local.savePetCoverPhotoPaths(paths);

  Future<Uint8List> _encodeImage(File source) async {
    final decoded = img.decodeImage(await source.readAsBytes());
    if (decoded == null) throw const FormatException('Unsupported image.');

    var image = img.bakeOrientation(decoded);
    final longestSide = image.width > image.height ? image.width : image.height;
    if (longestSide > 1600) {
      final scale = 1600 / longestSide;
      image = img.copyResize(
        image,
        width: (image.width * scale).round(),
        height: (image.height * scale).round(),
      );
    }

    for (var resizePass = 0; resizePass < 5; resizePass++) {
      for (final quality in const [85, 75, 65, 55, 45, 35]) {
        final encoded = Uint8List.fromList(img.encodeJpg(image, quality: quality));
        if (encoded.lengthInBytes <= _maxCloudImageBytes) return encoded;
      }
      final nextWidth = (image.width * 0.8).round();
      final nextHeight = (image.height * 0.8).round();
      if (nextWidth < 160 || nextHeight < 160) break;
      image = img.copyResize(image, width: nextWidth, height: nextHeight);
    }
    throw const FormatException('Image is too large to store safely.');
  }

  String _photoDocId(String petId, _PhotoKind kind) =>
      '${Uri.encodeComponent(petId)}__${kind.name}';

  String _pendingToken(String operation, String uid, String petId,
          [_PhotoKind? kind]) =>
      'pet_photo_$operation:$uid:${Uri.encodeComponent(petId)}${kind == null ? '' : ':${kind.name}'}';

  Future<void> _queueOrUpload(
    String petId,
    _PhotoKind kind, {
    bool allowDuringAccountResolution = false,
  }) async {
    final uid = _auth.userId;
    if (uid == 'guest' ||
        !_auth.isAuthenticated ||
        (!_auth.accountSyncAllowed && !allowDuringAccountResolution)) {
      return;
    }
    // A newly selected image supersedes any queued delete for this pet.
    await _local.removePendingOp(_pendingToken('delete', uid, petId));
    if (!_canSync) {
      await _local.queuePendingOp(_pendingToken('upload', uid, petId, kind));
      return;
    }
    try {
      await _uploadPhoto(uid, petId, kind);
      await _local.removePendingOp(_pendingToken('upload', uid, petId, kind));
    } catch (error) {
      debugPrint('PetPhotoService: cloud photo upload failed: $error');
      await _local.queuePendingOp(_pendingToken('upload', uid, petId, kind));
    }
  }

  Future<void> _uploadPhoto(String uid, String petId, _PhotoKind kind) async {
    final path = _pathsFor(kind)[petId];
    if (path == null) return;
    final file = File(path);
    if (!await file.exists()) return;
    final data = base64Encode(await _encodeImage(file));
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection(_collectionName)
        .doc(_photoDocId(petId, kind))
        .set({
      'petId': petId,
      'kind': kind.name,
      'contentType': 'image/jpeg',
      'imageBase64': data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Pushes local photos only when explicitly requested by the guest-data
  /// merge flow. This prevents guest photos silently attaching to an account.
  Future<void> uploadLocalPhotosForPets(Iterable<String> petIds) async {
    await init();
    if (!_auth.isAuthenticated) return;
    final uid = _auth.userId;
    if (uid == 'guest') return;
    for (final petId in petIds.toSet()) {
      for (final kind in _PhotoKind.values) {
        if (_pathsFor(kind).containsKey(petId)) {
          await _queueOrUpload(
            petId,
            kind,
            allowDuringAccountResolution: true,
          );
        }
      }
    }
  }

  /// Downloads cloud copies for the signed-in account and materializes them
  /// as local files so existing image widgets continue to work offline.
  Future<void> restorePhotosForPetIds(
    Iterable<String> petIds, {
    Iterable<String> uploadMissingLocalPhotosFor = const [],
  }) async {
    await init();
    final collection = _photoCollection;
    if (collection == null || !_connectivity.isOnline) return;
    final pending = (await _local.fetchPendingOps()).toSet();
    final uid = _auth.userId;
    final cloudPetIds = uploadMissingLocalPhotosFor.toSet();
    for (final petId in petIds.toSet()) {
      for (final kind in _PhotoKind.values) {
        try {
          // Do not replace a newer local image while its upload is pending.
          if (pending.contains(_pendingToken('upload', uid, petId, kind))) {
            continue;
          }
          final snapshot = await collection.doc(_photoDocId(petId, kind)).get();
          final encoded = snapshot.data()?['imageBase64'];
          if (!snapshot.exists || encoded is! String || encoded.isEmpty) {
            // Existing installations may have a local copy from before cloud
            // photo sync existed. Migrate it only when this pet profile is
            // already present in this signed-in account's cloud data.
            if (cloudPetIds.contains(petId) &&
                _pathsFor(kind).containsKey(petId)) {
              await _queueOrUpload(petId, kind);
            }
            continue;
          }
          final bytes = base64Decode(encoded);
          await _writeRestoredPhoto(petId, kind, bytes);
        } catch (error) {
          debugPrint('PetPhotoService: photo restore failed: $error');
        }
      }
    }
  }

  Future<void> _writeRestoredPhoto(
    String petId,
    _PhotoKind kind,
    Uint8List bytes,
  ) async {
    final oldPath = _pathsFor(kind)[petId];
    final dir = await getApplicationDocumentsDirectory();
    final destination = File(
      '${dir.path}/pet_${kind.filePrefix}_${Uri.encodeComponent(petId)}_cloud.jpg',
    );
    await destination.writeAsBytes(bytes, flush: true);
    final paths = {..._pathsFor(kind), petId: destination.path};
    await _savePaths(kind, paths);
    _setPaths(kind, paths);
    if (oldPath != null && oldPath != destination.path) {
      try {
        final oldFile = File(oldPath);
        if (await oldFile.exists()) await oldFile.delete();
      } catch (_) {
        // Best-effort cleanup of the previous local copy.
      }
    }
    notifyListeners();
  }

  /// Removes local guest photos without deleting anything from the account's
  /// cloud. Used by the explicit "Use Cloud Data" reconciliation path.
  Future<void> removeLocalPhotosForPet(String petId) async {
    await init();
    await _removeLocalPhoto(petId, _PhotoKind.avatar);
    await _removeLocalPhoto(petId, _PhotoKind.cover);
    notifyListeners();
  }

  Future<void> _removeLocalPhoto(String petId, _PhotoKind kind) async {
    final oldPath = _pathsFor(kind)[petId];
    if (oldPath != null) {
      try {
        final file = File(oldPath);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    final paths = {..._pathsFor(kind)}..remove(petId);
    await _savePaths(kind, paths);
    _setPaths(kind, paths);
  }

  Future<void> deletePhotoForPet(String petId) async {
    await init();
    await removeLocalPhotosForPet(petId);
    final uid = _auth.userId;
    if (uid == 'guest' || !_auth.isAuthenticated || !_auth.accountSyncAllowed) {
      return;
    }
    final token = _pendingToken('delete', uid, petId);
    if (!_connectivity.isOnline) {
      await _local.queuePendingOp(token);
      return;
    }
    try {
      await _deleteCloudPhotos(uid, petId);
      await _local.removePendingOp(token);
    } catch (error) {
      debugPrint('PetPhotoService: cloud photo delete failed: $error');
      await _local.queuePendingOp(token);
    }
  }

  Future<void> _deleteCloudPhotos(String uid, String petId) async {
    final collection = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection(_collectionName);
    final batch = FirebaseFirestore.instance.batch();
    for (final kind in _PhotoKind.values) {
      batch.delete(collection.doc(_photoDocId(petId, kind)));
      await _local.removePendingOp(_pendingToken('upload', uid, petId, kind));
    }
    await batch.commit();
  }

  Future<void> flushPendingCloudPhotosIfPossible() async {
    if (!_canSync || _flushInProgress) return;
    _flushInProgress = true;
    try {
      await init();
      final uid = _auth.userId;
      final tokens = (await _local.fetchPendingOps())
        ..sort((a, b) {
          final aIsDelete = a.startsWith('pet_photo_delete:');
          final bIsDelete = b.startsWith('pet_photo_delete:');
          if (aIsDelete == bIsDelete) return 0;
          return aIsDelete ? -1 : 1;
        });
      for (final token in tokens) {
        // A prior delete may have removed a queued upload from Hive. Don't
        // process a stale copy of that token from this iteration snapshot.
        if (!(await _local.fetchPendingOps()).contains(token)) continue;
        final parts = token.split(':');
        if (parts.length < 3 || parts[1] != uid) continue;
        final petId = Uri.decodeComponent(parts[2]);
        try {
          if (parts[0] == 'pet_photo_upload' && parts.length == 4) {
            final kind = _PhotoKind.fromName(parts[3]);
            if (kind == null) continue;
            await _uploadPhoto(uid, petId, kind);
          } else if (parts[0] == 'pet_photo_delete' && parts.length == 3) {
            await _deleteCloudPhotos(uid, petId);
          } else {
            continue;
          }
          await _local.removePendingOp(token);
        } catch (_) {
          // Leave failed work queued for the next online/auth notification.
        }
      }
    } finally {
      _flushInProgress = false;
    }
  }

  Future<void> deletePhotoForPets(Iterable<String> petIds) async {
    for (final petId in petIds.toSet()) {
      await deletePhotoForPet(petId);
    }
  }

  Future<void> clearAll() async {
    await init();
    for (final path in [..._paths.values, ..._coverPaths.values]) {
      try {
        final file = File(path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    _paths = {};
    _coverPaths = {};
    await _local.savePetPhotoPaths(_paths);
    await _local.savePetCoverPhotoPaths(_coverPaths);
    notifyListeners();
  }
}

enum _PhotoKind {
  avatar('avatar'),
  cover('cover');

  const _PhotoKind(this.filePrefix);
  final String filePrefix;

  static _PhotoKind? fromName(String name) {
    for (final value in values) {
      if (value.name == name) return value;
    }
    return null;
  }
}
