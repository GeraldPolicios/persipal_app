import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const PersipalApp());
}

class PersipalApp extends StatelessWidget {
  const PersipalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PERSIPAL',
      theme: ThemeData(fontFamily: 'Arial'),
      home: const SplashScreen(),
    );
  }
}
