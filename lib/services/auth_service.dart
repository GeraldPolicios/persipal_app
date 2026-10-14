// lib/services/auth_service.dart
//
// Wraps Firebase Authentication.
// Exposes a clean async API.  Never throws raw FirebaseAuthExceptions
// to the UI — converts them to friendly strings via friendlyError().

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'session_manager.dart';

enum AuthStatus { unknown, authenticated, guest }

class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  bool get isFirebaseAvailable => Firebase.apps.isNotEmpty;

  FirebaseAuth get _auth => FirebaseAuth.instance;
  final _google = GoogleSignIn();

  User? get currentUser {
    if (!isFirebaseAvailable) return null;
    try {
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  bool get isAuthenticated => currentUser != null;
  bool get isGuest => currentUser == null;
  String get userId => currentUser?.uid ?? 'guest';
  String? get userEmail => currentUser?.email;
  String? get displayName => currentUser?.displayName;

  /// True only for a signed-in Firebase user whose email isn't verified
  /// yet. False for guests (no currentUser) and for Google sign-ins,
  /// since Firebase already marks a Google-authenticated email verified.
  bool get needsEmailVerification =>
      currentUser != null && !currentUser!.emailVerified;

  Stream<User?> get authStateChanges {
    if (!isFirebaseAvailable) return Stream<User?>.value(null);
    try {
      return _auth.authStateChanges();
    } catch (_) {
      return Stream<User?>.value(null);
    }
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (!isFirebaseAvailable) return;
    try {
      _auth.authStateChanges().listen((user) {
        if (user != null) {
          SessionManager.instance.onFirebaseLogin(user);
        }
        notifyListeners();
      });
    } catch (error) {
      // Authentication is optional for startup. Keep the local guest flow
      // available if the native Firebase Auth plugin is unavailable.
      debugPrint('Persipal: Firebase Auth unavailable during startup: $error');
    }
  }

  // ── Email / password ──────────────────────────────────────────────────────

  Future<AuthResult> signInWithEmail(String email, String password) async {
    if (!isFirebaseAvailable) {
      return AuthResult.failure(
        'Sign-in is temporarily unavailable. Please try again when Firebase is available.',
      );
    }
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await SessionManager.instance.onFirebaseLogin(cred.user!);
      notifyListeners();
      return AuthResult.success(cred.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(friendlyError(e));
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred.');
    }
  }

  Future<AuthResult> createAccount(
    String email,
    String password, {
    String? displayName,
  }) async {
    if (!isFirebaseAvailable) {
      return AuthResult.failure(
        'Account creation is temporarily unavailable. Please try again when Firebase is available.',
      );
    }
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (displayName != null && displayName.isNotEmpty) {
        await cred.user?.updateDisplayName(displayName);
        await cred.user?.reload();
      }
      // The account itself was created successfully regardless of whether
      // this send succeeds — a transient failure here (e.g. rate limiting)
      // shouldn't be reported as account-creation failure. The user can
      // resend from VerifyEmailScreen.
      try {
        await cred.user?.sendEmailVerification();
      } catch (_) {}
      await SessionManager.instance.onFirebaseLogin(cred.user!);
      notifyListeners();
      return AuthResult.success(cred.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(friendlyError(e));
    } catch (e) {
      return AuthResult.failure('An unexpected error occurred.');
    }
  }

  // ── Email verification ────────────────────────────────────────────────────

  /// Resends the verification email to the currently signed-in user.
  Future<AuthResult> resendVerificationEmail() async {
    if (!isFirebaseAvailable) {
      return AuthResult.failure(
          'Email verification is temporarily unavailable.');
    }
    final user = currentUser;
    if (user == null) {
      return AuthResult.failure('You need to be signed in to do that.');
    }
    try {
      await user.sendEmailVerification();
      return AuthResult.successMsg('Verification email sent to ${user.email}.');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(friendlyError(e));
    } catch (e) {
      return AuthResult.failure('Failed to send verification email.');
    }
  }

  /// Refetches the current user from Firebase (e.g. after the user has
  /// clicked the verification link) so `currentUser.emailVerified` and
  /// [needsEmailVerification] reflect the latest server-side state.
  Future<void> reloadUser() async {
    if (!isFirebaseAvailable) return;
    await currentUser?.reload();
    notifyListeners();
  }

  // ── Google sign-in ────────────────────────────────────────────────────────

  Future<AuthResult> signInWithGoogle() async {
    if (!isFirebaseAvailable) {
      return AuthResult.failure(
        'Google sign-in is temporarily unavailable. Please try again when Firebase is available.',
      );
    }
    try {
      final googleUser = await _google.signIn();
      if (googleUser == null) {
        return AuthResult.failure('Google sign-in was cancelled.');
      }
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final cred = await _auth.signInWithCredential(credential);
      await SessionManager.instance.onFirebaseLogin(cred.user!);
      notifyListeners();
      return AuthResult.success(cred.user!);
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(friendlyError(e));
    } catch (e) {
      return AuthResult.failure('Google sign-in failed. Please try again.');
    }
  }

  // ── Password reset ────────────────────────────────────────────────────────

  Future<AuthResult> sendPasswordReset(String email) async {
    if (!isFirebaseAvailable) {
      return AuthResult.failure('Password reset is temporarily unavailable.');
    }
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return AuthResult.successMsg(
          'Password reset email sent to ${email.trim()}.');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(friendlyError(e));
    } catch (e) {
      return AuthResult.failure('Failed to send reset email.');
    }
  }

  // ── Sign out ──────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    if (!isFirebaseAvailable) {
      // Keep the local session intact while cloud auth is unavailable.
      notifyListeners();
      return;
    }
    try {
      await _google.signOut();
    } catch (_) {
      // Ignore when there is no active Google session.
    }
    await _auth.signOut();
    await SessionManager.instance.onFirebaseSignOut();
    notifyListeners();
  }

  // ── Delete account ────────────────────────────────────────────────────────

  Future<AuthResult> deleteAccount() async {
    if (!isFirebaseAvailable) {
      return AuthResult.failure('Account deletion is temporarily unavailable.');
    }
    try {
      await _auth.currentUser?.delete();
      try {
        await _google.signOut();
      } catch (_) {
        // Firebase account deletion has already succeeded.
      }
      await SessionManager.instance.onFirebaseSignOut();
      notifyListeners();
      return AuthResult.successMsg('Account deleted.');
    } on FirebaseAuthException catch (e) {
      return AuthResult.failure(friendlyError(e));
    } catch (e) {
      return AuthResult.failure('Failed to delete account.');
    }
  }

  // ── Friendly error messages ───────────────────────────────────────────────

  String friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'No internet connection.';
      case 'requires-recent-login':
        return 'Please sign in again to complete this action.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
}

// ── Result type ───────────────────────────────────────────────────────────────

class AuthResult {
  final bool isSuccess;
  final User? user;
  final String? message; // success message
  final String? error; // error message

  AuthResult._({
    required this.isSuccess,
    this.user,
    this.message,
    this.error,
  });

  factory AuthResult.success(User u) => AuthResult._(isSuccess: true, user: u);

  factory AuthResult.successMsg(String msg) =>
      AuthResult._(isSuccess: true, message: msg);

  factory AuthResult.failure(String err) =>
      AuthResult._(isSuccess: false, error: err);
}
