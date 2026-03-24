import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  // A controller to broadcast the connection status
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  ConnectivityService() {
    // Listen to the system's connectivity changes
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      // If the list contains 'none', we are offline
      bool isOnline = !results.contains(ConnectivityResult.none);
      _connectionController.add(isOnline);
    });
  }

  // Helper for one-time checks
  Future<bool> checkConnection() async {
    var result = await Connectivity().checkConnectivity();
    return !result.contains(ConnectivityResult.none);
  }
}