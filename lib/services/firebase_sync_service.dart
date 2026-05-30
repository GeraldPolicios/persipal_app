// lib/services/firebase_sync_service.dart
//
// Firestore-backed cloud sync.  Hive is ALWAYS the primary source.
// Firestore is a background backup only.
//
// Firestore structure:
//   users/{uid}/pets/{petId}
//   users/{uid}/logs/{logId}
//   users/{uid}/reminders/{reminderId}
//   users/{uid}/settings/app_settings
//   users/{uid}/quizzes/{resultId}

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';
import 'local_storage_service.dart';

// Import AppProvider only for the flushPendingOps parameter type.
// Using a late import avoids the circular-dependency issue.
import '../providers/app_provider.dart';

enum SyncState { idle, syncing, synced, failed, offline }

class FirebaseSyncService extends ChangeNotifier {
  FirebaseSyncService._();
  static final FirebaseSyncService instance = FirebaseSyncService._();

  final _db = FirebaseFirestore.instance;
  final _auth = AuthService.instance;
  final _connectivity = ConnectivityService.instance;
  final _local = LocalStorageService.instance;

  SyncState _state = SyncState.idle;
  DateTime? _lastSyncAt;
  String? _lastError;
  bool _syncInProgress = false;

  SyncState get state => _state;
  DateTime? get lastSyncAt => _lastSyncAt;
  String? get lastError => _lastError;
  bool get isSyncing => _syncInProgress;

  // ── Collection refs ───────────────────────────────────────────────────────

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _db.collection('users').doc(_auth.userId).collection(name);

  // ── Guards ────────────────────────────────────────────────────────────────

  bool get _canSync =>
      _auth.isAuthenticated && _connectivity.isOnline && !_syncInProgress;

  // ── Full upload (Hive → Firestore) ────────────────────────────────────────

  Future<SyncResult> uploadAll({
    required List<PetModel> pets,
    required List<ActivityLogModel> logs,
    required List<ReminderModel> reminders,
    required AppSettings settings,
    required List<QuizResult> quizzes,
  }) async {
    if (!_canSync) {
      return SyncResult.failed(_syncBlockReason());
    }
    _begin();
    try {
      final allOps = <Future<void>>[];

      for (final pet in pets) {
        allOps.add(
            _col('pets').doc(pet.id).set(pet.toMap(), SetOptions(merge: true)));
      }
      for (final log in logs.take(200)) {
        allOps.add(
            _col('logs').doc(log.id).set(log.toMap(), SetOptions(merge: true)));
      }
      for (final r in reminders) {
        allOps.add(_col('reminders')
            .doc(r.id)
            .set(r.toMap(), SetOptions(merge: true)));
      }
      for (final q in quizzes) {
        allOps.add(
            _col('quizzes').doc(q.id).set(q.toMap(), SetOptions(merge: true)));
      }
      allOps.add(_col('settings')
          .doc('app_settings')
          .set(settings.toMap(), SetOptions(merge: true)));

      await Future.wait(allOps);
      await _local.clearPendingOps();
      return _succeed();
    } catch (e) {
      return _fail(e.toString());
    }
  }

  // ── Full download (Firestore → Hive) ──────────────────────────────────────

  Future<CloudData> downloadAll() async {
    if (!_canSync) return CloudData.empty();
    _begin();
    try {
      final results = await Future.wait([
        _col('pets').get(),
        _col('logs').orderBy('timestamp', descending: true).limit(500).get(),
        _col('reminders').get(),
        _col('quizzes').get(),
        _col('settings').get(),
      ]);

      final pets = _snap<PetModel>(results[0], PetModel.fromMap);
      final logs =
          _snap<ActivityLogModel>(results[1], ActivityLogModel.fromMap);
      final reminders = _snap<ReminderModel>(results[2], ReminderModel.fromMap);
      final quizzes = _snap<QuizResult>(results[3], QuizResult.fromMap);

      AppSettings? settings;
      final sDocs = (results[4] as QuerySnapshot<Map<String, dynamic>>).docs;
      if (sDocs.isNotEmpty) {
        settings = AppSettings.fromMap(sDocs.first.data());
      }

      _succeed();
      return CloudData(
        pets: pets,
        logs: logs,
        reminders: reminders,
        quizzes: quizzes,
        settings: settings,
      );
    } catch (e) {
      _fail(e.toString());
      return CloudData.empty();
    }
  }

  // ── Individual record ops ─────────────────────────────────────────────────

  Future<void> savePet(PetModel pet) async {
    if (!_canSync) {
      await _local.queuePendingOp('pet:${pet.id}');
      return;
    }
    try {
      await _col('pets').doc(pet.id).set(pet.toMap(), SetOptions(merge: true));
    } catch (_) {
      await _local.queuePendingOp('pet:${pet.id}');
    }
  }

  Future<void> deletePet(String id) async {
    if (!_canSync) return;
    try {
      await _col('pets').doc(id).delete();
    } catch (_) {}
  }

  Future<void> saveReminder(ReminderModel r) async {
    if (!_canSync) {
      await _local.queuePendingOp('reminder:${r.id}');
      return;
    }
    try {
      await _col('reminders').doc(r.id).set(r.toMap(), SetOptions(merge: true));
    } catch (_) {
      await _local.queuePendingOp('reminder:${r.id}');
    }
  }

  Future<void> deleteReminder(String id) async {
    if (!_canSync) return;
    try {
      await _col('reminders').doc(id).delete();
    } catch (_) {}
  }

  Future<void> addLog(ActivityLogModel log) async {
    if (!_canSync) {
      await _local.queuePendingOp('log:${log.id}');
      return;
    }
    try {
      await _col('logs').doc(log.id).set(log.toMap());
    } catch (_) {
      await _local.queuePendingOp('log:${log.id}');
    }
  }

  Future<void> saveSettings(AppSettings s) async {
    if (!_canSync) return;
    try {
      await _col('settings')
          .doc('app_settings')
          .set(s.toMap(), SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> saveQuizResult(QuizResult r) async {
    if (!_canSync) return;
    try {
      await _col('quizzes').doc(r.id).set(r.toMap());
    } catch (_) {}
  }

  // ── Flush pending ops ──────────────────────────────────────────────────────

  Future<void> flushPendingOps(AppProvider provider) async {
    if (!_canSync) return;
    final tokens = await _local.fetchPendingOps();
    if (tokens.isEmpty) return;

    for (final token in tokens) {
      try {
        final parts = token.split(':');
        if (parts.length < 2) continue;
        final type = parts[0];
        final id = parts[1];

        switch (type) {
          case 'pet':
            final pet = provider.pets
                .cast<PetModel?>()
                .firstWhere((p) => p?.id == id, orElse: () => null);
            if (pet != null) await savePet(pet);
            break;
          case 'reminder':
            final r = provider.reminders
                .cast<ReminderModel?>()
                .firstWhere((r) => r?.id == id, orElse: () => null);
            if (r != null) await saveReminder(r);
            break;
          case 'log':
            final logs = await _local.fetchLogs();
            final log = logs
                .cast<ActivityLogModel?>()
                .firstWhere((l) => l?.id == id, orElse: () => null);
            if (log != null) await addLog(log);
            break;
        }
        await _local.removePendingOp(token);
      } catch (_) {
        // Leave token in queue for next attempt
      }
    }
  }

  // ── Delete all cloud data ─────────────────────────────────────────────────

  Future<void> deleteAllCloudData() async {
    if (!_auth.isAuthenticated) return;
    final uid = _auth.userId;
    final cols = ['pets', 'logs', 'reminders', 'settings', 'quizzes'];
    for (final name in cols) {
      final snap =
          await _db.collection('users').doc(uid).collection(name).get();
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    await _db.collection('users').doc(uid).delete();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  List<T> _snap<T>(
    QuerySnapshot<Map<String, dynamic>> snap,
    T Function(Map<String, dynamic>) fromMap,
  ) =>
      snap.docs.map((d) => fromMap(d.data())).toList();

  void _begin() {
    _syncInProgress = true;
    _state = SyncState.syncing;
    notifyListeners();
  }

  SyncResult _succeed() {
    _syncInProgress = false;
    _lastSyncAt = DateTime.now();
    _state = SyncState.synced;
    notifyListeners();
    return SyncResult.success(_lastSyncAt!);
  }

  SyncResult _fail(String msg) {
    _syncInProgress = false;
    _lastError = msg;
    _state = SyncState.failed;
    notifyListeners();
    return SyncResult.failed(msg);
  }

  String _syncBlockReason() {
    if (!_auth.isAuthenticated) return 'Sign in to enable cloud sync.';
    if (!_connectivity.isOnline) return 'No internet connection.';
    if (_syncInProgress) return 'Sync already in progress.';
    return 'Sync unavailable.';
  }

  void markOffline() {
    _state = SyncState.offline;
    notifyListeners();
  }

  void markIdle() {
    _state = SyncState.idle;
    notifyListeners();
  }
}

// ── Data containers ───────────────────────────────────────────────────────────

class CloudData {
  final List<PetModel> pets;
  final List<ActivityLogModel> logs;
  final List<ReminderModel> reminders;
  final List<QuizResult> quizzes;
  final AppSettings? settings;

  const CloudData({
    required this.pets,
    required this.logs,
    required this.reminders,
    required this.quizzes,
    this.settings,
  });

  factory CloudData.empty() => const CloudData(
        pets: [],
        logs: [],
        reminders: [],
        quizzes: [],
      );

  bool get isEmpty =>
      pets.isEmpty && logs.isEmpty && reminders.isEmpty && quizzes.isEmpty;
}

class SyncResult {
  final bool success;
  final DateTime? syncedAt;
  final String? error;

  SyncResult._({required this.success, this.syncedAt, this.error});

  factory SyncResult.success(DateTime at) =>
      SyncResult._(success: true, syncedAt: at);

  factory SyncResult.failed(String msg) =>
      SyncResult._(success: false, error: msg);
}
