// lib/services/session_manager.dart
//
// Single source of truth for the current user session.
// Responsibilities:
//   • Detect & restore existing session on cold start (guest or auth)
//   • Create guest sessions with stable UUID
//   • Bridge Firebase Auth state changes into SessionModel
//   • Persist session data locally in Hive
//   • Ensure a session always exists after init() — a brand-new install
//     auto-creates a guest session rather than requiring login/signup
//     first. Account creation/sign-in stays fully optional, reachable
//     later from Settings.

import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
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
  bool _restoredGuestSession = false;

  SessionModel? get session => _session;
  bool get hasSession => _session != null;
  bool get isGuest => _session?.isGuest ?? false;
  bool get isAuthenticated => _session?.isAuthenticated ?? false;
  String get userId => _session?.userId ?? '';
  String get displayName =>
      _session?.displayName ?? (_session?.isGuest == true ? 'Guest' : '');
  bool get initialized => _initialized;
  bool get restoredGuestSession => _restoredGuestSession;

  Box<String> get _box => Hive.box<String>(_boxName);

  // ── Boot ──────────────────────────────────────────────────────────────────

  /// Call once at app startup (after Hive.initFlutter).
  /// Always returns true once complete — a session (restored or a freshly
  /// auto-created guest one) always exists after this resolves. When Firebase
  /// is available, wait for Auth's initial state event before falling back to
  /// Hive: currentUser can still be null while Firebase restores a saved user.
  Future<bool> init({
    Future<User?> Function(String? expectedEmail)? googleSessionRestorer,
  }) async {
    await Hive.openBox<String>(_boxName);
    _restoredGuestSession = false;

    // Read the cached app session before consulting Firebase. If an account
    // was signed in on the previous run, a transient initial null from the
    // native auth stream should not immediately replace it with a guest.
    SessionModel? restoredSession;
    final raw = _box.get(_keySession);
    if (raw != null) {
      try {
        restoredSession =
            SessionModel.fromMap(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        await _box.delete(_keySession);
      }
    }

    // Check Firebase Auth first. currentUser may be null until the SDK has
    // finished restoring its persisted user, so use the initial auth event as
    // the startup source of truth. This event is delivered from Firebase's
    // local persisted state and does not require a network connection.
    User? firebaseUser;
    var firebaseAuthStateResolved = false;
    if (Firebase.apps.isNotEmpty) {
      try {
        firebaseUser = await waitForInitialAuthState(
          FirebaseAuth.instance.authStateChanges(),
          waitAfterInitialNull: restoredSession?.isAuthenticated ?? false,
        );
        firebaseAuthStateResolved = true;
      } catch (error) {
        // A native Auth-plugin failure must not prevent restoring local data.
        debugPrint(
            'Persipal: Firebase Auth unavailable; restoring local session: $error');
      }
    }
    if (firebaseUser != null) {
      _session = _sessionFromFirebase(firebaseUser);
      await _saveSession();
      _initialized = true;
      notifyListeners();
      return true;
    }

    // Fall back to locally persisted session. A confirmed null Firebase
    // state means a cached authenticated session is no longer valid; keep
    // guests as-is, but return stale account sessions to the guest/account
    // choice flow. If Firebase itself was unavailable, preserve the local
    // session so the app remains usable offline.
    if (restoredSession != null) {
      try {
        if (firebaseAuthStateResolved &&
            firebaseUser == null &&
            restoredSession.isAuthenticated) {
          final recoveredUser =
              await googleSessionRestorer?.call(restoredSession.email);
          if (recoveredUser != null) {
            _session = _sessionFromFirebase(recoveredUser);
            await _saveSession();
            _initialized = true;
            notifyListeners();
            return true;
          }

          _initialized = true;
          await createGuestSession(reason: 'startup_firebase_user_missing');
          return true;
        }
        _restoredGuestSession = restoredSession.isGuest;
        _session = restoredSession;
        _initialized = true;
        // Touch lastActiveAt
        _session = _session!.copyWith(lastActiveAt: DateTime.now());
        await _saveSession();
        notifyListeners();
        return true;
      } catch (_) {
        // Corrupt session — continue without a restored session.
        await _box.delete(_keySession);
      }
    }

    // No existing session anywhere (brand-new install, or a corrupt one
    // just cleared above). Auto-create a guest session so the app opens
    // directly rather than forcing a login/signup screen first — account
    // creation stays fully optional, reachable later from Settings.
    _initialized = true;
    await createGuestSession(reason: 'startup_no_restored_account');
    return true;
  }

  // ── Guest session ─────────────────────────────────────────────────────────

  Future<SessionModel> createGuestSession({
    String reason = 'user_selected_guest',
  }) async {
    debugPrint('Persipal: guest session created ($reason).');
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
    await _saveSession();
    notifyListeners();
    return _session!;
  }

  // ── Firebase Auth session ─────────────────────────────────────────────────

  /// Called after a successful Firebase sign-in or sign-up.
  Future<void> onFirebaseLogin(User user) async {
    _session = _sessionFromFirebase(user);
    await _saveSession();
    debugPrint('Persipal: authenticated session persisted to Hive.');
    notifyListeners();
  }

  /// Called on Firebase sign-out.
  Future<void> onFirebaseSignOut() async {
    await _box.delete(_keySession);
    _session = null;
    debugPrint('Persipal: authenticated Hive session cleared after sign-out.');
    notifyListeners();
  }

  /// Update display name in session (e.g. after profile update).
  Future<void> updateDisplayName(String name) async {
    if (_session == null) return;
    _session = _session!.copyWith(displayName: name);
    await _saveSession();
    notifyListeners();
  }

  /// Called when the app resumes to refresh lastActiveAt.
  void touchSession() {
    if (_session == null) return;
    _session = _session!.copyWith(lastActiveAt: DateTime.now());
    unawaited(_saveSession());
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

  Future<void> _saveSession() async {
    if (_session == null) return;
    await _box.put(_keySession, jsonEncode(_session!.toMap()));
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

/// Waits for Firebase's first state event rather than sampling currentUser
/// while persisted auth restoration may still be in progress.
@visibleForTesting
Future<User?> waitForInitialAuthState(
  Stream<User?> authStateChanges, {
  bool waitAfterInitialNull = false,
  Duration restoreGracePeriod = const Duration(seconds: 2),
}) async {
  if (!waitAfterInitialNull) return authStateChanges.first;

  final iterator = StreamIterator<User?>(authStateChanges);
  try {
    if (!await iterator.moveNext()) return null;
    if (iterator.current != null) return iterator.current;

    // A cached account is known to exist locally, so give native Firebase
    // Auth a short window to deliver the persisted user if its first event
    // races credential restoration. Do not manufacture auth from Hive: on
    // timeout, the normal unauthenticated/guest path remains in effect.
    final deadline = DateTime.now().add(restoreGracePeriod);
    while (true) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) return null;
      final hasNext = await iterator
          .moveNext()
          .timeout(remaining, onTimeout: () => false);
      if (!hasNext) return null;
      if (iterator.current != null) return iterator.current;
    }
  } finally {
    await iterator.cancel();
  }
}
