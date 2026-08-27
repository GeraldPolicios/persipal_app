// screens/verify_email_screen.dart
//
// Shown to a signed-in Firebase user whose email isn't verified yet
// (AuthService.needsEmailVerification). Reached from two places:
//   • login_screen.dart, right after sign-in/sign-up/Google sign-in,
//     via _handlePostLogin() — passes [onVerified] so that once verified,
//     the existing guest-merge-dialog/_goHome() flow runs exactly as it
//     always has.
//   • splash_screen.dart, on a cold start for an already-authenticated
//     but still-unverified user — no [onVerified] passed, so Continue
//     just navigates to HomeScreen directly.
//
// Google sign-ins never land here: Firebase marks a Google-authenticated
// email verified automatically, so needsEmailVerification is already
// false for them.

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class VerifyEmailScreen extends StatefulWidget {
  final VoidCallback? onVerified;

  const VerifyEmailScreen({super.key, this.onVerified});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  bool _checking = false;
  bool _resending = false;
  bool _signingOut = false;
  String? _message;
  bool _messageIsError = true;

  bool get _anyLoading => _checking || _resending || _signingOut;

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _message = null;
    });
    final result = await AuthService.instance.resendVerificationEmail();
    if (!mounted) return;
    setState(() {
      _resending = false;
      _messageIsError = !result.isSuccess;
      _message = result.isSuccess ? result.message : result.error;
    });
  }

  Future<void> _continue() async {
    setState(() {
      _checking = true;
      _message = null;
    });

    await AuthService.instance.reloadUser();
    final verified = !AuthService.instance.needsEmailVerification;

    if (!mounted) return;

    if (verified) {
      if (widget.onVerified != null) {
        widget.onVerified!();
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
      return;
    }

    setState(() {
      _checking = false;
      _messageIsError = true;
      _message =
          "We haven't detected your verification yet. Check your inbox "
          '(and spam folder), tap the link, then try again.';
    });
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = AuthService.instance.userEmail ?? 'your email address';

    return Scaffold(
      backgroundColor: const Color(0xFFFFE6CC),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.11,
              child: Image.asset('assets/images/paws_bg.png', fit: BoxFit.cover),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.pets, size: 40, color: Color(0xFFFF8C69)),
                    const SizedBox(height: 6),
                    const Text('PERSIPAL',
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.5,
                            color: Color(0xFF7A3B1E))),
                    const SizedBox(height: 24),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.07),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF8C69).withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.mark_email_unread_outlined,
                                color: Color(0xFFFF8C69), size: 28),
                          ),
                          const SizedBox(height: 16),
                          const Text('Verify your email',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF7A3B1E))),
                          const SizedBox(height: 8),
                          Text(
                            "We sent a verification link to $email. "
                            'Please verify your email before continuing — '
                            'this keeps your account and synced data secure.',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.grey, height: 1.4),
                          ),

                          if (_message != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: (_messageIsError
                                        ? Colors.redAccent
                                        : const Color(0xFF32CD32))
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: (_messageIsError
                                          ? Colors.redAccent
                                          : const Color(0xFF32CD32))
                                      .withValues(alpha: 0.35),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    _messageIsError
                                        ? Icons.error_outline
                                        : Icons.check_circle_outline,
                                    color: _messageIsError
                                        ? Colors.redAccent
                                        : const Color(0xFF32CD32),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _message!,
                                      style: TextStyle(
                                        color: _messageIsError
                                            ? Colors.redAccent
                                            : const Color(0xFF2E9E2E),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFF8C69),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              onPressed: _anyLoading ? null : _continue,
                              child: _checking
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5, color: Colors.white),
                                    )
                                  : const Text("I've verified — Continue",
                                      style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 10),

                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                    color: Colors.grey.withValues(alpha: 0.35)),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: _anyLoading ? null : _resend,
                              child: _resending
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Color(0xFFFF8C69)),
                                    )
                                  : const Text('Resend email',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF7A3B1E))),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _anyLoading ? null : _signOut,
                      child: _signingOut
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Color(0xFFAA7755)),
                            )
                          : const Text('Sign Out',
                              style: TextStyle(
                                  color: Color(0xFFAA7755),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
