// screens/login_screen.dart
//
// Fully functional login screen with:
//   • Sign In   — real Firebase email/password auth
//   • Create Account — real Firebase registration
//   • Google Sign-In — real Google OAuth via firebase_auth
//   • Forgot Password — real Firebase password reset email
//   • Skip / Guest — instant guest session via SessionManager
//
// All auth calls go through AuthService which wraps firebase_auth.
// On success, SessionManager is updated and the user lands on HomeScreen.
// Guest data merge dialog appears when a guest signs into a real account.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/session_manager.dart';
import '../services/activity_log_service.dart';
import '../providers/app_provider.dart';
import 'home_screen.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // ── Mode ──────────────────────────────────────────────────────────────────
  // 0 = Sign In   1 = Create Account
  int _mode = 0;

  // ── Controllers ───────────────────────────────────────────────────────────
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _nameCtrl = TextEditingController(); // register only
  final _confirmCtrl = TextEditingController(); // register only
  final _resetCtrl = TextEditingController(); // forgot password dialog

  // ── UI state ──────────────────────────────────────────────────────────────
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  bool _googleLoading = false;
  bool _guestLoading = false;
  String? _error;

  // ── Tips carousel ─────────────────────────────────────────────────────────
  int _tipIndex = 0;
  static const _tips = [
    {
      'emoji': '🪮',
      'tip': 'Brush your Persian daily to keep its coat tangle-free.'
    },
    {
      'emoji': '💧',
      'tip': 'Always provide fresh water — Persians are prone to kidney issues.'
    },
    {
      'emoji': '👁️',
      'tip': "Clean your Persian's eyes daily to prevent tear stains."
    },
    {
      'emoji': '🍗',
      'tip': "Feed high-protein cat food to support your Persian's muscles."
    },
    {
      'emoji': '🏠',
      'tip':
          'Keep Persians indoors — their flat faces make them heat-sensitive.'
    },
  ];

  @override
  void initState() {
    super.initState();
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 4));
      if (!mounted) return false;
      setState(() => _tipIndex = (_tipIndex + 1) % _tips.length);
      return true;
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _nameCtrl.dispose();
    _confirmCtrl.dispose();
    _resetCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _setLoading(bool v) => mounted ? setState(() => _loading = v) : null;
  void _setGoogleLoading(bool v) =>
      mounted ? setState(() => _googleLoading = v) : null;
  void _setGuestLoading(bool v) =>
      mounted ? setState(() => _guestLoading = v) : null;
  void _setError(String? msg) => mounted ? setState(() => _error = msg) : null;
  void _clearError() => _setError(null);

  bool get _anyLoading => _loading || _googleLoading || _guestLoading;

  void _goHome() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  // ── Validation ────────────────────────────────────────────────────────────

  String? _validateSignIn() {
    if (_emailCtrl.text.trim().isEmpty) return 'Please enter your email.';
    if (!_emailCtrl.text.contains('@')) return 'Please enter a valid email.';
    if (_passCtrl.text.isEmpty) return 'Please enter your password.';
    return null;
  }

  String? _validateRegister() {
    if (_nameCtrl.text.trim().isEmpty) return 'Please enter your name.';
    if (_emailCtrl.text.trim().isEmpty) return 'Please enter your email.';
    if (!_emailCtrl.text.contains('@')) return 'Please enter a valid email.';
    if (_passCtrl.text.length < 6)
      return 'Password must be at least 6 characters.';
    if (_passCtrl.text != _confirmCtrl.text) return 'Passwords do not match.';
    return null;
  }

  // ── Auth actions ──────────────────────────────────────────────────────────

  Future<void> _signIn() async {
    _clearError();
    final err = _validateSignIn();
    if (err != null) {
      _setError(err);
      return;
    }

    _setLoading(true);
    final result = await AuthService.instance.signInWithEmail(
      _emailCtrl.text.trim(),
      _passCtrl.text,
    );
    _setLoading(false);

    if (!mounted) return;
    if (result.isSuccess) {
      await ActivityLogService.instance.logSignIn(_emailCtrl.text.trim());
      await _handlePostLogin();
    } else {
      _setError(result.error);
    }
  }

  Future<void> _createAccount() async {
    _clearError();
    final err = _validateRegister();
    if (err != null) {
      _setError(err);
      return;
    }

    _setLoading(true);
    final result = await AuthService.instance.createAccount(
      _emailCtrl.text.trim(),
      _passCtrl.text,
      displayName: _nameCtrl.text.trim(),
    );
    _setLoading(false);

    if (!mounted) return;
    if (result.isSuccess) {
      await ActivityLogService.instance.logSignUp(_emailCtrl.text.trim());
      await _handlePostLogin();
    } else {
      _setError(result.error);
    }
  }

  Future<void> _googleSignIn() async {
    _clearError();
    _setGoogleLoading(true);
    final result = await AuthService.instance.signInWithGoogle();
    _setGoogleLoading(false);

    if (!mounted) return;
    if (result.isSuccess) {
      await ActivityLogService.instance
          .logGoogleSignIn(result.user?.email ?? '');
      await _handlePostLogin();
    } else {
      _setError(result.error);
    }
  }

  Future<void> _skipAsGuest() async {
    _clearError();
    _setGuestLoading(true);
    await SessionManager.instance.createGuestSession();
    await ActivityLogService.instance.logGuestCreated();
    _setGuestLoading(false);
    _goHome();
  }

  // ── Post-login: check for guest data to merge ─────────────────────────────

  Future<void> _handlePostLogin() async {
    final hasGuest = await SessionManager.instance.hasLocalGuestData();
    if (!mounted) return;
    if (hasGuest) {
      _showMergeDialog();
    } else {
      _goHome();
    }
  }

  void _showMergeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        backgroundColor: const Color(0xFFFFF5EE),
        title: const Row(children: [
          Text('🐱 ', style: TextStyle(fontSize: 22)),
          Expanded(
              child: Text('Sync Offline Progress?',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
        ]),
        content: const Text(
          'You have offline progress saved locally. What would you like to do?',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _goHome();
            },
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF4682B4)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              if (!mounted) return;
              final provider = context.read<AppProvider>();
              await provider.replaceLocalWithCloud();
              await SessionManager.instance.clearGuestId();
              _goHome();
            },
            child: const Text('Use Cloud Data',
                style: TextStyle(color: Color(0xFF4682B4), fontSize: 12)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF8C69),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              if (!mounted) return;
              final provider = context.read<AppProvider>();
              await provider.mergeGuestDataWithCloud();
              await SessionManager.instance.clearGuestId();
              _goHome();
            },
            child: const Text('Merge Progress', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // ── Forgot password dialog ────────────────────────────────────────────────

  void _showForgotPassword() {
    _resetCtrl.text = _emailCtrl.text.trim();
    bool sending = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          backgroundColor: const Color(0xFFFFF5EE),
          title: const Row(children: [
            Icon(Icons.lock_reset, color: Color(0xFFFF8C69)),
            SizedBox(width: 8),
            Text('Reset Password',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                  "Enter your email and we'll send a password reset link.",
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 14),
              TextField(
                controller: _resetCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDeco('Email address', Icons.email_outlined),
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF8C69),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: sending
                  ? null
                  : () async {
                      final email = _resetCtrl.text.trim();
                      if (email.isEmpty || !email.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Enter a valid email address.')));
                        return;
                      }
                      setD(() => sending = true);
                      final res =
                          await AuthService.instance.sendPasswordReset(email);
                      if (!ctx.mounted) return;
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(res.isSuccess
                            ? res.message ?? 'Reset email sent!'
                            : res.error ?? 'Failed to send reset email.'),
                        backgroundColor: res.isSuccess
                            ? const Color(0xFF32CD32)
                            : Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ));
                    },
              child: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Send Reset Email'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final tip = _tips[_tipIndex];
    final isSignIn = _mode == 0;

    return Scaffold(
      backgroundColor: const Color(0xFFFFE6CC),
      body: Stack(children: [
        // Paw background
        Positioned.fill(
            child: Opacity(
          opacity: 0.11,
          child: Image.asset('assets/images/paws_bg.png', fit: BoxFit.cover),
        )),

        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
            child: Column(children: [
              const SizedBox(height: 10),

              // ── Logo ──────────────────────────────────────────────────────
              const Icon(Icons.pets, size: 40, color: Color(0xFFFF8C69)),
              const SizedBox(height: 6),
              const Text('PERSIPAL',
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2.5,
                      color: Color(0xFF7A3B1E))),
              const SizedBox(height: 4),
              const Text('Persian Cat Care Companion',
                  style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFFAA7755),
                      fontStyle: FontStyle.italic)),

              const SizedBox(height: 24),

              // ── Auth card ─────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.88),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.07),
                        blurRadius: 16,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Mode tab switcher
                    Container(
                      decoration: BoxDecoration(
                          color: const Color(0xFFFFF3E0),
                          borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        _modeTab('Sign In', 0),
                        _modeTab('Create Account', 1),
                      ]),
                    ),
                    const SizedBox(height: 18),

                    // Greeting text
                    Text(
                      isSignIn ? 'Welcome back 👋' : 'Join PersiPal 🐱',
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7A3B1E)),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isSignIn
                          ? 'Sign in to continue caring for your cat.'
                          : 'Create your free account to get started.',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    // Error banner
                    if (_error != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: Colors.redAccent.withOpacity(0.35)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline,
                              color: Colors.redAccent, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(_error!,
                                  style: const TextStyle(
                                      color: Colors.redAccent, fontSize: 12))),
                          GestureDetector(
                            onTap: _clearError,
                            child: const Icon(Icons.close,
                                size: 16, color: Colors.redAccent),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Name field (register only)
                    if (!isSignIn) ...[
                      _textField(_nameCtrl, 'Full Name', Icons.person_outline),
                      const SizedBox(height: 10),
                    ],

                    // Email
                    _textField(
                        _emailCtrl, 'Email Address', Icons.email_outlined,
                        type: TextInputType.emailAddress),
                    const SizedBox(height: 10),

                    // Password
                    _passwordField(_passCtrl, 'Password', _obscurePass,
                        () => setState(() => _obscurePass = !_obscurePass)),

                    // Confirm password (register only)
                    if (!isSignIn) ...[
                      const SizedBox(height: 10),
                      _passwordField(
                          _confirmCtrl,
                          'Confirm Password',
                          _obscureConfirm,
                          () => setState(
                              () => _obscureConfirm = !_obscureConfirm)),
                    ],

                    // Forgot password (sign-in only)
                    if (isSignIn) ...[
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _anyLoading ? null : _showForgotPassword,
                          style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 32)),
                          child: const Text('Forgot Password?',
                              style: TextStyle(
                                  color: Color(0xFFFF8C69), fontSize: 12)),
                        ),
                      ),
                    ] else
                      const SizedBox(height: 14),

                    // Primary CTA button
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
                        onPressed: _anyLoading
                            ? null
                            : (isSignIn ? _signIn : _createAccount),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white))
                            : Text(
                                isSignIn ? 'SIGN IN' : 'CREATE ACCOUNT',
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Divider
                    Row(children: [
                      Expanded(
                          child: Divider(color: Colors.grey.withOpacity(0.3))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text('OR',
                            style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.withOpacity(0.6))),
                      ),
                      Expanded(
                          child: Divider(color: Colors.grey.withOpacity(0.3))),
                    ]),

                    const SizedBox(height: 14),

                    // Google Sign-In
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side:
                              BorderSide(color: Colors.grey.withOpacity(0.35)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: _anyLoading ? null : _googleSignIn,
                        child: _googleLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Color(0xFF4285F4)))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Google "G" logo approximation
                                  Container(
                                    width: 22,
                                    height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: const Color(0xFF4285F4),
                                          width: 2),
                                    ),
                                    child: const Center(
                                      child: Text('G',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF4285F4))),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Text('Continue with Google',
                                      style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87)),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── Skip for Now / Guest button ────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: TextButton(
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    side: BorderSide(
                        color: const Color(0xFFAA7755).withOpacity(0.3)),
                  ),
                  onPressed: _anyLoading ? null : _skipAsGuest,
                  child: _guestLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Color(0xFFAA7755)))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.person_outline,
                                size: 18, color: Color(0xFFAA7755)),
                            const SizedBox(width: 8),
                            const Text(
                              'Skip for Now  —  Continue as Guest',
                              style: TextStyle(
                                  color: Color(0xFFAA7755),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 6),
              const Text(
                'Guest mode gives full access. Sign in anytime to backup your data.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: Colors.grey),
              ),

              const SizedBox(height: 20),

              // ── Tip of the day ─────────────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                child: Container(
                  key: ValueKey(_tipIndex),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8C69).withOpacity(0.10),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFFFF8C69).withOpacity(0.25)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tip['emoji']!, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('TIP OF THE DAY',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1,
                                  color: Color(0xFFAA5533))),
                          const SizedBox(height: 3),
                          Text(tip['tip']!,
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                  color: Color(0xFF7A3B1E),
                                  height: 1.4)),
                        ],
                      )),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Tip dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                    _tips.length,
                    (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: i == _tipIndex ? 16 : 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: i == _tipIndex
                                ? const Color(0xFFFF8C69)
                                : const Color(0xFFFF8C69).withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        )),
              ),

              const SizedBox(height: 20),
            ]),
          ),
        ),
      ]),
    );
  }

  // ── Widget helpers ────────────────────────────────────────────────────────

  Widget _modeTab(String label, int idx) {
    final active = _mode == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_mode == idx) return;
          _clearError();
          setState(() => _mode = idx);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: active ? const Color(0xFFFF8C69) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: active ? Colors.white : const Color(0xFFAA7755),
              )),
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController ctrl,
    String hint,
    IconData icon, {
    TextInputType type = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      onChanged: (_) => _clearError(),
      decoration: _inputDeco(hint, icon),
      style: const TextStyle(fontSize: 14),
    );
  }

  Widget _passwordField(
    TextEditingController ctrl,
    String hint,
    bool obscure,
    VoidCallback toggleObscure,
  ) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      onChanged: (_) => _clearError(),
      decoration: _inputDeco(hint, Icons.lock_outline,
          suffix: IconButton(
            icon: Icon(
              obscure
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 20,
              color: const Color(0xFFAA7755),
            ),
            onPressed: toggleObscure,
          )),
      style: const TextStyle(fontSize: 14),
    );
  }

  InputDecoration _inputDeco(String hint, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFFAA7755)),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFFFF5EE),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                BorderSide(color: const Color(0xFFFF8C69).withOpacity(0.2))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFFF8C69), width: 1.5)),
      );
}
