// screens/splash_screen.dart
//
// Shows the Persipal brand for ~2.4s, then:
//   • If a session (guest or auth) exists in Hive → HomeScreen
//   • Otherwise → LoginScreen
// Firebase is NEVER awaited here.

import 'dart:async';
import 'package:flutter/material.dart';
import '../services/session_manager.dart';
import 'home_screen.dart';
import 'login_screen.dart';

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
    Future.delayed(const Duration(milliseconds: 2400), _navigate);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _navigate() async {
    if (!mounted) return;
    await _ctrl.reverse();
    if (!mounted) return;

    final hasSession = SessionManager.instance.hasSession;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) =>
            hasSession ? const HomeScreen() : const LoginScreen(),
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
                        Image.asset('assets/images/cat_normal_clean.png',
                            height: 210),
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
                                const Color(0xFFFF8C69).withOpacity(0.65)),
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
