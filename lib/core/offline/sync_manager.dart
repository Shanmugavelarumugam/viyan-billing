import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SyncManager {
  static final SyncManager _instance = SyncManager._internal();
  factory SyncManager() => _instance;
  SyncManager._internal();

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  void start() {
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        _syncPendingData();
      }
    });
  }

  Future<void> _syncPendingData() async {
    final box = Hive.box('orders_box');
    if (box.isEmpty) return;

    // Simulate Syncing
    debugPrint('Syncing ${box.length} orders to remote server...');
    await Future.delayed(const Duration(seconds: 2));
    
    // Clear pending queue after successful sync
    // await box.clear();
    debugPrint('Sync Complete 🚀');
  }

  void stop() {
    _subscription?.cancel();
  }
}
