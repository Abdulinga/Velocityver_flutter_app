import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'network_discovery_service.dart';
import 'sync_service.dart';

/// Background service that automatically discovers and maintains server connection
class BackgroundDiscoveryService {
  static final BackgroundDiscoveryService _instance = BackgroundDiscoveryService._internal();
  factory BackgroundDiscoveryService() => _instance;
  BackgroundDiscoveryService._internal();

  final NetworkDiscoveryService _discoveryService = NetworkDiscoveryService();
  Timer? _discoveryTimer;
  bool _isDiscovering = false;
  String? _lastKnownServerUrl;

  /// Initialize background discovery
  Future<void> initialize() async {
    debugPrint('🚀 Initializing background discovery service...');
    
    // Try to connect immediately with known server
    await _quickConnect();
    
    // Start periodic discovery
    _startPeriodicDiscovery();
  }

  /// Quick connection attempt with known/cached server
  Future<void> _quickConnect() async {
    try {
      debugPrint('⚡ Attempting quick connection...');
      
      // Try last known server first
      final prefs = await SharedPreferences.getInstance();
      final lastServer = prefs.getString('last_server_ip');
      
      if (lastServer != null) {
        debugPrint('🎯 Testing last known server: $lastServer');
        if (await _discoveryService.testServerUrl(lastServer)) {
          debugPrint('✅ Quick connection successful: $lastServer');
          await _setServerUrl(lastServer);
          return;
        }
      }
      
      // Try hardcoded fallback
      const fallbackUrl = 'http://192.168.1.155:5000';
      debugPrint('🎯 Testing fallback server: $fallbackUrl');
      if (await _discoveryService.testServerUrl(fallbackUrl)) {
        debugPrint('✅ Fallback connection successful: $fallbackUrl');
        await _setServerUrl(fallbackUrl);
        return;
      }
      
      debugPrint('⚠️ Quick connection failed, will try full discovery');
      
      // If quick connect fails, do full discovery
      await _performFullDiscovery();
      
    } catch (e) {
      debugPrint('❌ Quick connect error: $e');
    }
  }

  /// Perform full network discovery
  Future<void> _performFullDiscovery() async {
    if (_isDiscovering) return;
    
    try {
      _isDiscovering = true;
      debugPrint('🔍 Starting full network discovery...');
      
      final serverUrl = await _discoveryService.discoverServer(
        timeout: const Duration(seconds: 15),
      );
      
      if (serverUrl != null) {
        debugPrint('🎉 Full discovery successful: $serverUrl');
        await _setServerUrl(serverUrl);
      } else {
        debugPrint('❌ Full discovery failed - no server found');
      }
      
    } catch (e) {
      debugPrint('❌ Full discovery error: $e');
    } finally {
      _isDiscovering = false;
    }
  }

  /// Set server URL and update all services
  Future<void> _setServerUrl(String serverUrl) async {
    try {
      _lastKnownServerUrl = serverUrl;
      
      // Update sync service
      SyncService.updateServerUrl(serverUrl);
      
      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      final uri = Uri.parse(serverUrl);
      await prefs.setString('server_ip', uri.host);
      await prefs.setString('server_port', uri.port.toString());
      await prefs.setString('server_url', serverUrl);
      await prefs.setString('last_server_ip', serverUrl);
      
      debugPrint('💾 Server configuration saved: $serverUrl');
      
    } catch (e) {
      debugPrint('❌ Failed to set server URL: $e');
    }
  }

  /// Start periodic discovery to maintain connection
  void _startPeriodicDiscovery() {
    // Check connection every 30 seconds
    _discoveryTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _checkAndMaintainConnection();
    });
    
    debugPrint('⏰ Periodic discovery started (30s intervals)');
  }

  /// Check current connection and rediscover if needed
  Future<void> _checkAndMaintainConnection() async {
    if (_isDiscovering) return;
    
    try {
      // Test current connection
      if (_lastKnownServerUrl != null) {
        if (await _discoveryService.testServerUrl(_lastKnownServerUrl!)) {
          // Connection is good
          return;
        }
      }
      
      debugPrint('🔄 Connection lost, attempting rediscovery...');
      await _quickConnect();
      
    } catch (e) {
      debugPrint('❌ Connection check error: $e');
    }
  }

  /// Get current server status
  Future<Map<String, dynamic>> getServerStatus() async {
    final status = <String, dynamic>{
      'connected': false,
      'serverUrl': null,
      'lastCheck': DateTime.now().toIso8601String(),
    };
    
    if (_lastKnownServerUrl != null) {
      status['serverUrl'] = _lastKnownServerUrl;
      status['connected'] = await _discoveryService.testServerUrl(_lastKnownServerUrl!);
    }
    
    return status;
  }

  /// Force rediscovery
  Future<void> forceRediscovery() async {
    debugPrint('🔄 Forcing rediscovery...');
    await _performFullDiscovery();
  }

  /// Stop background discovery
  void stop() {
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
    debugPrint('⏹️ Background discovery stopped');
  }

  /// Dispose resources
  void dispose() {
    stop();
  }
}
