// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/app_provider.dart';
import 'services/activity_log_service.dart';
import 'services/auth_service.dart';
import 'services/connectivity_service.dart';
import 'services/firebase_sync_service.dart';
import 'services/local_storage_service.dart';
import 'services/session_manager.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Hive — must initialise before anything reads local data
  await LocalStorageService.instance.init();

  // 2. Firebase — initialise once, never required for startup
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3. Auth listener
  await AuthService.instance.init();

  // 4. Connectivity watcher
  await ConnectivityService.instance.init();

  // 5. Session manager — restores last session from Hive
  await SessionManager.instance.init();

  // 6. Activity log — loads from Hive
  await ActivityLogService.instance.init();

  runApp(const PersipalApp());
}

class PersipalApp extends StatelessWidget {
  const PersipalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()..init()),
        ChangeNotifierProvider.value(value: ActivityLogService.instance),
        ChangeNotifierProvider.value(value: AuthService.instance),
        ChangeNotifierProvider.value(value: SessionManager.instance),
        ChangeNotifierProvider.value(value: ConnectivityService.instance),
        ChangeNotifierProvider.value(value: FirebaseSyncService.instance),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'PERSIPAL',
        theme: ThemeData(
          fontFamily: 'Nunito',
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFF8C69),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
