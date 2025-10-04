import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'sync_service.dart';

enum NetworkStatus { online, offline, unknown }

class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final SyncService _syncService = SyncService();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  NetworkStatus _status = NetworkStatus.unknown;
  bool _isServerReachable = false;
  DateTime? _lastConnectedTime;
  DateTime? _lastSyncAttempt;

  NetworkStatus get status => _status;
  bool get isOnline => _status == NetworkStatus.online;
  bool get isOffline => _status == NetworkStatus.offline;
  bool get isServerReachable => _isServerReachable;
  DateTime? get lastConnectedTime => _lastConnectedTime;
  DateTime? get lastSyncAttempt => _lastSyncAttempt;

  Future<void> initialize() async {
    await _checkInitialConnectivity();
    _startListening();
  }

  void _startListening() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        final result = results.isNotEmpty
            ? results.first
            : ConnectivityResult.none;
        _onConnectivityChanged(result);
      },
      onError: (error) {
        print('Connectivity stream error: $error');
      },
    );
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final result = results.isNotEmpty
          ? results.first
          : ConnectivityResult.none;
      await _onConnectivityChanged(result);
    } catch (e) {
      print('Error checking initial connectivity: $e');
      _updateStatus(NetworkStatus.unknown);
    }
  }

  Future<void> _onConnectivityChanged(ConnectivityResult result) async {
    print('Connectivity changed: $result');

    if (result == ConnectivityResult.none) {
      _updateStatus(NetworkStatus.offline);
      _isServerReachable = false;
    } else {
      // Check if server is actually reachable
      final serverReachable = await _checkServerConnectivity();
      _isServerReachable = serverReachable;

      if (serverReachable) {
        _updateStatus(NetworkStatus.online);
        _lastConnectedTime = DateTime.now();

        // Trigger sync when coming online
        _triggerAutoSync();
      } else {
        _updateStatus(NetworkStatus.offline);
      }
    }
  }

  Future<bool> _checkServerConnectivity() async {
    try {
      return await _syncService.isConnected();
    } catch (e) {
      print('Server connectivity check failed: $e');
      return false;
    }
  }

  void _updateStatus(NetworkStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      notifyListeners();
      print('Network status updated: $newStatus');
    }
  }

  void _triggerAutoSync() {
    // Avoid too frequent sync attempts
    final now = DateTime.now();
    if (_lastSyncAttempt != null) {
      final timeSinceLastSync = now.difference(_lastSyncAttempt!);
      if (timeSinceLastSync.inMinutes < 1) {
        print('Skipping auto-sync, too soon since last attempt');
        return;
      }
    }

    _lastSyncAttempt = now;

    // Delay sync to ensure connection is stable
    Future.delayed(const Duration(seconds: 3), () async {
      if (isOnline && _isServerReachable) {
        print('Triggering auto-sync...');
        final success = await _syncService.performSync();
        if (success) {
          print('Auto-sync completed successfully');
        } else {
          print('Auto-sync failed');
        }
      }
    });
  }

  // Manual connectivity check
  Future<bool> checkConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final result = results.isNotEmpty
          ? results.first
          : ConnectivityResult.none;
      await _onConnectivityChanged(result);
      return isOnline;
    } catch (e) {
      print('Manual connectivity check failed: $e');
      return false;
    }
  }

  // Force sync if online
  Future<bool> forceSyncIfOnline() async {
    if (!isOnline) {
      print('Cannot sync: offline');
      return false;
    }

    _lastSyncAttempt = DateTime.now();
    return await _syncService.performSync();
  }

  // Get connection info
  Map<String, dynamic> getConnectionInfo() {
    return {
      'status': _status.toString(),
      'isOnline': isOnline,
      'isServerReachable': _isServerReachable,
      'lastConnectedTime': _lastConnectedTime?.toIso8601String(),
      'lastSyncAttempt': _lastSyncAttempt?.toIso8601String(),
      'isSyncing': _syncService.isSyncing,
      'lastSyncTime': _syncService.lastSyncTime?.toIso8601String(),
    };
  }

  // Get network type
  Future<String> getNetworkType() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final result = results.isNotEmpty
          ? results.first
          : ConnectivityResult.none;
      switch (result) {
        case ConnectivityResult.wifi:
          return 'WiFi';
        case ConnectivityResult.mobile:
          return 'Mobile Data';
        case ConnectivityResult.ethernet:
          return 'Ethernet';
        case ConnectivityResult.bluetooth:
          return 'Bluetooth';
        case ConnectivityResult.vpn:
          return 'VPN';
        case ConnectivityResult.none:
          return 'No Connection';
        default:
          return 'Unknown';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  // Check if on WiFi (preferred for large file syncs)
  Future<bool> isOnWiFi() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result.contains(ConnectivityResult.wifi);
    } catch (e) {
      return false;
    }
  }

  // Check if on mobile data
  Future<bool> isOnMobileData() async {
    try {
      final result = await _connectivity.checkConnectivity();
      return result.contains(ConnectivityResult.mobile);
    } catch (e) {
      return false;
    }
  }

  // Get time since last connection
  Duration? getTimeSinceLastConnection() {
    if (_lastConnectedTime == null) return null;
    return DateTime.now().difference(_lastConnectedTime!);
  }

  // Get time since last sync attempt
  Duration? getTimeSinceLastSyncAttempt() {
    if (_lastSyncAttempt == null) return null;
    return DateTime.now().difference(_lastSyncAttempt!);
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
