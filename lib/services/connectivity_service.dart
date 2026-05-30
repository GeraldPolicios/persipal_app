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
    // Check immediately
    final results = await Connectivity().checkConnectivity();
    _isOnline = _hasConnection(results);

    // Subscribe to changes
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      final online = _hasConnection(results);
      if (online != _isOnline) {
        _isOnline = online;
        notifyListeners();
      }
    });
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
