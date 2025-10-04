import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NetworkDiscoveryService {
  static final NetworkDiscoveryService _instance =
      NetworkDiscoveryService._internal();
  factory NetworkDiscoveryService() => _instance;
  NetworkDiscoveryService._internal();

  final NetworkInfo _networkInfo = NetworkInfo();

  // Common ports to check for VelocityVer server (prioritized)
  static const List<int> _commonPorts = [5000, 8080, 3000, 8000, 5001, 80, 443];

  // Server identification endpoints
  static const List<String> _identificationEndpoints = ['/health', '/api/test'];

  /// Automatically discover VelocityVer server on the local network
  Future<String?> discoverServer({
    Function(String)? onProgress,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    try {
      debugPrint('🔍 Starting smart server discovery...');
      onProgress?.call('🔍 Looking for server...');

      // Step 1: Try known good IPs first (fast path)
      final knownIPs = await _getKnownServerIPs();
      for (final ip in knownIPs) {
        debugPrint('🎯 Testing known IP: $ip');
        final result = await _testServerIP(ip);
        if (result != null) {
          debugPrint('✅ Found server at known IP: $result');
          await _saveServerIP(result);
          return result;
        }
      }

      // Step 2: Check if we have network connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult.contains(ConnectivityResult.none)) {
        debugPrint('❌ No network connection');
        return null;
      }

      // Step 3: Get current device's network info
      final networkInfo = await _getNetworkInfo();
      if (networkInfo == null) {
        debugPrint('❌ Could not get network information');
        return null;
      }

      debugPrint('🌐 Network Info: ${networkInfo.toString()}');

      // Step 4: Smart network scanning
      final serverUrl = await _smartNetworkScan(
        networkInfo,
        onProgress: onProgress,
        timeout: timeout,
      );

      if (serverUrl != null) {
        debugPrint('✅ Server discovered: $serverUrl');
        await _saveServerIP(serverUrl);
        return serverUrl;
      } else {
        debugPrint('❌ No VelocityVer server found on network');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Server discovery error: $e');
      return null;
    }
  }

  /// Get current device's network information
  Future<Map<String, dynamic>?> _getNetworkInfo() async {
    try {
      final wifiIP = await _networkInfo.getWifiIP();
      final wifiName = await _networkInfo.getWifiName();
      final wifiBSSID = await _networkInfo.getWifiBSSID();

      if (wifiIP == null || wifiIP.isEmpty) {
        return null;
      }

      // Parse IP to get subnet
      final ipParts = wifiIP.split('.');
      if (ipParts.length != 4) {
        return null;
      }

      final subnet = '${ipParts[0]}.${ipParts[1]}.${ipParts[2]}';

      return {
        'deviceIP': wifiIP,
        'wifiName': wifiName?.replaceAll('"', '') ?? 'Unknown',
        'wifiBSSID': wifiBSSID ?? 'Unknown',
        'subnet': subnet,
        'ipParts': ipParts,
      };
    } catch (e) {
      debugPrint('Error getting network info: $e');
      return null;
    }
  }

  /// Scan the network for VelocityVer servers
  Future<String?> _scanNetwork(
    Map<String, dynamic> networkInfo, {
    Function(String)? onProgress,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final subnet = networkInfo['subnet'] as String;
    final deviceIP = networkInfo['deviceIP'] as String;

    // Create list of IPs to scan (prioritize common server IPs)
    final ipsToScan = _generateScanIPs(subnet, deviceIP);

    onProgress?.call(
      '🔍 Scanning ${ipsToScan.length} IPs across ${_commonPorts.length} ports...',
    );

    // Use parallel scanning with limited concurrency
    final completer = Completer<String?>();
    var completed = 0;
    var found = false;

    // Scan in batches to avoid overwhelming the network
    const batchSize = 10;
    for (int i = 0; i < ipsToScan.length; i += batchSize) {
      if (found) break;

      final batch = ipsToScan.skip(i).take(batchSize).toList();
      final futures = batch
          .map((ip) => _scanIPForServer(ip, onProgress))
          .toList();

      final results = await Future.wait(futures);

      for (final result in results) {
        completed++;
        if (result != null && !found) {
          found = true;
          completer.complete(result);
          break;
        }
      }

      if (!found) {
        final progress =
            ((completed / (ipsToScan.length * _commonPorts.length)) * 100)
                .round();
        onProgress?.call('🔍 Scanning... ${progress}% complete');
      }

      // Small delay between batches
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (!found) {
      completer.complete(null);
    }

    return completer.future.timeout(timeout, onTimeout: () => null);
  }

  /// Generate list of IPs to scan (prioritized)
  List<String> _generateScanIPs(String subnet, String deviceIP) {
    final ips = <String>[];

    debugPrint('🌐 Device IP: $deviceIP, Subnet: $subnet');

    // Priority 1: Common server IPs (most likely to host servers)
    final priorityIPs = [
      '1',
      '100',
      '101',
      '102',
      '150',
      '151',
      '152',
      '153',
      '154',
      '155',
      '156',
      '157',
      '158',
      '159',
      '160',
      '200',
      '254',
    ];
    for (final lastOctet in priorityIPs) {
      final ip = '$subnet.$lastOctet';
      if (ip != deviceIP) {
        ips.add(ip);
        debugPrint('🎯 Priority IP: $ip');
      }
    }

    // Priority 2: IPs around device IP (±20 range)
    final deviceLastOctet = int.tryParse(deviceIP.split('.').last) ?? 0;
    debugPrint('📱 Device last octet: $deviceLastOctet');

    for (int offset = 1; offset <= 20; offset++) {
      for (final delta in [offset, -offset]) {
        final targetOctet = deviceLastOctet + delta;
        if (targetOctet >= 1 && targetOctet <= 254) {
          final ip = '$subnet.$targetOctet';
          if (!ips.contains(ip) && ip != deviceIP) {
            ips.add(ip);
            debugPrint('🔍 Nearby IP: $ip');
          }
        }
      }
    }

    // Priority 3: Full range scan (comprehensive but limited)
    for (int i = 1; i <= 254; i++) {
      final ip = '$subnet.$i';
      if (!ips.contains(ip) && ip != deviceIP) {
        ips.add(ip);
      }
      // Limit total IPs to scan to avoid taking too long
      if (ips.length >= 100) break;
    }

    debugPrint('📋 Total IPs to scan: ${ips.length}');
    debugPrint('🔍 First 10 IPs: ${ips.take(10).join(', ')}');

    return ips;
  }

  /// Scan a specific IP for VelocityVer server
  Future<String?> _scanIPForServer(
    String ip,
    Function(String)? onProgress,
  ) async {
    debugPrint('🔍 Scanning IP: $ip');

    for (final port in _commonPorts) {
      try {
        final serverUrl = 'http://$ip:$port';
        debugPrint('🔌 Testing: $serverUrl');

        // Quick health check
        final response = await http
            .get(
              Uri.parse('$serverUrl/health'),
              headers: {'Content-Type': 'application/json'},
            )
            .timeout(const Duration(seconds: 3));

        debugPrint('📡 Response from $serverUrl: ${response.statusCode}');

        if (response.statusCode == 200) {
          debugPrint('✅ Health check passed for $serverUrl');

          // Verify it's actually VelocityVer server
          if (await _verifyVelocityVerServer(serverUrl)) {
            debugPrint('🎉 Found VelocityVer server at: $serverUrl');
            onProgress?.call('🎉 Found server at $serverUrl');
            return serverUrl;
          } else {
            debugPrint('⚠️ Server at $serverUrl is not VelocityVer');
          }
        }
      } catch (e) {
        debugPrint('❌ Failed to connect to $ip:$port - $e');
        // Ignore connection errors, continue scanning
        continue;
      }
    }
    debugPrint('❌ No VelocityVer server found on $ip');
    return null;
  }

  /// Verify that the discovered server is actually VelocityVer
  Future<bool> _verifyVelocityVerServer(String serverUrl) async {
    try {
      // Check multiple endpoints to confirm it's VelocityVer
      for (final endpoint in _identificationEndpoints) {
        final response = await http
            .get(
              Uri.parse('$serverUrl$endpoint'),
              headers: {'Content-Type': 'application/json'},
            )
            .timeout(const Duration(seconds: 3));

        if (response.statusCode != 200) {
          return false;
        }
      }

      // If all endpoints respond correctly, it's likely VelocityVer
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Quick test if a specific server URL is reachable
  Future<bool> testServerUrl(String serverUrl) async {
    try {
      final response = await http
          .get(
            Uri.parse('$serverUrl/health'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Get list of known/previously working server IPs
  Future<List<String>> _getKnownServerIPs() async {
    final prefs = await SharedPreferences.getInstance();
    final knownIPs = <String>[];

    // Add last known working IP
    final lastIP = prefs.getString('last_server_ip');
    if (lastIP != null) {
      knownIPs.add(lastIP);
    }

    // Add your specific server IP first (router always assigns this to your PC)
    knownIPs.add('http://192.168.1.155:5000');

    // Add other common IPs based on typical router assignments
    knownIPs.addAll([
      'http://192.168.1.100:5000',
      'http://192.168.1.1:5000',
      'http://192.168.1.101:5000',
      'http://192.168.1.102:5000',
      'http://192.168.0.155:5000', // In case router uses 192.168.0.x
      'http://192.168.0.100:5000',
      'http://192.168.0.1:5000',
    ]);

    return knownIPs;
  }

  /// Test a specific server IP quickly
  Future<String?> _testServerIP(String serverUrl) async {
    try {
      debugPrint('🔌 Quick test: $serverUrl');
      final response = await http
          .get(
            Uri.parse('$serverUrl/health'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        // Verify it's VelocityVer
        if (await _verifyVelocityVerServer(serverUrl)) {
          return serverUrl;
        }
      }
    } catch (e) {
      debugPrint('❌ Quick test failed for $serverUrl: $e');
    }
    return null;
  }

  /// Save working server IP for future use
  Future<void> _saveServerIP(String serverUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_server_ip', serverUrl);
      debugPrint('💾 Saved working server IP: $serverUrl');
    } catch (e) {
      debugPrint('❌ Failed to save server IP: $e');
    }
  }

  /// Smart network scanning with prioritized IPs
  Future<String?> _smartNetworkScan(
    Map<String, dynamic> networkInfo, {
    Function(String)? onProgress,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final subnet = networkInfo['subnet'] as String;
    final deviceIP = networkInfo['deviceIP'] as String;

    // Create prioritized IP list
    final priorityIPs = _generateSmartScanIPs(subnet, deviceIP);

    debugPrint('🎯 Smart scanning ${priorityIPs.length} priority IPs...');

    // Scan in small batches for speed
    const batchSize = 5;
    for (int i = 0; i < priorityIPs.length; i += batchSize) {
      final batch = priorityIPs.skip(i).take(batchSize).toList();

      // Test batch in parallel
      final futures = batch
          .map((ip) => _scanIPForServer(ip, onProgress))
          .toList();
      final results = await Future.wait(futures);

      // Return first successful result
      for (final result in results) {
        if (result != null) {
          return result;
        }
      }

      // Progress update
      final progress = ((i + batchSize) / priorityIPs.length * 100).round();
      onProgress?.call('🔍 Scanning... ${progress}% complete');

      // Small delay between batches
      await Future.delayed(const Duration(milliseconds: 100));
    }

    return null;
  }

  /// Generate smart IP list based on network analysis
  List<String> _generateSmartScanIPs(String subnet, String deviceIP) {
    final ips = <String>[];
    final deviceLastOctet = int.tryParse(deviceIP.split('.').last) ?? 0;

    // Priority 1: Your specific range (150-160)
    for (int i = 150; i <= 160; i++) {
      ips.add('$subnet.$i');
    }

    // Priority 2: Common server IPs
    final commonOctets = [1, 100, 101, 102, 200, 254];
    for (final octet in commonOctets) {
      final ip = '$subnet.$octet';
      if (!ips.contains(ip)) {
        ips.add(ip);
      }
    }

    // Priority 3: Around device IP
    for (int offset = 1; offset <= 10; offset++) {
      for (final delta in [offset, -offset]) {
        final targetOctet = deviceLastOctet + delta;
        if (targetOctet >= 1 && targetOctet <= 254) {
          final ip = '$subnet.$targetOctet';
          if (!ips.contains(ip) && ip != deviceIP) {
            ips.add(ip);
          }
        }
      }
    }

    debugPrint('🎯 Generated ${ips.length} priority IPs for scanning');
    return ips.take(50).toList(); // Limit to 50 for speed
  }
}
