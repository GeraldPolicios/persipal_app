import 'dart:async';
import 'package:flutter/material.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Animation setup
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(_controller);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(_controller);

    // Navigate after delay
    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;

      await _controller.forward(); // play animation

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.98, end: 1.0).animate(animation),
                child: child,
              ),
            );
          },
        ),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE6CC),

      body: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Stack(
            children: [
              // paw background
              Positioned.fill(
                child: Opacity(
                  opacity: 0.10,
                  child: Image.asset(
                    "assets/images/paws_bg.png",
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              // top paw icon
              const Positioned(
                top: 60,
                left: 0,
                right: 0,
                child: Icon(Icons.pets, size: 45),
              ),

              // content
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset('assets/images/cat_normal.png', height: 250),

                    const SizedBox(height: 20),

                    const Text(
                      "PERSIPAL",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      "Learn Persian Cat Care",
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 50),

                    const CircularProgressIndicator(),

                    const SizedBox(height: 10),

                    const Text("Loading..."),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
