// lib/services/connectivity_service.dart
//
// Monitors network connectivity and notifies listeners.
// Used by the AppProvider to decide whether to sync with Firestore.

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService extends ChangeNotifier {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool get isOnline => _isOnline;
  bool get isOffline => !_isOnline;

  Future<void> init() async {
    try {
      // Check immediately.
      final results = await Connectivity().checkConnectivity();
      _isOnline = _hasConnection(results);

      // Subscribe to changes.
      _sub = Connectivity().onConnectivityChanged.listen(
        (results) {
          final online = _hasConnection(results);
          if (online != _isOnline) {
            _isOnline = online;
            notifyListeners();
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          // Connectivity is a convenience for sync decisions, not a
          // requirement for launching the local-first app.
          debugPrint('Persipal: connectivity updates unavailable: $error');
          if (_isOnline) {
            _isOnline = false;
            notifyListeners();
          }
        },
      );
    } catch (error, stackTrace) {
      // If the platform connectivity plugin fails during startup, continue
      // in offline mode instead of preventing runApp() from being reached.
      _isOnline = false;
      debugPrint(
          'Persipal: connectivity check unavailable; using offline mode: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  bool _hasConnection(List<ConnectivityResult> results) => results.any((r) =>
      r == ConnectivityResult.mobile ||
      r == ConnectivityResult.wifi ||
      r == ConnectivityResult.ethernet);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
