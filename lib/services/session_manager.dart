// lib/services/session_manager.dart
//
// Single source of truth for the current user session.
// Responsibilities:
//   • Detect & restore existing session on cold start (guest or auth)
//   • Create guest sessions with stable UUID
//   • Bridge Firebase Auth state changes into SessionModel
//   • Persist session data locally in Hive
//   • Decide whether to show the login screen

import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/models.dart';

class SessionManager extends ChangeNotifier {
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  static const _boxName = 'session';
  static const _keySession = 'current_session';
  static const _keyGuestId = 'guest_id';

  final _uuid = const Uuid();
  SessionModel? _session;
  bool _initialized = false;

  SessionModel? get session => _session;
  bool get hasSession => _session != null;
  bool get isGuest => _session?.isGuest ?? false;
  bool get isAuthenticated => _session?.isAuthenticated ?? false;
  String get userId => _session?.userId ?? '';
  String get displayName =>
      _session?.displayName ?? (_session?.isGuest == true ? 'Guest' : '');
  bool get initialized => _initialized;

  Box<String> get _box => Hive.box<String>(_boxName);

  // ── Boot ──────────────────────────────────────────────────────────────────

  /// Call once at app startup (after Hive.initFlutter).
  /// Returns true if a session was restored (skip login screen).
  Future<bool> init() async {
    await Hive.openBox<String>(_boxName);

    // Check Firebase Auth first — might be restored from a previous login
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      _session = _sessionFromFirebase(firebaseUser);
      _saveSession();
      _initialized = true;
      notifyListeners();
      return true;
    }

    // Fall back to locally persisted session
    final raw = _box.get(_keySession);
    if (raw != null) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _session = SessionModel.fromMap(map);
        _initialized = true;
        // Touch lastActiveAt
        _session = _session!.copyWith(lastActiveAt: DateTime.now());
        _saveSession();
        notifyListeners();
        return true;
      } catch (_) {
        // Corrupt session — fall through to login
        await _box.delete(_keySession);
      }
    }

    _initialized = true;
    notifyListeners();
    return false;
  }

  // ── Guest session ─────────────────────────────────────────────────────────

  Future<SessionModel> createGuestSession() async {
    // Reuse stable guest ID across launches
    String guestId = _box.get(_keyGuestId) ?? _uuid.v4();
    await _box.put(_keyGuestId, guestId);

    _session = SessionModel(
      userId: 'guest_$guestId',
      type: SessionType.guest,
      displayName: 'Guest',
      createdAt: DateTime.now(),
      lastActiveAt: DateTime.now(),
    );
    _saveSession();
    notifyListeners();
    return _session!;
  }

  // ── Firebase Auth session ─────────────────────────────────────────────────

  /// Called after a successful Firebase sign-in or sign-up.
  Future<void> onFirebaseLogin(User user) async {
    _session = _sessionFromFirebase(user);
    _saveSession();
    notifyListeners();
  }

  /// Called on Firebase sign-out.
  Future<void> onFirebaseSignOut() async {
    await _box.delete(_keySession);
    _session = null;
    notifyListeners();
  }

  /// Update display name in session (e.g. after profile update).
  Future<void> updateDisplayName(String name) async {
    if (_session == null) return;
    _session = _session!.copyWith(displayName: name);
    _saveSession();
    notifyListeners();
  }

  /// Called when the app resumes to refresh lastActiveAt.
  void touchSession() {
    if (_session == null) return;
    _session = _session!.copyWith(lastActiveAt: DateTime.now());
    _saveSession();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  SessionModel _sessionFromFirebase(User user) => SessionModel(
        userId: user.uid,
        type: SessionType.authenticated,
        displayName: user.displayName ?? user.email?.split('@').first,
        email: user.email,
        createdAt: user.metadata.creationTime ?? DateTime.now(),
        lastActiveAt: DateTime.now(),
      );

  void _saveSession() {
    if (_session == null) return;
    _box.put(_keySession, jsonEncode(_session!.toMap()));
  }

  /// Whether local guest data exists (used for merge prompt).
  Future<bool> hasLocalGuestData() async {
    return _box.containsKey(_keyGuestId);
  }

  /// Clear guest ID (called after merging to real account).
  Future<void> clearGuestId() async {
    await _box.delete(_keyGuestId);
  }
}
