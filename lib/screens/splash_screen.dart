// screens/splash_screen.dart
//
// Shows the Persipal brand for ~2.4s, then goes to HomeScreen.
//
// SessionManager.init() (awaited in main() before runApp) always leaves a
// session in place by the time this navigates — a brand-new install gets
// an auto-created guest session rather than being routed to LoginScreen.
// The LoginScreen fallback below only matters if that invariant is ever
// broken. Firebase is NEVER awaited here.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/session_manager.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'verify_email_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;
  late Animation<double> _slide;

  int _catFrame = 0;

  // Splash-only performance fix: the original sequence had 141 full-size
  // PNG frames (~72MB) all decoded into memory at once for a splash shown
  // for well under 3 seconds — only a fraction of them were ever actually
  // seen. This keeps every 4th frame (36 total), evenly sampled across the
  // full original animation so the same motion/visual identity is
  // preserved, just at a lower temporal resolution. Does not touch any
  // virtual-cat asset folder — only assets/images/splash_cat/.
  static const List<int> _frameNumbers = [
    1, 5, 9, 13, 17, 21, 25, 29, 33, 37, 41, 45, 49, 53, 57, 61, 65, 69, 73,
    77, 81, 85, 89, 93, 97, 101, 105, 109, 113, 117, 121, 125, 129, 133, 137,
    141,
  ];
  int get totalFrames => _frameNumbers.length;
  Timer? _catTimer;

  final List<Widget> _catImages = [];
  bool _framesLoaded = false;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _scale = Tween<double>(begin: 0.82, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _slide = Tween<double>(begin: 28, end: 0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    _ctrl.forward();

    _loadCatFrames();

    Future.delayed(
      const Duration(milliseconds: 2800),
      _navigate,
    );
  }

  Future<void> _loadCatFrames() async {
    for (final n in _frameNumbers) {
      final asset = await rootBundle.load(
        'assets/images/splash_cat/frame_${n.toString().padLeft(4, '0')}.png',
      );

      _catImages.add(
        Image.memory(
          asset.buffer.asUint8List(),
          fit: BoxFit.contain,
          gaplessPlayback: true,
          filterQuality: FilterQuality.high,
        ),
      );
    }

    if (!mounted) return;

    setState(() {
      _framesLoaded = true;
    });

    _startCatAnimation();
  }

  void _startCatAnimation() {
    _catTimer = Timer.periodic(
      const Duration(milliseconds: 60),
      (timer) {
        if (!mounted) return;

        setState(() {
          _catFrame = (_catFrame + 1) % totalFrames;
        });
      },
    );
  }

  @override
  void dispose() {
    _catTimer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    await _ctrl.reverse();
    if (!mounted) return;

    final hasSession = SessionManager.instance.hasSession;
    // Catches an authenticated-but-unverified user reopening the app —
    // Firebase persists sign-in state locally regardless of verification,
    // so without this check they could bypass VerifyEmailScreen just by
    // restarting. Google sign-ins are never affected (already verified).
    final needsVerification = AuthService.instance.needsEmailVerification;

    Widget destination;
    if (!hasSession) {
      destination = const LoginScreen();
    } else if (needsVerification) {
      destination = const VerifyEmailScreen();
    } else {
      destination = const HomeScreen();
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) => destination,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE6CC),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.10,
              child:
                  Image.asset('assets/images/paws_bg.png', fit: BoxFit.cover),
            ),
          ),
          const Positioned(
            top: 56,
            left: 0,
            right: 0,
            child: Icon(Icons.pets, size: 40, color: Color(0xFFFF8C69)),
          ),
          Center(
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => FadeTransition(
                opacity: _fade,
                child: Transform.scale(
                  scale: _scale.value,
                  child: Transform.translate(
                    offset: Offset(0, _slide.value),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 240,
                          height: 240,
                          decoration: const BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 18,
                                spreadRadius: 1,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: RepaintBoundary(
                            child: SizedBox(
                              width: 240,
                              height: 240,
                              child: _framesLoaded
                                  ? _catImages[_catFrame]
                                  : const CircularProgressIndicator(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'PERSIPAL',
                          style: TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            color: Color(0xFF7A3B1E),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Persian Cat Care Companion',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFFAA7755),
                            fontStyle: FontStyle.italic,
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 48),
                        SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                const Color(0xFFFF8C69)
                                    .withValues(alpha: 0.65)),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text('Loading…',
                            style: TextStyle(
                                fontSize: 12, color: Color(0xFFAA7755))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
